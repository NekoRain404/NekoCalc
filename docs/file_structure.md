# NekoCalc 文件结构

项目按 Feature-first + Clean Architecture 简化版组织。

## 根目录

- `lib/`：Flutter/Dart 主源码。
- `android/`：Flutter Android 宿主工程，打包 APK 时使用。
- `docs/`：需求、参考图、结构说明和 demo 记录。
- `test/`：核心解析器、计算逻辑和记录分类的自动化测试。
- `.flutter/`：本机 Flutter Gradle 插件兼容层缓存。用于避开部分系统 Flutter 安装缺少 Gradle 插件目录的问题，不作为源码提交。
- `CHANGELOG.md`：Beta 版本更新记录。
- `pubspec.yaml` / `pubspec.lock`：Flutter 依赖与版本锁定。
- `analysis_options.yaml`：Dart 静态分析规则。

## lib 分层

- `lib/app.dart`：应用根节点，只负责主题、设置注入和启动壳装配。
- `lib/application/`：状态、Controller、应用设置。
- `lib/core/`：数学解析、单位换算、格式化、常量和通用工具。
- `lib/data/`：SQLite、本地模型、Repository、备份恢复和持久化。
- `lib/domain/`：实体、工具目录、计算 UseCase、校核逻辑。
- `lib/features/`：按功能拆分的页面与交互。
- `lib/shared/`：跨页面复用的主题、应用壳、启动页和通用组件。

## 不提交的生成物

这些目录由 Flutter、Gradle 或 Android Studio 自动生成，不属于项目源码：

- `.dart_tool/`
- `.gradle/`
- `build/`
- `android/.gradle/`
- `android/.kotlin/`
- `android/build/`
- `.flutter/`
- `.idea/workspace.xml`
- `.idea/deploymentTargetSelector.xml`

需要 APK 时重新运行：

```bash
flutter build apk --release
```
