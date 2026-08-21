# 출시명

**COAD DOOR v1.7.2 — 전일 미처리 안내**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.7.2 전일 미처리 안내`

**출시노트**  
```
• 고객지원 홈에서 전일 미처리 건수를 바로 확인하고 목록으로 갈 수 있습니다
• 전일 미통화는 영업 미통화만 보여 혼동을 줄였습니다
• 버전 1.7.2 / 빌드 155
```

### 변경 요약
- **고객지원**: 일 화면 상단에 전일 미처리 알림
- **홈**: 전일 미통화에서 A/S 선택 창을 빼고 영업만 표시
- **제안**: 남현우 팀장

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.7.2)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.7.2** / versionCode **155**
