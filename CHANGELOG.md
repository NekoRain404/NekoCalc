# Changelog

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
