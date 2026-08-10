import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9'

type PushUser = {
  id: string
  name: string
  fcm_token?: string | null
}

/** 유저별 활성 기기 토큰 전부 + 레거시 users.fcm_token (중복 제거) */
async function resolvePushTokens(
  supabaseAdmin: ReturnType<typeof createClient>,
  users: PushUser[],
): Promise<string[]> {
  const userIds = Array.from(
    new Set(users.map((u) => (u.id ?? '').toString()).filter((id) => id.length > 0)),
  )
  if (userIds.length === 0) return []

  const { data: tokenRows, error: tokenError } = await supabaseAdmin
    .from('user_push_tokens')
    .select('fcm_token')
    .in('user_id', userIds)
    .eq('is_active', true)
    .not('fcm_token', 'is', null)

  if (tokenError) {
    console.error('Error loading user_push_tokens:', tokenError)
  }

  const tableTokens = (tokenRows ?? [])
    .map((r) => (r?.fcm_token ?? '').toString().trim())
    .filter((t) => t.length > 5)

  const legacyTokens = users
    .map((u) => (u.fcm_token ?? '').toString().trim())
    .filter((t) => t.length > 5)

  return Array.from(new Set([...tableTokens, ...legacyTokens]))
}

async function deactivateInvalidToken(
  supabaseAdmin: ReturnType<typeof createClient>,
  token: string,
): Promise<void> {
  try {
    await supabaseAdmin
      .from('user_push_tokens')
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .eq('fcm_token', token)
    await supabaseAdmin
      .from('users')
      .update({ fcm_token: null })
      .eq('fcm_token', token)
  } catch (e) {
    console.error('Failed to deactivate invalid token:', e)
  }
}

serve(async (req) => {
  try {
    const body = await req.json().catch(() => ({}))
    const latestVersion = String(body.latest_version ?? '').trim()
    const minVersion = String(body.min_version ?? latestVersion).trim()
    const storeUrl = String(
      body.store_url ?? 'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
    ).trim()

    if (!latestVersion) {
      return new Response(JSON.stringify({ error: 'latest_version is required' }), {
        headers: { "Content-Type": "application/json" },
        status: 400,
      })
    }

    const title = String(body.title ?? '새 버전 업데이트 안내').trim()
    const message = String(
      body.message ?? `최신 버전(v${latestVersion})이 배포되었습니다. 설정 > 업데이트 확인에서 확인해 주세요.`,
    ).trim()

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // 활성 유저 전부 — fcm_token 유무와 무관 (기기별 토큰은 user_push_tokens)
    const { data: users, error: userError } = await supabaseAdmin
      .from('users')
      .select('id, name, fcm_token')

    if (userError) throw userError

    const tokens = await resolvePushTokens(supabaseAdmin, (users ?? []) as PushUser[])

    if (tokens.length === 0) {
      return new Response(JSON.stringify({ success: true, message: 'No fcm tokens found', count: 0 }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      })
    }

    const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')
    const FIREBASE_SERVICE_ACCOUNT = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}')
    const auth = new GoogleAuth({
      credentials: FIREBASE_SERVICE_ACCOUNT,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })

    const client = await auth.getClient()
    const accessToken = (await client.getAccessToken()).token
    if (!accessToken) throw new Error('Failed to get FCM access token')

    const results = await Promise.all(tokens.map(async (token: string) => {
      try {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
          {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              message: {
                token,
                notification: {
                  title,
                  body: message,
                },
                data: {
                  type: 'app_update',
                  action: 'open_update',
                  latest_version: latestVersion,
                  min_version: minVersion,
                  store_url: storeUrl,
                  click_action: 'FLUTTER_NOTIFICATION_CLICK',
                },
                android: {
                  priority: 'high',
                  notification: {
                    channel_id: 'high_importance_channel',
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                  },
                },
                apns: {
                  headers: {
                    'apns-push-type': 'alert',
                    'apns-priority': '10',
                  },
                  payload: {
                    aps: {
                      alert: {
                        title,
                        body: message,
                      },
                      sound: 'default',
                    },
                  },
                },
              },
            }),
          },
        )
        const text = await res.text()
        if (res.status === 404 && text.includes('UNREGISTERED')) {
          await deactivateInvalidToken(supabaseAdmin, token)
        }
        return { status: res.status, body: text }
      } catch (e: any) {
        return { error: e.message ?? String(e) }
      }
    }))

    return new Response(JSON.stringify({ success: true, count: tokens.length, results }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message ?? String(error) }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})
