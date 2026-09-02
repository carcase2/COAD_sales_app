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

  test('견적서 이미지를 PDF로 감싼다', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    final pdf = await supportQuotePngToPdf(Uint8List.fromList(png));
    expect(pdf.length, greaterThan(100));
    expect(ascii.decode(pdf.take(4).toList()), '%PDF');
  });
}
