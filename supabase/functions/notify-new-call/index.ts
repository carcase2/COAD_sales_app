import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9'

serve(async (req) => {
  try {
    const payload = await req.json()
    const { type, record, old_record } = payload
    
    // Only notify on NEW Reception (INSERT)
    if (type !== 'INSERT') {
      console.log(`Skipping notification for event type: ${type}`)
      return new Response(JSON.stringify({ message: 'Only INSERT events are notified' }), { status: 200 })
    }

    const activeRecord = record || old_record

    // 1. Initialize Supabase Admin Client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    console.log(`Webhook (${type}) payload received:`, JSON.stringify(payload))

    // 2. Fetch ALL target users who have an FCM token (Broadcast mode)
    console.log(`Querying ALL users with FCM tokens for broadcast...`)

    const { data: users, error: userError } = await supabaseAdmin
      .from('users')
      .select('id, name, role, fcm_token')
      .not('fcm_token', 'is', null)

    if (userError) {
      console.error('Error fetching users:', userError)
      throw userError
    }
    
    if (!users || users.length === 0) {
      console.log('No target users with FCM tokens found')
      return new Response(JSON.stringify({ message: 'No target users found' }), { status: 200 })
    }

    const tokens = users.map((u: any) => u.fcm_token).filter((t: any) => t && t.length > 5)
    console.log(`Found ${tokens.length} valid tokens to notify from ${users.length} matching users.`)
    console.log(`Target users:`, users.map((u: any) => `${u.name}(${u.fcm_token ? 'Token OK' : 'No Token'})`).join(', '))

    // 3. Authenticate with Firebase Service Account
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

    // 4. Fetch related data for richer notification
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

    let assigneeName = '미지정'
    try {
      if (activeRecord && activeRecord.assigned_to) {
        const { data: userData } = await supabaseAdmin
          .from('users')
          .select('name')
          .eq('id', activeRecord.assigned_to)
          .maybeSingle()
        if (userData) assigneeName = userData.name
      }
    } catch (e) {
      console.error('Error fetching assignee:', e)
    }

    // 5. Build Notification Content
    const customerName = (activeRecord && activeRecord.customer_name) || '이름없음'
    const phone = (activeRecord && activeRecord.customer_phone) || ''
    const content = activeRecord ? (activeRecord.inquiry_content || activeRecord.inquiryContent || activeRecord.memo || '내용 없음') : '내용 없음'
    
    // Title with Assignee
    const title = `[새 접수] ${customerName} (담당: ${assigneeName})`
    const body = `📦 모델: ${categoryName}\n📍 지역: ${regionText}\n📞 연락처: ${phone}\n📝 상세: ${content}`

    console.log(`Sending reception notification for: ${customerName}, assigned to: ${assigneeName}`)

    // 6. Send notifications
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
                notification: {
                  title: title,
                  body: body,
                },
                data: {
                  call_id: activeRecord ? activeRecord.id.toString() : '',
                  click_action: 'FLUTTER_NOTIFICATION_CLICK',
                },
                android: {
                  priority: 'high',
                  notification: {
                    channel_id: 'high_importance_channel',
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                    // Using default launcher icon to prevent missing resource errors
                  },
                },
              },
            }),
          }
        )
        const resText = await res.text()
        console.log(`FCM Response for token ${token.substring(0, 10)}... (Status: ${res.status}):`, resText)
        return { status: res.status, body: resText }
      } catch (e: any) {
        console.error(`FCM error for token ${token.substring(0, 10)}... :`, e)
        return { error: e.message }
      }
    }))

    return new Response(JSON.stringify({ success: true, results }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (error: any) {
    console.error('Error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})
