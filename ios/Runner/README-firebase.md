# iOS Firebase 설정 안내

`ios/Runner/GoogleService-Info.plist`는 Android의 `android/app/google-services.json`과
동일하게 **저장소에 커밋하는 설정 파일**입니다. 이 폴더에 아직 파일이 없다면 아래 절차로
받아서 그대로 커밋하면 됩니다.

## 1. 파일 받기

Firebase 콘솔(`after30-c854a` 프로젝트) → 프로젝트 설정 → 일반 → "내 앱" 섹션에서
iOS 앱(Bundle ID `com.after30.app`)을 등록하고 `GoogleService-Info.plist`를 내려받습니다.
iOS 앱이 아직 등록되지 않았다면 Apple Developer Team ID 확정 후 APNs 인증 키(.p8)를
Firebase에 먼저 업로드해야 합니다.

## 2. 파일 배치 및 커밋

다운로드한 파일을 그대로 `ios/Runner/GoogleService-Info.plist` 경로에 두고 커밋합니다.
**Xcode에서 별도로 드래그하거나 타깃 멤버십을 체크할 필요가 없습니다.** Runner 타깃의
`[Firebase] Copy GoogleService-Info.plist` Run Script 빌드 단계(Copy Bundle Resources
다음 순서)가 빌드 시점에 `ios/Runner/GoogleService-Info.plist`가 존재하면 앱 번들 루트로
복사하고, 파일이 없으면 빌드를 실패시키지 않고 경고만 출력합니다. 이 방식을 쓰는 이유는
Xcode 프로젝트 파일(`project.pbxproj`)에 직접 리소스로 참조를 추가하면, 파일이 없는
클론이나 CI 환경에서 "Build input file cannot be found" 오류로 빌드 자체가 실패하기
때문입니다.

## 3. 빌드 확인

```bash
flutter build ios --simulator --no-codesign
```

파일이 없어도 위 명령은 경고만 출력하고 성공합니다. 다만 파일이 없는 상태로 앱을
실행하면 `Firebase.initializeApp()`이 런타임에 예외를 던지며 즉시 종료됩니다
(`lib/main.dart`에서 try/catch 없이 최상단에서 호출하기 때문). 로컬 스모크 테스트만
필요하다면 `ios/Runner/GoogleService-Info.plist`에 임시(더미 값) plist를 두고 테스트한
뒤 반드시 삭제하고, `git status`로 깨끗한지 확인한 후 커밋하지 마세요. 더미 `API_KEY`는
Firebase SDK가 형식(39자, `AIzaSy` 접두사)을 검증하므로 실제 키 형식과 길이를 맞춰야
크래시 없이 초기화됩니다.
