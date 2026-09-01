# 출시명

**COAD DOOR v1.8.4 — 자동문의고수 접수**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.8.4 자동문의고수 접수`

**출시노트**  
```
• 자동문의고수 접수에서 사진 앨범과 명함 인식을 쓸 수 있습니다
• 제품군·문의방법·담당자 선택이 더 잘 구분됩니다
• 버전 1.8.4 / 빌드 171
```

### 변경 요약
- **첨부**: 아이폰에서 사진 앱으로 여러 장 선택
- **명함**: 접수 시 이름·연락처 자동 입력
- **선택 칩**: 선택된 버튼 채움·체크로 구분
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.8.4)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 Transporter 업로드

### 버전 정보
- 버전: **1.8.4** / versionCode **171**
