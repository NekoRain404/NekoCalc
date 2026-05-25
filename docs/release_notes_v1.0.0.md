# NekoCalc v1.0.0 / 正式版

NekoCalc 1.0 is the first stable release of the local-first Android calculation toolbox.

NekoCalc 1.0 是本地优先 Android 计算工具箱的第一个正式稳定版。

## Highlights / 重点更新

- Stable scientific calculator with cursor editing, symbol display, degree/radian mode, memory keys, and responsive haptics.
- 稳定的科学计算器：支持光标编辑、数学符号显示、角度/弧度模式、记忆键和更及时的触感反馈。
- Expanded toolbox for math, engineering, electronics, finance, physics, units, programming, text, and data workflows.
- 扩展工具箱：覆盖数学、工程、电路、财务、物理、单位、编程、文本和数据处理场景。
- Data Fit Chart tool with multi-series data, axes, grid, fitted curves, residual table, R², and RMSE.
- 数据拟合图表：支持多组数据、坐标轴、网格、拟合曲线、残差表、R² 和 RMSE。
- Function graphing with selectable zeros, intersections, and local extrema.
- 函数图形：支持零点、交点和局部极值高亮，并可点击查看点信息。
- SQLite-backed notes, history, favorites, recent tools, settings, and validated JSON backup/restore.
- SQLite 本地存储笔记、历史、收藏、最近工具和设置，并支持经过校验的 JSON 备份恢复。
- Removed unused network permission. NekoCalc remains offline and local-first.
- 移除了未使用的网络权限。NekoCalc 保持离线、本地优先。

## Assets / 下载包

- `NekoCalc-v1.0.0+6-arm64-v8a.apk` for most modern Android phones.
- `NekoCalc-v1.0.0+6-armeabi-v7a.apk` for older 32-bit Android devices.
- `NekoCalc-v1.0.0+6-x86_64.apk` for x86_64 Android environments.
- `NekoCalc-v1.0.0+6-universal.apk` if you need one APK for every supported ABI.

## Checksums / SHA-256

```text
587dd2fed733b1489b413bcf3c64e4889e5f5e997e0787791e6e04f300ba3ec7  NekoCalc-v1.0.0+6-arm64-v8a.apk
f2646db5791616ca7fea753d195fc920128d6300e42b6008df38ef02c743bcd6  NekoCalc-v1.0.0+6-armeabi-v7a.apk
4f34b63839a89401cf17aacd01f857a20e18fb7cbb0ddf18e0c783a216ece321  NekoCalc-v1.0.0+6-x86_64.apk
9835a5b773120025d3fa29f0898b484667465b5a4f31431a13ed93757be993d0  NekoCalc-v1.0.0+6-universal.apk
```

## Upgrade Note / 升级说明

If your device already has a debug-signed beta installed, Android may block direct installation because the stable APK uses a release signing certificate. Export a backup from the old app first, uninstall the old build, install v1.0.0, then import the backup.

如果设备上已安装 debug 签名的 beta 版本，Android 可能会因为签名不同而拒绝覆盖安装。请先在旧版中导出备份，再卸载旧版，安装 v1.0.0 后导入备份。
