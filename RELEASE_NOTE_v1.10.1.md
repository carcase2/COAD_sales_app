# 출시명

**COAD DOOR v1.10.1 — 본사일반·대구지사 담당자 색 고정**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.10.1 본사일반·대구지사 담당자 색 고정`

**출시노트**  
```
• 본사일반·대구지사 일정에서 담당자 색이 사람마다 고정됩니다
• 달이 바뀌어도 같은 담당자는 같은 색입니다
• 버전 1.10.1 / 빌드 184
```

### 변경 요약
- **본사일반·대구지사**: 담당자 색을 `users.color`에 저장하고 달력·필터 칩에 사용
- 월이 바뀌어도 같은 사람은 같은 색을 유지
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (담당자 색 지정, 업데이트 내역 v1.10.1)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 Transporter 업로드

### 버전 정보
- 버전: **1.10.1** / versionCode **184**
