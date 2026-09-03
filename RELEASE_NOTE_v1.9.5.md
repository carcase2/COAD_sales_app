# 출시명

**COAD DOOR v1.9.5 — A/S 접수 앱 알림**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.9.5 A/S 접수 앱 알림`

**출시노트**  
```
• 인트라넷·앱에서 A/S(고객지원) 접수 시 고객지원팀·관리자 폰으로 알림이 갑니다
• 아이폰에서도 배너가 보이도록 알림 제목·본문을 함께 보냅니다
• 버전 1.9.5 / 빌드 178
```

### 변경 요약
- **A/S 푸시**: 수신 대상을 고객지원·고객지원팀·관리자로 맞춤, iOS notification payload
- **제안**: 이상수 팀장

### 배포 시 함께 필요
- Supabase: `supabase db push` + `supabase functions deploy notify-as-reception`
- COAD_home: 인트라넷 `createCallLog` 후 `notify-as-reception` 호출 배포
- Play / iOS 빌드·업로드

### 버전 정보
- 버전: **1.9.5** / versionCode **178**
