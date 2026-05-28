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

/**
 * 휴가 대행 기간이면 푸시는 임시 담당자(`temp_manager`)에게만.
 * 해당 없으면 null → 호출부에서 기존 브로드캐스트.
 */
async function resolveTempManagerNameForPush(
  supabaseAdmin: ReturnType<typeof createClient>,
  record: Record<string, unknown> | null | undefined,
): Promise<string | null> {
  if (!record) return null

  const regionName = (record.region_name ?? '').toString().trim()
  const regionManager = (record.region_manager ?? '').toString().trim()
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
    if (regionManager && o.original_manager !== regionManager) continue
    const temp = (o.temp_manager ?? '').toString().trim()
    if (temp) {
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

    const tempManagerForPush = await resolveTempManagerNameForPush(supabaseAdmin, activeRecord)

    let users: Array<{ id: string; name: string; role: string; fcm_token: string }> = []
    if (tempManagerForPush) {
      console.log(`Routing push to temp manager only: ${tempManagerForPush}`)
      const { data, error: userError } = await supabaseAdmin
        .from('users')
        .select('id, name, role, fcm_token')
        .eq('name', tempManagerForPush)
        .not('fcm_token', 'is', null)

      if (userError) throw userError
      users = data ?? []
      if (users.length === 0) {
        console.log(`No users with FCM token matched temp manager name: ${tempManagerForPush}`)
        return new Response(
          JSON.stringify({ message: 'No temp manager user with FCM token', tempManager: tempManagerForPush }),
          { status: 200 },
        )
      }
    } else {
      console.log(`Querying ALL users with FCM tokens for broadcast...`)
      const { data, error: userError } = await supabaseAdmin
        .from('users')
        .select('id, name, role, fcm_token')
        .not('fcm_token', 'is', null)

      if (userError) throw userError
      users = data ?? []
    }

    if (!users || users.length === 0) {
      console.log('No target users with FCM tokens found')
      return new Response(JSON.stringify({ message: 'No target users found' }), { status: 200 })
    }

    const tokens = Array.from(
      new Set(
        users
          .map((u) => (u.fcm_token ?? '').trim())
          .filter((t) => t.length > 5),
      ),
    )
    console.log(`Found ${tokens.length} unique valid tokens from ${users.length} users.`)
    console.log(`Target users:`, users.map((u) => `${u.name}(Token OK)`).join(', '))

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

    // 푸시 제목: 당일 처리 담당(대행 중이면 assigned_to = 임시 담당)
    const assigneeName = (
      (activeRecord?.assigned_to ?? activeRecord?.region_manager ?? '') as string
    ).toString().trim() || '미지정'

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
              },
            }),
          },
        )
        const resText = await res.text()
        console.log(`FCM Response (Status: ${res.status}):`, resText)
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
        routedTo: tempManagerForPush ?? 'broadcast',
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
