# 출시명

**COAD DOOR v1.7.12 — 표준단가 직접 입력**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.7.12 표준단가 직접 입력`

**출시노트**  
```
• 사이즈 표준단가에서 폭·높이를 키패드로 직접 넣고, 칸을 다시 누르면 지우고 다시 입력할 수 있습니다
• 금액이 나오면 복사 버튼을 바로 누를 수 있습니다
• 버전 1.7.12 / 빌드 165
```

### 변경 요약
- **표준단가**: 폭/높이 직접 입력, 다시 탭하면 지움, 분류 탭·복사 버튼 강화
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.7.12)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.7.12** / versionCode **165**
