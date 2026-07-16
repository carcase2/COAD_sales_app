import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9'

type NotifyPayload = {
  event: 'request' | 'completed'
  domain: string
  masterId: string
  issueId: string
  title: string
  body: string
}

type PushUser = {
  id: string
  name: string
  role: string
  fcm_token: string
  groups?: { name?: string | null } | null
}

function assigneeFromMasterRow(
  row: Record<string, unknown> | null | undefined,
): string | null {
  if (!row) return null
  const requester = (row.requester ?? '').toString().trim()
  if (requester) return requester
  const createdBy = (row.created_by ?? '').toString().trim()
  if (createdBy) return createdBy
  return null
}

async function resolveAssigneeName(
  supabaseAdmin: ReturnType<typeof createClient>,
  notify: NotifyPayload,
  record?: Record<string, unknown>,
): Promise<string | null> {
  const fromRecord = assigneeFromMasterRow(record)
  if (fromRecord) return fromRecord

  const table = notify.domain === 'taxInvoice' ? 'tax_invoices' : 'performance_bonds'
  const { data, error } = await supabaseAdmin
    .from(table)
    .select('requester, created_by')
    .eq('id', notify.masterId)
    .maybeSingle()

  if (error) {
    console.error(`Error fetching assignee from ${table}:`, error)
    return null
  }

  return assigneeFromMasterRow(data as Record<string, unknown> | null)
}

/** 발급요청·완료 푸시: role admin 또는 관리자·총무부 그룹 + 해당 건 담당자(requester) */
async function resolveIssuancePushRecipients(
  supabaseAdmin: ReturnType<typeof createClient>,
  assigneeName: string | null,
): Promise<PushUser[]> {
  const { data: users, error: adminError } = await supabaseAdmin
    .from('users')
    .select('id, name, role, fcm_token, groups(name)')
    .not('fcm_token', 'is', null)

  if (adminError) throw adminError

  const admins = (users ?? []).filter((u) => {
    const role = (u.role ?? '').toString().trim().toLowerCase()
    const groupName = (u.groups?.name ?? '').toString().trim()
    return role === 'admin' || groupName === '관리자' || groupName === '총무부'
  })

  const trimmed = (assigneeName ?? '').trim()
  let assigneeUsers: PushUser[] = []
  if (trimmed && trimmed !== '미지정') {
    const { data, error: assigneeError } = await supabaseAdmin
      .from('users')
      .select('id, name, role, fcm_token, groups(name)')
      .eq('name', trimmed)
      .not('fcm_token', 'is', null)

    if (assigneeError) throw assigneeError
    assigneeUsers = data ?? []
  }

  const byId = new Map<string, PushUser>()
  for (const u of [...(admins ?? []), ...assigneeUsers]) {
    if (u?.id) byId.set(u.id, u)
  }
  return Array.from(byId.values())
}

function hasText(value: unknown): boolean {
  return (value ?? '').toString().trim().length > 0
}

function buildFromAppRecord(record: Record<string, unknown>): NotifyPayload | null {
  const masterId = (record.master_id ?? '').toString().trim()
  if (!masterId) return null
  const notificationType = (record.notification_type ?? record.type ?? '')
    .toString()
    .toLowerCase()
  const isCompleted = notificationType.includes('completed')
  return {
    event: isCompleted ? 'completed' : 'request',
    domain: (record.issuance_domain ?? 'taxInvoice').toString(),
    masterId,
    issueId: (record.issue_id ?? '').toString(),
    title: (record.title ?? (isCompleted ? '발급 완료' : '발급요청')).toString(),
    body: (record.body ?? (isCompleted
      ? '발급이 완료되었습니다.'
      : '새 발급요청이 등록되었습니다.')).toString(),
  }
}

function becameIssued(
  oldRecord: Record<string, unknown>,
  record: Record<string, unknown>,
  field: string,
): boolean {
  return !hasText(oldRecord[field]) && hasText(record[field])
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
    event: 'request',
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
    event: 'request',
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
    event: 'request',
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
    event: 'request',
    domain: 'performanceBond',
    masterId,
    issueId: (issue.id ?? '').toString(),
    title: '이행증권 발급요청',
    body: '이행증권 건의 발급요청이 등록되었습니다.',
  }
}

async function buildCompletedFromTaxInvoiceIssue(
  supabaseAdmin: ReturnType<typeof createClient>,
  issue: Record<string, unknown>,
): Promise<NotifyPayload | null> {
  const masterId = (issue.tax_invoice_id ?? '').toString().trim()
  if (!masterId) return null

  const { data: invoice } = await supabaseAdmin
    .from('tax_invoices')
    .select('customer_name')
    .eq('id', masterId)
    .maybeSingle()

  const name = (invoice?.customer_name ?? '요청 건').toString()
  return {
    event: 'completed',
    domain: 'taxInvoice',
    masterId,
    issueId: (issue.id ?? '').toString(),
    title: '세금계산서 발급 완료',
    body: `${name} 건이 발급 완료되었습니다.`,
  }
}

async function buildCompletedFromBondIssue(
  supabaseAdmin: ReturnType<typeof createClient>,
  issue: Record<string, unknown>,
): Promise<NotifyPayload | null> {
  const masterId = (issue.performance_bond_id ?? '').toString().trim()
  if (!masterId) return null

  const { data: bond } = await supabaseAdmin
    .from('performance_bonds')
    .select('company_name, bond_type')
    .eq('id', masterId)
    .maybeSingle()

  const name = (bond?.company_name ?? bond?.bond_type ?? '요청 건').toString()
  return {
    event: 'completed',
    domain: 'performanceBond',
    masterId,
    issueId: (issue.id ?? '').toString(),
    title: '이행증권 발급 완료',
    body: `${name} 건이 발급 완료되었습니다.`,
  }
}

function buildCompletedFromTaxInvoice(
  record: Record<string, unknown>,
): NotifyPayload | null {
  const masterId = (record.id ?? '').toString().trim()
  if (!masterId) return null
  const name = (record.customer_name ?? '요청 건').toString()
  return {
    event: 'completed',
    domain: 'taxInvoice',
    masterId,
    issueId: '',
    title: '세금계산서 발급 완료',
    body: `${name} 건이 발급 완료되었습니다.`,
  }
}

function buildCompletedFromPerformanceBond(
  record: Record<string, unknown>,
): NotifyPayload | null {
  const masterId = (record.id ?? '').toString().trim()
  if (!masterId) return null
  const name = (record.company_name ?? record.bond_type ?? '요청 건').toString()
  return {
    event: 'completed',
    domain: 'performanceBond',
    masterId,
    issueId: '',
    title: '이행증권 발급 완료',
    body: `${name} 건이 발급 완료되었습니다.`,
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
  const oldRecord = (payload.old_record ?? {}) as Record<string, unknown>

  if (type === 'UPDATE') {
    switch (table) {
      case 'tax_invoice_issues':
        if (!becameIssued(oldRecord, record, 'invoice_image_url')) return null
        return await buildCompletedFromTaxInvoiceIssue(supabaseAdmin, record)
      case 'performance_bond_issues':
        if (!becameIssued(oldRecord, record, 'bond_image_url')) return null
        return await buildCompletedFromBondIssue(supabaseAdmin, record)
      case 'tax_invoices':
        if (!becameIssued(oldRecord, record, 'invoice_image_url')) return null
        return buildCompletedFromTaxInvoice(record)
      case 'performance_bonds':
        if (!becameIssued(oldRecord, record, 'bond_image_url')) return null
        return buildCompletedFromPerformanceBond(record)
      default:
        return null
    }
  }

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

    const dedupeKey = notify.event === 'completed'
      ? `completed:${notify.domain}:${notify.masterId}:${notify.issueId || 'master'}`
      : notify.domain === 'taxInvoice'
      ? `request:${notify.domain}:${notify.masterId}`
      : `request:${notify.domain}:${notify.masterId}:${notify.issueId}`
    if (await shouldSkipDuplicate(supabaseAdmin, dedupeKey)) {
      return new Response(JSON.stringify({ success: true, skipped: true, dedupeKey }), {
        status: 200,
      })
    }

    const record = (payload.record ?? {}) as Record<string, unknown>
    const assigneeName = await resolveAssigneeName(supabaseAdmin, notify, record)
    const users = await resolveIssuancePushRecipients(supabaseAdmin, assigneeName)

    const tokens = Array.from(
      new Set(
        users
          .map((u) => (u.fcm_token ?? '').trim())
          .filter((t) => t.length > 5),
      ),
    )

    if (tokens.length === 0) {
      console.log(
        `No issuance push recipients with FCM tokens: assignee=${assigneeName}`,
      )
      return new Response(JSON.stringify({ message: 'No target users found' }), {
        status: 200,
      })
    }

    console.log(
      `Routing issuance ${notify.event} push to admin(role/group) + assignee=${assigneeName} (${tokens.length} token(s))`,
    )

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

    const fcmType = notify.event === 'completed'
      ? 'issuance_completed'
      : 'issuance_request'

    console.log(
      `Sending issuance ${notify.event} push: domain=${notify.domain} masterId=${notify.masterId} issueId=${notify.issueId}`,
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
                    type: fcmType,
                    issuance_domain: notify.domain,
                    master_id: notify.masterId,
                    issue_id: notify.issueId,
                    title: notify.title,
                    body: dataBody,
                    show_completed: notify.event === 'completed' ? 'true' : 'false',
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
