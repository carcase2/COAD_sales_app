import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiExtractResult {
  final int statusId;
  final String callStage;
  final String inquiryContent;

  AiExtractResult({
    required this.statusId,
    required this.callStage,
    required this.inquiryContent,
  });

  factory AiExtractResult.fromJson(Map<String, dynamic> json) {
    return AiExtractResult(
      statusId: (json['status_id'] as num?)?.toInt() ?? 1,
      callStage: json['call_stage']?.toString() ?? '1차',
      inquiryContent: json['inquiry_content']?.toString() ?? '',
    );
  }
}

class BusinessCardResult {
  final String name;
  final String company;
  final String phone;

  BusinessCardResult({
    required this.name,
    required this.company,
    required this.phone,
  });

  factory BusinessCardResult.fromJson(Map<String, dynamic> json) {
    return BusinessCardResult(
      name: json['name']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }
}

class AiExtractorService {
  final String apiKey;

  AiExtractorService({required this.apiKey});

  static const _systemPrompt = '''
당신은 CRM 영업 콜 데이터를 분석하여 DB에 저장하기 좋도록 정형화(JSON)해 주는 'AI 데이터 추출기'입니다.

사용자(영업 담당자)가 입력한 거친 형태의 '상담 메모(텍스트)'를 읽고, 아래의 엄격한 판별 규칙에 따라 JSON 포맷으로 데이터를 추출하세요.

# Classification Rules
1. status_id (통화 상태 판별):
   - [가장 중요한 규칙]: 메모에서 "질의응답, 견적 안내, 일정 조율, 요구사항 청취" 등 고객과 연결되어 내용이 오간 흔적이 단 한 줄이라도 있다면 무조건 2 (진행중/완료)로 판별합니다. 상담 내용이 존재하는데 1(미통화)로 판별하는 것은 절대 금지됩니다.
   - 단, "안 받음, 부재중, 바쁘다고 끊어버림, 나중에 다시 하라고 함(본론을 꺼내지 못함)"처럼 통화가 불발된 경우에만 1 (미통화)로 판별합니다.

2. call_stage (통화 차수 추출):
   - 텍스트 내에서 "1차", "2차", "1번", "재발신" 등 통화 차수나 시도 횟수를 나타내는 단어를 찾아 문자열로 반환합니다. (예: "2차")
   - 언급이 없다면 기본값인 "1차"를 반환합니다.

3. inquiry_content (상담 내용 요약):
   - status_id가 2로 판별된 경우: 오타나 비속어를 제거하고, 영업 담당자가 쓴 내용을 비즈니스 톤으로 깔끔하게 1~2문장으로 요약하세요.
   - status_id가 1로 판별된 경우: 실제 상담 내용이 없으므로, 메모 문맥에 맞춰 "고객 부재중으로 통화 실패", "바쁘다며 통화 거절" 등으로 매우 간결하게 작성하세요.

# Output Format
오직 아래의 순수 JSON 형태만 반환해야 합니다. 마크다운 언어 표시(```json 등)도 절대 붙이지 마세요. 설명 텍스트도 없이 JSON만 반환하세요.
{
  "status_id": 1 또는 2,
  "call_stage": "1차",
  "inquiry_content": "여기에 요약 또는 불발 사유 작성"
}
''';

  static const _businessCardPrompt = '''
당신은 비즈니스 전문가입니다. 제공된 사진(명함)에서 고객의 정보를 추출하여 JSON으로 반환하세요.

# 추출 항목
1. name: 사람의 이름. (못 찾으면 빈 문자열)
2. company: 회사명 또는 상호명. (못 찾으면 빈 문자열)
3. phone: 휴대폰 번호 또는 일반 전화번호. 숫자와 하이픈(-)만 포함된 1개만 반환하세요. (못 찾으면 빈 문자열)

# 규칙
- 결과를 오직 JSON으로만 반환하세요.
- 마크다운 블록(```json)을 사용하지 마세요.
{
  "name": "성함",
  "company": "회사/상호",
  "phone": "010-0000-0000"
}
''';

  Future<AiExtractResult> extract(String memo) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(_systemPrompt),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.1,
      ),
    );

    final response = await model.generateContent([
      Content.text(memo),
    ]);

    final text = response.text?.trim() ?? '';
    final cleaned = _cleanJson(text);
    final json = jsonDecode(cleaned) as Map<String, dynamic>;
    return AiExtractResult.fromJson(json);
  }

  Future<BusinessCardResult> extractBusinessCard(Uint8List imageBytes) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.1,
      ),
    );

    final response = await model.generateContent([
      Content.multi([
        TextPart(_businessCardPrompt),
        DataPart('image/jpeg', imageBytes),
      ]),
    ]);

    final text = response.text?.trim() ?? '';
    final cleaned = _cleanJson(text);
    final json = jsonDecode(cleaned) as Map<String, dynamic>;
    return BusinessCardResult.fromJson(json);
  }

  static const _summaryPrompt = '''
당신은 영업 팀장입니다. 아래 나열된 오늘자 '영업 상담 내역'들을 읽고, 전체적인 현황과 핵심 이슈를 1~2문장으로 아주 명쾌하게 요약하여 브리핑하세요.

# 추출 지침
- 영업 전략적 관점에서 중요한 내용(견적 요청, 클레임, 긴급 팔로업 등)을 우선 순위로 두세요.
- 격식 있는 비즈니스 톤을 유지하세요.
- 2문장을 넘기지 마세요.

# 출력 예시
"오늘은 스피드도어 대량 견적 요청이 주를 이루었으며, 특정 업체의 설치 일정 조율이 긴급한 이슈로 확인됩니다."
''';

  Future<String> summarizeCalls(List<String> callTexts) async {
    if (callTexts.isEmpty) return '오늘 등록된 상담 내역이 없습니다.';

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3,
      ),
    );

    final combinedText = callTexts.map((e) => "- $e").join('\n');

    final response = await model.generateContent([
      Content.text('$_summaryPrompt\n\n# 상담 내역:\n$combinedText'),
    ]);

    return response.text?.trim() ?? '요약을 생성할 수 없습니다.';
  }

  String _cleanJson(String text) {
    return text
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*```$', multiLine: true), '')
        .trim();
  }
}
