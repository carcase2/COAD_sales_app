import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9'

type NotifyPayload = {
  domain: string
  masterId: string
  issueId: string
  title: string
  body: string
}

function hasText(value: unknown): boolean {
  return (value ?? '').toString().trim().length > 0
}

function buildFromAppRecord(record: Record<string, unknown>): NotifyPayload | null {
  const masterId = (record.master_id ?? '').toString().trim()
  if (!masterId) return null
  return {
    domain: (record.issuance_domain ?? 'taxInvoice').toString(),
    masterId,
    issueId: (record.issue_id ?? '').toString(),
    title: (record.title ?? '발급요청').toString(),
    body: (record.body ?? '새 발급요청이 등록되었습니다.').toString(),
  }
}

async function buildFromTaxInvoiceIssue(
  supabaseAdmin: ReturnType<typeof createClient>,
  issue: Record<string, unknown>,
): Promise<NotifyPayload | null> {
  if (hasText(issue.invoice_image_url)) return null

  const masterId = (issue.tax_invoice_id ?? '').toString().trim()
  if (!masterId) return null

  const { data: invoice } = await supabaseAdmin
    .from('tax_invoices')
    .select('customer_name, status')
    .eq('id', masterId)
    .maybeSingle()

  const name = (invoice?.customer_name ?? '요청 건').toString()
  const statusRaw = (invoice?.status ?? '').toString().toLowerCase()
  const isPartial = statusRaw === 'in_progress'
  const isUrgent = issue.is_urgent === true
  const pct = issue.percentage
  const pctNum = typeof pct === 'number' ? pct : Number(pct)

  const urgentPrefix = isUrgent ? '🚨 [긴급] ' : ''
  const partialLabel = isPartial ? ' 부분' : ''
  const title = `${urgentPrefix}세금계산서${partialLabel} 발급요청`
  const body =
    isPartial && !Number.isNaN(pctNum)
      ? `${name} · ${Math.round(pctNum)}% 발급요청이 등록되었습니다.`
      : `${name} 건의 발급요청이 등록되었습니다.`

  return {
    domain: 'taxInvoice',
    masterId,
    issueId: (issue.id ?? '').toString(),
    title,
    body,
  }
}

function buildFromTaxInvoice(record: Record<string, unknown>): NotifyPayload | null {
  const status = (record.status ?? '').toString().toLowerCase()
  if (status !== 'pending') return null

  const masterId = (record.id ?? '').toString().trim()
  if (!masterId) return null

  const name = (record.customer_name ?? '요청 건').toString()
  return {
    domain: 'taxInvoice',
    masterId,
    issueId: '',
    title: '세금계산서 발급요청',
    body: `${name} 건의 발급요청이 등록되었습니다.`,
  }
}

function buildFromPerformanceBond(record: Record<string, unknown>): NotifyPayload | null {
  const status = (record.status ?? '').toString().toLowerCase()
  if (status !== 'pending' && status !== 'draft') return null

  const masterId = (record.id ?? '').toString().trim()
  if (!masterId) return null

  const name = (record.company_name ?? record.bond_type ?? '요청 건').toString()
  return {
    domain: 'performanceBond',
    masterId,
    issueId: '',
    title: '이행증권 발급요청',
    body: `${name} 건의 발급요청이 등록되었습니다.`,
  }
}

async function buildFromBondIssue(
  issue: Record<string, unknown>,
): Promise<NotifyPayload | null> {
  if (hasText(issue.bond_image_url)) return null

  const masterId = (issue.performance_bond_id ?? '').toString().trim()
  if (!masterId) return null

  return {
    domain: 'performanceBond',
    masterId,
    issueId: (issue.id ?? '').toString(),
    title: '이행증권 발급요청',
    body: '이행증권 건의 발급요청이 등록되었습니다.',
  }
}

async function resolveNotifyPayload(
  supabaseAdmin: ReturnType<typeof createClient>,
  payload: Record<string, unknown>,
): Promise<NotifyPayload | null> {
  const record = (payload.record ?? {}) as Record<string, unknown>
  if (hasText(record.master_id) || hasText(record.title)) {
    return buildFromAppRecord(record)
  }

  const table = (payload.table ?? '').toString()
  const type = (payload.type ?? '').toString().toUpperCase()
  if (type !== 'INSERT') return null

  switch (table) {
    case 'tax_invoices':
      return buildFromTaxInvoice(record)
    case 'performance_bonds':
      return buildFromPerformanceBond(record)
    case 'tax_invoice_issues':
      return await buildFromTaxInvoiceIssue(supabaseAdmin, record)
    case 'performance_bond_issues':
      return await buildFromBondIssue(record)
    default:
      return null
  }
}

async function shouldSkipDuplicate(
  supabaseAdmin: ReturnType<typeof createClient>,
  dedupeKey: string,
): Promise<boolean> {
  const since = new Date(Date.now() - 60_000).toISOString()
  await supabaseAdmin
    .from('issuance_push_dedup')
    .delete()
    .lt('sent_at', since)

  const { data: existing } = await supabaseAdmin
    .from('issuance_push_dedup')
    .select('dedupe_key')
    .eq('dedupe_key', dedupeKey)
    .maybeSingle()

  if (existing) {
    console.log(`Skip duplicate issuance push: ${dedupeKey}`)
    return true
  }

  await supabaseAdmin.from('issuance_push_dedup').insert({ dedupe_key: dedupeKey })
  return false
}

serve(async (req) => {
  try {
    const payload = await req.json()
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const notify = await resolveNotifyPayload(supabaseAdmin, payload)
    if (!notify) {
      return new Response(JSON.stringify({ message: 'No issuance request to notify' }), {
        status: 200,
      })
    }

    const dedupeKey =
      notify.domain === 'taxInvoice'
        ? `${notify.domain}:${notify.masterId}`
        : `${notify.domain}:${notify.masterId}:${notify.issueId}`
    if (await shouldSkipDuplicate(supabaseAdmin, dedupeKey)) {
      return new Response(JSON.stringify({ success: true, skipped: true, dedupeKey }), {
        status: 200,
      })
    }

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

    const dataBody = notify.body.replace(/\s+/g, ' ').trim()

    console.log(
      `Sending issuance request push: domain=${notify.domain} masterId=${notify.masterId} issueId=${notify.issueId}`,
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
                    issuance_domain: notify.domain,
                    master_id: notify.masterId,
                    issue_id: notify.issueId,
                    title: notify.title,
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
        dedupeKey,
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
