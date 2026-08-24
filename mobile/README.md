# PlanIT mobile

This directory contains the Flutter application shell, design system, navigation, and shared domain primitives.

Flutter is not installed in the current workstation environment, so native Android/iOS runner files have not been generated. After installing current Flutter stable, run once from this directory:

```powershell
flutter create --org com.planit --project-name planit_mobile --platforms android,ios .
flutter pub get
flutter analyze
flutter test
```

The generated platform projects must then be reviewed for signing, secure-storage requirements, Android backup exclusions, minimum OS versions, and release flavors before committing.
