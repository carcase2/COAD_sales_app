import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9'

/** KST 기준 오늘 yyyy-MM-dd */
function todayKstYmd(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date())
}

function isYmdInInclusiveRange(
  today: string,
  startYmd?: string | null,
  endYmd?: string | null,
): boolean {
  if (startYmd && startYmd.length > 0 && today < startYmd) return false
  if (endYmd && endYmd.length > 0 && today > endYmd) return false
  return true
}

type PushUser = {
  id: string
  name: string
  role: string
  groups?: { name?: string | null } | null
  fcm_token?: string | null
}

/**
 * 접수 푸시 수신 대상.
 * - 관리자(role=admin 또는 관리자·총무부 그룹) + 담당자(이름 일치)
 * - 담당자 미지정: 관리자·총무부 그룹만 수신
 * - users.fcm_token 유무와 무관 (기기별 토큰은 user_push_tokens에서 조회)
 */
async function resolvePushRecipients(
  supabaseAdmin: ReturnType<typeof createClient>,
  assigneeName: string | null,
): Promise<PushUser[]> {
  const { data: users, error: adminError } = await supabaseAdmin
    .from('users')
    .select('id, name, role, fcm_token, groups(name)')

  if (adminError) throw adminError

  const admins = (users ?? []).filter((u) => {
    const role = (u.role ?? '').toString().trim().toLowerCase()
    const groupName = (u.groups?.name ?? '').toString().trim()
    return role === 'admin' || groupName === '관리자' || groupName === '총무부'
  })

  const trimmed = (assigneeName ?? '').trim()
  if (!trimmed || trimmed === '미지정') {
    return admins
  }

  const { data: assigneeUsers, error: assigneeError } = await supabaseAdmin
    .from('users')
    .select('id, name, role, fcm_token, groups(name)')
    .eq('name', trimmed)

  if (assigneeError) throw assigneeError

  const byId = new Map<string, PushUser>()
  for (const u of [...(admins ?? []), ...(assigneeUsers ?? [])]) {
    if (u?.id) byId.set(u.id, u)
  }
  return Array.from(byId.values())
}

/** 유저별 활성 기기 토큰 전부 + 레거시 users.fcm_token (중복 제거) */
async function resolvePushTokens(
  supabaseAdmin: ReturnType<typeof createClient>,
  users: PushUser[],
): Promise<string[]> {
  const userIds = Array.from(new Set(users.map((u) => (u.id ?? '').toString()).filter((id) => id.length > 0)))
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

  // 레거시 users.fcm_token fallback (마이그레이션 과도기)
  const legacyTokens = users
    .map((u) => (u.fcm_token ?? '').toString().trim())
    .filter((t) => t.length > 5)

  return Array.from(new Set([...tableTokens, ...legacyTokens]))
}

/** 만료·해지된 FCM 토큰 정리 (다중 기기 테이블 + 레거시 컬럼) */
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

/**
 * 휴가 대행 기간이면 담당자를 임시 담당자(`temp_manager`)로 보정.
 * 해당 없으면 null → 호출부에서 `assigned_to` 사용.
 */
async function resolveTempManagerNameForPush(
  supabaseAdmin: ReturnType<typeof createClient>,
  record: Record<string, unknown> | null | undefined,
): Promise<string | null> {
  if (!record) return null

  const regionName = (record.region_name ?? '').toString().trim()
  const assignedTo = (record.assigned_to ?? '').toString().trim()
  if (!regionName) return null

  const today = todayKstYmd()
  const { data: overrides, error } = await supabaseAdmin
    .from('temp_manager_overrides')
    .select('region_name, original_manager, temp_manager, start_date, end_date, is_active')
    .eq('is_active', true)
    .eq('region_name', regionName)

  if (error) {
    console.error('Error fetching temp_manager_overrides:', error)
    return null
  }

  for (const o of overrides ?? []) {
    if (!isYmdInInclusiveRange(today, o.start_date, o.end_date)) continue
    const temp = (o.temp_manager ?? '').toString().trim()
    if (temp) {
      if (assignedTo) {
        const original = (o.original_manager ?? '').toString().trim()
        if (assignedTo !== original && assignedTo !== temp) continue
      }
      console.log(
        `Active temp override for push: region=${regionName} original=${o.original_manager} temp=${temp}`,
      )
      return temp
    }
  }
  return null
}

serve(async (req) => {
  try {
    const payload = await req.json()
    const { type, record, old_record } = payload

    if (type !== 'INSERT') {
      console.log(`Skipping notification for event type: ${type}`)
      return new Response(JSON.stringify({ message: 'Only INSERT events are notified' }), { status: 200 })
    }

    const activeRecord = record || old_record

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    console.log(`Webhook (${type}) payload received:`, JSON.stringify(payload))

    const assigneeFromRecord = (
      (activeRecord?.assigned_to ?? '') as string
    ).toString().trim() || '미지정'

    const tempManagerForPush = await resolveTempManagerNameForPush(supabaseAdmin, activeRecord)
    const effectiveAssignee = tempManagerForPush ??
      (assigneeFromRecord !== '미지정' ? assigneeFromRecord : null)

    console.log(
      `Routing push to admins + assignee: record=${assigneeFromRecord}` +
        (tempManagerForPush ? ` effective=${tempManagerForPush}` : ''),
    )

    const users = await resolvePushRecipients(supabaseAdmin, effectiveAssignee)

    if (users.length === 0) {
      console.log('No admin/assignee users found for push routing')
      return new Response(JSON.stringify({ message: 'No target users found' }), { status: 200 })
    }

    const tokens = await resolvePushTokens(supabaseAdmin, users)
    if (tokens.length === 0) {
      console.log(
        `No FCM tokens for ${users.length} recipient user(s):`,
        users.map((u) => u.name).join(', '),
      )
      return new Response(
        JSON.stringify({ message: 'No FCM tokens for target users', recipientUsers: users.map((u) => u.name) }),
        { status: 200 },
      )
    }
    console.log(`Found ${tokens.length} unique valid tokens from ${users.length} users.`)
    console.log(`Target users:`, users.map((u) => u.name).join(', '))

    const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')
    const FIREBASE_SERVICE_ACCOUNT = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}')

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

    let categoryName = '미지정'
    try {
      if (activeRecord && activeRecord.product_category_id) {
        const { data: catData } = await supabaseAdmin
          .from('product_categories')
          .select('name')
          .eq('id', activeRecord.product_category_id)
          .maybeSingle()
        if (catData) categoryName = catData.name
      }
    } catch (e) {
      console.error('Error fetching category:', e)
    }

    const regionText = activeRecord && activeRecord.region_sido && activeRecord.region_name
      ? `${activeRecord.region_sido} ${activeRecord.region_name}`
      : (activeRecord ? (activeRecord.region_display || activeRecord.region_name || '지역 미상') : '지역 미상')

    // 푸시 제목: 당일 처리 담당(대행 중이면 effectiveAssignee = 임시 담당)
    const assigneeName = effectiveAssignee ?? assigneeFromRecord

    const customerName = (activeRecord && activeRecord.customer_name) || '이름없음'
    const phone = (activeRecord && activeRecord.customer_phone) || ''
    const content = activeRecord
      ? (activeRecord.inquiry_content || activeRecord.inquiryContent || activeRecord.memo || '내용 없음')
      : '내용 없음'

    const title = `[${assigneeName}] ${customerName}`
    const body = `📦 모델: ${categoryName}\n📍 지역: ${regionText}\n📞 연락처: ${phone}\n📝 상세: ${content}`
    // FCM data 값은 단일 문자열. data.body는 한 줄로(탭·로컬 알림용), notification.body는 여러 줄 유지.
    const dataBody = body.replace(/\s+/g, ' ').trim()

    const callId = activeRecord ? String(activeRecord.id) : ''
    if (!callId) {
      console.error('Missing call id in activeRecord; aborting push')
      return new Response(JSON.stringify({ error: 'Missing call id' }), { status: 400 })
    }

    console.log(`Sending reception notification for: ${customerName}, handler: ${assigneeName}, callId=${callId}`)

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
                token: token,
                // data-only → 앱이 로컬 알림(payload 포함)으로 표시·탭 처리 (시스템 알림은 call_id 탭 불안정).
                data: {
                  type: 'sales_call',
                  call_id: callId,
                  id: callId,
                  title,
                  body: dataBody,
                  click_action: 'FLUTTER_NOTIFICATION_CLICK',
                },
                android: {
                  priority: 'high',
                },
                // iOS: alert 푸시여야 백그라운드/종료 상태에서도 배너가 표시됨.
                // (background + content-available 만으로는 앱이 깨지 않으면 알림이 안 뜸)
                apns: {
                  headers: {
                    'apns-push-type': 'alert',
                    'apns-priority': '10',
                  },
                  payload: {
                    aps: {
                      alert: {
                        title,
                        body: dataBody,
                      },
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
        // iOS APNs 환경 키 불일치 등 — 운영에서 바로 보이도록 강조 로그
        if (
          resText.includes('BadEnvironmentKeyInToken') ||
          resText.includes('THIRD_PARTY_AUTH_ERROR') ||
          resText.includes('ApnsError')
        ) {
          console.error(
            'APNs/FCM auth error for token (check Firebase Console → Cloud Messaging → Apple APNs key/environment):',
            token.slice(0, 16) + '...',
            resText,
          )
        }
        return { status: res.status, body: resText }
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e)
        console.error(`FCM error:`, msg)
        return { error: msg }
      }
    }))

    return new Response(
      JSON.stringify({
        success: true,
        routedTo: effectiveAssignee ?? 'broadcast',
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
