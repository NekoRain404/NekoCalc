# NekoCalc

一个面向 Android 的 Flutter 计算工具箱。NekoCalc 把日常计算、科学函数、工程工具、单位换算、函数图形和本地笔记放在同一个轻量工作台里，适合学习、调试、估算和移动端快速记录。

<p>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-Android-4A7DFF?style=flat-square">
  <img alt="Version" src="https://img.shields.io/badge/version-0.3.0--beta-6D5DFB?style=flat-square">
  <img alt="Storage" src="https://img.shields.io/badge/storage-SQLite-23B45D?style=flat-square">
  <img alt="Architecture" src="https://img.shields.io/badge/architecture-Feature--first-111827?style=flat-square">
</p>

## 预览

<p>
  <img src="docs/images/preview-1.png" alt="NekoCalc preview 1" width="32%">
  <img src="docs/images/preview-2.png" alt="NekoCalc preview 2" width="32%">
  <img src="docs/images/preview-3.png" alt="NekoCalc preview 3" width="32%">
</p>

## 功能

- 计算器：基础运算、科学函数、三角函数、幂函数、常数输入、角度/弧度模式、记忆寄存器。
- 工具箱：数学、电路电子、机械工程、财务商业、物理科学、单位换算、编程数据工具。
- 数据分析：支持 Excel 风格列表数据拟合、散点图、拟合曲线、R²、RMSE、拟合值和残差表。
- 工程校核：工具结果包含公式、输入摘要、误差范围、边界条件和场景限制。
- 图形：函数绘制、拖拽缩放、零点/交点/极值标记与点选查看。
- 笔记与历史：计算历史、工具结果、个人笔记均存储在本机 SQLite。
- 数据管理：通过 JSON 备份/恢复历史、笔记、收藏、最近工具和设置。
- 体验：启动动画、深色模式、夜间图标、触感反馈、状态恢复。

## 架构

项目采用 Feature-first + Clean Architecture 简化版，核心目标是让页面、状态、计算逻辑和数据持久化保持清晰边界。

```text
lib/
├── app.dart                         # 应用根节点：主题、设置注入、启动壳装配
├── main.dart                        # Flutter 入口
├── application/                     # Controller、应用设置、状态编排
├── core/                            # 数学解析、单位换算、格式化、常量
├── data/                            # SQLite、本地模型、持久化
├── domain/                          # 实体、工具目录、计算 UseCase、校核逻辑
├── features/                        # 按功能组织页面与交互
└── shared/                          # 应用壳、启动页、主题和通用组件
```

更多说明见 [docs/file_structure.md](docs/file_structure.md) 和 [docs/architecture.md](docs/architecture.md)。

## 运行

环境要求：

- Flutter 3.x
- Android SDK
- Android Studio 或命令行 Gradle 环境

常用命令：

```bash
flutter pub get
flutter analyze
flutter run
```

构建 APK：

```bash
flutter build apk --release
```

按 ABI 拆分发布包：

```bash
flutter build apk --release --split-per-abi
```

构建产物位于：

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Android Studio

打开项目根目录，也就是包含 `pubspec.yaml` 的目录。Flutter Android 宿主工程位于 `android/`，不要再使用旧式根级 `app/` 模块。

如果本机 Flutter 安装缺少 `packages/flutter_tools/gradle`，项目会优先使用本地 `.flutter/flutter_tools_gradle` 兼容层。该目录属于机器缓存，已被 `.gitignore` 忽略；重新同步前可由本机环境生成或保留。

## 数据

NekoCalc 当前只使用本机 SQLite：

- 计算历史
- 工具结果历史
- 收藏工具
- 设置项
- 笔记
- JSON 备份与恢复

数据不会上传到网络服务。

## 文档

- [架构说明](docs/architecture.md)
- [Demo 记录](docs/demo.md)
- [文件结构](docs/file_structure.md)
- [更新日志](CHANGELOG.md)

## 状态

当前版本：`v0.3.0-beta`

Beta 0.3 重点放在数据拟合图表、表格化结果、图表可读性、笔记描述搜索和按 ABI 拆分的轻量发布包上。后续适合继续补充更多拟合模型、图表导出和正式签名配置。
