import 'dart:convert';
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

    // Strip potential markdown code fences
    final cleaned = text
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*```$', multiLine: true), '')
        .trim();

    final json = jsonDecode(cleaned) as Map<String, dynamic>;
    return AiExtractResult.fromJson(json);
  }
}
