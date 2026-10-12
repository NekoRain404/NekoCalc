# NekoCalc Privacy Policy / 隐私政策

Effective date / 生效日期：2026-05-25

NekoCalc is designed as an offline Android calculation toolbox. The app does not require an account, does not include analytics, and does not upload your calculation data to a server.

NekoCalc 是一款离线 Android 计算工具箱。应用不需要账号，不包含统计分析服务，也不会把你的计算数据上传到服务器。

## Data Stored Locally / 本地存储的数据

The app stores the following data in local SQLite storage on your device:

应用会把以下数据存储在你设备本机的 SQLite 数据库中：

- Calculator history / 计算历史
- Tool calculation results / 工具计算结果
- Notes, including title, description, and body / 笔记，包括标题、描述和正文
- Favorite tools and recently used tools / 收藏工具和最近使用工具
- App settings, such as theme, haptics, and display preferences / 应用设置，例如主题、触感和显示偏好

## Backup and Restore / 备份与恢复

Backup export creates a local JSON backup file selected by you. Import reads the backup file you choose and replaces the local app data after validation. NekoCalc does not upload backup files.

备份导出会生成由你选择保存位置的本地 JSON 文件。导入时，应用会读取你选择的备份文件，并在校验通过后替换本地应用数据。NekoCalc 不会上传备份文件。

## Permissions / 权限

NekoCalc declares **two** permissions: **vibration**, used only for optional haptic feedback during calculator
and tool interactions, and **internet**, used only by the user-initiated "check for updates" action in Settings
— which fetches the public release list from GitHub and **uploads nothing**.

NekoCalc 声明**两项**权限：**震动**，仅用于计算器和工具交互中的可选触感反馈；以及**网络**，仅用于设置页里
**由用户主动触发**的「检查更新」——它从 GitHub 取公开的发行列表，**不上传任何内容**。

⚠️ **Corrected 2026-10-12.** This section used to say "the vibration permission only", while
`AndroidManifest.xml` also declares `android.permission.INTERNET` (for the update check described above).
**A privacy policy that omits one of the permissions is worse than one that lists none** — it lets the reader
believe they have seen them all.

⚠️ **2026-10-12 更正。** 本节此前写的是「仅使用震动权限」，而 `AndroidManifest.xml` 里同时声明着
`android.permission.INTERNET`（供上面那条更新检查使用）。**漏列一项权限的隐私政策比不写更坏**——
它会让读者以为自己已经看到了全部。

## Data Deletion / 数据删除

You can delete history, notes, and app data inside the app where available. You can also remove all local data by uninstalling the app or clearing app storage in Android system settings.

你可以在应用内删除历史、笔记和相关数据。也可以通过卸载应用，或在 Android 系统设置中清除应用存储来删除全部本地数据。

## Contact / 联系

For issues or privacy questions, use the GitHub repository issue tracker:

如需反馈问题或询问隐私相关事项，请通过 GitHub 仓库 issue 联系：

https://github.com/NekoRain404/NekoCalc
