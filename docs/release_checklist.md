# NekoCalc Release Checklist

This checklist is the minimum gate for a public stable release.

## Version

- Update `pubspec.yaml` with the public version and monotonically increasing build number.
- Update `lib/core/constants/app_info.dart`.
- Update `CHANGELOG.md`.
- Update `PRIVACY.md` when permissions or data handling changes.
- Update README version badges and status text.

## Signing

- Create `android/key.properties` from `android/key.properties.example`.
- Keep the real keystore and `key.properties` out of git.
- Run a release build and verify it is signed with the release certificate.
- Do not publish a release APK signed with the debug certificate.

```bash
flutter build apk --release --split-per-abi
```

## Quality Gate

```bash
dart format lib test
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

## Manual QA

- Calculator:
  - Fast numeric input does not lag.
  - `=` shows the result immediately and saves history once.
  - Degree/radian switching changes trigonometric results.
  - Memory keys update instantly and persist after restart.
  - Mathematical symbol display and function-expression display both work.

- Tools:
  - Tool search works with Chinese, English, and tool ids.
  - Favorite and recent tools persist after restart.
  - Numeric tools recalculate smoothly while editing.
  - Text/data tools handle paste, empty input, and invalid input without crashing.

- Graph:
  - Add, edit, hide, and delete functions.
  - Pan and zoom remain smooth.
  - Zero, intersection, and local extreme markers are selectable.
  - Invalid functions do not crash the page.

- Data Fit Chart:
  - Single-series data fits correctly.
  - Multi-series data can switch selected series.
  - Chart axes, table, residuals, and copy/save actions work.
  - Light and dark themes keep the chart readable.

- Notes and History:
  - Note title, description, and body are searchable.
  - History deletion and clear history behave as expected.
  - Saving history as a note includes useful context.

- Backup:
  - Export from a populated database.
  - Import into a fresh install.
  - Import over an existing database.
  - Invalid backup files show a useful error and do not wipe data.

## Device Smoke Test

Install the arm64 build on a real phone:

```bash
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
adb shell dumpsys package com.nekorain.nekocalc | rg "versionCode|versionName|lastUpdateTime"
adb shell monkey -p com.nekorain.nekocalc -c android.intent.category.LAUNCHER 1
```

## Release Assets

- `NekoCalc-vX.Y.Z+N-arm64-v8a.apk`
- `NekoCalc-vX.Y.Z+N-armeabi-v7a.apk`
- `NekoCalc-vX.Y.Z+N-x86_64.apk`
- Optional: `NekoCalc-vX.Y.Z+N-universal.apk`

Use bilingual release notes for public GitHub releases.
