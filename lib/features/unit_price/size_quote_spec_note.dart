/// 견적서 NOTE. 1–7은 공통, 8번부터는 양식 spec. 시트의 모델별 문구.
const kSizeQuoteBaseNote = '''NOTE
1. VAT. 별도
2. 설치비, 운반비 포함
3. 1차 전원 공사별도 - 단상220V 60Hz, 접지 포함
4. 견적서 이외의 추가 자재비 별도 청구
5. 결제조건 : 계약시 50 % 공사완료 당일 50% 현금 결제
6. 안전관리자 / 수신호원 화기감시자 발주처 지원조건
7. 양중 필요시 추가 비용발생''';

const _speedC1 = '''8. 스피드도어 전 모델 CE인증
9. 스피드도어 COAD-1 적용
10. ALL ROUND AL. FRAME 적용(미려한 디자인)
11. DOOR SHEET 폴리벨트 UV / 항균 코팅처리 SHEET 적용 / 5겹 고강도 SHEET
   (오렌지, 블루, 그레이 선택적용, 투명창 기본적용)
12. 강풍에도 이탈되지 않는 WIND LOCK 장치적용
13. FULL 감지센서 적용
14. 2단 열림제어 및 경광등, 에어커튼, 컨베이어 등 다양한 기기와 연동 가능
15. SERVO MOTOR 적용''';

const _speedC2 = '''8. 스피드도어 전 모델 CE인증
9. 스피드도어 COAD-2 적용
10. ALL ROUND AL. FRAME 적용(미려한 디자인)
11. DOOR SHEET 폴리벨트 UV / 항균 코팅처리 SHEET 적용 / 5겹 고강도 SHEET
   (오렌지, 블루, 그레이 선택적용, 투명창 기본적용)
12. 강풍에도 이탈되지 않는 WIND LOCK 장치적용
13. FULL 감지센서 적용
14. 2단 열림제어 및 경광등, 에어커튼, 컨베이어 등 다양한 기기와 연동 가능
15. ALTAX MOTOR 적용''';

const _speedC3 = '''8. 스피드도어 전 모델 CE인증
9. 스피드도어 COAD-3 적용
10. ALL ROUND AL. FRAME 적용(미려한 디자인)
11. DOOR SHEET 폴리벨트 UV / 항균 코팅처리 SHEET 적용 / 5겹 고강도 SHEET
   (오렌지, 블루, 그레이 선택적용, 투명창 기본적용)
12. 차량충돌시 자동으로 복구기능적용
13. FULL 감지센서 적용
14. 2단 열림제어 및 경광등, 에어커튼, 컨베이어 등 다양한 기기와 연동 가능
15. SERVO MOTOR 적용
*후면 마감 협의후 견적진행 협의''';

const _speedVe = '''8. 스피드도어 전 모델 CE인증
9. 스피드도어 COAD-VE 적용
10. ALL ROUND AL. FRAME 적용(미려한 디자인)
11. DOOR SHEET 폴리벨트 UV / 항균 코팅처리 SHEET 적용 / 0.9T 연질 SHEET
   (오렌지, 블루, 그레이 선택적용, 투명창 기본적용)
12. 강풍에도 이탈되지 않는 WIND LOCK 장치적용
13. 스마트 안전센서 적용
14. 2단 열림제어 및 경광등, 에어커튼, 컨베이어 등 다양한 기기와 연동 가능
15. SERVO MOTOR 적용''';

const _speedBlast = '''8. 스피드도어 전 모델 CE인증
9. 스피드도어 방폭형
10. ALL ROUND AL. FRAME 적용(미려한 디자인)
11. DOOR SHEET 폴리벨트 UV / 항균 코팅처리 SHEET 적용/5겹 고강도 SHEET
   (오렌지, 블루, 그레이 선택적용, 투명창 기본적용)
12. 차량충돌시 자동으로 복구기능적용
13. 스마트 안전센서 적용
14. 2단 열림제어 및 경광등, 에어커튼, 컨베이어 등 다양한 기기와 연동 가능
15. 방폭형 MOTOR 적용''';

const _speedBig = '''8. 스피드도어 전 모델 CE인증
9. 스피드도어 C-10(빅도어) 적용
10. ALL ROUND AL. FRAME 적용(미려한 디자인)
11. DOOR SHEET 폴리벨트 UV / 항균 코팅처리 SHEET 적용 / 5겹 고강도 SHEET
   (오렌지, 블루, 그레이 선택적용, 투명창 기본적용)
12. 2단 열림제어 및 경광등, 에어커튼, 컨베이어 등 다양한 기기와 연동 가능
13. MADE IN JAPAN HYPONIC MOTOR 적용
14. 안전센서 2채널, LOOP SENSOR(지게차 감지)''';

const _shutterWindInsul = '''8. 내풍압단열셔터
    * SLAT - 80mm, 1.2T X 20mm AL이중압출물 (분체 도장,우레탄충진)
    * GUIDE RAIL - 150 X 5T AL6060 이중압출물 (도장별도)
    * WIDLOCK - AL6063 FIX TYPE  - SLAT 매 8단마다 설치
    * SHUTTER BOX - 노출형 GI 1.2T 3면 (도색별도)
    * 하부마감 - 고무재질의 WEATHER STRIP''';

const _shutterWindInsulBy = '''8. 내풍압단열셔터
    * SLAT - 80mm, 1.2T X 22mm AL이중압출물 (분체 도장,우레탄충진)
    * GUIDE RAIL - 140 X 5T AL6060 이중압출물 (도장별도)
    * WIDLOCK - AL6063 FIX TYPE  - SLAT 매 8단마다 설치
    * SHUTTER BOX - 노출형 GI 1.2T 3면 (도색별도)
    * 하부마감 - 고무재질의 WEATHER STRIP''';

const _shutterWind = '''8. 내풍압셔터
    * SLAT - 72mm, 1.2T X 16mm AL이중압출물 (분체 도장)
    * GUIDE RAIL - 115 or 160 X 5T AL6060 이중압출물 (도장별도)
    * WIDLOCK - AL6063 FIX TYPE  - SLAT 매 8단마다 설치
    * SHUTTER BOX - 노출형 GI 1.2T 3면(도색별도)
    * 하부마감 - 고무재질의 WEATHER STRIP''';

const _shutterDouble = '''8. 이중압출셔터
    * SLAT - 72mm, 1.2T X 16mm AL이중압출물 (분체 도장)
    * GUIDE RAIL - SUS304
    * SHUTTER BOX - 출형 GI 1.2T 3면 마감 (도색별도)
    * 하부마감 - 고무재질의 WEATHER STRIP''';

const _shutterDoubleInsul = '''8. 이중압출단열셔터
    * SLAT - 80mm, 1.2T X 20mm AL이중압출물 (분체 도장,우레탄충진)
    * GUIDE RAIL - AL6063 이중압출물(도장별도) 혹은 SUS304
    * SHUTTER BOX - 노출형 GI 1.2T 3면 마감 (도색별도)
    * 하부마감 - 고무재질의 WEATHER STRIP''';

const _shutterDoubleInsulBy = '''8. 이중압출단열셔터
    * SLAT - 80mm, 1.2T X 22mm AL이중압출물 (분체 도장,우레탄충진)
    * GUIDE RAIL - AL6063 이중압출물(도장별도) 혹은 SUS304
    * SHUTTER BOX - 노출형 GI 1.2T 3면 마감 (도색별도)
    * 하부마감 - 고무재질의 WEATHER STRIP''';

const _shutterScreen = '''8. 마감별도
9. 건교부 소방법에 적합한 제품
10. 열, 연감지기 소방설비 별도, 모터에서 연동제어기까지 배관,배선 별도
11. 상부방화구획 별도
12. 방화셔터 사양
   * 스크린  실리카 0.7T
   * GUIDE RAIL,하장바 1.55T 전기아연도금강판+SUS 마감
   * SHUTTER BOX - EGI 1.55T 4면 마감 (도색별도),SUS 마감 별도
   * 연동제어기, 자동폐쇄기(이단강하형)
   * 방화셔터 특성상 조합페인트 마감은 불가 (화재시 유독가스 발생)
   * 인정제품 방화 (철재,스크린)셔터는 폭8M, 높이4M 로 규정되어 있습니다.
     - 규격초과시 성적서 발급이 안됩니다.
   * 인정 제품 성적서는 레일측 방화구획 공사가 있습니다
     - ALC블럭, 방화석고보드, 조적등 방화구획 마감 및공사 별도.)''';

const _shutterSteel = '''8. 마감별도
9. 건교부 소방법에 적합한 제품
10. 열, 연감지기 소방설비 별도, 모터에서 연동제어기까지 배관,배선 별도
11. 상부방화구획 별도
12. 방화셔터 사양
   * 슬라트 SECC 1.55T
   * GUIDE RAIL,하장바 1.55T 전기아연도금강판+SUS마감
   * SHUTTER BOX - EGI 1.55T 4면 마감 (도색별도),SUS 마감 별도
   * 연동제어기, 자동폐쇄기(이단강하형)
   * 방화셔터 특성상 조합페인트 마감은 불가 (화재시 유독가스 발생)
   * 인정제품 방화 (철재,스크린)셔터는 폭8M, 높이4M 로 규정되어 있습니다.
     - 규격초과시 성적서 발급이 안됩니다.
   * 인정 제품 성적서는 레일측 방화구획 공사가 있습니다
     - ALC블럭, 방화석고보드, 조적등 방화구획 마감 및공사 별도.)''';

const _shutterElectric = '''7. 슬라트 : AL 1.2T
8. 가이드레일 : AL(OR SUS) 1.2T
9. 셔터BOX : EGI 1.2T''';

const _overheadIndustrial = '''8. 오버헤드도어
    - THK 50T 폴리우레탄 충진 고강도 압축 판넬(양면 0.5mm 아연도강판 폴리에스터 코팅)
    - TRACK : 2" 중량트랙(고내구성 용융 아연도 철판)
    - 작동방법 : 평상시 PUSH BUTTON에 의한 전동작동
                      비상시 체인호이스트에 의한 수동작동''';

const _overheadStorage = '''8. 수납식 타입(COAD-20)
    * THK 50T 폴리우레탄 충진 고강도 압축 판넬(양면 0.5mm 아연도강판 폴리에스터 코팅)
    * 3상 220V 전용 Geared MOTOR / 인버터 전용 컨트롤러 적용
    * 고강도 알루미늄 프레임(6063-T5) 적용
    * 체인방식을 적용한 제품의 안전성 확보
    * 작동방법 : 평상시 PUSH BUTTON에 의한 전동작동
    * 안전장치 : Safety Sensor 설치(OPTION)''';

const _garagePower = '''9. 채광창, 리모컨 추가 등은 별도 옵션 금액 적용
10. 1차 전원공사 
     - 콘센트 위치(문입구에서 높이 2200이하는 3.5M, 2200이상은 4M 천장상부 위치)''';

const _garageSatin = '''8. 차고용 오버헤드도어 - 사틴펄 판넬
    - 색상 : 사틴펄 그레이, 사틴펄 크래용 중 택 1
    - 40T 2중 폴리우레탄 충진 판넬 적용
    - 인장스프링 및 로우헤드룸 타입 적용
    - AL프레임 145*145*200 적용(실버/화이트/블랙 중 택 1)(좌/우 사이드 씰 적용)  
    - 정전시 수동 개폐 가능
    - SET당 차량용 리모컨 2개 / 무선 벽스위치 1개 기본 제공
$_garagePower
11. 계약고객행사제품(사틴펄판넬 설치시 스마트폰 원격제어 기능 무료)''';

const _garageHemlock = '''8. 차고용 오버헤드도어 - 햄록 판넬
    - 햄록 목제 판넬 적용(오일스텐 선택 가능)
    - 인장스프링 및 로우헤드룸 타입 적용
    - AL 프레임 - 145*145*200적용 기준(실버/화이트/블랙 중 택 1)(좌/우 사이드 씰 적용)
    - 정전시 수동 개폐 가능
    - SET당 차량용 리모컨 2개 / 무선 벽스위치 1개 기본 제공
$_garagePower''';

const _garageWood = '''8. 차고용 오버헤드도어
    - 색상 : 우드줄무늬
    - 40T 2중 폴리우레탄 충진 판넬 적용
    - 인장스프링 및 로우헤드룸 타입 적용
    - AL프레임 145*145*200 적용(실버/화이트/블랙 중 택 1)(좌/우 사이드 씰 적용)
    - 정전시 수동 개폐 가능
    - SET당 차량용 리모컨 2개 / 무선 벽스위치 1개 기본 제공
$_garagePower''';

const _garageDeluxe = '''8. 차고용 오버헤드도어
    - 색상 : 다크그레이, 다크브라운 중 택 1
    - 40T 2중 폴리우레탄 충진 판넬 적용
    - 인장스프링 및 로우헤드룸 타입 적용
    - AL프레임 145*145*200 적용(실버/화이트/블랙 중 택 1)(좌/우 사이드 씰 적용)
    - 정전시 수동 개폐 가능
    - SET당 차량용 리모컨 2개 / 무선 벽스위치 1개 기본 제공
$_garagePower''';

const _garageMarble = '''8. 차고용 오버헤드도어 - 마블스톤
    - 인장스프링 및 로우헤드룸 타입 적용
    - AL프레임 145*145*200 적용(실버/화이트/블랙 중 택 1)(좌/우 사이드 씰 적용)
    - 정전시 수동 개폐 가능
    - SET당 차량용 리모컨 2개 / 무선 벽스위치 1개 기본 제공
$_garagePower''';

const _garageAl = '''8. 차고용 오버헤드도어 - 알루미늄 복합판넬
    - 인장스프링 및 로우헤드룸 타입 적용
    - AL프레임 145*145*200 적용(실버/화이트/블랙 중 택 1)(좌/우 사이드 씰 적용)
    - 정전시 수동 개폐 가능
    - SET당 차량용 리모컨 2개 / 무선 벽스위치 1개 기본 제공
$_garagePower''';

const _securityWave = '''8. 마감별도
9. SLAT - Ø13.8*1.1T SUS H/L
10. GUIDE RAIL - SUS 1.2T H/L
11. SHUTTER BOX - EGI 1.2T 3면 노출(도색별도)
12. BOTTOM BAR - SUS 1.2T H/L
13. 1차 전기 인입 별도,2차 배관 별도''';

const _glassDoor = '(신한은행 140-010-683521 예금주 : (주)코아드 이대훈)';

const _snail = '''8. 초고속 개폐(4 m/s), 듀얼 하이브리드 도어(단열, 방범)
9. 알루미늄 우레탄 단열 패널 적용 (두께 43 mm, 열관류율 1.35 W/(m²·K), 내풍압 40 m/s)
10. 패널 EPDM Seal 적용(기밀, 단열)
11. 마찰 최소화, 구동부 내구성 향상을 위한 나선형(SPIRAL) 구조 적용
12. Full 감지센서(1,200 mm, 16-channel), 하부 안전센서, 2단 열림·연동제어 가능
13. 비상정전시 수동개폐 기능 적용
14. 1차 전원: 단상 220 V, 60 Hz''';

String _norm(String raw) {
  var s = raw.trim().toLowerCase();
  s = s.replaceAll(RegExp(r'''[\s_\-()（）/·,.+]'''), '');
  s = s.replaceAll('deluex', 'delux').replaceAll('deluxe', 'delux');
  return s;
}

enum _Family { speed, garage, shutter, overhead, snail, security, glass, other }

_Family _family(String categoryName, String modelName) {
  final cat = _norm(categoryName);
  final model = _norm(modelName);
  if (cat.contains('스피드') || cat.contains('speed')) return _Family.speed;
  if (cat.contains('차고')) return _Family.garage;
  if (cat.contains('셔터') || cat.contains('shutter')) return _Family.shutter;
  if (cat.contains('오버헤드')) return _Family.overhead;
  if (cat.contains('스네일') || cat.contains('snail')) return _Family.snail;
  if (cat.contains('방범')) return _Family.security;
  if (cat.contains('유리')) return _Family.glass;
  if (model.contains('차고문') ||
      model.contains('샤틴') ||
      model.contains('사틴') ||
      model.contains('마블') ||
      model.contains('햄록') ||
      model.contains('우드')) {
    return _Family.garage;
  }
  if (model.contains('스네일') || model.contains('snail')) return _Family.snail;
  if (model.contains('오버헤드')) return _Family.overhead;
  if (model.contains('방범') || model.contains('웨이브')) return _Family.security;
  if (model.contains('유리')) return _Family.glass;
  if (model.contains('셔터') ||
      model.contains('이중압출') ||
      model.contains('내풍압') ||
      model.contains('방화')) {
    return _Family.shutter;
  }
  if (model.contains('스피드') ||
      model == 'premium' ||
      model == 'standard' ||
      model == 'delux' ||
      model.contains('vestandard')) {
    return _Family.speed;
  }
  return _Family.other;
}

String? _speedNote(String model) {
  if (model.contains('방폭')) return _speedBlast;
  if (model.contains('빅') || model.contains('c10')) return _speedBig;
  if (model.contains('premium') ||
      model.contains('프리미엄') ||
      model.contains('c3') ||
      model.contains('복구')) {
    return _speedC3;
  }
  if (model.contains('delux') ||
      model.contains('디럭스') ||
      model.contains('c2') ||
      model.contains('슬림')) {
    return _speedC2;
  }
  if (model.contains('ve') ||
      model.contains('경제') ||
      model.contains('스탠다드s') ||
      model.contains('standards')) {
    return _speedVe;
  }
  if (model.contains('standard') ||
      model.contains('스탠다드') ||
      model.contains('c1') ||
      model.contains('기본')) {
    return _speedC1;
  }
  return null;
}

String? _garageNote(String model) {
  if (model.contains('샤틴') || model.contains('사틴')) return _garageSatin;
  if (model.contains('마블')) return _garageMarble;
  if (model.contains('햄록')) return _garageHemlock;
  if (model.contains('복합') || model.contains('알루미늄')) return _garageAl;
  if (model.contains('delux') ||
      model.contains('디럭스') ||
      model.contains('다크')) {
    return _garageDeluxe;
  }
  if (model.contains('standard') ||
      model.contains('스탠다드') ||
      model.contains('우드')) {
    return _garageWood;
  }
  return null;
}

String? _shutterNote(String model) {
  final bywy = model.contains('비와이');
  if (model.contains('스크린')) return _shutterScreen;
  if (model.contains('철제')) return _shutterSteel;
  if (model.contains('내풍압단열')) {
    return bywy ? _shutterWindInsulBy : _shutterWindInsul;
  }
  if (model.contains('내풍압')) return _shutterWind;
  if (model.contains('이중압출단열')) {
    return bywy ? _shutterDoubleInsulBy : _shutterDoubleInsul;
  }
  if (model.contains('이중압출')) return _shutterDouble;
  if (model.contains('전동')) return _shutterElectric;
  return null;
}

String? _overheadNote(String model) {
  if (model.contains('수납')) return _overheadStorage;
  if (model.contains('산업')) return _overheadIndustrial;
  return null;
}

/// DB에 저장된 공통·모델 노트. 행이 없으면 코드의 기본 문구를 쓴다.
class SizeQuoteNoteBook {
  const SizeQuoteNoteBook({
    this.hasCommon = false,
    this.common = '',
    this.models = const {},
  });

  final bool hasCommon;
  final String common;

  /// 키는 `분류|모델` 소문자. 값이 있다는 것은 DB 행이 있다는 뜻이다.
  final Map<String, String> models;

  static String key(String categoryName, String modelName) =>
      '${categoryName.trim().toLowerCase()}|${modelName.trim().toLowerCase()}';

  bool hasModel(String categoryName, String modelName) =>
      models.containsKey(key(categoryName, modelName));

  String modelBody(String categoryName, String modelName) =>
      models[key(categoryName, modelName)] ?? '';

  SizeQuoteNoteBook putCommon(String body) => SizeQuoteNoteBook(
        hasCommon: true,
        common: body,
        models: models,
      );

  SizeQuoteNoteBook putModel({
    required String categoryName,
    required String modelName,
    required String body,
  }) {
    final next = Map<String, String>.from(models);
    next[key(categoryName, modelName)] = body;
    return SizeQuoteNoteBook(hasCommon: hasCommon, common: common, models: next);
  }

  SizeQuoteNoteBook removeModel({
    required String categoryName,
    required String modelName,
  }) {
    final next = Map<String, String>.from(models)
      ..remove(key(categoryName, modelName));
    return SizeQuoteNoteBook(hasCommon: hasCommon, common: common, models: next);
  }
}

/// 앱에 기본으로 심어 두는 모델. 표가 비어 있으면 이 목록으로 DB를 채운다.
const kSizeQuoteNoteSeedModels = <(String, String)>[
  ('스피드도어', 'PREMIUM'),
  ('스피드도어', 'STANDARD'),
  ('스피드도어', 'DELUEX'),
  ('스피드도어', 'VE STANDARD'),
  ('스피드도어', '방폭형'),
  ('스피드도어', '빅도어'),
  ('차고문', 'PREMIUM(샤틴펄)'),
  ('차고문', 'PREMIUM(마블스톤)'),
  ('차고문', 'DELUEX(다크 그레이,브라운)'),
  ('차고문', 'STANDARD(우드판넬)'),
  ('셔터', '이중압출'),
  ('셔터', '이중압출단열'),
  ('셔터', '내풍압'),
  ('셔터', '내풍압단열'),
  ('셔터', '철제방화'),
  ('셔터', '스크린방화'),
  ('스네일도어', '스네일도어(SNAIL DOOR)'),
];

/// spec. 시트의 모델별 추가 노트. 맞는 모델이 없으면 빈 문자열.
String sizeQuoteSpecNote({
  required String categoryName,
  required String modelName,
}) {
  final model = _norm(modelName);
  final family = _family(categoryName, modelName);
  final String? note = switch (family) {
    _Family.speed => _speedNote(model),
    _Family.garage => _garageNote(model),
    _Family.shutter => _shutterNote(model),
    _Family.overhead => _overheadNote(model),
    _Family.snail => _snail,
    _Family.security => _securityWave,
    _Family.glass => _glassDoor,
    _Family.other =>
      _speedNote(model) ??
          _garageNote(model) ??
          _shutterNote(model) ??
          _overheadNote(model),
  };
  return (note ?? '').trim();
}

/// 견적서에 찍는 NOTE. 공통 1–7, 모델 사양, 작성자가 더한 메모 순이다.
String sizeQuotePaperNote({
  required String categoryName,
  required String modelName,
  String extra = '',
  SizeQuoteNoteBook? book,
}) {
  final base = book != null && book.hasCommon
      ? book.common.trim()
      : kSizeQuoteBaseNote;
  final spec = book != null && book.hasModel(categoryName, modelName)
      ? book.modelBody(categoryName, modelName).trim()
      : sizeQuoteSpecNote(
          categoryName: categoryName,
          modelName: modelName,
        );
  final more = extra.trim();
  final buf = StringBuffer(base);
  if (spec.isNotEmpty) {
    buf
      ..writeln()
      ..writeln()
      ..write(spec);
  }
  if (more.isNotEmpty && more != spec && !spec.contains(more)) {
    buf
      ..writeln()
      ..writeln()
      ..write(more);
  }
  return buf.toString();
}
