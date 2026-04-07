import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 빌드 시 `--dart-define=BASE_URL=https://example.com` 으로 주입.
const String kBaseUrlDefine = String.fromEnvironment('BASE_URL', defaultValue: '');

String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
