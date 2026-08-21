import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient? _supportClient;

/// 고객지원(A/S) 전용 Supabase. 키가 없으면 메인 클라이언트를 쓴다.
SupabaseClient supportSupabaseClient() {
  final existing = _supportClient;
  if (existing != null) return existing;
  final url = (dotenv.env['NEXT_PUBLIC_SUPPORT_SUPABASE_URL'] ?? '').trim();
  final key = (dotenv.env['NEXT_PUBLIC_SUPPORT_SUPABASE_ANON_KEY'] ?? '')
      .trim();
  if (url.isEmpty || key.isEmpty) {
    return Supabase.instance.client;
  }
  final client = SupabaseClient(url, key);
  _supportClient = client;
  return client;
}
