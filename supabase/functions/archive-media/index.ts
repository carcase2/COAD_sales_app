import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AwsClient } from 'https://esm.sh/aws4fetch@1.0.20'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

function isChecksheet(row: {
  type_code?: string | null
  stage?: string | null
  r2_key?: string | null
  local_path?: string | null
  original_name?: string | null
}): boolean {
  const code = (row.type_code || row.stage || '').toUpperCase()
  if (code === 'TP1') return true
  const path = `${row.r2_key || ''}|${row.local_path || ''}|${row.original_name || ''}`
  return path.includes('04_체크시트') || /TP1[_/\\-]/i.test(path)
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors })
  }

  try {
    const url = new URL(req.url)
    const id = (url.searchParams.get('id') || '').trim()
    if (!id) {
      return new Response(JSON.stringify({ error: 'id is required' }), {
        status: 400,
        headers: { ...cors, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const accountId = (Deno.env.get('R2_ACCOUNT_ID') || '').trim()
    const accessKey = (Deno.env.get('R2_ACCESS_KEY_ID') || '').trim()
    const secretKey = (Deno.env.get('R2_SECRET_ACCESS_KEY') || '').trim()
    const defaultBucket = (Deno.env.get('R2_BUCKET') || 'coad-mes-r2-test').trim()
    const publicBase = (Deno.env.get('R2_PUBLIC_BASE') || '').trim().replace(/\/$/, '')

    if (!supabaseUrl || !serviceKey) {
      return new Response(JSON.stringify({ error: '서버 설정 오류' }), {
        status: 500,
        headers: { ...cors, 'Content-Type': 'application/json' },
      })
    }

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })

    const { data: row, error } = await admin
      .from('archive_attachments')
      .select('id, type_code, stage, r2_key, r2_bucket, local_path, original_name, mime')
      .eq('id', id)
      .maybeSingle()

    if (error || !row) {
      return new Response(JSON.stringify({ error: 'not found' }), {
        status: 404,
        headers: { ...cors, 'Content-Type': 'application/json' },
      })
    }

    if (!isChecksheet(row)) {
      return new Response(JSON.stringify({ error: '체크시트(TP1)만 조회할 수 있습니다.' }), {
        status: 403,
        headers: { ...cors, 'Content-Type': 'application/json' },
      })
    }

    const key = (row.r2_key || '').trim()
    if (!key) {
      return new Response(JSON.stringify({ error: 'r2_key missing' }), {
        status: 404,
        headers: { ...cors, 'Content-Type': 'application/json' },
      })
    }

    const bucket = ((row.r2_bucket as string | null) || defaultBucket).trim()
    const encodedKey = key.split('/').map(encodeURIComponent).join('/')

    if (publicBase) {
      const publicUrl = `${publicBase}/${encodedKey}`
      return Response.redirect(publicUrl, 302)
    }

    if (!accountId || !accessKey || !secretKey) {
      console.error('archive-media R2 env missing')
      return new Response(JSON.stringify({ error: 'R2 설정이 없습니다.' }), {
        status: 503,
        headers: { ...cors, 'Content-Type': 'application/json' },
      })
    }

    const endpoint = `https://${accountId}.r2.cloudflarestorage.com`
    const aws = new AwsClient({
      accessKeyId: accessKey,
      secretAccessKey: secretKey,
      service: 's3',
      region: 'auto',
    })

    const objectUrl = `${endpoint}/${bucket}/${encodedKey}`
    const signed = await aws.sign(
      new Request(objectUrl, { method: 'GET' }),
      { aws: { signQuery: true } },
    )

    // 프록시: 앱이 서명 쿼리 없이 로드
    const upstream = await fetch(signed.url)
    if (!upstream.ok) {
      console.error('archive-media r2 status', upstream.status)
      return new Response(JSON.stringify({ error: '미디어를 불러오지 못했습니다.' }), {
        status: 502,
        headers: { ...cors, 'Content-Type': 'application/json' },
      })
    }

    const bytes = new Uint8Array(await upstream.arrayBuffer())
    const contentType =
      (row.mime as string | null) ||
      upstream.headers.get('content-type') ||
      'image/jpeg'

    return new Response(bytes, {
      status: 200,
      headers: {
        ...cors,
        'Content-Type': contentType,
        'Cache-Control': 'private, max-age=300',
        'Content-Length': String(bytes.byteLength),
        'X-Content-Type-Options': 'nosniff',
      },
    })
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'unknown'
    console.error('archive-media', msg.slice(0, 120))
    return new Response(JSON.stringify({ error: '미디어를 불러오지 못했습니다.' }), {
      status: 500,
      headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }
})
