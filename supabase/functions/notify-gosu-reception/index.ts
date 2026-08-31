import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9'

const GOSU_GROUP = '자동문의고수'

type PushUser = {
  id: string
  name: string
  role: string
  fcm_token?: string | null
  is_active?: boolean | null
  group_id?: string | null
  groups?: { name?: string | null } | null
}

function isAdminUser(u: PushUser): boolean {
  const role = (u.role ?? '').toString().trim().toLowerCase()
  const groupName = (u.groups?.name ?? '').toString().trim()
  return role === 'admin' || groupName === '관리자'
}

function isGosuDeptUser(u: PushUser, gosuGroupIds: Set<string>): boolean {
  const groupName = (u.groups?.name ?? '').toString().trim()
  if (groupName === GOSU_GROUP) return true
  const gid = (u.group_id ?? '').toString().trim()
  return gid.length > 0 && gosuGroupIds.has(gid)
}

async function loadGosuGroupIds(
  supabaseAdmin: ReturnType<typeof createClient>,
): Promise<Set<string>> {
  const { data, error } = await supabaseAdmin
    .from('groups')
    .select('id')
    .eq('name', GOSU_GROUP)
  if (error) {
    console.error('Error loading gosu groups:', error)
    return new Set()
  }
  return new Set(
    (data ?? [])
      .map((g) => (g?.id ?? '').toString().trim())
      .filter((id) => id.length > 0),
  )
}

async function loadGosuMemberUserIds(
  supabaseAdmin: ReturnType<typeof createClient>,
  gosuGroupIds: Set<string>,
): Promise<Set<string>> {
  if (gosuGroupIds.size === 0) return new Set()
  try {
    const { data, error } = await supabaseAdmin
      .from('user_groups')
      .select('user_id')
      .in('group_id', Array.from(gosuGroupIds))
    if (error) {
      console.error('Error loading gosu user_groups:', error)
      return new Set()
    }
    return new Set(
      (data ?? [])
        .map((r) => (r?.user_id ?? '').toString().trim())
        .filter((id) => id.length > 0),
    )
  } catch (e) {
    console.error('user_groups lookup failed:', e)
    return new Set()
  }
}

async function resolveGosuReceptionUsers(
  supabaseAdmin: ReturnType<typeof createClient>,
): Promise<PushUser[]> {
  const gosuGroupIds = await loadGosuGroupIds(supabaseAdmin)
  const memberIds = await loadGosuMemberUserIds(supabaseAdmin, gosuGroupIds)

  const { data: users, error } = await supabaseAdmin
    .from('users')
    .select('id, name, role, fcm_token, is_active, group_id, groups(name)')

  if (error) throw error

  const byId = new Map<string, PushUser>()
  for (const raw of users ?? []) {
    const u = raw as PushUser
    const id = (u.id ?? '').toString().trim()
    if (!id) continue
    if (u.is_active === false) continue
    const allowed =
      isAdminUser(u) || isGosuDeptUser(u, gosuGroupIds) || memberIds.has(id)
    if (!allowed) continue
    byId.set(id, u)
  }
  return Array.from(byId.values())
}

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
    await supabaseAdmin.from('users').update({ fcm_token: null }).eq('fcm_token', token)
  } catch (e) {
    console.error('Failed to deactivate invalid token:', e)
  }
}

serve(async (req) => {
  try {
    const payload = await req.json()
    const record = (payload?.record ?? payload ?? {}) as Record<string, unknown>
    const gosuId = (record.id ?? record.gosu_id ?? '').toString().trim()
    if (!gosuId) {
      return new Response(JSON.stringify({ error: 'Missing gosu call id' }), { status: 400 })
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const users = await resolveGosuReceptionUsers(supabaseAdmin)
    if (users.length === 0) {
      return new Response(JSON.stringify({ message: 'No gosu/admin users found' }), {
        status: 200,
      })
    }

    const tokens = await resolvePushTokens(supabaseAdmin, users)
    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({
          message: 'No FCM tokens for gosu/admin recipients',
          recipientUsers: users.map((u) => u.name),
        }),
        { status: 200 },
      )
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

    const customerName = (record.customer_name ?? '이름없음').toString()
    const phone = (record.customer_phone ?? '').toString()
    const createdBy = (record.created_by ?? '').toString().trim()
    const assignedTo = (record.assigned_to ?? '').toString().trim()
    const content = (record.inquiry_content ?? '').toString().replace(/\s+/g, ' ').trim()
    const sido = (record.region_sido ?? '').toString().trim()
    const regionName = (record.region_name ?? '').toString().trim()
    const regionText =
      sido && regionName ? `[${sido}]${regionName}` : sido || regionName

    const title = `[자동문의고수] ${customerName}`
    const body = [
      phone ? `📞 ${phone}` : '',
      assignedTo ? `담당 ${assignedTo}` : '',
      createdBy && createdBy !== assignedTo ? `작성 ${createdBy}` : '',
      regionText ? `📍 ${regionText}` : '',
      content ? `📝 ${content}` : '새 자동문의고수 접수가 등록되었습니다.',
    ]
      .filter((s) => s.length > 0)
      .join(' · ')

    console.log(
      `Gosu push gosuId=${gosuId} users=${users.map((u) => u.name).join(',')} tokens=${tokens.length}`,
    )

    const results = await Promise.all(
      tokens.map(async (token: string) => {
        try {
          const res = await fetch(
            `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
            {
              method: 'POST',
              headers: {
                Authorization: `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                message: {
                  token,
                  data: {
                    type: 'gosu_reception',
                    gosu_id: gosuId,
                    title,
                    body,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                  },
                  android: { priority: 'high' },
                  apns: {
                    headers: {
                      'apns-push-type': 'alert',
                      'apns-priority': '10',
                    },
                    payload: {
                      aps: {
                        alert: { title, body },
                        sound: 'default',
                      },
                    },
                  },
                },
              }),
            },
          )
          const resText = await res.text()
          console.log(`FCM Response (Status: ${res.status}):`, resText)
          if (res.status === 404 && resText.includes('UNREGISTERED')) {
            await deactivateInvalidToken(supabaseAdmin, token)
          }
          return { status: res.status, body: resText }
        } catch (e: unknown) {
          const msg = e instanceof Error ? e.message : String(e)
          return { error: msg }
        }
      }),
    )

    return new Response(
      JSON.stringify({
        success: true,
        recipientCount: tokens.length,
        recipientUsers: users.map((u) => u.name),
        results,
      }),
      { headers: { 'Content-Type': 'application/json' }, status: 200 },
    )
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error)
    console.error('Error:', msg)
    return new Response(JSON.stringify({ error: msg }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
