# PlanIT mobile

This directory contains the Flutter application shell, Android/iOS/web runners, design system, navigation, and shared domain primitives. CI pins Flutter 3.47.1, project metadata records that SDK revision, and the committed lockfile pins package resolution.

After installing Flutter 3.47.1 and the target platform toolchain, run:

```powershell
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
dart run build_runner build
flutter test --no-pub
flutter build apk --debug --no-pub
flutter run --dart-define=PLANIT_API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Android network permission applies to every build type, and auto-backup is disabled so encrypted preferences are not restored without their Keystore keys. iOS Keychain entitlements are committed for debug/profile and release builds. Release signing credentials are intentionally not stored in the repository; configure them through the release environment before producing a signed artifact.

The Gradle distribution checksum is pinned, and CI validates the committed wrapper JAR before executing it.
