# iOS Firebase 설정 안내

이 저장소에는 `GoogleService-Info.plist`가 포함되어 있지 않습니다(비밀 값이 포함되어 있어 커밋하지 않습니다).
FCM(푸시 알림)을 iOS 시뮬레이터/실기기에서 사용하려면 아래 절차를 따르세요.

## 1. 파일 받기

Firebase 콘솔(`after30-c854a` 프로젝트) → 프로젝트 설정 → 일반 → "내 앱" 섹션에서
iOS 앱(Bundle ID `com.after30.app`)을 등록하고 `GoogleService-Info.plist`를 내려받습니다.
iOS 앱이 아직 등록되지 않았다면 Apple Developer Team ID 확정 후 APNs 인증 키(.p8)를
Firebase에 먼저 업로드해야 합니다.

## 2. 파일 배치

다운로드한 `GoogleService-Info.plist`를 이 폴더(`ios/Runner/GoogleService-Info.plist`)에 둡니다.
`.gitignore`에 이미 등록되어 있어 실수로 커밋되지 않습니다.

## 3. Xcode 타깃에 등록

1. Xcode에서 `ios/Runner.xcworkspace`를 엽니다.
2. `Runner` 프로젝트 네비게이터에서 `Runner` 그룹에 `GoogleService-Info.plist`를 드래그하여 추가합니다.
   이때 "Copy items if needed"를 체크하고, Target Membership에 `Runner`를 반드시 체크하세요.
3. `Runner` 타깃 → Build Phases → Copy Bundle Resources에 파일이 추가되었는지 확인합니다.

## 4. 빌드 확인

```bash
flutter build ios --simulator --no-codesign
```

파일이 없어도 위 명령은 실패하지 않지만, Firebase 초기화(`Firebase.initializeApp()`)가
런타임에 예외를 던지거나 FCM 토큰 발급이 되지 않습니다. 로컬 스모크 테스트만 필요하다면
임시(더미 값) plist를 만들어 테스트한 뒤 반드시 삭제하고, 절대 커밋하지 마세요.
