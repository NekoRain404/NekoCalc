# NekoCalc

NekoCalc 是一款面向 Android 的本地优先计算工具箱。它使用 Flutter 构建界面与交互，将科学计算器、工程计算工具、函数图形、数据拟合、笔记和计算历史整合在一个轻量应用中。

项目目标是提供一个可以长期维护的移动端计算工作台：功能足够实用，数据默认留在本机，代码结构清晰，发布流程可复现。

<p>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-Android-4A7DFF?style=flat-square">
  <img alt="Version" src="https://img.shields.io/badge/version-1.1.0-23B45D?style=flat-square">
  <img alt="Storage" src="https://img.shields.io/badge/storage-SQLite-23B45D?style=flat-square">
  <img alt="Architecture" src="https://img.shields.io/badge/architecture-Feature--first-111827?style=flat-square">
  <img alt="Release" src="https://img.shields.io/badge/release-stable-111827?style=flat-square">
</p>

## Overview

NekoCalc 适合日常计算、学习推导、工程估算、数据检查和移动端快速记录。应用不依赖云服务，计算历史、工具结果、笔记、收藏、最近使用工具和设置均存储在本机 SQLite 中。

正式版重点关注四件事：

- 清晰的计算体验：基础运算、科学函数、角度/弧度、记忆寄存器、光标编辑和数学符号显示。
- 实用的工具体系：覆盖数学、工程、电路、财务、物理、单位换算、编程、文本和数据处理。
- 可靠的数据管理：SQLite 持久化、笔记描述检索、历史去重、备份导出与导入前校验。
- 可维护的工程结构：Feature-first + Clean Architecture 简化分层，避免 UI、业务逻辑和数据访问混在一起。

## Features

- Scientific calculator with basic arithmetic, common functions, less-used functions, constants, memory keys, haptic feedback, and responsive input.
- Function graphing with pan/zoom, multiple functions, zeros, intersections, local extrema, highlighted points, and selectable point details.
- Data Fit Chart tool for Excel-like list data, including multi-series input, axes, grid, fitted curves, residuals, R², and RMSE.
- Engineering and utility tools for math, electronics, mechanics, finance, physics, unit conversion, programming data, and text workflows.
- Notes and history backed by SQLite, with searchable title, description, body, calculation history, and tool history.
- JSON backup and restore with schema validation before database import.
- Light/dark theme support, stable release icons, optional haptics, and local state restoration.

## Architecture

The project uses a simplified Feature-first + Clean Architecture layout. The intent is practical separation: UI handles interaction, application controllers coordinate state, domain code owns calculation rules, data code owns persistence, and core code contains shared math and formatting utilities.

```text
lib/
├── main.dart                        # Flutter entry point
├── app.dart                         # App root, theme, settings, and shell wiring
├── application/                     # Controllers, application state, settings orchestration
├── core/                            # Math parser, formatting, platform helpers, shared utilities
├── data/                            # SQLite database, repositories, backup persistence
├── domain/                          # Entities, tool catalog, use cases, calculation logic
├── features/                        # Feature-first screens, widgets, animations, interactions
└── shared/                          # App chrome, theme, reusable presentation components
```

More details:

- [Architecture](docs/architecture.md)
- [File Structure](docs/file_structure.md)
- [Release Checklist](docs/release_checklist.md)

## Requirements

- Flutter 3.x
- Android SDK
- Android Studio or a working command-line Android toolchain

Install dependencies:

```bash
flutter pub get
```

Run static checks and tests:

```bash
flutter analyze
flutter test
```

Run on a connected Android device:

```bash
flutter run
```

## Build

Build a universal release APK:

```bash
flutter build apk --release
```

Build split APKs by ABI:

```bash
flutter build apk --release --split-per-abi
```

Release outputs:

```text
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

## Release Signing

Local debug builds can run without a release keystore. Public release builds should use `android/key.properties`, based on the template in `android/key.properties.example`.

The real keystore and `android/key.properties` must stay outside git. They are ignored by `.gitignore`.

```properties
storeFile=/absolute/path/to/nekocalc-release.jks
storePassword=change-me
keyAlias=nekocalc
keyPassword=change-me
```

Before publishing, run:

```bash
dart format lib test
flutter analyze
flutter test
flutter build apk --release --split-per-abi
flutter build apk --release
```

## Data And Privacy

NekoCalc is local-first. It stores app data in SQLite on the device and does not upload user data to a server.

Stored data includes:

- Calculator history
- Tool result history
- Notes with title, description, and body
- Favorite tools and recent tools
- Settings
- User-created backup files

Full privacy details are available in [PRIVACY.md](PRIVACY.md).

## Android Studio

Open the repository root, the directory containing `pubspec.yaml`. The Android host project lives in `android/`.

If a local Flutter installation is missing `packages/flutter_tools/gradle`, the project can use the local `.flutter/flutter_tools_gradle` compatibility layer. That directory is machine-specific cache and is ignored by git.

## Release

Current stable version: `v1.1.0`

GitHub releases include split APKs for common Android ABIs and an optional universal APK:

- `arm64-v8a` for most modern Android phones
- `armeabi-v7a` for older 32-bit Android devices
- `x86_64` for emulator and x86 Android environments
- `universal` when one APK must cover all supported ABIs

See [CHANGELOG.md](CHANGELOG.md) for release history.

## Documentation

- [Architecture](docs/architecture.md)
- [File Structure](docs/file_structure.md)
- [Release Checklist](docs/release_checklist.md)
- [Privacy Policy](PRIVACY.md)
- [Changelog](CHANGELOG.md)

## License

See [LICENSE](LICENSE).
