import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 빌드 시 `--dart-define=BASE_URL=https://example.com` 으로 주입.
/// 그다음 앱 설정, 그다음 프로젝트 루트 `.env`의 `BASE_URL` ([AppDependencies.effectiveBaseUrl]).
const String kBaseUrlDefine = String.fromEnvironment('BASE_URL', defaultValue: '');

String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
