#!/bin/bash
# 中文：**把设备上的数据库拉下来——三个文件一起。**
#
#       ⚠️ **这个脚本存在的唯一理由是：我漏拉过 `-wal`，然后读到了一个过期的值。**
#       本仓那条规矩写着「`nekocalc.db` + `-wal` + `-shm` 要一起拉，少一个就不是同一份」，
#       而我在这一场里手写过十几遍这段拉取，**其中一次漏了 `-wal`**——
#       结果是对的旧值，于是我以为"应用没有写结果"，把一次测量判成了失败。
#
#       **手写的拉取会漏；脚本不会。** 这就是它全部的内容。
#
#       用法：
#           tool/pull_device_db.sh [输出目录]      # 默认 /tmp/nekocalc-db
#       之后用 `sqlite3 <目录>/nekocalc.db ...` 查——sqlite3 打开时会自己并上 WAL。
#
#       前置：设备已连（`adb devices` 里是 `device`），且 **装的是 debug 包**——
#       release 包不是 debuggable，`run-as` 会直接失败（见 HANDOVER 第十九节）。
#
# English: **pulls the database off the device — all three files together.**
#
#          ⚠️ **The only reason this script exists is that I once missed `-wal` and read a stale value.**
#          This repository's rule reads "`nekocalc.db` + `-wal` + `-shm` must be pulled together; with one
#          missing it is not the same database", and I hand-wrote that pull a dozen times in one session —
#          **one of those times without `-wal`**. What came back was the correct *old* value, so I concluded
#          the app had written no result and wrote a measurement off as a failure.
#
#          **A hand-written pull drops a file; a script does not.** That is its entire content.
set -euo pipefail

OUT="${1:-/tmp/nekocalc-db}"
PKG=com.nekorain.nekocalc
ADB="${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb"

mkdir -p "$OUT"
rm -f "$OUT"/nekocalc.db "$OUT"/nekocalc.db-wal "$OUT"/nekocalc.db-shm

for f in nekocalc.db nekocalc.db-wal nekocalc.db-shm; do
  # 中文：`exec-out` 而不是 `shell`——后者会把二进制内容按文本改写，`-wal` 会烂掉。
  # English: `exec-out` rather than `shell` — the latter mangles binary content and the `-wal` comes back
  #          corrupted.
  "$ADB" exec-out "run-as $PKG cat databases/$f" > "$OUT/$f" 2>/dev/null || true
done

if [ ! -s "$OUT/nekocalc.db" ]; then
  echo "拉取失败：$OUT/nekocalc.db 是空的。" >&2
  echo "  · 包名对不对（${PKG}）？" >&2
  echo "  · 装的是不是 debug 包？release 包不是 debuggable，run-as 会失败。" >&2
  exit 1
fi

# 中文：**三个文件都报一行大小**——少了一个（0 字节）在屏幕上是看得见的，
#       而不是等到查出一个旧值才发现。
# English: **report all three sizes** — a missing one (0 bytes) is then visible on screen, instead of
#          surfacing later as a stale query result.
for f in nekocalc.db nekocalc.db-wal nekocalc.db-shm; do
  printf '  %-20s %8d bytes\n' "$f" "$(wc -c < "$OUT/$f" 2>/dev/null || echo 0)"
done
echo "已拉到 $OUT（sqlite3 打开时会自己并上 WAL）"
