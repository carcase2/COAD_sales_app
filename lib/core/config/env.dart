import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 빌드 시 `--dart-define=BASE_URL=https://example.com` 으로 주입.
/// 그다음 앱 설정, 그다음 프로젝트 루트 `.env`의 `BASE_URL` ([AppDependencies.effectiveBaseUrl]).
const String kBaseUrlDefine = String.fromEnvironment(
  'BASE_URL',
  defaultValue: '',
);

/// COAD_home 웹(메일 발송 `/api/send-mail` 등) 기본 주소.
/// `.env`의 `BASE_URL`이 비어 있을 때 사용.
const String kDefaultCoadHomeUrl = 'https://coadsales.netlify.app';

String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

String get kakaoRestApiKey =>
    dotenv.env['KAKAO_REST_API_KEY'] ??
    dotenv.env['NEXT_PUBLIC_KAKAO_API_KEY'] ??
    '';
