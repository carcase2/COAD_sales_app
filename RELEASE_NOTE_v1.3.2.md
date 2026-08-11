# 출시명

**COAD DOOR v1.3.2 — 상담 입력 시트 UX**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.3.2 상담 입력 시트 UX`

**출시노트**  
```
• 상담내용 입력 시 키보드에 가려지지 않도록 시트·입력란 레이아웃을 개선했습니다
• 여러 줄 상담 내용을 입력하면서 윗줄을 확인할 수 있습니다
• 버전 1.3.2 / 빌드 139
```

### 변경 요약
- **상담 시트**: 키보드 높이에 맞춘 시트 크기, 고정 minLines 입력란, 요약/입력 영역 재구성
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.3.2)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.3.2** / versionCode **139**
