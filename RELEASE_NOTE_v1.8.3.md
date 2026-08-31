# 출시명

**COAD DOOR v1.8.3 — 자동문의고수 팔로업중**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.8.3 자동문의고수 팔로업중`

**출시노트**  
```
• 팔로업중은 종료되기 전 접수를 모두 보여 줍니다
• 기존진행중은 1차 상담 이후 미종료 건입니다
• 버전 1.8.3 / 빌드 170
```

### 변경 요약
- **홈**: 팔로업중 카드 = 종료 전 전체
- **목록**: 팔로업중에서 전체·접수·진행중 필터
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.8.3)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 Transporter 업로드

### 버전 정보
- 버전: **1.8.3** / versionCode **170**
