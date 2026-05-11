# NekoCalc

NekoCalc 是一个 Flutter Android 计算工具箱项目。

## Android Studio 打开方式

优先打开项目根目录，也就是包含 `pubspec.yaml` 的目录。Flutter 工程入口是：

- `lib/main.dart`
- `lib/app.dart`
- `android/`

仓库中原有的根级 `app/` 是旧的原生 Android 模块，目前不作为 Flutter 应用入口使用。后续确认无兼容需求后，可以单独清理。

## 架构

当前采用 Feature-first + Clean Architecture 简化版：

```text
lib/
├── app.dart
├── main.dart
├── core/                 # 数学解析器、格式化、通用工具
├── data/                 # SQLite、本地数据模型
├── domain/               # 实体、工具定义、工程计算逻辑
├── application/          # Controller、UseCase 编排
├── features/             # 按功能组织 UI
└── shared/               # 跨功能复用的纯 UI 组件
```

详细约束见 `docs/architecture.md`。
