import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_spec_note.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 사이즈 표준단가 영업 견적서 용지. 고객지원 A/S 견적서와 같은 칸.
/// 견적서에 찍는 지사. 양식 지역지사 시트의 주소·메일.
class SizeQuoteOffice {
  const SizeQuoteOffice({
    required this.label,
    required this.address,
    required this.email,
  });

  final String label;
  final String address;
  final String email;
}

const kSizeQuoteHeadOffice = SizeQuoteOffice(
  label: '본사',
  address: '경기도 화성시 남양읍 현대기아로 202-37',
  email: 'sales@coaddoor.com',
);

const kSizeQuoteJungbuOffice = SizeQuoteOffice(
  label: '중부지사',
  address: '충북 청주시 서원구 현도면 시목외천로137,2동',
  email: 'coaddj@coaddoor.com',
);

const kSizeQuoteYeongnamOffice = SizeQuoteOffice(
  label: '영남지사',
  address: '대구광역시 달성군 논공읍 금강로4길 21',
  email: 'coaddg@coaddoor.com',
);

const kSizeQuoteHonamOffice = SizeQuoteOffice(
  label: '호남지사',
  address: '전라남도 나주시 산포면 내길1길 36',
  email: 'coadjn@coaddoor.com',
);

/// 로그인 지사 이름을 견적서 지사로 맞춘다. 비어 있으면 본사.
SizeQuoteOffice sizeQuoteOfficeOf(String? branchName) {
  final raw = (branchName ?? '').trim();
  final key = raw.toLowerCase();
  if (raw.isEmpty || key == '본사' || key == 'hq') return kSizeQuoteHeadOffice;
  if (raw.contains('대구')) {
    return SizeQuoteOffice(
      label: '대구지사',
      address: kSizeQuoteYeongnamOffice.address,
      email: kSizeQuoteYeongnamOffice.email,
    );
  }
  if (raw.contains('영남')) return kSizeQuoteYeongnamOffice;
  if (raw.contains('중부') || raw.contains('청주')) return kSizeQuoteJungbuOffice;
  if (raw.contains('전남') || raw.contains('호남') || raw.contains('나주')) {
    return SizeQuoteOffice(
      label: raw.contains('호남') ? '호남지사' : '전남지사',
      address: kSizeQuoteHonamOffice.address,
      email: kSizeQuoteHonamOffice.email,
    );
  }
  return SizeQuoteOffice(label: raw.isEmpty ? '본사' : raw, address: '', email: '');
}

class QuoteBranchContact {
  const QuoteBranchContact({
    required this.id,
    required this.name,
    this.shortName = '',
    this.address = '',
    this.email = '',
  });

  final String id;
  final String name;
  final String shortName;
  final String address;
  final String email;

  bool matches(String branchName) {
    final raw = branchName.trim();
    if (raw.isEmpty) return false;
    return name.trim() == raw || shortName.trim() == raw;
  }
}

/// 지사 표에 주소·메일이 있으면 그 값을 쓰고, 없으면 양식 기본값을 쓴다.
SizeQuoteOffice sizeQuoteOfficeFor(
  String? branchName,
  List<QuoteBranchContact> contacts,
) {
  final raw = (branchName ?? '').trim();
  final fallback = sizeQuoteOfficeOf(raw);
  for (final row in contacts) {
    if (!row.matches(raw)) continue;
    return SizeQuoteOffice(
      label: row.name.trim().isEmpty ? fallback.label : row.name.trim(),
      address: row.address.trim().isNotEmpty
          ? row.address.trim()
          : fallback.address,
      email: row.email.trim().isNotEmpty ? row.email.trim() : fallback.email,
    );
  }
  return fallback;
}

class SizeQuotePaper extends StatelessWidget {
  const SizeQuotePaper({
    super.key,
    required this.doc,
    this.managerName,
    this.branchName,
    this.office,
    this.notes,
  });

  final SizeQuoteDocument doc;

  /// 회사측 담당자. 넘긴 이름이 있으면 그 이름(로그인한 사람)을 쓴다.
  final String? managerName;

  /// 로그인한 사람의 지사.
  final String? branchName;

  /// 지사별 주소·메일. 있으면 이 값을 견적서에 찍는다.
  final SizeQuoteOffice? office;

  /// DB에 있는 공통·모델 노트. 없으면 코드의 기본 문구를 쓴다.
  final SizeQuoteNoteBook? notes;

  String get _manager {
    final given = (managerName ?? '').trim();
    if (given.isNotEmpty) return given;
    return (doc.createdBy ?? '').trim();
  }

  SizeQuoteOffice get _office => office ?? sizeQuoteOfficeOf(branchName);

  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF4B5563);
  static const _line = Color(0xFF111827);
  static const _nego = Color(0xFFDC2626);
  static final _won = NumberFormat('#,###');

  String _money(int n) {
    if (n == 0) return '-';
    if (n < 0) return '-${_won.format(-n)}원';
    return '${_won.format(n)}원';
  }

  @override
  Widget build(BuildContext context) {
    var no = 0;
    return Container(
      width: 560,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '見  積  書',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _field(
                      '현장명',
                      doc.site.trim().isEmpty ? doc.customerName : doc.site,
                    ),
                    _field(
                      '공사명',
                      sizeQuoteResolvedWorkName(
                        workName: doc.workName,
                        categoryName: doc.categoryName,
                        modelName: doc.modelName,
                      ),
                    ),
                    _field('담당자', _manager, oneLine: true),
                    _field('H.P', doc.phone),
                    _field('E-MAIL', doc.email),
                    _field('견적번호', doc.quoteNo),
                    _field('견적일', doc.ymd),
                    _field('납기', '발주 후 15일 이내'),
                    _field('유효기간', '견적 후 10일 이내'),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 228,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Image.asset(
                        'assets/images/quote_logo.png',
                        width: 188,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_office.address.trim().isNotEmpty)
                      Text(
                        '주소 : ${_office.address}',
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.35,
                          color: _ink,
                        ),
                      ),
                    const Text(
                      'TEL : 1899-7081   FAX : 0505-182-5567',
                      style: TextStyle(fontSize: 10, height: 1.35, color: _ink),
                    ),
                    const Text(
                      'Homepage : www.coaddoor.com',
                      style: TextStyle(fontSize: 10, height: 1.35, color: _ink),
                    ),
                    if (_office.email.trim().isNotEmpty)
                      Text(
                        'E-mail : ${_office.email}',
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.35,
                          color: _ink,
                        ),
                      ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 58,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerLeft,
                        children: [
                          const Positioned(
                            right: 0,
                            top: 0,
                            child: Image(
                              image: AssetImage('assets/images/quote_stamp.png'),
                              width: 58,
                              height: 58,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '코아드  ${_office.label}',
                                maxLines: 1,
                                softWrap: false,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              if (_manager.isNotEmpty)
                                SizedBox(
                                  width: double.infinity,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '담당자 : $_manager',
                                      maxLines: 1,
                                      softWrap: false,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        height: 1.35,
                                        fontWeight: FontWeight.w800,
                                        color: _ink,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '下記와 같이 見積하나이다.',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '금액 : ${sizeQuoteKoreanTotalLabel(doc.total)}',
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Table(
            border: TableBorder.all(color: _line, width: 0.8),
            columnWidths: const {
              0: FixedColumnWidth(28),
              1: FlexColumnWidth(3.4),
              2: FlexColumnWidth(2.0),
              3: FixedColumnWidth(36),
              4: FixedColumnWidth(36),
              5: FixedColumnWidth(86),
              6: FixedColumnWidth(92),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
                children: [
                  _th('NO'),
                  _th('품명\n(Description)'),
                  _th('규격\n(Specification)'),
                  _th('단위\n(Unit)'),
                  _th("수량\n(Q'ty)"),
                  _th('단가\n(Unit Price)'),
                  _th('금액\n(Amount)'),
                ],
              ),
              for (final kind in kSizeQuoteKindOrder) ...[
                if (doc.linesOfKind(kind).isNotEmpty)
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFFEEF2FF)),
                    children: [
                      _td(''),
                      _td(
                        '◆ ${sizeQuoteKindLabel(kind)}',
                        bold: true,
                        align: TextAlign.left,
                      ),
                      _td(''),
                      _td(''),
                      _td(''),
                      _td(''),
                      _td(''),
                    ],
                  ),
                for (final line in doc.linesOfKind(kind))
                  TableRow(
                    children: [
                      _td('${++no}'),
                      _td(line.name, align: TextAlign.left),
                      _td(line.spec.trim().isEmpty ? '-' : line.spec.trim()),
                      _td(line.unit.trim().isEmpty ? '-' : line.unit.trim()),
                      _td('${line.qty}'),
                      _moneyTd(line.unitPrice ?? 0),
                      _moneyTd(line.amount, bold: true),
                    ],
                  ),
              ],
              if (doc.lines.isEmpty)
                TableRow(
                  children: [
                    _td(''),
                    _td('품목 없음', align: TextAlign.left),
                    _td(''),
                    _td(''),
                    _td(''),
                    _td(''),
                    _td(''),
                  ],
                ),
              if (doc.hasNego) ...[
                TableRow(
                  children: [
                    _td(''),
                    _td('소계', bold: true, align: TextAlign.left),
                    _td(''),
                    _td(''),
                    _td(''),
                    _td(''),
                    _moneyTd(doc.listTotal, bold: true),
                  ],
                ),
                TableRow(
                  children: [
                    _td(''),
                    _td(
                      '네고 ${doc.negoSummary}',
                      bold: true,
                      align: TextAlign.left,
                      color: _nego,
                    ),
                    _td(''),
                    _td(''),
                    _td(''),
                    _td(''),
                    _moneyTd(-doc.negoOff, bold: true, color: _nego),
                  ],
                ),
              ],
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
                children: [
                  _td(''),
                  _td('TOTAL', bold: true, align: TextAlign.left),
                  _td(''),
                  _td(''),
                  _td(''),
                  _td(''),
                  _moneyTd(doc.total, bold: true),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: _line)),
            child: Text(
              sizeQuotePaperNote(
                categoryName: doc.categoryName,
                modelName: doc.modelName,
                extra: doc.note,
                book: notes,
              ),
              style: const TextStyle(fontSize: 11, height: 1.4, color: _ink),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '※ 코아드자동문(C-Series)은 전 모델 CE인증을 통과한 제품입니다.\n※ 6년연속한국소비자만족지수 1위 / 2015한국소비자선호도 1위 브랜드 대상',
            style: TextStyle(fontSize: 9.5, height: 1.35, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value, {bool oneLine = false}) {
    final shown = value.trim().isEmpty ? '-' : value.trim();
    final style = const TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: _ink,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '$label :',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          Expanded(
            child: oneLine
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      shown,
                      maxLines: 1,
                      softWrap: false,
                      style: style,
                    ),
                  )
                : Text(shown, style: style),
          ),
        ],
      ),
    );
  }

  Widget _th(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1.15,
          color: _ink,
        ),
      ),
    );
  }

  Widget _td(
    String text, {
    TextAlign align = TextAlign.center,
    bool bold = false,
    Color color = _ink,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Text(
        text,
        textAlign: align,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          height: 1.2,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _moneyTd(int n, {bool bold = false, Color color = _ink}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          _money(n),
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 10,
            height: 1,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
