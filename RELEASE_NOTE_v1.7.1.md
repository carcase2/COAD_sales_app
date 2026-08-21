# 출시명

**COAD DOOR v1.7.1 — 내풍압 자재비**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.7.1 내풍압 자재비`

**출시노트**  
```
• 내풍압 셔터는 자재비에 윈드락·프레임까지 포함해 보여 줍니다
• 견적 상세에서 롤파이프와 브라켓 종류를 한 줄씩 읽기 쉽게 했습니다
• 버전 1.7.1 / 빌드 154
```

### 변경 요약
- **자재비**: 내풍압·내풍압단열은 스라트·모터·절곡에 윈드락·프레임 포함
- **상세**: 롤파이프·브라켓을 한 줄씩 표시
- **제안**: 이상수 팀장

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.7.1)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.7.1** / versionCode **154**
