import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 사이즈 표준단가 영업 견적서 용지. 고객지원 A/S 견적서와 같은 칸.
class SizeQuotePaper extends StatelessWidget {
  const SizeQuotePaper({super.key, required this.doc});

  final SizeQuoteDocument doc;

  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF4B5563);
  static const _line = Color(0xFF111827);
  static const _headerBg = Color(0xFF111827);
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _headerBg,
              border: Border.all(color: _line, width: 1.4),
            ),
            child: const Text(
              '見  積  書',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
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
                      doc.workName.trim().isEmpty
                          ? '${doc.modelName} 설치 공사'
                          : doc.workName,
                    ),
                    _field('담당자', doc.createdBy?.trim() ?? ''),
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
              const SizedBox(
                width: 210,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '본사주소 : 경기도 화성시 남양읍 현대기아로 202-37',
                      style: TextStyle(fontSize: 10, height: 1.35, color: _ink),
                    ),
                    Text(
                      'TEL : 1899-7081   FAX : 0505-182-5567',
                      style: TextStyle(fontSize: 10, height: 1.35, color: _ink),
                    ),
                    Text(
                      'Homepage : www.coaddoor.com',
                      style: TextStyle(fontSize: 10, height: 1.35, color: _ink),
                    ),
                    Text(
                      'E-mail : sales@coaddoor.com',
                      style: TextStyle(fontSize: 10, height: 1.35, color: _ink),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '코아드',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _ink,
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
              [
                '※ NOTE',
                '',
                '1. VAT. 별도',
                '2. 상기 견적서 이외의 추가 자재비 별도 청구',
                '3. 결제조건 : 계약 시 협의',
                if (doc.note.trim().isNotEmpty) '',
                if (doc.note.trim().isNotEmpty) doc.note.trim(),
              ].join('\n'),
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

  Widget _field(String label, String value) {
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
            child: Text(
              value.trim().isEmpty ? '-' : value.trim(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
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
