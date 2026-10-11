# NekoCalc v1.1.0 / 可靠性增强版

NekoCalc 1.1 improves the stable release with safer backups, clearer calculator feedback, and stronger data analysis workflows.

NekoCalc 1.1 在正式版基础上继续增强备份安全、计算器错误反馈和数据分析工作流。

## Highlights / 重点更新

- Added backup metadata with app version and snapshot format information.
- 备份文件新增应用版本和快照格式元信息。
- Added import preview before restore, including history, notes, favorites, recent tools, settings, and total row counts.
- 导入恢复前新增摘要预览，显示历史、笔记、收藏、最近工具、设置和总记录数。
- Improved calculator error messages for missing parentheses, unknown functions, invalid roots, invalid factorials, and malformed numbers.
- 优化计算器错误提示，覆盖缺少括号、未知函数、非法开根、非法阶乘和数字输入错误。
- Added logarithmic and reciprocal fitting models to Data Fit Chart.
- 数据拟合图表新增对数拟合和倒数拟合模型。
- Updated the project to Flutter 3.44 build metadata and refreshed dependency lock versions.
- 更新 Flutter 3.44 构建元数据并刷新依赖锁定版本。

## Assets / 下载包

- `NekoCalc-v1.1.0+7-arm64-v8a.apk` for most modern Android phones.
- `NekoCalc-v1.1.0+7-armeabi-v7a.apk` for older 32-bit Android devices.
- `NekoCalc-v1.1.0+7-x86_64.apk` for x86_64 Android environments.
- `NekoCalc-v1.1.0+7-universal.apk` if one APK must cover all supported ABIs.

## Checksums / SHA-256

```text
e25dd94602759602288f68f6868b26333f219091d67cdb560131a0f74d08f477  NekoCalc-v1.1.0+7-arm64-v8a.apk
181a5b236deb76dfe53de44eef9b704208b47cf8f568bd6db0135ef9f4671487  NekoCalc-v1.1.0+7-armeabi-v7a.apk
fc05b23d1257a5ea4183cd48a8b8f0c4bd77f38627cb04c21f5b2a979997f938  NekoCalc-v1.1.0+7-x86_64.apk
f44c0e9260e33d0daf775ca7861b6672fea3c114483fe5d0e2c455730292e292  NekoCalc-v1.1.0+7-universal.apk
```

## Verification / 验证

- `flutter analyze` passed.
- `flutter test` passed with 30 tests.
- Split ABI and universal release APK builds passed.
- `arm64-v8a` release was installed on a real device and reported `versionName=1.1.0`, `versionCode=2007`.
