# 출시명

**COAD DOOR v1.5.0 — 명함 수첩·표준단가**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.5.0 명함 수첩·표준단가`

**출시노트**  
```
• 명함을 촬영해 등록하고, 검색·메모·블랙리스트를 쓸 수 있습니다
• 사이즈 표준단가를 조회하고 조정할 수 있습니다
• 버전 1.5.0 / 빌드 146
```

### 변경 요약
- **명함 수첩**: 촬영 인식·영역 자르기, 검색, 메모, 블랙리스트
- **표준단가**: 폭×높이·모델 표준단가 조회와 조정
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.5.0)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.5.0** / versionCode **146**
