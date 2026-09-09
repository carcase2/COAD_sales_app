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

function isChecksheet(row: Row): boolean {
  const code = (row.type_code || row.stage || '').toUpperCase()
  if (code === 'TP1') return true
  const path = `${row.r2_key || ''}|${row.local_path || ''}|${row.original_name || ''}`
  return path.includes('04_체크시트') || /TP1[_/\\-]/i.test(path)
}

function isInstallAfter(row: Row): boolean {
  const path = `${row.r2_key || ''}|${row.local_path || ''}|${row.original_name || ''}`
  if (
    path.includes('시공전') ||
    path.includes('시공_전') ||
    /\/0[12]_시공전/i.test(path) ||
    /TP[26][_/\\-]/i.test(path)
  ) {
    return false
  }
  const code = (row.type_code || row.stage || '').toUpperCase()
  if (
    code === 'TP3' ||
    code === 'TP3_INSTALL_AFTER' ||
    code.includes('INSTALL_AFTER')
  ) {
    return true
  }
  return (
    path.includes('시공후') ||
    path.includes('시공_후') ||
    path.includes('INSTALL_AFTER') ||
    /TP3[_/\\-]/i.test(path)
  )
}

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

const ATT_COLS =
  'id, site_key, site_name, type_code, stage, original_name, mime, file_size, local_path, r2_key, r2_bucket, uploaded_at, created_at'

const TP3_OR =
  'type_code.eq.TP3,type_code.eq.TP3_INSTALL_AFTER,type_code.ilike.%INSTALL_AFTER%,r2_key.ilike.%시공후%,r2_key.ilike.%/TP3_%'

/** C-1 ↔ COAD-1. `%C-1%` 는 C-10 과 섞이고, 최근 인쿼리는 COAD-1 만 있음. */
function modelTokens(model: string): string[] {
  const raw = model.trim()
  if (!raw) return []
  const tokens = new Set<string>()
  tokens.add(raw)
  const c = raw.match(/^C-(\d+)/i)
  if (c) {
    tokens.add(`C-${c[1]}`)
    tokens.add(`COAD-${c[1]}`)
  }
  const coad = raw.match(/^COAD-([A-Z0-9]+)/i)
  if (coad) {
    tokens.add(`COAD-${coad[1]}`)
    if (/^\d+$/.test(coad[1])) tokens.add(`C-${coad[1]}`)
  }
  return Array.from(tokens)
}

function itemCdMatchesModel(itemCd: string, tokens: string[]): boolean {
  const parts = itemCd
    .split(/[,/|]/)
    .map((s) => s.trim().toUpperCase())
    .filter(Boolean)
  const wants = tokens.map((t) => t.toUpperCase())
  return parts.some((p) => {
    const compact = p.replace(/\s+/g, '')
    return wants.some((w) => {
      if (compact === w) return true
      // COAD-1S · COAD-1 STANDARD. COAD-10 은 제외
      if (compact.startsWith(w) && compact.length > w.length) {
        return !/^\d/.test(compact.slice(w.length))
      }
      return false
    })
  })
}

/**
 * C-1 이 C-10 에 포함되지 않게 토큰 경계로 매칭.
 * 뒤가 숫자가 아니기만 하면 UUID `6C-50E6` 도 C-50 으로 오인하므로
 * 앞·뒤 모두 비알파벳숫자여야 한다.
 */
function hayHasModel(hay: string, tokens: string[]): boolean {
  const s = hay.toUpperCase()
  for (const t of tokens) {
    const u = t.toUpperCase()
    if (u.length < 3) continue
    let from = 0
    while (from <= s.length) {
      const i = s.indexOf(u, from)
      if (i < 0) break
      const before = i === 0 ? '' : s[i - 1]
      const after = s[i + u.length] || ''
      const beforeOk = i === 0 || /[^A-Z0-9]/.test(before)
      const afterOk = after === '' || /[^A-Z0-9]/.test(after)
      if (beforeOk && afterOk) return true
      from = i + 1
    }
  }
  return false
}

function mesSiteName(raw: unknown): string {
  if (!raw || typeof raw !== 'object') return ''
  const o = raw as Record<string, unknown>
  return String(o.SITE_NM || o.site_nm || o.SITE || '').trim()
}

function mesItemCd(itemCd: unknown, raw: unknown): string {
  const col = String(itemCd || '').trim()
  if (col) return col
  if (!raw || typeof raw !== 'object') return ''
  const o = raw as Record<string, unknown>
  return String(o.ITEM_CD || o.item_cd || '').trim()
}

function preferredModelLabel(itemCd: string, tokens: string[]): string | null {
  const parts = itemCd.split(/[,/|]/).map((s) => s.trim()).filter(Boolean)
  const hit = parts.find((p) => itemCdMatchesModel(p, tokens))
  return hit || null
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors })
  }

  try {
    const url = new URL(req.url)
    const kindRaw = (url.searchParams.get('kind') || url.searchParams.get('type') || '').trim().toLowerCase()
    const installAfter =
      kindRaw === 'install_after' ||
      kindRaw === 'install-after' ||
      kindRaw === 'tp3' ||
      kindRaw === 'after'
    const qRaw = (url.searchParams.get('q') || url.searchParams.get('query') || '').trim()
    const modelRaw = (url.searchParams.get('model') || url.searchParams.get('model_name') || '').trim()
    const cleaned = qRaw
      .replace(/\s*체크시트\s*/gi, ' ')
      .replace(/\s*시공후\s*/gi, ' ')
      .replace(/\s*시공\s*후\s*/gi, ' ')
      .trim()
    const q = cleaned || qRaw
    const model = modelRaw
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
    const tokens = installAfter && model ? modelTokens(model) : []
    const modelSiteNames = new Set<string>()
    const modelBySiteExact = new Map<string, string>()
    const modelBySiteNorm = new Map<string, string>()
    const putSiteModel = (siteName: string, itemCd: string) => {
      const n = (siteName || '').trim()
      if (!n) return
      const label = preferredModelLabel(itemCd, tokens) || itemCd.trim()
      if (!label) return
      modelSiteNames.add(n)
      if (!modelBySiteExact.has(n)) modelBySiteExact.set(n, label)
      const nk = normSite(n)
      if (nk && !modelBySiteNorm.has(nk)) modelBySiteNorm.set(nk, label)
    }

    if (tokens.length > 0) {
      for (let from = 0; from < 20000; from += 1000) {
        const { data: inqRows } = await admin
          .from('inquiries')
          .select('site_nm, item_cd')
          .range(from, from + 999)
        if (!inqRows || inqRows.length === 0) break
        for (const r of inqRows) {
          const cd = String(r.item_cd || '')
          if (!itemCdMatchesModel(cd, tokens)) continue
          putSiteModel(String(r.site_nm || ''), cd)
        }
        if (inqRows.length < 1000) break
      }
      // MES 원본 인쿼리(2025 포함). home inquiries 는 최근분만 있어
      // C-50 계열이 2024 경로 오탐만 남거나 2025가 빠지던 원인.
      for (let from = 0; from < 20000; from += 1000) {
        const { data: mesRows } = await admin
          .from('mes_inquiries')
          .select('item_cd, raw_data')
          .range(from, from + 999)
        if (!mesRows || mesRows.length === 0) break
        for (const r of mesRows) {
          const cd = mesItemCd(r.item_cd, r.raw_data)
          if (!itemCdMatchesModel(cd, tokens)) continue
          putSiteModel(mesSiteName(r.raw_data), cd)
        }
        if (mesRows.length < 1000) break
      }
    }

    const byId = new Map<string, Row>()
    const pushRows = (list: Row[] | null | undefined) => {
      for (const r of list || []) {
        if (r?.id) byId.set(r.id, r)
      }
    }

    if (installAfter && tokens.length > 0) {
      const names = Array.from(modelSiteNames)
      const chunkSize = 40
      for (let i = 0; i < names.length; i += chunkSize) {
        const chunk = names.slice(i, i + chunkSize)
        for (const col of ['site_name', 'site_key'] as const) {
          for (let from = 0; from < 4000; from += 1000) {
            const { data, error: attErr } = await admin
              .from('archive_attachments')
              .select(ATT_COLS)
              .or(TP3_OR)
              .in(col, chunk)
              .order('uploaded_at', { ascending: false })
              .range(from, from + 999)
            if (attErr) {
              console.error('archive-checksheets att', col, attErr.message)
              break
            }
            pushRows((data || []) as Row[])
            if (!data || data.length < 1000) break
          }
        }
      }
    } else {
      let query = admin
        .from('archive_attachments')
        .select(ATT_COLS)
        .order('uploaded_at', { ascending: false })
        .limit(fetchCap)

      if (installAfter) {
        query = query.or(TP3_OR)
        if (q) {
          const like = `%${q.replace(/%/g, '')}%`
          query = query.or(
            `site_name.ilike.${like},original_name.ilike.${like},r2_key.ilike.${like},local_path.ilike.${like}`,
          )
        }
      } else {
        query = query.eq('type_code', 'TP1')
        if (q) query = query.ilike('site_name', `%${q}%`)
        if (year && year >= 2000 && year <= 2100) {
          if (month && month >= 1 && month <= 12) {
            const mm = String(month).padStart(2, '0')
            query = query.ilike('r2_key', `data/sites/${year}/${mm}/%`)
          } else {
            query = query.ilike('r2_key', `data/sites/${year}/%`)
          }
        }
      }

      const { data, error } = await query
      if (error) {
        console.error('archive-checksheets query', error.message)
        return new Response(
          JSON.stringify({
            success: false,
            error: installAfter ? '시공후 사진 조회에 실패했습니다.' : '체크시트 조회에 실패했습니다.',
          }),
          { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } },
        )
      }
      pushRows((data || []) as Row[])
    }

    const rows = Array.from(byId.values())
    type Site = {
      site_key: string
      site_name: string
      model_name?: string | null
      reg_date: string | null
      install_completed_date: string | null
      year: number | null
      month: number | null
      checksheet_count: number
      photo_count?: number
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
      if (installAfter ? !isInstallAfter(row) : !isChecksheet(row)) continue
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
      const guessed = installAfter ? guessModel(row) : null
      const fromInq =
        modelBySiteExact.get(siteName) ||
        modelBySiteExact.get(siteKey) ||
        modelBySiteNorm.get(normSite(siteName)) ||
        modelBySiteNorm.get(normSite(siteKey)) ||
        null
      const existing = map.get(siteKey)
      if (!existing) {
        map.set(siteKey, {
          site_key: siteKey,
          site_name: siteName,
          model_name: fromInq || guessed,
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
        if (!existing.model_name && (fromInq || guessed)) {
          existing.model_name = fromInq || guessed
        }
        if (!existing.reg_date && ym.reg_date) existing.reg_date = ym.reg_date
        if (existing.year == null && ym.year != null) existing.year = ym.year
        if (existing.month == null && ym.month != null) existing.month = ym.month
      }
    }

    let sites = Array.from(map.values())
    for (const s of sites) {
      s.attachments.sort((a, b) => (b.uploaded_at || '').localeCompare(a.uploaded_at || ''))
      s.thumbnail_media_path = s.attachments[0]?.media_path ?? null
      s.photo_count = s.attachments.length
    }
    if (installAfter && q) {
      const qq = q.toLowerCase()
      sites = sites.filter((s) => {
        const hay = `${s.site_name}|${s.site_key}|${s.model_name || ''}`.toLowerCase()
        return hay.includes(qq)
      })
    }
    if (installAfter && tokens.length > 0) {
      sites = sites.filter((s) => {
        const inqHit =
          modelBySiteExact.has(s.site_name) ||
          modelBySiteExact.has(s.site_key) ||
          modelBySiteNorm.has(normSite(s.site_name)) ||
          modelBySiteNorm.has(normSite(s.site_key))
        if (inqHit) return true
        const hay = `${s.model_name || ''}|${s.site_name}|${s.attachments.map((a) => a.r2_key || a.original_name || '').join('|')}`
        return hayHasModel(hay, tokens)
      })
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

      // 2) inquiries + mes_inquiries 등록일 (archive_sites 2024 로 덮어쓰지 않게 이후 날짜 우선)
      const { data: inqAll } = await admin
        .from('inquiries')
        .select('site_nm, inq_dt, instal_dt, install_dt_act')
        .limit(1000)
      for (const r of inqAll || []) {
        const name = String(r.site_nm || '').trim()
        addInstall(name, ymdOnly(r.install_dt_act) || ymdOnly(r.instal_dt))
        addReg(name, ymdOnly(r.inq_dt))
      }
      for (let from = 0; from < 5000; from += 1000) {
        const { data: mesInq } = await admin
          .from('mes_inquiries')
          .select('inq_dt, in_date, raw_data')
          .range(from, from + 999)
        if (!mesInq || mesInq.length === 0) break
        for (const r of mesInq) {
          const name = mesSiteName(r.raw_data)
          addReg(name, ymdOnly(r.inq_dt) || ymdOnly(r.in_date))
        }
        if (mesInq.length < 1000) break
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

      // 4) sales_schedule2
      const { data: ss2 } = await admin
        .from('sales_schedule2')
        .select('site, construction_completed_date, end_date, is_construction_completed')
        .limit(1000)
      for (const r of ss2 || []) {
        const sn = String(r.site || '').trim()
        const d =
          ymdOnly(r.construction_completed_date) ||
          (r.is_construction_completed ? ymdOnly(r.end_date) : null)
        addInstall(sn, d)
      }

      for (const s of page) {
        const fromReg =
          regExact.get(s.site_name) || regExact.get(s.site_key)
        if (fromReg) {
          const y = Number(fromReg.slice(0, 4)) || 0
          // 사진 경로 연도보다 오래된 archive_sites.reg_date 로 덮지 않음
          if (s.year == null || y >= s.year) {
            s.reg_date = fromReg
            if (y) {
              s.year = y
              s.month = Number(fromReg.slice(5, 7)) || s.month
            }
          } else if (!s.reg_date) {
            s.reg_date = fromReg
          }
        }

        s.install_completed_date =
          lookupInstall(s.site_name, installExact, installNorm) ||
          lookupInstall(s.site_key, installExact, installNorm) ||
          null
      }
    }

    const totalAttachments = page.reduce((n, s) => n + s.checksheet_count, 0)
    const nextOffset = offset + limit < totalSites ? offset + limit : null

    return new Response(
      JSON.stringify({
        success: true,
        query: q,
        kind: installAfter ? 'install_after' : 'checksheet',
        model: model || null,
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
    console.error('archive-checksheets', msg.slice(0, 120))
    return new Response(
      JSON.stringify({ success: false, error: '아카이브 조회 중 오류가 발생했습니다.' }),
      { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } },
    )
  }
})
