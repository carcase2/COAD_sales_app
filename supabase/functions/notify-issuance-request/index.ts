import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9'

serve(async (req) => {
  try {
    const payload = await req.json()
    const record = (payload.record ?? {}) as Record<string, unknown>

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { data: users, error: userError } = await supabaseAdmin
      .from('users')
      .select('id, name, role, fcm_token')
      .not('fcm_token', 'is', null)

    if (userError) throw userError

    const tokens = Array.from(
      new Set(
        (users ?? [])
          .map((u) => (u.fcm_token ?? '').trim())
          .filter((t) => t.length > 5),
      ),
    )

    if (tokens.length === 0) {
      console.log('No users with FCM tokens found for issuance request')
      return new Response(JSON.stringify({ message: 'No target users found' }), {
        status: 200,
      })
    }

    const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')
    const FIREBASE_SERVICE_ACCOUNT = JSON.parse(
      Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}',
    )

    const auth = new GoogleAuth({
      credentials: FIREBASE_SERVICE_ACCOUNT,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })

    const client = await auth.getClient()
    const accessTokenResponse = await client.getAccessToken()
    const accessToken = accessTokenResponse.token

    if (!accessToken) {
      throw new Error('Failed to get FCM access token')
    }

    const domain = (record.issuance_domain ?? 'taxInvoice').toString()
    const masterId = (record.master_id ?? '').toString()
    const issueId = (record.issue_id ?? '').toString()
    const title = (record.title ?? '발급요청').toString()
    const body = (record.body ?? '새 발급요청이 등록되었습니다.').toString()
    const dataBody = body.replace(/\s+/g, ' ').trim()

    if (!masterId) {
      return new Response(JSON.stringify({ error: 'Missing master_id' }), {
        status: 400,
      })
    }

    console.log(
      `Sending issuance request push: domain=${domain} masterId=${masterId} issueId=${issueId}`,
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
                    type: 'issuance_request',
                    issuance_domain: domain,
                    master_id: masterId,
                    issue_id: issueId,
                    title,
                    body: dataBody,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                  },
                  android: {
                    priority: 'high',
                  },
                },
              }),
            },
          )
          const resText = await res.text()
          console.log(`FCM Response (Status: ${res.status}):`, resText)
          return { status: res.status, body: resText }
        } catch (e: unknown) {
          const msg = e instanceof Error ? e.message : String(e)
          console.error('FCM error:', msg)
          return { error: msg }
        }
      }),
    )

    return new Response(
      JSON.stringify({
        success: true,
        recipientCount: tokens.length,
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
