import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  final url = dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ?? '';
  final anonKey = dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ?? '';

  await Supabase.initialize(url: url, anonKey: anonKey);
  final client = Supabase.instance.client;

  final row = await client
      .from('app_update_policy')
      .select()
      .order('updated_at', ascending: false)
      .limit(1)
      .maybeSingle();

  print('Current policy: $row');
  exit(0);
}
