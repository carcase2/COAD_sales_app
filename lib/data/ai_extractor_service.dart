import 'dart:convert';
import 'dart:typed_data';

import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/data/business_card_ocr.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

export 'business_card_ocr.dart' show BusinessCardResult, parseBusinessCardText;

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
   - [가장 중요한 규칙]: 메모에서 "질의응답, 견적 안내, 일정 조율, 요구사항 청취" 등 고객과 연결되어 내용이 오간 흔적이 단 한 줄이라도 있다면 무조건 2 (진행중/완료)로 판별합니다. 문의내용이 존재하는데 1(미통화)로 판별하는 것은 절대 금지됩니다.
   - 단, "안 받음, 부재중, 바쁘다고 끊어버림, 나중에 다시 하라고 함(본론을 꺼내지 못함)"처럼 통화가 불발된 경우에만 1 (미통화)로 판별합니다.

2. call_stage (통화 차수 추출):
   - 텍스트 내에서 "1차", "2차", "1번", "재발신" 등 통화 차수나 시도 횟수를 나타내는 단어를 찾아 문자열로 반환합니다. (예: "2차")
   - 언급이 없다면 기본값인 "1차"를 반환합니다.

3. inquiry_content (문의내용 요약):
   - status_id가 2로 판별된 경우: 오타나 비속어를 제거하고, 영업 담당자가 쓴 내용을 비즈니스 톤으로 깔끔하게 1~2문장으로 요약하세요.
   - status_id가 1로 판별된 경우: 실제 문의내용이 없으므로, 메모 문맥에 맞춰 "고객 부재중으로 통화 실패", "바쁘다며 통화 거절" 등으로 매우 간결하게 작성하세요.

# Output Format
오직 아래의 순수 JSON 형태만 반환해야 합니다. 마크다운 언어 표시(```json 등)도 절대 붙이지 마세요. 설명 텍스트도 없이 JSON만 반환하세요.
{
  "status_id": 1 또는 2,
  "call_stage": "1차",
  "inquiry_content": "여기에 요약 또는 불발 사유 작성"
}
''';

  static const _businessCardPrompt = '''
당신은 한국 명함 OCR 전문가입니다. 사진에서 보이는 글자만 읽고 JSON으로 반환하세요. 추측하지 마세요.

# 추출 항목
- name: 사람 이름만. 직함(대표, 이사, 팀장 등)은 넣지 마세요.
- company: 회사명/상호. 로고만 있고 글자가 없으면 빈 문자열.
- title: 직함/부서. 예: "대표이사", "영업팀장".
- phone: 휴대폰 번호 1개. 010/011/016/017/018/019를 최우선. 하이픈 포함(010-1234-5678). 없으면 빈 문자열.
- office_phone: 사무실/대표 전화. FAX가 아닌 번호만. 없으면 빈 문자열.
- fax: 팩스 번호. 명함에 FAX/팩스로 적힌 번호만. 하이픈 포함. 없으면 빈 문자열.
- email: 이메일. 없으면 빈 문자열.
- address: 주소. 없으면 빈 문자열.

# 규칙
- 팩스는 office_phone에 넣지 말고 fax에만 넣으세요.
- 글자가 흐리면 빈 문자열.
- 오직 JSON만 반환. 마크다운 금지.
{
  "name": "",
  "company": "",
  "title": "",
  "phone": "",
  "office_phone": "",
  "fax": "",
  "email": "",
  "address": ""
}
''';

  Future<AiExtractResult> extract(String memo) async {
    final model = GenerativeModel(
      model: 'gemini-3.6-flash',
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

  static const _businessCardModels = [
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-flash-latest',
  ];

  Future<BusinessCardResult> extractBusinessCard(
    Uint8List imageBytes, {
    String? filePath,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw ApiException('명함 인식 API 키가 없습니다. 앱을 다시 설치한 뒤 시도해 주세요.');
    }
    debugPrint('명함 인식: Gemini (${imageBytes.length} bytes)');
    try {
      final result = await _extractWithGemini(imageBytes);
      if (result.hasAnyField) return result;
      throw ApiException('명함에서 글자를 읽지 못했습니다. 밝은 곳에서 정면으로 다시 촬영해 주세요.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_humanizeOcrError(e));
    }
  }

  Future<BusinessCardResult> _extractWithGemini(Uint8List imageBytes) async {
    final mime = _imageMime(imageBytes);
    Object? lastError;
    for (final modelName in _businessCardModels) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.0,
          ),
        );
        final response = await model.generateContent([
          Content.multi([
            TextPart(_businessCardPrompt),
            DataPart(mime, imageBytes),
          ]),
        ]);
        final text = response.text?.trim() ?? '';
        if (text.isEmpty) {
          lastError = ApiException('인식 결과가 비어 있습니다.');
          continue;
        }
        final json = jsonDecode(_cleanJson(text)) as Map<String, dynamic>;
        return BusinessCardResult.fromJson(json);
      } catch (e) {
        debugPrint('명함 인식 모델 실패 $modelName: $e');
        lastError = e;
      }
    }
    throw lastError ?? ApiException('명함 인식에 실패했습니다.');
  }

  static String _humanizeOcrError(Object error) {
    final t = error.toString().toLowerCase();
    if (t.contains('api key') || t.contains('api_key') || t.contains('unauthorized') || t.contains('403')) {
      return '명함 인식 API 키가 올바르지 않습니다.';
    }
    if (t.contains('404') || t.contains('not found') || t.contains('no longer available')) {
      return '명함 인식 모델을 찾을 수 없습니다. 앱을 다시 설치해 주세요.';
    }
    if (t.contains('429') || t.contains('quota') || t.contains('resource exhausted')) {
      return '명함 인식 사용량이 초과되었습니다. 잠시 후 다시 시도해 주세요.';
    }
    if (t.contains('socket') || t.contains('network') || t.contains('failed host')) {
      return '네트워크 연결을 확인한 뒤 다시 시도해 주세요.';
    }
    return '명함 인식에 실패했습니다. 다시 촬영해 주세요.';
  }

  static String _imageMime(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  static const _summaryPrompt = '''
당신은 영업 팀장입니다. 아래 나열된 오늘자 '문의내역'들을 읽고, 전체적인 현황과 핵심 이슈를 1~2문장으로 아주 명쾌하게 요약하여 브리핑하세요.

# 추출 지침
- 영업 전략적 관점에서 중요한 내용(견적 요청, 클레임, 긴급 팔로업 등)을 우선 순위로 두세요.
- 격식 있는 비즈니스 톤을 유지하세요.
- 2문장을 넘기지 마세요.

# 출력 예시
"오늘은 스피드도어 대량 견적 요청이 주를 이루었으며, 특정 업체의 설치 일정 조율이 긴급한 이슈로 확인됩니다."
''';

  Future<String> summarizeCalls(List<String> callTexts) async {
    if (callTexts.isEmpty) return '오늘 등록된 문의내역이 없습니다.';

    final model = GenerativeModel(
      model: 'gemini-3.6-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3,
      ),
    );

    final combinedText = callTexts.map((e) => "- $e").join('\n');

    final response = await model.generateContent([
      Content.text('$_summaryPrompt\n\n# 문의내용:\n$combinedText'),
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
