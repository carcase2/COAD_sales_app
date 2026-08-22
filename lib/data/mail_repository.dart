import 'dart:convert';

import 'package:coad_customer_calls/core/config/env.dart';
import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/mail_permissions.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/features/mail/mail_compose.dart';
import 'package:coad_customer_calls/features/mail/mail_models.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// SMTP는 끝났는데 게이트웨이 타임아웃으로 앱만 실패로 보이는 경우.
class MailDeliveryUnconfirmedException extends ApiException {
  MailDeliveryUnconfirmedException()
    : super(
        '보내기 확인이 늦었습니다. 메일은 이미 도착했을 수 있으니 '
        '받은 편지함을 확인한 뒤, 없을 때만 다시 보내 주세요.',
        statusCode: 408,
      );
}

class MailSendRequest {
  const MailSendRequest({
    required this.toEmail,
    required this.subject,
    required this.body,
    required this.attachments,
    this.sender,
    this.notifyTelegram = false,
    this.telegramAgentName,
  });

  final String toEmail;
  final String subject;
  final String body;
  final List<MailAttachment> attachments;
  final MailAssignee? sender;
  final bool notifyTelegram;
  final String? telegramAgentName;
}

class MailRepository {
  MailRepository(this._deps);

  final AppDependencies _deps;
  final SupabaseClient _client = Supabase.instance.client;

  /// 메일·텔레그램 API는 COAD_home Next 서버가 필요.
  /// BASE_URL이 비어 있으면 운영 홈 주소를 쓴다.
  String get _mailApiBase {
    final configured = _deps.effectiveBaseUrl.trim();
    if (configured.isNotEmpty) return configured;
    for (final key in const ['MAIL_API_URL', 'COAD_HOME_URL']) {
      final v = dotenv.env[key]?.trim() ?? '';
      if (v.isNotEmpty) {
        return v.endsWith('/') ? v.substring(0, v.length - 1) : v;
      }
    }
    return kDefaultCoadHomeUrl;
  }

  Future<MailCatalog> fetchCatalog() async {
    final assignees = await fetchAssignees();
    final files = await fetchFiles();
    final categories = await fetchCategories();
    return MailCatalog(
      assignees: assignees,
      files: files,
      categories: categories,
    );
  }

  Future<List<MailAssignee>> fetchAssignees() async {
    final groupsRes = await _client
        .from('groups')
        .select('id, name, color, permissions');
    final mailGroupIds = <String>[];
    final groupMeta = <String, ({String name, String? color})>{};
    for (final raw in groupsRes as List) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final perms = <String>[];
      final p = map['permissions'];
      if (p is List) {
        perms.addAll(p.map((e) => e.toString()));
      }
      if (!groupHasMailPermission(perms)) continue;
      final id = '${map['id'] ?? ''}';
      if (id.isEmpty) continue;
      mailGroupIds.add(id);
      groupMeta[id] = (
        name: '${map['name'] ?? ''}',
        color: map['color']?.toString(),
      );
    }

    final List usersRes;
    if (mailGroupIds.isEmpty) {
      usersRes =
          await _client
                  .from('users')
                  .select('id, name, phone, email, group_id, is_active, role')
                  .eq('role', 'admin')
                  .not('is_active', 'eq', false)
                  .order('name')
              as List;
    } else {
      usersRes =
          await _client
                  .from('users')
                  .select('id, name, phone, email, group_id, is_active')
                  .inFilter('group_id', mailGroupIds)
                  .not('is_active', 'eq', false)
                  .order('name')
              as List;
    }

    final out = <MailAssignee>[];
    for (final raw in usersRes) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final gid = map['group_id']?.toString();
      final meta = gid == null ? null : groupMeta[gid];
      out.add(
        MailAssignee(
          id: '${map['id'] ?? ''}',
          name: '${map['name'] ?? ''}'.trim(),
          phone: map['phone']?.toString(),
          email: map['email']?.toString(),
          groupName: meta?.name,
          groupColorHex: meta?.color,
        ),
      );
    }
    return out;
  }

  Future<List<MailFile>> fetchFiles() async {
    final res = await _client
        .from('mail_files')
        .select('id,name,original_name,url,category,category_id,created_at')
        .order('created_at', ascending: false);
    return (res as List)
        .whereType<Map>()
        .map((e) => MailFile.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<MailCategory>> fetchCategories() async {
    final res = await _client
        .from('mail_categories')
        .select('id,name,color')
        .order('name');
    return (res as List)
        .whereType<Map>()
        .map((e) => MailCategory.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<MailSendRecord>> fetchSends() async {
    final res = await _client
        .from('mail_sends')
        .select()
        .order('created_at', ascending: false);
    return (res as List)
        .whereType<Map>()
        .map((e) => MailSendRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<String>> fetchTelegramAgentNames() async {
    final base = _mailApiBase;
    try {
      final res = await _deps.transport.request(
        baseUrl: base,
        method: 'GET',
        path: '/api/telegram/agents',
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return const [];
      if (decoded['success'] != true) return const [];
      final agents = decoded['agents'];
      if (agents is! List) return const [];
      return agents
          .map((e) {
            if (e is Map) return '${e['agent_name'] ?? ''}'.trim();
            return '';
          })
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> sendMail(MailSendRequest req) async {
    final to = req.toEmail.trim();
    if (!MailCompose.isValidEmail(to)) {
      throw ApiException('받는 이메일 형식을 확인하세요.');
    }
    if (req.attachments.isEmpty) {
      throw ApiException('첨부 파일을 선택하세요.');
    }
    final base = _mailApiBase;

    try {
      final res = await _deps.transport.request(
        baseUrl: base,
        method: 'POST',
        path: '/api/send-mail',
        timeout: const Duration(minutes: 3),
        jsonBody: {
          'to': to,
          'cc': MailCompose.ccRecipients,
          'subject': req.subject,
          'text': req.body,
          'attachments': req.attachments.map((e) => e.toJson()).toList(),
        },
      );
      final decoded = _decodeJson(res.body);
      if (_isUnconfirmedStatus(res.statusCode)) {
        await _insertSend(
          req,
          status: 'pending',
          error: '응답 지연(${res.statusCode}) — 도착 여부 확인',
        );
        throw MailDeliveryUnconfirmedException();
      }
      final ok =
          res.statusCode >= 200 &&
          res.statusCode < 300 &&
          (decoded['success'] == true || decoded['success'] == null);
      if (!ok) {
        final err = decoded['error']?.toString() ?? '메일 발송에 실패했습니다.';
        await _insertSend(req, status: 'failed', error: err);
        throw ApiException(err, statusCode: res.statusCode);
      }
    } on MailDeliveryUnconfirmedException {
      rethrow;
    } catch (e) {
      if (_looksLikeTimeout(e)) {
        await _insertSend(req, status: 'pending', error: '응답 지연 — 도착 여부 확인');
        throw MailDeliveryUnconfirmedException();
      }
      if (e is ApiException) rethrow;
      await _insertSend(req, status: 'failed', error: e.toString());
      throw ApiException('메일 발송 실패: $e');
    }

    await _insertSend(req, status: 'success');

    final agent = req.telegramAgentName?.trim() ?? '';
    if (req.notifyTelegram && agent.isNotEmpty) {
      await _notifyTelegram(req: req, agentName: agent);
    }
  }

  Future<void> _insertSend(
    MailSendRequest req, {
    required String status,
    String? error,
  }) async {
    try {
      await _client.from('mail_sends').insert({
        'to_email': req.toEmail.trim(),
        'subject': req.subject,
        'body': req.body,
        'sender_user_id': req.sender?.id,
        'sender_user_name': req.sender?.name,
        'attachments': req.attachments.map((e) => e.toJson()).toList(),
        'status': status,
        if (status == 'success') 'sent_at': DateTime.now().toIso8601String(),
        'error_message': ?error,
      });
    } catch (_) {}
  }

  Future<void> _notifyTelegram({
    required MailSendRequest req,
    required String agentName,
  }) async {
    final base = _mailApiBase;
    final names = req.attachments.map((e) => e.name).toList();
    final preview = names.take(12).join(', ');
    final more = names.length > 12 ? ' 외 ${names.length - 12}건' : '';
    final text = [
      '메일 발송 완료',
      '보낸 사람: ${req.sender?.name ?? '미지정'}',
      '받는 사람: ${req.toEmail.trim()}',
      '제목: ${req.subject}',
      '첨부 ${names.length}개: $preview$more',
    ].join('\n');
    try {
      await _deps.transport.request(
        baseUrl: base,
        method: 'POST',
        path: '/api/telegram',
        jsonBody: {
          'text': text,
          'source': 'mail_send',
          'sendToAgents': true,
          'agentNames': [agentName],
          'sendToChannel': false,
        },
      );
    } catch (_) {}
  }

  bool _isUnconfirmedStatus(int status) =>
      status == 408 || status == 502 || status == 504 || status == 524;

  bool _looksLikeTimeout(Object e) {
    if (e is ApiException && _isUnconfirmedStatus(e.statusCode ?? 0)) {
      return true;
    }
    final m = e.toString();
    return m.contains('지연') ||
        m.contains('timeout') ||
        m.contains('Timeout') ||
        m.contains('Timed out');
  }

  Map<String, dynamic> _decodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }
}
