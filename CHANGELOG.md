# Changelog

## v1.0.0

NekoCalc 1.0 is the first stable release. It focuses on daily reliability, local-first data safety, release packaging, and a smoother scientific calculator workflow.

NekoCalc 1.0 是第一个正式稳定版，重点完善日常可用性、本地数据安全、发布打包和科学计算器交互。

- Promoted the app from beta to stable with public version `1.0.0+6`.
- Added a formal privacy policy and removed the unused network permission.
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
