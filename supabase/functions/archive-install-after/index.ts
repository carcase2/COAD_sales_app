import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

type Row = {
  id: string
  site_key: string | null
  site_name: string | null
  type_code: string | null
  stage: string | null
  original_name: string | null
  mime: string | null
  file_size: number | null
  local_path: string | null
  r2_key: string | null
  r2_bucket: string | null
  uploaded_at: string | null
  created_at: string | null
}

function isInstallAfter(row: Row): boolean {
  const code = (row.type_code || row.stage || '').toUpperCase()
  if (
    code === 'TP3' ||
    code === 'TP3_INSTALL_AFTER' ||
    code.includes('INSTALL_AFTER')
  ) {
    return true
  }
  const path = `${row.r2_key || ''}|${row.local_path || ''}|${row.original_name || ''}`
  return (
    path.includes('시공후') ||
    path.includes('시공_후') ||
    path.includes('INSTALL_AFTER') ||
    /TP3[_/\\-]/i.test(path)
  )
}

/** 경로·파일명에서 모델명 후보 추출 */
function guessModel(row: Row): string | null {
  const path = `${row.r2_key || ''}|${row.local_path || ''}|${row.original_name || ''}`
  const folder = path.match(
    /\/([^\/]+)\/(?:\d*_?시공후|시공_후|INSTALL_AFTER|TP3)/i,
  )
  if (
    folder &&
    folder[1] &&
    !/^\d{4}$/.test(folder[1]) &&
    folder[1].length < 40
  ) {
    const name = folder[1].trim()
    if (name && !name.includes('sites') && name !== (row.site_name || '').trim()) {
      return name
    }
  }
  return null
}

/** 경로 data/sites/YYYY/MM/DD/... 에서 날짜·연·월 추출 */
function parsePathDate(r2Key: string | null, localPath: string | null) {
  const path = r2Key || localPath || ''
  const full = path.match(/(?:^|\/)(\d{4})\/(\d{1,2})\/(\d{1,2})\//)
  if (full) {
    const year = Number(full[1])
    const month = Number(full[2])
    const day = Number(full[3])
    if (
      year >= 2000 && year <= 2100 &&
      month >= 1 && month <= 12 &&
      day >= 1 && day <= 31
    ) {
      return {
        year,
        month,
        reg_date: `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`,
      }
    }
  }
  const ym = path.match(/(?:^|\/)(\d{4})\/(\d{1,2})\//)
  if (ym) {
    const year = Number(ym[1])
    const month = Number(ym[2])
    if (year >= 2000 && year <= 2100 && month >= 1 && month <= 12) {
      return {
        year,
        month,
        reg_date: `${year}-${String(month).padStart(2, '0')}-01`,
      }
    }
  }
  return {
    year: null as number | null,
    month: null as number | null,
    reg_date: null as string | null,
  }
}

function ymdOnly(v: unknown): string | null {
  if (v == null) return null
  const s = String(v).trim()
  if (!s) return null
  // 2026-07-20 or 2026-07-20T...
  if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10)
  return null
}

/** 현장명 비교용 정규화 (공백·법인표기 제거) */
function normSite(s: string): string {
  return (s || '')
    .trim()
    .toLowerCase()
    .replace(/\(주\)/g, '')
    .replace(/㈜/g, '')
    .replace(/주식회사/g, '')
    .replace(/\s+/g, '')
    .replace(/[._\-·]/g, '')
}

function putLatest(map: Map<string, string>, key: string, date: string | null) {
  if (!key || !date) return
  const prev = map.get(key)
  if (!prev || date > prev) map.set(key, date)
}

/** exact + 정규화 키 맵에서 현장명으로 시공일 조회 */
function lookupInstall(
  name: string,
  exact: Map<string, string>,
  byNorm: Map<string, string>,
): string | null {
  const t = (name || '').trim()
  if (!t) return null
  if (exact.has(t)) return exact.get(t)!
  const n = normSite(t)
  if (n && byNorm.has(n)) return byNorm.get(n)!
  // 포함 관계 (짧은 이름 오매칭 방지: 양쪽 4자 이상)
  if (n.length >= 4) {
    for (const [k, v] of byNorm) {
      if (k.length < 4) continue
      if (k.includes(n) || n.includes(k)) return v
    }
  }
  return null
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors })
  }

  try {
    const url = new URL(req.url)
    const qRaw = (url.searchParams.get('q') || url.searchParams.get('query') || '').trim()
    const cleaned = qRaw
      .replace(/\s*시공후\s*/gi, ' ')
      .replace(/\s*시공\s*후\s*/gi, ' ')
      .replace(/\s*체크시트\s*/gi, ' ')
      .trim()
    const q = cleaned || qRaw
    const year = Number(url.searchParams.get('year') || '') || null
    const month = Number(url.searchParams.get('month') || '') || null
    const limit = Math.min(Math.max(Number(url.searchParams.get('limit') || 50) || 50, 1), 100)
    const offset = Math.max(Number(url.searchParams.get('offset') || 0) || 0, 0)

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    if (!supabaseUrl || !serviceKey) {
      return new Response(
        JSON.stringify({ success: false, error: '서버 Supabase 설정이 없습니다.' }),
        { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } },
      )
    }

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })

    const fetchCap = Math.min(Math.max((offset + limit) * 40, 200), 2000)
    let query = admin
      .from('archive_attachments')
      .select(
        'id, site_key, site_name, type_code, stage, original_name, mime, file_size, local_path, r2_key, r2_bucket, uploaded_at, created_at',
      )
      .or('type_code.eq.TP3,type_code.eq.TP3_INSTALL_AFTER,type_code.ilike.%INSTALL_AFTER%,r2_key.ilike.%시공후%,r2_key.ilike.%/TP3_%')
      .order('uploaded_at', { ascending: false })
      .limit(fetchCap)

    if (q) {
      // 현장명 · 파일명 · 경로(모델명 포함) 검색
      const like = `%${q.replace(/%/g, '')}%`
      query = query.or(
        `site_name.ilike.${like},original_name.ilike.${like},r2_key.ilike.${like},local_path.ilike.${like}`,
      )
    }
    if (year && year >= 2000 && year <= 2100) {
      if (month && month >= 1 && month <= 12) {
        const mm = String(month).padStart(2, '0')
        query = query.ilike('r2_key', `data/sites/${year}/${mm}/%`)
      } else {
        query = query.ilike('r2_key', `data/sites/${year}/%`)
      }
    }

    const { data, error } = await query
    if (error) {
      console.error('archive-install-after query', error.message)
      return new Response(
        JSON.stringify({ success: false, error: '시공후 사진 조회에 실패했습니다.' }),
        { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } },
      )
    }

    const rows = (data || []) as Row[]
    type Site = {
      site_key: string
      site_name: string
      model_name: string | null
      reg_date: string | null
      install_completed_date: string | null
      year: number | null
      month: number | null
      checksheet_count: number
      photo_count: number
      thumbnail_media_path: string | null
      attachments: Array<{
        id: string
        original_name: string | null
        mime: string | null
        file_size: number | null
        r2_key: string | null
        uploaded_at: string | null
        media_path: string
      }>
    }

    const map = new Map<string, Site>()
    for (const row of rows) {
      if (!isInstallAfter(row)) continue
      if (!row.r2_key && !row.local_path) continue
      const siteName = (row.site_name || row.site_key || '').trim()
      if (!siteName) continue
      const siteKey = (row.site_key || siteName).trim()
      const ym = parsePathDate(row.r2_key, row.local_path)
      const mediaPath = `edge:archive-media?id=${encodeURIComponent(row.id)}`
      const att = {
        id: row.id,
        original_name: row.original_name,
        mime: row.mime,
        file_size: row.file_size,
        r2_key: row.r2_key,
        uploaded_at: row.uploaded_at || row.created_at,
        media_path: mediaPath,
      }
      const existing = map.get(siteKey)
      if (!existing) {
        map.set(siteKey, {
          site_key: siteKey,
          site_name: siteName,
          model_name: guessModel(row),
          reg_date: ym.reg_date,
          install_completed_date: null,
          year: ym.year,
          month: ym.month,
          checksheet_count: 1,
          photo_count: 1,
          thumbnail_media_path: mediaPath,
          attachments: [att],
        })
      } else {
        existing.attachments.push(att)
        existing.checksheet_count = existing.attachments.length
        existing.photo_count = existing.attachments.length
        if (!existing.model_name) existing.model_name = guessModel(row)
        if (!existing.reg_date && ym.reg_date) existing.reg_date = ym.reg_date
        if (existing.year == null && ym.year != null) existing.year = ym.year
        if (existing.month == null && ym.month != null) existing.month = ym.month
      }
    }

    let sites = Array.from(map.values())
    for (const s of sites) {
      s.attachments.sort((a, b) => (b.uploaded_at || '').localeCompare(a.uploaded_at || ''))
      s.thumbnail_media_path = s.attachments[0]?.media_path ?? null
    }
    sites.sort((a, b) => {
      const ta = a.attachments[0]?.uploaded_at || a.reg_date || ''
      const tb = b.attachments[0]?.uploaded_at || b.reg_date || ''
      return tb.localeCompare(ta)
    })

    if (year && year >= 2000) {
      sites = sites.filter((s) => s.year === year || s.year == null)
      if (month && month >= 1 && month <= 12) {
        sites = sites.filter((s) => s.month === month || s.month == null)
      }
    }

    const totalSites = sites.length
    const page = sites.slice(offset, offset + limit)

    // 등록일: archive_sites.reg_date 우선
    // 시공완료일: inquiries + mes_unpaid + sales_schedule2 (이름 정규화 매칭)
    const names = Array.from(
      new Set(
        page
          .flatMap((s) => [s.site_name, s.site_key])
          .map((n) => (n || '').trim())
          .filter((n) => n.length > 0),
      ),
    )
    if (names.length > 0) {
      const installExact = new Map<string, string>()
      const installNorm = new Map<string, string>()
      const regExact = new Map<string, string>()

      const addInstall = (siteName: string, date: string | null) => {
        const d = ymdOnly(date)
        const n = (siteName || '').trim()
        if (!n || !d) return
        putLatest(installExact, n, d)
        putLatest(installNorm, normSite(n), d)
      }
      const addReg = (siteName: string, date: string | null) => {
        const d = ymdOnly(date)
        const n = (siteName || '').trim()
        if (!n || !d) return
        putLatest(regExact, n, d)
      }

      // 1) archive_sites 등록일
      const { data: siteRows } = await admin
        .from('archive_sites')
        .select('site_key, site_name, reg_date')
        .in('site_name', names)
      for (const r of siteRows || []) {
        addReg(String(r.site_name || ''), ymdOnly(r.reg_date))
        addReg(String(r.site_key || ''), ymdOnly(r.reg_date))
      }
      // site_key 로도 한 번 더
      const { data: siteRows2 } = await admin
        .from('archive_sites')
        .select('site_key, site_name, reg_date')
        .in('site_key', names)
      for (const r of siteRows2 || []) {
        addReg(String(r.site_name || ''), ymdOnly(r.reg_date))
        addReg(String(r.site_key || ''), ymdOnly(r.reg_date))
      }

      // 2) inquiries 전체(최대 1000) — 정규화 매칭 포함
      const { data: inqAll } = await admin
        .from('inquiries')
        .select('site_nm, inq_dt, instal_dt, install_dt_act')
        .limit(1000)
      for (const r of inqAll || []) {
        const name = String(r.site_nm || '').trim()
        addInstall(name, ymdOnly(r.install_dt_act) || ymdOnly(r.instal_dt))
        addReg(name, ymdOnly(r.inq_dt))
      }

      // 3) mes_unpaid_receivables 전체 페이지네이션
      for (let from = 0; from < 5000; from += 1000) {
        const { data: unpaidRows } = await admin
          .from('mes_unpaid_receivables')
          .select('instal_ymd, snapshot')
          .range(from, from + 999)
        if (!unpaidRows || unpaidRows.length === 0) break
        for (const r of unpaidRows) {
          const snap = (r.snapshot || {}) as Record<string, unknown>
          const sn = String(snap.SITE_NM || snap.site_nm || '').trim()
          const d =
            ymdOnly(r.instal_ymd) ||
            ymdOnly(snap.INSTAL_DT) ||
            ymdOnly(snap.instal_dt)
          addInstall(sn, d)
        }
        if (unpaidRows.length < 1000) break
      }

      // 4) sales_schedule2 (+ 모델명)
      const modelExact = new Map<string, string>()
      const modelNorm = new Map<string, string>()
      const putModel = (siteName: string, model: string | null) => {
        const n = (siteName || '').trim()
        const m = (model || '').trim()
        if (!n || !m) return
        if (!modelExact.has(n)) modelExact.set(n, m)
        const nk = normSite(n)
        if (nk && !modelNorm.has(nk)) modelNorm.set(nk, m)
      }
      const { data: ss2, error: ss2Err } = await admin
        .from('sales_schedule2')
        .select('site, construction_completed_date, end_date, is_construction_completed, model_name')
        .limit(1000)
      if (ss2Err) {
        // model_name 없는 환경 폴백
        const { data: ss2b } = await admin
          .from('sales_schedule2')
          .select('site, construction_completed_date, end_date, is_construction_completed')
          .limit(1000)
        for (const r of ss2b || []) {
          const sn = String(r.site || '').trim()
          const d =
            ymdOnly(r.construction_completed_date) ||
            (r.is_construction_completed ? ymdOnly(r.end_date) : null)
          addInstall(sn, d)
        }
      } else {
        for (const r of ss2 || []) {
          const sn = String(r.site || '').trim()
          const d =
            ymdOnly(r.construction_completed_date) ||
            (r.is_construction_completed ? ymdOnly(r.end_date) : null)
          addInstall(sn, d)
          putModel(sn, String(r.model_name || '').trim() || null)
        }
      }

      for (const s of page) {
        const fromArchive =
          regExact.get(s.site_name) || regExact.get(s.site_key)
        if (fromArchive) {
          s.reg_date = fromArchive
          s.year = Number(fromArchive.slice(0, 4)) || s.year
          s.month = Number(fromArchive.slice(5, 7)) || s.month
        } else if (!s.reg_date) {
          // 경로 날짜 유지, 없으면 인쿼리 등록일
          const fromInq =
            regExact.get(s.site_name) || regExact.get(s.site_key)
          if (fromInq) s.reg_date = fromInq
        }

        s.install_completed_date =
          lookupInstall(s.site_name, installExact, installNorm) ||
          lookupInstall(s.site_key, installExact, installNorm) ||
          null
        if (!s.model_name) {
          s.model_name =
            modelExact.get(s.site_name) ||
            modelExact.get(s.site_key) ||
            modelNorm.get(normSite(s.site_name)) ||
            modelNorm.get(normSite(s.site_key)) ||
            null
        }
      }
    }

    const totalAttachments = page.reduce((n, s) => n + s.checksheet_count, 0)
    const nextOffset = offset + limit < totalSites ? offset + limit : null

    return new Response(
      JSON.stringify({
        success: true,
        query: q,
        year,
        month,
        total_sites: totalSites,
        total_attachments: totalAttachments,
        offset,
        limit,
        next_offset: nextOffset,
        sites: page,
      }),
      { status: 200, headers: { ...cors, 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'unknown'
    console.error('archive-install-after', msg.slice(0, 120))
    return new Response(
      JSON.stringify({ success: false, error: '시공후 사진 조회 중 오류가 발생했습니다.' }),
      { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } },
    )
  }
})
