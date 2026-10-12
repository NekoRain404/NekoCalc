# Changelog

## Unreleased

Post-beta fixes. They are listed here, without a version number, because none of them has been **felt on a
device** yet — the entry gets a version when that changes.

beta 之后的修复。**不给版本号**，因为其中还没有一条在**真机上被感受到**过——等到那一步，它们才会有版本号。

- Corrected a **privacy statement**: the app declares `android.permission.INTERNET` and uses it for the
  user-initiated "check for updates" action, while three documents said the permission had been removed and that
  the app stays offline. Nothing is uploaded and the app remains local-first — but the permission was never
  removed, so the sentence was false. Corrected in place, with dated notes, in `PRIVACY.md`,
  `docs/release_notes_v1.0.0.md` and this file.
- Fixed the `◀` `▶` cursor keys jumping to the ends: they now move **exactly one character** from the caret on
  screen. The cause was a non-collapsed selection the display band never draws (it renders a single caret at
  `selection.end`), which also survived a restart because `restoreState` persists and restores it — so the first
  keypress after launch met it with nothing on screen to explain the jump. Range replacement
  (`input`/`backspace`) is untouched. (docs/verification.md §5q)
- Fixed the graph page **ignoring the app's angle mode**: under DEG a `sin(x)` curve — and its zeros,
  intersections and extrema — were computed in radians while the calculator used degrees, so the two
  disagreed on the same input. The code's own comment claimed they matched. (docs/verification.md §5r, §5s)
- Fixed note search **missing matches past the first page**: a query holding a date, an engineering symbol or
  punctuation cannot go through the SQL filter, so it was applied locally — **to the first page only**, which
  made "searched, found nothing" a false answer rather than an incomplete one. The decision to read one page,
  rather than every match, is unchanged; what changed is its consequence. (docs/verification.md §5r)
- Fixed the engine's "units and constants failed to load" verdict being **written only to logcat**, which made
  an engine with no units indistinguishable from one returning a real answer. (docs/verification.md §5o)
- Fixed backup export/import over the storage-access channel: on a device with no activity for
  `ACTION_CREATE_DOCUMENT` the call threw across the platform thread and left the channel answering `busy`
  **for the rest of the process's life**. Both paths now catch, reset their state, and answer a real error.
- Made the libqalculate bridge **process-scoped**. The library documents that there should never be more than
  one `Calculator` object per process; holding it per Activity created a second engine and a second native
  thread whenever the system recreated the Activity.
- Locked the interface to portrait.
- Unified theming: every Material colour role now resolves through a `CalcTheme` token, with light and dark
  built by a single builder, so a theme change cannot leave a screen on the old palette.
- Added the Kotlin/JNI layer's first tests (11 JVM tests over the pure mapping logic, plus a JNI test double
  that shadows the AAR's glue so a broken double fails loudly instead of passing quietly).
- Added widget tests that drive the **real** cursor keys — including the launch-restored selection case that
  the previous tests never entered.

## v1.2.0-beta.1

NekoCalc 1.2 beta is a release-candidate style preview that closes the large feature and maintainability work for the next public release.

NekoCalc 1.2 beta 是面向下一次公开发布的预览版，集中收口大范围功能完善、细节可靠性和代码解耦工作。

- Updated the public prerelease version to `1.2.0-beta.1+8`.
- Expanded engineering, finance, physics, structure, electronics, math, unit, programming, text, and data workflow coverage.
- Split large calculation, insight, paste, and text-tool logic into focused modules to reduce controller and use-case coupling.
- Improved calculator submit, paste, save-to-history, and save-to-note flows with structured results and clearer failure messages.
- Improved numeric tools, text tools, and Data Fit Chart save flows so invalid input, empty output, write failures, and exceptions are handled explicitly.
- Improved notes and history management with structured delete/import results and more robust search and clipboard import behavior.
- Improved backup export/import reporting with metadata, previews, row-count impact, and safer user-facing messages.
- Improved graph workspace paste/restore, marker handling, and test coverage for graph interactions.
- Improved recent-tool management with structured remove/clear results and real affected-row feedback.
- Added broader automated coverage for calculator controllers, tool controllers, text tools, data fitting, graph functions, backup handling, notes, and UI workflows.

## v1.1.0

NekoCalc 1.1 focuses on reliability and professional workflow improvements after the first stable release.

NekoCalc 1.1 聚焦正式版后的可靠性和专业工作流增强。

- Updated the public version to `1.1.0+7`.
- Added backup metadata with app version and snapshot format information.
- Added backup import preview with row counts for history, notes, favorites, recent tools, and settings.
- Improved calculator errors with clearer messages for missing parentheses, unknown functions, invalid roots, and invalid factorials.
- Added logarithmic and reciprocal models to Data Fit Chart.
- Added tests for the new fitting models and backup preview parsing.

## v1.0.0

NekoCalc 1.0 is the first stable release. It focuses on daily reliability, local-first data safety, release packaging, and a smoother scientific calculator workflow.

NekoCalc 1.0 是第一个正式稳定版，重点完善日常可用性、本地数据安全、发布打包和科学计算器交互。

- Promoted the app from beta to stable with public version `1.0.0+6`.
- Added a formal privacy policy and removed the unused network permission.

  ⚠️ **Corrected 2026-10-12 — the second half of that line is not true.** `AndroidManifest.xml` still declares
  `android.permission.INTERNET`, and it is **used**: the user-initiated "check for updates" action in Settings
  fetches the public release list from GitHub (`github_release_checker.dart`). Nothing is uploaded. The same
  false claim stood in `docs/release_notes_v1.0.0.md` and in the privacy policy's permissions section; both were
  corrected the same day. The line is kept as written with the correction under it, because a changelog entry is
  a record.
  ⚠️ **2026-10-12 更正——这一行的后半句不成立。** `AndroidManifest.xml` 里仍然声明着
  `android.permission.INTERNET`，而且它**在用**：设置页里**由用户主动触发**的「检查更新」会从 GitHub 取公开的
  发行列表（`github_release_checker.dart`）。不上传任何内容。同一句假话也出现在
  `docs/release_notes_v1.0.0.md` 与隐私政策的权限一节，同日一并更正。原行**保留**、更正写在它下面——
  变更记录是记录。
- Added release signing support with local `key.properties` and split-ABI release packaging.
- Improved calculator responsiveness by showing results before background SQLite writes.
- Improved haptic feedback timing and added clearer settings for haptic strength.
- Improved calculator expression display with mathematical symbols and cursor-based editing.
- Improved SQLite backup validation before import to protect local notes, history, settings, favorites, and recent tools.
- Improved notes search so title, description, and body all participate in matching.
- Improved tool search, favorite toggles, recent tools, and large text/data tool recalculation.
- Improved graph markers for zeros, intersections, and local extrema with selectable point details.
- Improved Data Fit Chart with axes, grid, multi-series handling, readable themes, and table-style results.
- Added broader bilingual code comments and release documentation for maintainability.

## v0.3.0-beta

Beta 0.3 focuses on data analysis tools, chart readability, and better local search.

- Added a Data Fit Chart tool under Math / Statistics for Excel-like list data fitting.
- Supported single-series `x,y`, multi-column `x,y1,y2`, and blank-line separated multi-series datasets.
- Added linear, quadratic, exponential, and power-function fitting with equation, R², RMSE, fitted values, and residuals.
- Added an in-app chart with axes, grid, tick labels, legend, selected-series highlighting, and a real data table.
- Improved chart colors so the chart uses the app theme surface consistently in light and dark modes.
- Fixed note search so keywords in note descriptions are searchable.
- Built release packages with ABI splitting to reduce APK size.

## v0.2.0-beta

Beta 0.2 focuses on making the calculator usable as a daily scientific tool.

- Added cursor-based calculator input with left/right movement and insertion at the cursor.
- Separated expression display modes: mathematical symbols and editable mathematical expressions.
- Improved mathematical symbol rendering for powers, logarithm bases, square roots, cube roots, and incomplete function input.
- Fixed notes and history refresh when returning to the notes page.
- Preserved local data during debug installation by switching to replacement install for device testing.
- Added stronger guardrails around notes/history database reads so failures show explicit UI feedback.

## v1.0.0-beta.2

Beta 2 focuses on reliability and release readiness.

- Added repository boundaries for history, notes, settings, tool usage, and backup data.
- Improved SQLite behavior with indexed queries, WAL mode, duplicate history protection, bounded history/recent records, and safer migrations.
- Added JSON backup and restore for history, notes, favorites, recent tools, and settings.
- Added calculator memory controls: `MC`, `MR`, `M-`, and `M+`.
- Added note descriptions and migrated existing notes safely.
- Added unit tests for expression parsing, tool calculations, and record filtering.
- Cleaned project structure and generated-file ignore rules for Android Studio and Flutter builds.

## v1.0.0-beta.1

Initial beta preview.

- Added scientific calculator, engineering toolbox, graph page, notes, and SQLite history.
- Added dark mode, startup animation, haptics, app icons, and basic Android build support.
