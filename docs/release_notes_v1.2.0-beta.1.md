# NekoCalc v1.2.0-beta.1

This prerelease closes the large 1.2 beta workstream. It is intended for users who want the newest tool coverage and reliability improvements before the next stable release.

这个预览版用于收口 1.2 beta 的大范围功能和维护性改进，适合希望提前体验新工具、新交互和可靠性增强的用户。

## Highlights

- Expanded calculator, graph, data fit, engineering, finance, physics, electronics, structure, unit conversion, programming, text, notes, backup, and search workflows.
- Decoupled large controllers/use cases into focused modules for calculation domains, text tools, paste parsing, graph workspace paste, tool insights, and result objects.
- Added structured result objects for calculator submit/paste/save, tool save, notes delete/import, backup export/import, and recent-tool management.
- Improved save and delete feedback so invalid input, missing output, zero database writes, missing records, and write failures produce explicit messages.
- Added broader unit and widget coverage across the core parser, backup validation, calculator controller, tool controller, text tools, graph functions, notes, settings, and tool pages.

## 安装

Pick the APK that matches your device:

- `arm64-v8a`: most modern Android phones
- `armeabi-v7a`: older 32-bit Android devices
- `x86_64`: emulators and x86 Android devices
- `universal`: one larger APK that supports all included ABIs

如果不确定设备架构，请下载 universal 包。

## Verification

Release artifacts were built from Flutter release mode and include SHA-256 checksums.
