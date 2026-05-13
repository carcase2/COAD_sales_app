# Play Console 업로드 키 재설정 (내부 테스트 포함)

Play에 등록된 **업로드 키** SHA-1과 로컬 `upload-keystore.jks`가 다르면 AAB 업로드가 거절됩니다.  
아래는 **현재 PC의 키를 새 업로드 키로 등록**하는 절차입니다.

## 1) PEM 파일 만들기 (로컬 Mac)

프로젝트 루트에서:

```bash
chmod +x scripts/export_play_upload_certificate.sh
./scripts/export_play_upload_certificate.sh
```

성공하면 루트에 **`upload_certificate.pem`** 이 생깁니다.  
터미널에 나온 **SHA1**이 `CE:F7:D0:AC:...` (로컬 키)와 같은지 확인하세요.

> `JAVA_HOME` 또는 Homebrew `openjdk@17` 의 `keytool`이 PATH에 있어야 합니다.

## 2) Play Console에서 재설정 요청

1. [Play Console](https://play.google.com/console) → 해당 앱  
2. **출시(Release)** → **설정(Setup)** → **앱 무결성(App integrity)**  
3. **업로드 키 재설정 요청** / **Request upload key reset** (표기는 콘솔 버전에 따라 다를 수 있음)  
4. 안내에 따라 **`upload_certificate.pem`** 첨부  
5. 사유 예: *기존 업로드 키와 로컬 키 불일치, 로컬 키로 재등록 요청*

처리가 완료되면, 콘솔의 **업로드 키 인증서** SHA-1이 **로컬 키와 동일**해집니다.

## 3) 승인 후 배포

```bash
flutter build appbundle --release
```

생성된 `build/app/outputs/bundle/release/app-release.aab` 를 내부 테스트 트랙에 업로드합니다.

## 주의

- **`upload_certificate.pem`** 은 공개 인증서이지만, 저장소에 올리지 마세요 (`.gitignore`에 포함).  
- **`.jks`와 `key.properties` 비밀번호**는 절대 커밋·공유하지 마세요.
