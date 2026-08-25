# 출시명

**COAD DOOR v1.7.7 — MES 메뉴**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.7.7 MES 메뉴`

**출시노트**  
```
• MES 홈·영업등록·달력·시공완료·수금 메뉴를 권한에 따라 사용할 수 있습니다
• 사이즈 표준단가에서 중간 사이즈 예상단가를 보여주고, 테스트중 표시를 뺐습니다
• 버전 1.7.7 / 빌드 160
```

### 변경 요약
- **MES**: 권한별 홈·영업 등록·달력·시공완료 확인·수금 메뉴 추가
- **사이즈 표준단가**: 중간 사이즈 보간 예상단가, 차고문 높이 구간, 테스트중 라벨 제거
- **제안**: 박정훈 상무

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.7.7)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.7.7** / versionCode **160**
