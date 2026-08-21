import 'package:coad_customer_calls/features/customer_support/support_quote_document.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A/S 견적서 용지. 테마와 상관없이 흰 배경으로 캡처한다.
class SupportQuotePaper extends StatelessWidget {
  const SupportQuotePaper({super.key, required this.doc});

  final SupportQuoteDocument doc;

  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _line = Color(0xFFD1D5DB);
  static const _accent = Color(0xFF0F766E);
  static const _headerBg = Color(0xFF0F766E);
  static final _won = NumberFormat('#,###');

  String _money(int n) => n <= 0 ? '-' : '${_won.format(n)}원';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: _headerBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              children: [
                Text(
                  'A/S 견 적 서',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '코아드 고객지원팀',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _kv('견적일', doc.ymd),
          _kv('고객명', doc.customerName),
          if (doc.phone.trim().isNotEmpty) _kv('전화', doc.phone.trim()),
          if (doc.email.trim().isNotEmpty) _kv('이메일', doc.email.trim()),
          if (doc.site.trim().isNotEmpty) _kv('현장명', doc.site.trim()),
          if (doc.address.trim().isNotEmpty) _kv('주소', doc.address.trim()),
          if ((doc.createdBy ?? '').trim().isNotEmpty)
            _kv('작성', doc.createdBy!.trim()),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(7),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 4, child: Text('품명', style: _headStyle)),
                      Expanded(flex: 3, child: Text('규격', style: _headStyle)),
                      Expanded(child: Text('수량', style: _headStyle)),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '단가',
                          style: _headStyle,
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '금액',
                          style: _headStyle,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                if (doc.lines.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('품목 없음', style: TextStyle(color: _muted)),
                  )
                else
                  for (final line in doc.lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(line.name, style: _cellStyle),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              line.spec.trim().isEmpty ? '-' : line.spec.trim(),
                              style: _cellStyle,
                            ),
                          ),
                          Expanded(
                            child: Text('${line.qty}', style: _cellStyle),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _money(line.unitPrice ?? 0),
                              style: _cellStyle,
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _money(line.amount),
                              style: _cellStyle.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '합계 ${_money(doc.total)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _accent,
              ),
            ),
          ),
          if (doc.note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              '비고',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              doc.note.trim(),
              style: const TextStyle(fontSize: 12, height: 1.35, color: _ink),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            '본 견적서는 코아드 고객지원팀 A/S 전용입니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _headStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w800,
  color: Color(0xFF374151),
);

const _cellStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: Color(0xFF111827),
);
