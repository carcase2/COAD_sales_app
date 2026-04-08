import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9'

serve(async (req) => {
  try {
    const payload = await req.json()
    const { record } = payload

    // 1. Initialize Supabase Admin Client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    console.log('Webhook payload received:', JSON.stringify(payload))

    // 2. Fetch all users who have an FCM token
    const { data: users, error: userError } = await supabaseAdmin
      .from('users')
      .select('name, fcm_token')
      .not('fcm_token', 'is', null)

    if (userError) {
      console.error('Error fetching users:', userError)
      throw userError
    }
    
    if (!users || users.length === 0) {
      console.log('No users with FCM tokens found in DB')
      return new Response(JSON.stringify({ message: 'No users with FCM tokens found' }), { status: 200 })
    }

    const tokens = users.map(u => u.fcm_token)
    console.log(`Found ${tokens.length} tokens to notify:`, users.map(u => u.name).join(', '))

    // 3. Authenticate with Firebase Service Account
    const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')
    const FIREBASE_SERVICE_ACCOUNT = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}')

    const auth = new GoogleAuth({
      credentials: FIREBASE_SERVICE_ACCOUNT,
      scopes: ['https://www.googleapis.com/auth/cloud-platform'],
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
      if (record.product_category_id) {
        const { data: catData } = await supabaseAdmin
          .from('product_categories')
          .select('name')
          .eq('id', record.product_category_id)
          .maybeSingle()
        if (catData) categoryName = catData.name
      }
    } catch (e) {
      console.error('Error fetching category:', e)
    }

    const regionText = record.region_sido && record.region_name 
      ? `${record.region_sido} ${record.region_name}`
      : (record.region_display || record.region_name || '지역 미상')

    let assigneeName = '미지정'
    try {
      if (record.assigned_to) {
        const { data: userData } = await supabaseAdmin
          .from('users')
          .select('name')
          .eq('id', record.assigned_to)
          .maybeSingle()
        if (userData) assigneeName = userData.name
      }
    } catch (e) {
      console.error('Error fetching assignee:', e)
    }

    // 5. Build Notification Content
    const customerName = record.customer_name || '이름없음'
    const phone = record.customer_phone || ''
    const content = record.inquiry_content || record.inquiryContent || record.memo || '내용 없음'
    
    console.log(`Sending notification for: ${customerName}, assigned to: ${assigneeName}`)

    // 6. Send notifications
    const results = await Promise.all(tokens.map(async (token) => {
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
                  title: `[COAD] 새 접수: ${customerName}님`,
                  body: `📞 ${phone}\n📍 지역: ${regionText}\n👤 담당: ${assigneeName}\n📝 내용: ${content}`,
                },
                data: {
                  call_id: record.id.toString(),
                  click_action: 'FLUTTER_NOTIFICATION_CLICK',
                },
                android: {
                  priority: 'high',
                  notification: {
                    channel_id: 'high_importance_channel',
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                    icon: 'ic_notification_coad',
                    color: '#28A745',
                  },
                },
              },
            }),
          }
        )
        const resJson = await res.json()
        console.log(`FCM Response for token ${token.substring(0, 10)}... :`, JSON.stringify(resJson))
        return resJson
      } catch (e) {
        console.error(`FCM error for token ${token.substring(0, 10)}... :`, e)
        return { error: e.message }
      }
    }))

    return new Response(JSON.stringify({ success: true, results }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (error) {
    console.error('Error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})
