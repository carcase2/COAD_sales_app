import 'package:coad_customer_calls/core/utils/date_seoul.dart';

/// 고수 사이트(coadmaster.com) 무료견적상담 — 홈페이지 문의.
/// coad-gosu-followup 이 20분마다 `gosu_sites` 로 동기화한다. 뷰 `gosu_sites_board` 한 행.
class GosuSite {
  const GosuSite({
    required this.gosuId,
    required this.receivedAt,
    required this.workerStatus,
    this.estimateId,
    this.customerName,
    this.customerPhone,
    this.area,
    this.address,
    this.productName,
    this.productSize,
    this.requestText,
    this.workerName,
    this.onsiteAt,
    this.canceledAt,
    this.gosuUpdatedAt,
    this.gosuMemo,
    this.imageUrls = const [],
    this.lastFollowupAt,
    this.lastResult,
    this.lastReason,
    this.lastAuthor,
    this.lastNextAction,
    this.lastNextActionAt,
    this.followupCount = 0,
  });

  final String gosuId;
  final String? estimateId;
  final DateTime receivedAt;
  final String? customerName;
  final String? customerPhone;
  final String? area;
  final String? address;
  final String? productName;
  final String? productSize;
  final String? requestText;

  /// 담당 (고수 사이트에 지정된 담당자 — 웹 '담당' 칸과 같음)
  final String? workerName;

  /// 고수 진행상황 그대로 (접수중 / 접수완료 / 취소 / …)
  final String workerStatus;
  final DateTime? onsiteAt;
  final DateTime? canceledAt;
  final DateTime? gosuUpdatedAt;
  final String? gosuMemo;
  final List<String> imageUrls;

  final DateTime? lastFollowupAt;
  final String? lastResult;
  final String? lastReason;
  final String? lastAuthor;
  final String? lastNextAction;

  /// 다음 통화 예정일 (YYYY-MM-DD)
  final String? lastNextActionAt;
  final int followupCount;

  factory GosuSite.fromJson(Map<String, dynamic> j) {
    String? s(String k) {
      final v = j[k];
      if (v == null) return null;
      final t = v.toString().trim();
      return t.isEmpty ? null : t;
    }

    List<String> urls(Object? raw) => raw is List
        ? raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const [];

    return GosuSite(
      gosuId: j['gosu_id'].toString(),
      estimateId: s('estimate_id'),
      receivedAt:
          parseSupabaseTimestampUtc(j['received_at']) ?? DateTime.now().toUtc(),
      customerName: s('customer_name'),
      customerPhone: s('customer_phone'),
      area: s('area'),
      address: s('address'),
      productName: s('product_name'),
      productSize: s('product_size'),
      requestText: s('request_text'),
      workerName: s('worker_name'),
      workerStatus: s('worker_status') ?? '',
      onsiteAt: parseSupabaseTimestampUtc(j['onsite_at']),
      canceledAt: parseSupabaseTimestampUtc(j['canceled_at']),
      gosuUpdatedAt: parseSupabaseTimestampUtc(j['gosu_updated_at']),
      gosuMemo: s('gosu_memo'),
      imageUrls: urls(j['image_urls']),
      lastFollowupAt: parseSupabaseTimestampUtc(j['last_followup_at']),
      lastResult: s('last_result'),
      lastReason: s('last_reason'),
      lastAuthor: s('last_author'),
      lastNextAction: s('last_next_action'),
      lastNextActionAt: s('last_next_action_at'),
      followupCount: (j['followup_count'] as num?)?.toInt() ?? 0,
    );
  }

  String get displayName => customerName ?? '이름 없음';

  /// 01012345678 → 010-1234-5678
  String get displayPhone {
    final p = customerPhone ?? '';
    if (RegExp(r'^\d{11}$').hasMatch(p)) {
      return '${p.substring(0, 3)}-${p.substring(3, 7)}-${p.substring(7)}';
    }
    return p.isEmpty ? '-' : p;
  }

  String get productLabel {
    final parts = [productName, productSize].whereType<String>().toList();
    return parts.isEmpty ? '-' : parts.join(' · ');
  }
}

class GosuSiteFollowup {
  const GosuSiteFollowup({
    required this.id,
    required this.gosuId,
    required this.stage,
    required this.result,
    required this.author,
    required this.createdAt,
    this.reason,
    this.nextAction,
    this.nextActionAt,
  });

  final String id;
  final String gosuId;
  final String stage;
  final String result;
  final String? reason;
  final String? nextAction;
  final String? nextActionAt;
  final String author;
  final DateTime createdAt;

  factory GosuSiteFollowup.fromJson(Map<String, dynamic> j) {
    String? s(String k) {
      final v = j[k];
      if (v == null) return null;
      final t = v.toString().trim();
      return t.isEmpty ? null : t;
    }

    return GosuSiteFollowup(
      id: j['id'].toString(),
      gosuId: j['gosu_id'].toString(),
      stage: s('stage') ?? '',
      result: s('result') ?? '',
      reason: s('reason'),
      nextAction: s('next_action'),
      nextActionAt: s('next_action_at'),
      author: s('author') ?? '',
      createdAt:
          parseSupabaseTimestampUtc(j['created_at']) ?? DateTime.now().toUtc(),
    );
  }
}
