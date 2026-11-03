import 'dart:convert';
import 'dart:io';

import 'package:coad_customer_calls/models/business_card.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 명함 → vCard 3.0. 공유 시트로 넘기면 휴대폰이 「연락처에 추가」를 띄우고,
/// 카톡·문자로도 그대로 보낼 수 있다. 연락처 권한이 필요 없다.
String businessCardVCard(BusinessCard card) {
  String esc(String v) => v
      .trim()
      .replaceAll(r'\', r'\\')
      .replaceAll('\r\n', r'\n')
      .replaceAll('\n', r'\n')
      .replaceAll(',', r'\,')
      .replaceAll(';', r'\;');

  final name = card.name.trim();
  final company = card.company.trim();
  // 이름이 없으면 회사명을 표시 이름으로 — 연락처에 빈 이름으로 들어가지 않게.
  final display = name.isNotEmpty ? name : company;

  final lines = <String>[
    'BEGIN:VCARD',
    'VERSION:3.0',
    // 한국 이름은 성·이름을 나누지 않고 그대로 둔다.
    'N:${esc(display)};;;;',
    'FN:${esc(display)}',
    if (company.isNotEmpty) 'ORG:${esc(company)}',
    if (card.title.trim().isNotEmpty) 'TITLE:${esc(card.title)}',
    if (card.mobilePhone.trim().isNotEmpty)
      'TEL;TYPE=CELL:${esc(card.mobilePhone)}',
    if (card.officePhone.trim().isNotEmpty)
      'TEL;TYPE=WORK,VOICE:${esc(card.officePhone)}',
    if (card.faxPhone.trim().isNotEmpty)
      'TEL;TYPE=WORK,FAX:${esc(card.faxPhone)}',
    if (card.email.trim().isNotEmpty)
      'EMAIL;TYPE=INTERNET:${esc(card.email)}',
    if (card.address.trim().isNotEmpty)
      'ADR;TYPE=WORK:;;${esc(card.address)};;;;',
    'NOTE:${esc('COAD 명함 수첩')}',
    'END:VCARD',
  ];
  return '${lines.join('\r\n')}\r\n';
}

/// 공유용 .vcf 파일 이름 — 파일 시스템에 못 쓰는 글자만 뺀다.
String businessCardVCardFileName(BusinessCard card) {
  final base = (card.name.trim().isNotEmpty ? card.name : card.company)
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  return '${base.isEmpty ? '명함' : base}.vcf';
}

/// 임시 폴더에 .vcf를 쓰고 경로를 돌려준다.
Future<File> writeBusinessCardVCard(BusinessCard card) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${businessCardVCardFileName(card)}');
  return file.writeAsBytes(utf8.encode(businessCardVCard(card)), flush: true);
}

/// .vcf로 공유 시트를 연다 — 「연락처」를 고르면 휴대폰 연락처에 저장, 카톡·문자로도 보낸다.
Future<void> shareBusinessCardVCard(
  BuildContext context,
  BusinessCard card,
) async {
  final box = context.findRenderObject() as RenderBox?;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final file = await writeBusinessCardVCard(card);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/vcard')],
        subject: card.displayName,
        // 아이패드는 공유 창 위치가 있어야 뜬다.
        sharePositionOrigin: box == null || !box.hasSize
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } catch (e) {
    messenger?.showSnackBar(
      SnackBar(content: Text('연락처 파일을 만들지 못했습니다: $e')),
    );
  }
}
