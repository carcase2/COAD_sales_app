# 출시명

**COAD DOOR v1.7.6 — 종료 건 팔로우 달력 제외**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.7.6 종료 건 팔로우 달력 제외`

**출시노트**  
```
• 수주·미수주·단순문의·설계문의는 팔로우 달력에 더 이상 나오지 않습니다
• 버전 1.7.6 / 빌드 159
```

### 변경 요약
- **고객전화 팔로우**: 종료 상태(수주·미수주·단순문의·설계문의·기타)는 달력·오늘 팔로우·지연 팔로우에서 제외
- **제안**: 홍창우 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.7.6)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.7.6** / versionCode **159**
