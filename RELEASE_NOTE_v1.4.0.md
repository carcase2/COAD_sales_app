# 출시명

**COAD DOOR v1.4.0 — 체크시트 아카이브 검색**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.4.0 체크시트 아카이브 검색`

**출시노트**  
```
• MES 아카이브 체크시트(TP1)를 앱에서 검색·조회할 수 있습니다
• 연·월 필터와 키워드 검색으로 원하는 체크시트를 빠르게 찾습니다
• 관리자는 체크시트 사용 내역·순위를 확인할 수 있습니다
• 버전 1.4.0 / 빌드 141
```

### 변경 요약
- **체크시트 검색**: MES 아카이브(TP1) 검색·조회, 이미지 저장
- **사용 내역**: 관리자용 체크시트 사용량·순위
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.4.0)
- Edge Function: `archive-checksheets` / `archive-media` (미배포 시 배포)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.4.0** / versionCode **141**
