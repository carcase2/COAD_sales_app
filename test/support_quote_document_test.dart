import 'dart:convert';
import 'dart:typed_data';

import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_document.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_export.dart';
import 'package:coad_customer_calls/features/customer_support/support_site_index.dart';
import 'package:coad_customer_calls/models/region.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SupportQuoteDocument doc() => const SupportQuoteDocument(
    id: '1',
    customerName: '김현장',
    phone: '010-0000-0000',
    email: 'as@example.com',
    site: '수성 한빛',
    ymd: '2026-08-20',
    lines: [
      SupportQuoteLine(
        name: '모터',
        spec: '800N',
        unit: 'EA',
        qty: 2,
        unitPrice: 85000,
      ),
    ],
    note: '유상',
  );

  test('수량×단가로 합계를 낸다', () {
    expect(doc().total, 170000);
    expect(doc().lines.first.amount, 170000);
  });

  test('네고 %·금액이 최종 합계에 반영된다', () {
    const base = SupportQuoteDocument(
      id: 'n1',
      customerName: '김현장',
      ymd: '2026-09-05',
      lines: [
        SupportQuoteLine(
          name: '모터',
          qty: 1,
          unitPrice: 200000,
        ),
      ],
    );
    expect(base.listTotal, 200000);
    expect(base.copyWith(negoPercent: 10).total, 180000);
    expect(base.copyWith(negoPercent: 10).negoSummary, contains('10%'));
    expect(base.copyWith(negoAmount: 30000).total, 170000);
    expect(base.copyWith(negoAmount: 30000).hasNego, isTrue);
  });

  test('수정 시 작성자는 유지하고 변경 요약·이력을 남긴다', () {
    const before = SupportQuoteDocument(
      id: 'a1',
      customerName: '김현장',
      ymd: '2026-09-05',
      createdBy: '홍길동',
      createdAt: '2026-09-05T01:00:00.000Z',
      lines: [
        SupportQuoteLine(name: '모터', qty: 1, unitPrice: 100000),
      ],
    );
    final after = before.copyWith(
      negoPercent: 10,
      lines: const [
        SupportQuoteLine(name: '모터', qty: 1, unitPrice: 100000),
        SupportQuoteLine(name: '인건비', qty: 1, unitPrice: 50000, kind: kSupportQuoteKindLabor),
      ],
    );
    final summary = supportQuoteEditDiffSummary(before, after);
    expect(summary, contains('합계'));
    expect(summary, contains('품목'));
    expect(summary, contains('네고'));

    final history = supportQuoteAppendEditHistory(
      previous: before.editHistory,
      at: '2026-09-05T02:00:00.000Z',
      by: '김수정',
      summary: summary,
    );
    expect(history, hasLength(1));
    expect(history.single.by, '김수정');

    final audited = after.copyWith(
      createdBy: '홍길동',
      createdAt: '2026-09-05T01:00:00.000Z',
      updatedBy: '김수정',
      updatedAt: '2026-09-05T02:00:00.000Z',
      editHistory: history,
    );
    final line = supportQuoteAuditLine(audited);
    expect(line, contains('작성 홍길동'));
    expect(line, contains('수정 김수정'));
  });

  test('부품·인건비·장비대를 나누고 한글 합계를 만든다', () {
    const mixed = SupportQuoteDocument(
      id: '2',
      customerName: '김현장',
      ymd: '2026-08-20',
      lines: [
        SupportQuoteLine(
          name: '모터',
          unit: 'EA',
          qty: 1,
          unitPrice: 100000,
          kind: kSupportQuoteKindPart,
        ),
        SupportQuoteLine(
          name: '교체인건비',
          unit: '식',
          qty: 1,
          unitPrice: 80000,
          kind: kSupportQuoteKindLabor,
        ),
        SupportQuoteLine(
          name: '고소작업대',
          unit: '식',
          qty: 1,
          unitPrice: 20000,
          kind: kSupportQuoteKindEquipment,
        ),
      ],
    );
    expect(mixed.total, 200000);
    expect(mixed.linesOfKind(kSupportQuoteKindLabor).single.name, '교체인건비');
    expect(supportQuoteKoreanTotalLabel(200000), contains('이십만원정'));
    expect(supportQuoteKoreanTotalLabel(0), '일금 영원정 (0원, VAT. 별도)');
    expect(supportQuoteHistoryLine(mixed), contains('200,000원'));
    final consult = supportQuoteConsultBody(mixed);
    expect(consult, contains('교체인건비'));
    expect(consult, contains('합계 200,000원'));
  });

  test('완료된 접수도 같은 전화면 한 현장으로 묶이고 검색된다', () {
    const open = SupportCallLog(
      id: 'a',
      customerName: '김현장',
      customerPhone: '010-0000-0000',
      issue: '현장: 수성 한빛\n모터 소음',
      address: '대구 수성구',
      serviceStatusId: kSupportStatusReceived,
    );
    const done = SupportCallLog(
      id: 'b',
      customerName: '김현장',
      customerPhone: '01000000000',
      issue: '현장: 수성 한빛\n리모컨',
      address: '대구 수성구',
      serviceStatusId: kSupportStatusCompleted,
    );
    const other = SupportCallLog(
      id: 'c',
      customerName: '다른곳',
      customerPhone: '010-1111-2222',
      issue: '현장: 송도',
      serviceStatusId: kSupportStatusCompleted,
    );
    final sites = buildSupportIndexedSites(logs: [open, done, other]);
    expect(sites, hasLength(2));
    final hanbit = sites.firstWhere((s) => s.title == '수성 한빛');
    expect(hanbit.receptionCount, 2);
    expect(hanbit.hasCompleted, isTrue);
    expect(hanbit.allCompleted, isFalse);
    expect(supportIndexedSiteMatches(hanbit, '한빛'), isTrue);
    expect(supportIndexedSiteMatches(hanbit, '010-0000-0000'), isTrue);
    expect(supportIndexedSiteMatches(hanbit, '송도'), isFalse);
    expect(supportIndexedSiteMatchesStatus(hanbit, '전체'), isTrue);
    expect(supportIndexedSiteMatchesStatus(hanbit, '미처리'), isTrue);
    expect(supportIndexedSiteMatchesStatus(hanbit, '완료'), isTrue);
    expect(supportIndexedSiteMatchesStatus(hanbit, '방문예정'), isFalse);
    final regions = [
      Region(
        id: 'daegu',
        sido: '대구',
        region: '대구',
        manager: 'm',
        branchType: '대구',
      ),
    ];
    expect(supportIndexedSiteBranch(hanbit, regions), '대구');
    final statusCounts = supportIndexedSiteStatusCounts(sites);
    expect(statusCounts['전체'], 2);
    expect(statusCounts['미처리'], 1);
    expect(statusCounts['완료'], 2);
    expect(supportIndexedSiteBranchCounts(sites, regions)['대구'], 1);
  });

  test('같은 현장 견적서는 현장 그룹으로 묶인다', () {
    final a = doc();
    const b = SupportQuoteDocument(
      id: '2',
      customerName: '김현장',
      phone: '010-0000-0000',
      site: '수성 한빛',
      ymd: '2026-09-01',
      lines: [
        SupportQuoteLine(name: '인건비', unit: '식', qty: 1, unitPrice: 80000),
      ],
    );
    const other = SupportQuoteDocument(
      id: '3',
      customerName: '다른곳',
      phone: '010-1111-2222',
      site: '송도',
      ymd: '2026-08-01',
    );
    final groups = supportQuoteSiteGroups([a, b, other]);
    expect(groups, hasLength(2));
    expect(groups.first.title, '수성 한빛');
    expect(groups.first.quotes, hasLength(2));
    expect(groups.first.total, 250000);
  });

  test('현장 전화·이름으로 견적을 묶는다', () {
    final quote = doc();
    expect(
      supportQuoteBelongsToSite(quote, phone: '010-0000-0000', site: '수성 한빛'),
      isTrue,
    );
    expect(
      supportQuoteBelongsToSite(quote, phone: '010-1111-2222', site: '다른현장'),
      isFalse,
    );
  });

  test('접수 견적은 주소가 같으면 묶고 이름만으로는 안 묶는다', () {
    const quote = SupportQuoteDocument(
      id: 'a1',
      customerName: '홍길동',
      phone: '010-1111-2222',
      site: '다른표기',
      address: '대구 수성구 동대구로 123',
      ymd: '2026-08-01',
      callLogId: 'old-log',
    );
    expect(
      supportQuoteBelongsToReception(
        quote,
        callLogId: 'new-log',
        address: '대구수성구동대구로123',
      ),
      isTrue,
    );
    expect(
      supportQuoteBelongsToReception(
        quote,
        callLogId: 'new-log',
        address: '서울 강남구 테헤란로 1',
      ),
      isFalse,
    );
    expect(
      supportQuoteBelongsToReception(
        quote,
        callLogId: 'old-log',
        address: '',
      ),
      isTrue,
    );
    expect(
      supportAddressesMatch('대구 수성구 동대구로 123', '대구 수성구 동대구로 123 101호'),
      isTrue,
    );
    expect(supportAddressesMatch('서울', '서울시'), isFalse);
  });

  test('고객·현장·품목으로 검색한다', () {
    expect(supportQuoteMatches(doc(), ''), isTrue);
    expect(supportQuoteMatches(doc(), '김현장'), isTrue);
    expect(supportQuoteMatches(doc(), '한빛'), isTrue);
    expect(supportQuoteMatches(doc(), '모터'), isTrue);
    expect(supportQuoteMatches(doc(), '셔터'), isFalse);
    expect(supportQuoteMatches(doc(), 'as@example.com'), isTrue);
  });

  test('이메일·파일 이름을 만든다', () {
    expect(supportQuoteFileStem(doc()), 'AS견적서_김현장_2026-08-20');
    expect(
      supportQuoteFileStem(
        const SupportQuoteDocument(
          id: '2',
          customerName: 'a/b:c',
          ymd: '2026-01-01',
        ),
      ),
      'AS견적서_a_b_c_2026-01-01',
    );
    expect(supportQuoteEmailSubject(doc()), contains('김현장'));
    expect(
      supportQuoteEmailBody(doc(), totalLabel: '170,000원'),
      contains('170,000원'),
    );
  });

  test('이메일을 json에 남긴다', () {
    final parsed = SupportQuoteDocument.fromJson(doc().toJson());
    expect(parsed.email, 'as@example.com');
    expect(parsed.total, 170000);
  });

  test('방문 기록용 견적서는 발송분을 우선한다', () {
    const unsent = SupportQuoteDocument(
      id: 'u',
      customerName: '김현장',
      ymd: '2026-09-01',
      callLogId: 'log-1',
      lines: [SupportQuoteLine(name: '구견적', unitPrice: 1000, qty: 1)],
    );
    const sentOlder = SupportQuoteDocument(
      id: 's1',
      customerName: '김현장',
      ymd: '2026-08-01',
      sentYmd: '2026-08-02',
      callLogId: 'log-1',
      lines: [SupportQuoteLine(name: '모터', unitPrice: 1000, qty: 1)],
    );
    const sentNewer = SupportQuoteDocument(
      id: 's2',
      customerName: '김현장',
      ymd: '2026-09-03',
      sentYmd: '2026-09-03',
      callLogId: 'log-1',
      lines: [
        SupportQuoteLine(name: '모터', unitPrice: 1000, qty: 1),
        SupportQuoteLine(name: '리모컨', unitPrice: 2000, qty: 1),
      ],
    );
    const otherLog = SupportQuoteDocument(
      id: 'other',
      customerName: '김현장',
      ymd: '2026-09-10',
      sentYmd: '2026-09-10',
      callLogId: 'log-2',
      lines: [SupportQuoteLine(name: '다른접수', unitPrice: 1, qty: 1)],
    );
    final picked = pickSupportQuoteForVisitReport(
      [unsent, sentOlder, sentNewer, otherLog],
      callLogId: 'log-1',
    );
    expect(picked?.id, 's2');
    expect(supportQuotePartNames(picked!), ['모터', '리모컨']);
  });

  test('견적서 이미지를 PDF로 감싼다', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    final pdf = await supportQuotePngToPdf(Uint8List.fromList(png));
    expect(pdf.length, greaterThan(100));
    expect(ascii.decode(pdf.take(4).toList()), '%PDF');
  });
}
