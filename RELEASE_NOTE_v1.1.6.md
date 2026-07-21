# 출시명

**COAD DOOR v1.1.6 — 홈 금일 업데이트·iOS 로그인 안정화**

## 출시 노트

### Play Console용 (복사용)

**출시명**  
`v1.1.6 홈 금일 업데이트·iOS 로그인 안정화`

**출시노트**  
```
• 홈 흐름에 금일 업데이트 카드를 추가했습니다 (updated_at 기준 전체)
• 홈 통계 카드 레이아웃을 라벨+숫자 형태로 보기 좋게 정리했습니다
• iOS에서 Firebase 미초기화 시 로그인이 막히던 문제를 수정했습니다
• iOS 최소 지원 버전을 15.0으로 올렸습니다
• 버전 1.1.6 / 빌드 125
```

### 변경 요약
- **금일 업데이트**: 홈 접수/미통화/팔로우와 함께 `updated_at` 당일 건 집계·목록
- **카드 UI**: 라벨 옆 숫자 표시, 잘림 완화
- **iOS**: Firebase 없어도 로그인 가능, deployment target 15.0
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.1.6)
- Play: `flutter build appbundle --release` 후 AAB 업로드

### 버전 정보
- 버전: **1.1.6** / versionCode **125**
