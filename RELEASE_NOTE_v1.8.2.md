# 출시명

**COAD DOOR v1.8.2 — 자동문의고수 담당자**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.8.2 자동문의고수 담당자`

**출시노트**  
```
• 자동문의고수 접수에서 담당자를 다시 고를 수 있습니다 (선택 사항)
• 담당자 목록은 인트라넷과 같이 자동문의고수 부서만 나옵니다
• 버전 1.8.2 / 빌드 169
```

### 변경 요약
- **접수**: 담당자 칩 복구, 선택 사항
- **목록**: 자동문의고수 부서만 표시 (인트라넷과 동일)
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.8.2)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 Transporter 업로드

### 버전 정보
- 버전: **1.8.2** / versionCode **169**
