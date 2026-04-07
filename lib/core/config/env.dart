/// 빌드 시 `--dart-define=BASE_URL=https://example.com` 으로 주입.
const String kBaseUrlDefine = String.fromEnvironment('BASE_URL', defaultValue: '');
