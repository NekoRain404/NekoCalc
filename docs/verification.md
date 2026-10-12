# Verification — what is proven, how, and what is not

The long-form measurements, engine probe logs and hand-over narrative live in
`.superpowers/backup/` (gitignored). This file is the **committed** summary.

## 1. How each layer is proven

| Layer | Proven by | Where |
|---|---|---|
| Pure maths (base conversion, Roman numerals, prime factorisation, polynomial factoring, differentiation, arithmetic steps) | unit tests; expected values from an **independent implementation** (sympy / Python `hex` / the engine itself) | `test/core/math/*_test.dart` |
| Engine selection (which answer is taken, which is refused) | controller tests with stub engines returning **measured** engine strings | `test/domain/calculator_engine_*_test.dart` |
| On-screen behaviour of engine-backed features | **a real device** — `flutter test` cannot prove engine behaviour | `.superpowers/backup/engine-capability-probe.md` §6, §8 |
| Tool registration | guards: catalogue tables, name/description/field tables, two source whitelists | `test/features/tool_*_test.dart` |
| Tools reachable **on screen** | widget tests that open the tool and assert its output | `test/features/new_text_tools_screen_test.dart` |
| Accessibility labels | Flutter's `labeledTapTargetGuideline`, at device size | `test/features/calculator_accessibility_test.dart` |

## 2. Baselines (measured 2026-09-30; **all but one re-checked 2026-10-10**)

| Quantity | Value | Re-checked 2026-10-10 |
|---|---|---|
| Release APK, `--split-per-abi` arm64-v8a | 32.6 MB | **32.64 MB — unchanged** |
| Cold start `am start -W` | debug 1.75 s / **release 0.33 s** | **debug 1.75–1.76 s** (`1913 / 1761 / 1754` ms; the first is the run right after `force-stop`) and **release 0.32–0.34 s** (`336 / 338 / 319` ms) — both unchanged |
| Engine call, host, bridge's own sequence | first call 16 ms (lazy `loadGlobalDefinitions`), then 0.02–0.6 ms | not re-measured (a host-side sequence, not reachable from the device pass) |
| Memory, release, idle | TOTAL PSS 216 MB | **217,634 KB ≈ 212.5 MiB — unchanged** |

⚠️ **Re-check attempt 2026-10-11 (after this session's changes) — one row confirmed, two not obtainable.**
The **release** build was compiled for the first time since the work began (it is a different compile path —
asserts off, tree shaking), it **installs cleanly** over the existing 4009 release-signed build
(`pkgFlags` without `DEBUGGABLE`, same signature and versionCode, i.e. an ordinary replace), and the APK
re-measures at **32.70 MiB (34,289,489 bytes) against the 32.64 MiB baseline** — **+60 KB, unchanged for
practical purposes**, and the decimal-MB trap above was avoided by comparing MiB to MiB.

⚠️ **The cold-start row is NOT re-measured — and my first write-up of that fact was itself wrong.** I first
recorded "`WaitTime` and `TotalTime` are different quantities, so no comparison can be made". **That was an
inference, and it does not hold here**: this ROM's `am start -W` prints **only** `WaitTime`, so the baseline's
`336 / 338 / 319 ms` were almost certainly that same field — **which makes them comparable**, and the three runs
obtained today (`WaitTime` ≈ **3.03 s**: 3032 / 3022 / 3025) would mean a **~9× cold-start regression**.

⚠️ **Resolved 2026-10-11 by the decisive experiment: the reading is a measurement artefact, not a regression.**
The doubt was that `WaitTime` might not be the field the baseline recorded. The way to settle it is to measure a
build whose baseline is known and **very different**: the **debug** build's documented cold start is
`1913 / 1761 / 1754 ms` against release's `336 / 338 / 319 ms` — a 5× difference. So the debug variant was
rebuilt and installed (the scripted ordinary replace; `pkgFlags` with `DEBUGGABLE`, database intact) and measured
**the same way**:

| build | documented baseline | measured today |
|---|---|---|
| debug | `1913 / 1761 / 1754 ms` | `3030 / 3025 / 3024 ms` |
| release | `336 / 338 / 319 ms` | `3032 / 3025 / 3025 ms` |

**Two builds whose baselines differ fivefold both measure ≈3.03 s, to within 7 ms.** A number that is identical
across two builds that are five times apart in the documented record is **not a property of either build** — it is
a fixed ~3 s that the device is currently adding to every launch (the same "fixed wait" shape the uniformity
suggested from the start). ⇒ **No cold-start regression is established, and none of this session's changes is
implicated**; equally, the baseline comparison remains impossible on this device under these conditions. Both
builds' readings were reproducible across three runs each.

⚠️ **And the internal contradiction is explained by the same fact**: a release build slower than its debug
sibling was the signal that something outside the app was being measured. The reasoning recorded above ("this
session's changes do not explain it") was therefore correct, and it is now **confirmed by measurement** rather
than left as reasoning. (The device now carries the **debug** variant again, so the `run-as` channel is back.)

**The idle-memory row WAS obtained — and the same decisive experiment that settled the cold-start row REFUTES my
first guess about this one.** After a single `am start`, three readings bracketed the release build's steady
state: **96,580 KB at +8 s, then 99,854 KB at +45 s and 99,812 KB at +60 s** (the last two agree to 0.04 %, so it
really is idle). Release therefore idles at **≈ 99.8 MB PSS**, against its baseline's **217,634 KB ≈ 212.5 MiB**.

⚠️ **I first guessed this was "two different states, not a change" — the same explanation the cold-start row
turned out to have. The measurement says otherwise.** The debug variant was still installed from that experiment,
so it was measured identically:

| build | documented baseline | measured 2026-10-11 |
|---|---|---|
| release | `217,634 KB` ≈ 212.5 MiB | **≈ 99.8 MB** (96,580 → 99,854 → 99,812 KB) |
| debug | `400,259 KB` ≈ 391 MiB | **≈ 255 MiB** (256,696 → 261,600 KB) |

**The two builds measure differently, and in the documented direction** — today's debug is ≈2.6× today's release,
against a baseline ratio of ≈1.8×. In the cold-start case two builds five times apart measured *identically*
(⇒ an added constant); here the measurement **discriminates between builds**, so it is reading a real property
rather than an artefact. **My "different state" guess was wrong and is recorded as wrong.**

Both readings are nevertheless **below their own baselines** (by ≈2.1× and ≈1.5×), and **the cause is not
determined** — candidates are the ~1800 lines this session deleted and the device's own condition; settling it
would need the baselines re-taken on the same device in a controlled state. What is established: **neither build
regressed — both use less memory than the record shows** — and today's release steady state is a stable
**≈100 MB PSS** in its own right.

**And the question can be narrowed without the device — by checking what this session actually touched on the
startup path.** `lib/main.dart` was **not modified at all** in the whole stretch of work (0 commits touching it);
its one startup-time extra — `unawaited(runQalculateSmokeTest())` — is **deliberately not awaited**, and the
comment says why ("startup must not be held up by the engine"), so it cannot add launch latency. The only
startup-path file that changed is `lib/app.dart`, where `AppTheme.light/dark(base)` now derives from the selected
`CalcTheme` — and it does so **through the same `ColorScheme.fromSeed` the code already used before**
(the old literal was the `seedColor` argument), so no new work was introduced there either. **This session's
changes therefore do not explain a 3-second cold start**, which leaves the reading as either a measurement
artefact or a pre-existing condition — still to be settled on a responsive device, but no longer open against
this body of work. (The reasoning is recorded as reasoning: the measurement is what would settle it.)

⚠️ **One measurement is deliberately left out of that table**: the **debug** build's idle memory, measured at
**391 MiB (`400259` KB)** during the same pass. It is a **different build type**, so it is **not comparable to
the release `212.5 MiB`** and is recorded here only so nobody compares the two.

⚠️ **I first wrote here that the two release rows "were declined deliberately", and then measured them.** The
reasoning for declining was itself wrong, and the measurement is what refuted it: I assumed the device carried
the **debug** build, so a release install would need an uninstall and would cost the app's data. **It carried a
release-signed build all along** — a debug APK re-signed with the release keystore, which is what the device
recipe in `HANDOVER.md` produces. Verified by pulling the installed APK and reading its certificate:

```
installed base.apk : CN=NekoCalc, OU=NekoRain, ... SHA-256 bbb28c50…2d1007
my app-arm64-v8a-release.apk : CN=NekoCalc, OU=NekoRain, ... SHA-256 bbb28c50…2d1007   ← identical
```

**Same certificate ⇒ `adb install -r` replaces in place and keeps the data** (it also went `2009 → 4009`, an
upgrade, so no downgrade guard fires). Both release rows above come from that install.

⚠️ **`HANDOVER.md` is not in this repository** (noted 2026-10-12). The citations below — and seven more elsewhere:
four comments in `hiper_keypad_angle_matrix_row.dart`, two in `calculator_value_start_test.dart`, one each in
`calculator_page_test.dart` and `tool/pull_device_db.sh` — point at a file that is **neither tracked nor on
disk**. **The knowledge did not go with it**: what §十九 held is **re-derived and recorded in this section**
(from `:119` onward), and those code comments **quote their citation inline**, which is how a citation should
read anyway. ⚠️ **A pointer to a file that is gone is exactly the rot §5s tracks** — recorded here **once**
rather than rewritten in nine places, and deliberately **not** recreated: a second copy of the same knowledge
would put one sentence in two places, which is the thing this repository keeps refusing to do.

⚠️ **`HANDOVER.md` 不在这个仓库里**（2026-10-12 记）。下面这段引用，以及别处另外七处 ——
`hiper_keypad_angle_matrix_row.dart` 四条注释、`calculator_value_start_test.dart` 两处、
`calculator_page_test.dart` 与 `tool/pull_device_db.sh` 各一处 —— 指的是一份**既未入库、也不在磁盘上**的
文件。**知识并没有跟着丢**：§十九 记的那些，在**本节**被重新推导并逐条记下（`:119` 起）；而那些代码注释
**把引文直接写在旁边**，这本来就是引用该有的样子。⚠️ **指向一个已经不存在的文件，正是 §5s 在追的那种腐烂**
—— 在这里记**一次**，好过在九处各改一遍；也**故意不重造**那份文件：同一份知识放两个地方，正是这个仓库一直
拒绝做的事。


none of this is new.** `HANDOVER.md` **§十九** — whose heading is "read this before going onto the device" —
recorded the whole trap on **2026-09-30**: the `4009`/`2009` split, all three flags being refused, `run-as`
breaking, and the uninstall + byte-exact database restore it used to recover. **I re-derived it the hard way
because I went onto the device without reading that section**, which is precisely what its heading warns
against; the correction is recorded in §十九 too. Going back
to a debuggable build means installing `2009` over `4009`, and **both entry points refuse it**:

```
adb install -r -d …                  → INSTALL_FAILED_VERSION_DOWNGRADE: Downgrade detected: Update version code 2009 is older than current 4009
adb shell pm install -r -d --user 0 … → same
```

`-d` is documented as "debuggable packages only" and the APK **is** debuggable (verified: `CN=NekoCalc`,
`bbb28c50…`), so this is the ROM refusing the downgrade rather than the flag being omitted.

⚠️ **Consequence: `flutter run` / `flutter install` on this device is blocked while `4009` is installed.** It
builds the **debug** variant at `2009`, a downgrade from `4009`. **The channel itself was recovered, though —
without uninstalling and without touching data**, and the recipe is now a script: `tool/install_debug_over_release.sh`
(written *and run* on 2026-10-10). The move is to build the debug variant at the **installed** versionCode and
re-sign it with the release key, so it is an ordinary replace rather than a downgrade:

```
flutter build apk --debug --build-number=4009      # = the installed release's versionCode
zipalign -f -p 4 … && apksigner sign --ks android/nekocalc-release.jks --out … …
adb install -r …                                   # 4009 over 4009 — a normal replace
```

`--build-number` is what makes this work: it overrides the build number **without editing `pubspec.yaml`**.
Verified afterwards: `pkgFlags=[ DEBUGGABLE … ]`, `versionCode=4009`, and `run-as … ls databases` listing the
database again. **So §十九's "uninstall is the only way back" is true of the *flags* — `-r` / `-d` /
`pm install -r -d` really are all refused — but not of the *problem*.**

⚠️ **And the device's data was verified intact — by row content, not by eye.** Compared against the 2026-09-30
backup **with its `-wal` attached**:

| table | 2026-09-30 | 2026-10-10 |
|---|---|---|
| `calculation_history` | 16 rows, `d9b39a721cd9` | **same fingerprint** |
| `recent_tools` | 12 rows, `3d0427d30c87` | **same fingerprint** |
| `notes` / `favorite_tools` | 0 / 0 | same |
| `app_settings` | 24 rows | 24 rows, **every value identical** |

The only `app_settings` "difference" is a last-touched timestamp on rows whose values are unchanged
(`1790710793363 → 1791639353009` — a delta of exactly the 10.75 days that elapsed, written when the app was
launched for the cold-start runs). **The release install cost the user no data.**

⚠️ **Two comparisons were invalid before that one, and both are the trap this repo already documents.** (1)
Comparing the pulled copy **without its `-wal`** is the "少一个就不是同一份" rule. (2) Letting `sqlite3` **open**
the copy **checkpoints the WAL and deletes the `-wal`/`-shm`**, so the main file's bytes legitimately change (the
header's change counter moves) — which is why the comparison has to be **logical** (row content), not bytewise.

⚠️ **The `versionCode` split itself**: measured, the debug variant is `2009` and release is `4009`, while this
project's `build.gradle.kts` contains only `versionCode = flutter.versionCode` (grepped). So the `+2000` on
release comes from Flutter's own Gradle plugin — **not verified here**, and worth knowing before anyone changes
version numbers by hand.

⚠️ **And a trap that nearly produced a false regression.** The *same* arm64-v8a artifact reads **32.64 MB** from
`ls -l` (binary MiB — the unit this table uses) and **"34.2MB"** in Flutter's own build output (decimal MB,
34.2 × 10⁶ bytes). Comparing the build log against this table reports a **1.6 MB regression that does not
exist** — 34.2 × 10⁶ / 2²⁰ = 32.62. **Match the unit before matching the number.**

⚠️ **Baselines, not comparisons**: HiPER's own figures were not obtainable. (This line sat here **twice** —
a duplication left by a revision — and the tally below replaces both.) The tally, with the **failure mode** of
each, written down so nobody re-walks them:

| route | outcome |
|---|---|
| the Play Store page, direct | a **JS shell**; the figures are not in the served HTML |
| `WebSearch` | **session budget exhausted (200/200)** — re-confirmed by a live attempt on 2026-10-10, not a stale note |
| apkpure / apkcombo / apkmirror | 403 / 410 / 403 |
| the developer's site (`hipercalc.com`) | socket closed |
| a saved copy of the Play page | the same JS shell |
| **`web.archive.org`** (Wayback — the route that *would* have sidestepped the JS problem) | **"Claude Code is unable to fetch from web.archive.org"** — blocked by the fetch tool itself, so this is **not** a dead end that more effort fixes |

**What that leaves, and why it is enough.** The comparison that exists is by **capability**, not by vanity
metrics: **`docs/comparison-with-hiper.md`** §1's item-by-item table against HiPER's **own v12 manual**, where
「HiPER 有、我们没有」 no longer appears. (⚠️ That document lived only in the gitignored scratch directory until
**2026-10-12**, so this sentence was citing a file no reader of the repository could open — it is tracked now.)
**Install count, rating and APK size are not reachable from this environment** — and none of the three would
change what gets built. If they are wanted, they have to come from a source the user supplies.

## 3. Where this project is *more correct than the engine*

- `factor(x^2+2x+1)` — the engine hands the input back; this app returns `(x+1)²`.
- `roman(10000)` / `roman(-1)` / `roman(0)` — the engine returns `"10000"` / `"-I"` / the number `0`;
  this app refuses, because none has a canonical spelling.
- Step-by-step differentiation — the engine gives no derivation at all.

## 4. Where it is **below** the platform's own standard

`androidTapTargetGuideline` (every tappable ≥ 48 dp) fails in the places below. ⚠️ **This table was
re-measured on 2026-10-10** — the first row carried a number that reproduces at **no** screen size and a code
pointer to the wrong file, and the second row's owner is identified and fixed in the prose directly below it.

| Where | Measured (2026-10-10) | Code |
|---|---|---|
| Calculator keypad — the **label bands**, *not* "every row" | bands **9.8–18.8 dp** at the six sizes measured; keys **29.0–46.3 dp**, and **clearing 48 at 412×915** | geometry: `calculator_keypad.dart` (`_row`'s two `Expanded`, `_bandCell`, `_keyButton`). `hiper_keypad_function_rows.dart` is the row/label **table**, not the geometry |
| Structured tool detail — **two fixes, one measured refusal** (2026-10-10) | The **14 × `28×28`** copy buttons use the **whole card** as their target, and the input field's **`119×32`** editable area is fixed by **`isDense: false`** (its box was already 48 ⇒ no layout cost). The **12 × `34×34`** steppers **stay 34** — growing them to 48 was implemented, measured, and reverted: 24 of the 28dp came out of the app's single card-spacing standard, and the only standard-preserving route costs the field half its digit room (§5c) | `tool_detail_screen.dart`, `tool_widgets.dart` |
| Calculator display (status row) — **fixed 2026-10-10** | ☰ was **`40 × 40`**, `More...` **`111.7 × 34.0`** → both 48; display floor 176 → 182 dp | `display_status_row.dart` |

⚠️ **Only one of these is deliberately left unfixed:**

- **The keypad's label bands** — the keypad is **laid out to match HiPER** and raising either strip shoves the
  whole keypad around. (Corrected 2026-10-10: this used to say "the keypad's *rows*", and the rows are not what
  fails — the *bands* are, and the keys clear 48 at 412×915.)
- ⚠️ **The `36 × 36` — my first statement of this was wrong, and measuring the buttons themselves corrected
  it.** (Resolved: it was this project's own `IconToolButton`, 36 → 48, further down.) The `IconButton`s on the
  text-tool detail screen measure **48×48**, `BoxConstraints(unconstrained)`:

  ```
  BTN size=Size(48.0, 48.0) constraints=BoxConstraints(unconstrained)   (×3)
  ```

  So **the buttons are not 36 dp.** What `androidTapTargetGuideline` flagged as a `36×36` *semantics node*
  is therefore something else on that screen, and "the paste / clear / copy buttons are 36 dp" —
  which this file said one revision ago — **is withdrawn**.

  **And the "prime candidate" is dead too**: every `IconButton` on that screen was measured, not just the
  first three —

  ```
  BTN total=4        (nothing printed for "size != 48")
  ```

  **All four are 48×48**, including the `IconButton.filledTonal(iconSize: 18)` one. So **the `36×36` semantics
  node is not an `IconButton` at all**, and which widget owns it is **still unidentified**.

  **Two guesses had to be withdrawn** ("the buttons are 36 dp", then "it is the `iconSize: 18` one") before
  the tree itself named the owner — walking `find.byType(Semantics)` and printing the **ancestor chain** of
  every node under 48 dp gave it in one run:

  ```
  NODE size=Size(36.0, 36.0)
    chain = _OverlayPortal < OverlayPortal < RawTooltip < Tooltip < **IconToolButton** < Row < …
  ```

  **`IconToolButton` is this project's own widget**, not a Flutter one — which is exactly why grepping for
  `IconButton` kept coming up empty. And its cause is one hard-coded number
  (`lib/shared/presentation/app_chrome.dart:64`):

  ```dart
  width: 36,
  ```

  **So the root cause was a shared chrome widget pinning its box to 36 dp — and it is now fixed.** The
  `InkWell` is wrapped in a `SizedBox(48, 48)` + `Center`, giving **a 48 dp tap target around the unchanged
  36 dp visual**. Verified two ways:

  - `androidTapTargetGuideline` on that screen: **passes** (it was `36 × 36` before);
  - the full suite: **1806 pass** — so the footprint change (36 → 48) broke **no** layout guard.

  **This fixes every `IconToolButton` in the app at once**, which is why it was worth measuring rather than
  guessing: two guesses about which *Flutter* widget was at fault cost budget, and the run that printed the
  ancestor chain named the project's own widget in one probe.

  **The transferable part**: two guesses were wrong and cost budget; the run that printed the ancestor chain
  cost one probe and was right. **When a measurement can name the owner, take that instead of guessing the
  class.**

`labeledTapTargetGuideline` passes on the screens measured so far — **four unnamed buttons were found
and fixed**: the keypad's figure-faced `[matrix]` key (no text for `InkWell` to derive from; see
`calculator_keypad.dart`'s `_variantFace`), the tools home's search button, and the category screen's
back + search buttons (`IconButton` with no `tooltip`). A repo-wide scan for "`IconButton` with no
`tooltip`" now comes back clean.

⚠️ **"Not yet measured" — now measured, and the harness problem was solved without touching the screen.**
This paragraph used to say the structured **tool detail screen** and the settings screen were unmeasured;
adding the former to `calculator_accessibility_test.dart` hit a **layout assertion** (the screen overflows at
that test's 360×800 surface), which is a harness problem, not a finding. **2026-10-10: measured by pumping the
screen at 360 × 2200 dp instead** — which is a harness change, not a screen change, and is exactly what the
distinction in the sentence above is for. What that walk found is in the table above and in §5c (the three
sub-48 classes, named by tooltip). Also re-measured the same day:

- **Text-tool detail: zero sub-48 tappables** (its tappables are `48×48` ×6, `76×48` ×4, `328×172` ×1) —
  **independent corroboration of the `IconToolButton` fix** recorded further up.
- **`labeledTapTargetGuideline` passes on the structured screen** — so the ✓ that the audit table gives it
  under *labels* is correct, and the `119 × 32` field's three empty semantics strings (label, value, tooltip)
  are **not** a labelling defect. **I nearly recorded them as one**; the guideline check is what stopped it.

Numbers in `docs/comparison-with-hiper.md` §11 (⚠️ this second reference was **missed** when the
document was recovered on 2026-10-12 — it still pointed into the gitignored scratch directory, which
left the same file at two addresses; both references now name the tracked copy).

## 5. What is **not** verified

- HiPER's own figures (size, version, memory) — seven sources tried, all blocked.
- Appearance / interaction versus HiPER — nothing measured.
- Device-side **pure** evaluation latency — the end-to-end path is measured, the evaluation alone is not.
  ⚠️ **And the "decision-relevant part" this bullet used to assert — "the controller's `engineTimeout` is
  5 s and a mid-weight symbolic sum exceeds it" — still has no witness.** A host-side probe on 2026-10-10
  could not reproduce it: with the engine's own argument order (**the variable goes last**), every symbolic
  sum tried **evaluates**, in **0.2–7.9 ms** — the heaviest (`sum(1/n^s, 1, 200, n)`) is ~630× under the 5 s
  budget. The control `sum(x,1,10,x)` returns **`55`** in both approximation modes, which is the value this
  repository's own `calculator_key_dispatch.dart` records for the `Σ` key. So the claim is **not refuted** —
  it simply **never named its witness**, and nothing in the shape its wording suggests comes near it.
  §5e is that probe; §2 is the engine-latency baseline that *is* measured.

  ⚠️ **This bullet carried a false generalisation for one revision, and the cause was my instrument.** The
  first version ran `sum(expr, n, lower, upper)` — the variable in the **middle** — so every case came back
  **unevaluated**, and it was written up as "the engine does not compute it", i.e. as a property of the
  engine. **It was a property of my argument order.** Caught by the app's own comment
  (`calculator_key_dispatch.dart`: 「`sum(x,1,10,x)`=55」) and re-run with the variable last — and that `55`
  is the control that proves the corrected order is the right one.
- Camera / natural-language input — not implemented (engineering scale, not a defect).

## 5b. The tool detail screen's overflow — **found, explained, and fixed**

`DetailMetric`'s content (label + value + unit) was **12 px taller than its grid cell**, at **every** phone
size tested (360×640 / 360×800 / 411×731 / 412×915):

```
A RenderFlex overflowed by 12 pixels on the bottom.
Column ← Padding ← DecoratedBox ← Container ← DetailMetric
```

⚠️ **Why it survived so long**: a **release** build does not paint the yellow/black stripes — it **clips
silently**, so the content was quietly cut rather than loudly wrong.

**Fixed** by `childAspectRatio: 1.55 → 1.35` (`tool_detail_screen.dart`), measured at all four sizes: 360 dp
gives a 160 dp-wide cell, 1.55 gives 103 dp (12 px short) and 1.35 gives 118 dp.

### The four guards that "blocked" it were tolerating it on purpose

Each of the four layout guards carried

```dart
expect(knownOverflows, greaterThan(0),
    reason: '那条已知溢出一条都没出现——溢出没了要么是好事（那就把这段拆掉），要么是这屏根本没渲染出来');
```

— i.e. they **required the overflow to be present**. Fixing it made all four red **by design**, and their own
sentence said what to do. All four now read `greaterThanOrEqualTo(0)`, with `others` (the "no *new* exception"
half) left in place.

### ⚠️ And I spent a long detour misreading one of them

I attributed the failures to the **`boxes`** assertion (`一格的单行结果标签都没找到`) and hunted that — six
hypotheses, all ruled out by probes that kept finding the cells. **The actual failing assertion was the
`knownOverflows` one, in the same test.** `boxes` came from a *different, earlier* run whose message I carried
forward without re-reading.

**The lesson is cheap and general**: when a test file has several assertions, **read the one that failed** —
not the first one in the file. Six probes' worth of budget went into a sentence I had mis-attributed.

## 5c. A second tap-target gap, on the **structured** tool detail screen (open)

With the `IconToolButton` fix in (§4), the **text**-tool detail screen passes `androidTapTargetGuideline`.
The **structured** tool screen (`ToolDetailScreen`, e.g. `battery_life`) **does not** — it reports many nodes
of **`34 × 34`**.

Walking the `Semantics` nodes (the method that named `IconToolButton`) finds owners of **40 × 40** and
**24 × 24**, but **not** the `34 × 34` ones:

```
N34 40.0x40.0: _OverlayPortal < OverlayPortal < RawTooltip < Tooltip < DefaultTextStyle
N34 40.0x40.0: Listener < _ExclusiveMouseRegion < Semantics < _OverlayPortal < …
N34 24.0x24.0: Align < Padding < Listener < RawGestureDetector < GestureDetector
N34 24.0x24.0: Icon < Semantics < Align < Padding < Listener < …
```

**⚠️ And that sentence was itself wrong — the `34 × 34` nodes do exist, 60 of them.** A census of **every**
semantics node's size on that screen:

```
34x34:60   28x28:70   48x48:37   18x18:36   16x16:28   40x40:24   24x24:11   …
```

`34 × 34: 60` — **sixty nodes**. My ancestor-chain probe *had* been printing them; **my `head -6` cut the output
off before it got there.** So "the owner is unidentified" was **my instrument's fault, not the tree's** — the
same family as the two earlier wrong guesses on this item, and worth recording for that reason:

> **When a probe says "not found", check that the probe printed everything before believing it.**

⚠️ **"The owner has been found" — and that sentence named ONE owner for TWO different populations. Corrected
2026-10-10 by measuring, not by reading.** The semantics walk on `battery_life` (360 × 2200 dp) gives the whole
sub-48 tappable population on that screen, **named by tooltip**:

| size | count | owner (measured — tooltip + ancestor chain from the render tree) |
|---|---|---|
| `28 × 28` | 14 | `DetailMetric`'s copy button — tooltip **`复制此项`** (`tool_widgets.dart`'s `SizedBox(28, 28)` ✓) |
| `34 × 34` | 12 | **`_stepButton`** — tooltips **`增大` / `减小`** (`tool_detail_screen.dart:512`, `SizedBox(34, 34)`) |
| `119 × 32` | 1 | the numeric **`TextField`** — label, value **and** tooltip all empty (see the ⚠️ below) |

**So the `34 × 34` nodes were never the copy button.** They are the **stepper buttons on the input rows**
(`[label][−][field][+]`), a **third** sub-48 class this section had not recorded at all; the copy button is the
`28 × 28` one. The earlier census's 60/70 counts came from a **different viewport** — the *sizes* are what name
the owners, and both were read off the render tree this time.

⚠️ **And the `119 × 32` field is emphatically *not* a labelling defect** — which I checked because the obvious
inference from "label empty, value empty, tooltip empty" is "a screen reader announces nothing". **Measured:
`labeledTapTargetGuideline` PASSES on this screen.** So the ✓ this table gives that screen under *labels* is
correct, and the three empties are recorded here **only** so the next reader does not re-derive the defect I
nearly recorded. (An empty `value` is also just what an empty input looks like.)

⚠️ **And as of 2026-10-10 it is not a tap-target defect either.** That `119 × 32` node is the field's
**editable area** — a *child* of a render box that was **already 118.86 × 48.00** — so "make the field 48 tall"
was the wrong question (I asked it first, and the measurement said no). `isDense: false` lets the editable area
fill that existing 48, and it **costs no layout**: the box and the row height measure identical before and
after. The screen's sub-48 tappable count goes **1 → 0**, and `tool_detail_screen.dart` now carries a note at
that line saying why it must stay `false` — the next reader's instinct will be to tighten it back.

**And enlarging the copy button to 48 dp was tried, and reverted** — it reddens **the same four layout guards**
the aspect-ratio change did, i.e. **it re-introduces the overflow this file just had fixed** (the label row grows
by 20 dp and the cell can no longer hold its content). The width half of that coupling is measured further down:
the label box is **exactly 110.00 dp** and the longest English label needs **109.1 dp**.

⚠️ **So the two gaps are coupled, and neither can be fixed alone**:

| Want | Cost |
|---|---|
| cell holds its content (no overflow) | needs a **shorter** cell or **taller** rows |
| copy button at 48 dp | makes the row **20 dp taller** ⇒ overflow returns |

**Fixing both means changing the cell's proportions *and* the button together, then re-deriving the four
guards' numbers.** That is one coherent piece of work, and it is written down as such rather than attempted
in halves — **which is exactly what happened here: the half was attempted and reverted.**

**And the number the coupled fix has to absorb is now measured**: with the copy button at 48 dp the cell
overflows **by 16 pixels** (not 12):

```
详情页上出现了这条已知溢出之外的异常：A RenderFlex overflowed by 16 pixels on the bottom.
```

⚠️ **Why that reddens those four guards while a 12 px overflow did not**: `_DetailErrors._collect` tolerates
one **exact** string — `'A RenderFlex overflowed by 12 pixels on the bottom'` **and** `DetailMetric` in the
information. A **16 px** overflow matches neither, so it lands in `others`, and `expect(others, isEmpty)`
goes red. **The tolerance is a literal, not a rule** — which is worth knowing before "fixing" it.

**So the coupled change was attempted in full** (button 48 dp **and** `childAspectRatio` 1.35 → 1.15) — and
**it works for the overflow**: the failure becomes a single sentence from a guard,

```
标签那一格实测 90.0dp，与记下的 110.0 dp 不同——布局动过，下面按这个宽度算的判据就都不成立了
```

**110.0 − 90.0 = exactly 20.0** — the 20 dp the copy button grew. So the mechanism is confirmed to the dp:
**the button takes its width out of the label's cell.**

**And that is the third consequence, the one that makes this more than a parameter change.** Those label
guards exist to guarantee that **English labels are not truncated**; a 90 dp cell is 20 dp narrower than the
one that guarantee was measured against (the widest label, `Speed for tgt speed`, is **109.1 dp** — wider than
90). So shrinking the cell to buy the button its tap target **buys it with truncated English labels**.

⚠️ **Which means the naive coupled fix is not available**: it trades one accessibility gap (a 28 dp button) for
another (truncated labels), and the second would need many labels re-abbreviated. **The real options are
structural** — put the copy button *below* or *over* the value instead of beside the label, or accept the
28 dp button. **Both are design calls, and this file now carries the numbers for either.**

### ✅ 2026-10-10: the copy button is **fixed** — the structural option was taken

The paragraph above lists the structural options and says taking one is a design call. **One was taken**: the
`IconButton` was demoted to decoration (its own `onTap` dropped, the icon kept) and the **whole card** wrapped
in `Tooltip` + `InkWell`. Measured on the structured screen (`battery_life`, 360 × 2200 dp):

| quantity | before | after |
|---|---|---|
| the tappable node | **28 × 28** | **160 × 119** (the whole card) |
| the label box | **110.00 dp** | **110.00 dp — unchanged** |
| sub-48 tappable nodes on that screen | **27** | **13** (12 steppers + 1 input field) |
| `labeledTapTargetGuideline` | passes | **passes** (the name now comes from the wrapping `Tooltip`) |

**So this one did not trade — it resolved.** The target grew ~40× in area and the label gave up **nothing**,
because the icon stayed (as the affordance) and only its *role* changed. That is exactly why "over/around the
card" was listed: it is the only one of the options that costs no width.

⚠️ **It is the `110.00` being identical before and after that makes this a resolution rather than a lucky
escape** — that box is the denominator of the 715-string English criterion, so anything that moved it would
have been a trade in disguise. It was measured, not assumed: the icon's 28dp still occupies that row.

⚠️ **What the change costs**: interaction semantics — tapping anywhere on a card copies it. On this screen a
card has exactly one action, so nothing is displaced. Full suite after: **1807 green**.

### ⚠️ The steppers are the **second** instance of the same coupling — and I predicted it wrong

The other 12 sub-48 nodes on that screen are the **input-row steppers** (`增大` / `减小`, 6 rows × 2). They were
tried at 48 dp on 2026-10-10 and **reverted**, because:

| what | 34dp | 48dp | delta |
|---|---|---|---|
| the row height | 48.0 | 48.0 | **0** |
| the input field | 118.9dp | 102.9dp | **−16.0** |
| the label cell | **89.142857dp** | 77.142857dp | **−12.0** |

**The height is free** — that row's height comes from the `TextField` (already 48), so 34 → 48 costs nothing
vertically. The 28dp of width is split by the two `Expanded`s (`flex: 3` label / `flex: 4` field) as
3/7 × 28 = 12.0 and 4/7 × 28 = 16.0 — matching the table to the digit.

⚠️ **And the 12dp is the whole argument.** The label cell's width is the **denominator** of the English
line criterion in `tool_field_strings_test.dart`
(`_lines = (advance / labelBox).ceil()`, cap **2 lines**). Re-run it with the measured 77.14 and **a screenful
of English labels cross it** — `op_amp_gain.vin` "Input voltage" 84.0dp, `ldo_power.current` "Load current"
81.7dp, `capacitor_charge.c` "Capacitance" 80.3dp, `complex.b` "z1 imag part" 80.7dp, `circle.circumference`
"Circumference" 161.1dp (3 lines), `op_amp_gain.fullPowerFrequency` "Full-power BW" 158.9dp (3 lines) — **a
dozen or more.**

⚠️ **My hypothesis was that this one would be *softer* than the copy button** — this cell's label **wraps**
(no `maxLines: 1`), and wrapping beats truncation. **Measured, it is not softer at all**: the cell width *is*
the criterion's denominator, so narrowing it 12dp tightens the criterion by 12dp. **Same class of coupling,
different symptom** — truncation there, an exceeded line count here. That is worth writing down precisely
because the *prediction* was the error, not the arithmetic.

**And the `IconToolButton` pattern does not buy its way out here**: splitting it into a "34dp visual + 48dp hit
area" saves the *visual*, not the *layout width* — the box is still 48 and the 28dp is still paid. The only
change that actually keeps the width is giving the steppers **their own row**, which is a design change rather
than a parameter. The numbers are in `_stepButton`'s comment in `tool_detail_screen.dart`.

### ❌ 2026-10-10: the steppers were grown to 48, then **reverted the same day** — consistency outranks them

Every route above spends *text* width. **A route that spends none was found and did work.** A row's **34dp per
side is measured** as page **16** + the `Card`'s margin **4** + the card's `padding` **14**, so reclaiming the
last two plus one gap (`margin: EdgeInsets.zero`, `padding: all(6)`, and the `SizedBox` between the label and
the first stepper **8 → 4**) returned exactly **28dp** — matching the steppers' growth (34 → 48) to the digit.
The flexible space stayed **208** and the text did not move (the steppers really did measure **48.0 × 48.0**, and
the label cell stayed **89.142857 dp**).

**It was reverted because of where those 28dp came from: 24 of them were the app's single card standard.**
`margin 4 → 0` and `padding 14 → 6` is the *only* card in the app that is not `padding: all(14)` + the default
margin (ten `Card` sites measured identical), and the other 4dp came out of a row gap — so the input card became
**the app's one exception to its own spacing rule**, on a screen whose whole job is to look like the rest of the
app. The user's priority is UI consistency, so the exception is not worth 14dp of hit area.

**The one other route that keeps the standard was measured too**: change the row's flex from **3 : 4** to
**1 : 1** — no card is touched, but the field's room for digits drops from about **41dp to 22dp**. That is a real
input defect for a numeric field, so it is out as well.

**Adopted instead: nothing on the steppers; the field's `isDense: false` stays.** That fix costs no layout at all
(its box was already 48 — only the *editable area* was 32), so it is not an exception to anything.

| quantity | value | note |
|---|---|---|
| the steppers | **34 × 34** | unchanged from the start; sub-48 by choice, with the three routes above measured |
| the input field's editable area | **48.0** ✓ | `isDense: false` — **kept**, zero layout cost |
| sub-48 tappable nodes on that screen | **12** | all twelve are the steppers; the field is no longer among them |

⚠️ **A variant that was reverted: reclaim only 20dp — and it costs exactly three English labels.** A row's **34dp per side is measured** as
page **16** + the `Card`'s margin **4** + the card's `padding` **14** (`CARD w=328 left=16`,
`PAD14 w=320 left=20`). Reclaiming the last two (`margin → 0`, `padding → 8`) returns **20dp**, so only the
remaining **8dp** comes out of the text (label : field = 3 : 4):

| what | as it stands | reclaimed + steppers at 48 |
|---|---|---|
| the steppers | 34 × 34 | **48.0 × 48.0** ✓ |
| sub-48 tap targets on that screen | **13** | **1** (the input field alone) ✓ |
| the input field | 118.86 | 114.29 (**−4.57**) |
| the label cell | 89.142857 | **85.714286** (**−3.43**) |

⚠️ **And the price is exactly three English labels.** With `labelBox = 85.714286` the line criterion reports
**exactly three** crossings — `wire_voltage_drop.parallel` "Parallel wires" (86.7dp), `npv.rate` "Discount
rate" (86.2dp), `work_power.distance` "Displacement" (88.4dp); each one's Chinese fits a single line, so its
English is allowed one. **So the reclaim is a trade as well** — unless the padding goes to 4 (visually
cramped), those three are allowed to wrap, or the tightening is generalised to every card on the screen.
**The route was tried in full and reverted** (byte-exact; suite green after).

**Where the audit stands** (a dimension with **zero** coverage before this work). ⚠️ **Two rows of this table
were re-measured and rewritten on 2026-10-10** — the keypad row carried a number that reproduces at no
screen size, and the structured row attributed its nodes to the wrong widget. Both corrections are in §5c.

| Screen | labels | tap targets |
|---|---|---|
| Calculator keypad | ✓ | **✗ label bands only**: bands are 9.8–18.8 dp at the six sizes measured and always fail; the **keys** are 29.0–46.3 dp and **clear 48 at 412×915**. HiPER-parity mechanism (§5c) |
| Calculator display (status row) | ✓ | **fixed 2026-10-10**: ☰ was **40 × 40** and `More...` **111.7 × 34.0** → both 48 (display floor 176 → 182 dp) |
| Tools home | ✓ (fixed) | **fixed 2026-10-10**: the one tappable section header (`收藏工具`) was **29 dp** (§5d) |
| Tool category | ✓ (fixed) | same fix — shared `SectionHeader` |
| Text tool detail | ✓ | ✓ (after the `IconToolButton` fix) |
| Structured tool detail | ✓ | **two fixes + one refusal** (2026-10-10): the 14 × **`28×28`** copy buttons (target = the whole card), and the input field's **`119×32`** editable area (**`isDense: false`** — its box was already 48 tall, so this cost no layout). The 12 × **`34×34`** steppers **were grown to 48 and reverted** — that route required 24dp from the app's single card-spacing rule (§5c). **`SUB48 = 12` on that screen now, all twelve being steppers** |
| Settings | ✓ | ✓ |

⚠️ **The same "reclaim the whitespace" question the steppers were fixed with (§5c), asked of the keypad, comes
back negative — and quantified.** The keypad's own padding is `_panelPadding = 6` (**12dp** of vertical
whitespace) plus `_cellInsets = all(1.5)` (**3dp** per row group), and its band/key split is a
`_bandFlex : _mainFlex = 2 : 5` flex inside each row group. Measured, a band is **15.0dp** at 360×800 and there
are **~6 band rows**; bringing each band to 48 needs **+33dp** ⇒ roughly **198dp** of extra height, against
roughly **30dp** of reclaimable padding — **short by a factor of about 6.6**. The keys are short as well
(29.0–46.3dp, each needing between +2 and +19dp).
*(The constants and the heights are measured; the shortfall is arithmetic on them — stated as arithmetic, since
a deduced limit is what hid the steppers' route for a while.)*
**So the keypad is a structural trade, not a whitespace question** — which is what "raising them shoves the whole
keypad around" meant, now with numbers.

### 5d. The two list screens: a **section header** is 29 dp — ⚠️ **and my first reading of this was wrong**

`androidTapTargetGuideline` on both the tools home and the category screen reports the same shape:

```
expected tap target size of at least Size(48.0, 48.0), but found Size(328.0, 29.0)
```

**I first wrote that `328 × 29` was "the tool list item, the app's main navigation target". That was an
inference, and it is wrong.** Walking the **semantics tree** (not the widget tree — that was the previous
probe's mistake) names the nodes directly:

```
SEM 328x29 actions=0       label=推荐工具
SEM 328x29 actions=4194305 label=收藏工具
SEM 328x29 actions=0       label=分类
SEMTOTAL 6
```

**They are section headers**, and only **`收藏工具`** carries a tap action — the other two have `actions=0`.
So the finding is **one tappable section header at 29 dp**, not "every row in the app's main list".

**And the tool rows themselves are not implicated at all**: `ToolListTile` is a `ListTile`, and its own file
comment records a **minimum of 88 dp** in search mode. Nothing here is 29 dp except the headers.

⚠️ **Three corrections of this kind in one day** (`knownOverflows` misread as `boxes`; "the buttons are 36 dp";
now "the rows are 29 dp"). The common shape is the same each time: **an inference about what a measurement was
of, where the measurement was available and I did not take it.** The semantics-tree walk — the instrument the
previous entry said to use — cost one probe and was right.

**Recorded, then fixed (2026-10-10)**: one tappable section header was 29 dp, and it was indeed the small, local
fix the next sentence predicted — **not** a proportions decision about the list, which is what I wrongly told
the reader one revision ago. The fix is a `ConstrainedBox(minHeight: 48)` around the `InkWell`'s child in
`SectionHeader` (`app_chrome.dart`), and it was verified **single-variable**: toggling that one `minHeight`
between **0 and 48** — same screen, same probe, nothing else touched — took the guideline from
`expected tap target size of at least Size(48.0, 48.0), but found Size(328.0, 29.0)` to **pass**. So the node is
provably that one. ⚠️ **A synthetic
reconstruction of the same shape is a false negative** — I built one and it *passed* the guideline, so this
class of question has to be measured on the real screen.

⚠️ **And "the text does not move a pixel" — which this section said when it was first written — is itself
wrong.** Caught the same day by re-reading my own commit rather than by any test. `minHeight` alone leaves the
row a `Row(crossAxisAlignment: center)`, so raising it 29 → 48 **centred the title** (down ≈ 9.5dp) while the
**action's text stayed pinned to the top of its stretched box** (up ≈ 3.5dp) — leaving the two texts ≈ 13dp
apart. Measured on the tools home:

| what | after the first attempt |
|---|---|
| the row | `265.0..313.0` (h **48.0**) |
| the title cell | `274.5..303.5` (h 29.0 — centred) |
| the action `Text` | `265.0..305.0` (h **40.0** — stretched by `minHeight`, text at the top) |

The repair: `Center` the action's text in that 48dp band (the same centring the title gets) and drop the 8dp of
bottom padding, which was written for the old 29dp geometry. Alignment then measures **Δcenters = 0.00** and
the guideline still passes (1807 green after).

⚠️ **The generalisable part**: raising one cell of a **centre-aligned** row does not only change that cell's
box — every other cell in the row re-centres. **"The extra height goes below it" is not true in a
centre-aligned row**, and that is exactly the sentence I wrote first.

### 5e. The engine's indefinite integral of a numeric power returns **±infinity** — measured

Probing host-side (`tool/qalculate_semantics_probe/`, libqalculate **5.12.0** — the same version this AAR
bundles) through the same `Calculator::calculate` the bridge enters, with the bridge's own options
(`QalculateOptions.kt`: `allow_complex`, `mixed_units_conversion = NONE`, `angle_unit = RADIANS`,
`comma_as_separator = false`), and **in both approximation modes**, because the app takes two paths
(`APPROXIMATION_EXACT` for the exact form, `APPROXIMATE` for the decimal one):

| input | `APPROXIMATE` | `EXACT` |
|---|---|---|
| `integrate(x^3, x)` | **`-infinity`** | **`-infinity`** |
| `integrate(x^2, x)` | **`+infinity`** | **`+infinity`** |
| `integrate(x^3, 0, 1, x)` | `0.25` ✓ | `0.25` ✓ |
| `integrate(x^2, 0, 1, x)` | `0.3333333333333333` ✓ | same ✓ |
| `integrate(x^n, x)` | `(x * x^n - x * x^n) / (n + 1)` | same |
| **control** `sin(1)` | `0.8414709848078965` | **`sin(1 rad)`** |

**The definite integral is right; the indefinite one is not.** `∫x³dx = x⁴/4`, and the engine answers
`-infinity`. And `integrate(x^n, x)` prints a numerator whose two terms are **textually identical**
(`x·x^n − x·x^n`), which **reads as 0**.

⚠️ **The control row is what makes this trustworthy**: `sin(1)` differs between the two modes exactly as the
app's two-path design requires, so "both modes agree on ±infinity" is a real agreement — not two modes that
were silently the same object.

⚠️ **How far this reaches into the app — carried as far as the repository allows, and no further.**

- **The keypad never produces the indefinite form.** `∫dx` inserts `integrate(x^2,0,1,x)`
  (`calculator_key_dispatch.dart:387`, `case 'ins:integrate'`) — **with bounds** — and that is the branch the
  engine answers **correctly** (`1/3`). So the **key-driven path is safe.**
- ⚠️ **Measured — and it refutes the inference that stood here.** Feeding a stubbed `MathEngine` a reply of
  exactly the shape the host probe says the engine produces (`displayText` / `displayTex` = `±infinity`,
  `decimalText` empty, two different non-quantity kinds) and submitting `integrate(x^3, x)`, a domain-level
  probe found:

  ```
  engineCalls=1   result="函数需要括号"   hasError=true   submitted=false     (×4: ±infinity × 2 kinds)
  ```

  - **`engineCalls=1`** — the engine **was** consulted.
  - **The screen does not carry `-infinity`**: what reaches the user is the legacy parser's message
    (`函数需要括号`, "the function needs brackets").

  So the sentence this replaces — "route 3 returns the engine's text as it stands ⇒ the screen would carry
  `-infinity`" — **is not how it goes. The app does not show it.**

- ⚠️ **And the previous revision's wording over-claimed in turn.** It said "the reply is **rejected before
  display**" — **that is an inference, not what was measured.** What was measured is the four-column line
  above. At least two readings fit it, and nothing measured yet separates them:
  (i) the reply was offered and refused somewhere between the engine and the screen; or
  (ii) the counter's single call came from the **live / as-you-type** path, while the **submit** path never
  used the engine at all (e.g. the translation refused this expression) — in which case the reply was never
  a candidate for display.

  Separating them means following the submit path (which call site the counter saw); getting the *real*
  reply's shape means reproducing the bridge's own print options on the host (`QalculateResultPrints.kt`)
  or reading the bridge off the device.

  **Left here deliberately**: the practically-live facts are established (the engine's behaviour is measured
  above; the key-driven path inserts the definite form and is safe; the app does not display `-infinity`),
  and what is left is a question about a **hand-typed** indefinite integral. The next layer of digging should
  be a deliberate choice, not a reflex — this thread has already had six of its own claims corrected today,
  and the errors were all in the *attributions*, never in the numbers.

- ⚠️ **What is still not established: whether a *real* bridge reply has this shape.** The reply above was
  **synthetic** (its `displayTex` is not valid LaTeX, and a real `resultKind` comes from the Kotlin
  classifier), so the *reason* for the rejection is unknown — a gate on the reply's shape, the `-infinity`
  spelling itself, or the stub being malformed. Settling that needs the real reply (the device's zero-touch
  channel, or a JVM test of the bridge).

**Reproducing the measurement**: `lib/core/math/math_engine.dart` is an interface, so a domain-level test can
carry its own `_FakeMathEngine implements MathEngine`, build the controller, call `setExpression(...)`,
`await controller.submit()`, and read `controller.result` / `hasError` — see `quantity_decimal_places_test.dart`
for the shape. **Add a call counter to the fake**: without it, "the screen says the function needs brackets"
has two very different readings (the engine answered and the display rewrote it, versus the expression never
reaching the engine).

### 5f. The portrait lock (禁止屏幕旋转) — **declared and merged ✓; the device-side rotation test could not be run**

The requirement is "no screen rotation". Two lines implement it, in `AndroidManifest.xml`:

```xml
<activity android:name=".MainActivity" android:screenOrientation="portrait" …>
    <property android:name="android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY"
              android:value="true" />
```

**Why two and not one.** `targetSdk` is **36** (it follows `flutter.targetSdkVersion`, which Flutter 3.44
resolves to 36 — confirmed by reading `FlutterExtension.kt`, and by the installed package reporting
`targetSdk=36`). Android's behaviour-changes page for API 36 states that for apps targeting 36 the system
**ignores** `screenOrientation`, `resizeableActivity`, `minAspectRatio`/`maxAspectRatio` and
`setRequestedOrientation()` on displays with **smallest width ≥ 600dp** — with `portrait`, `reversePortrait`,
`sensorPortrait` and `userPortrait` named explicitly in the ignored list. The documented opt-out is the
`<property>` above, declared as a child of the **activity** (per-activity form; an `<application>`-level form
also exists). **Worth knowing for later: the opt-out itself expires** — the same page says it will not apply
when targeting **API 37**, so the day `flutter.targetSdkVersion` becomes 37 this lock silently stops working on
tablets and foldables. Phones are unaffected either way, because `sw < 600dp` is an explicit exception to the
whole change. That is also why the plain attribute alone is sufficient on a phone.

**What is verified — mechanically, from the build product rather than from the source**: the merge kept both.
`aapt2 dump xmltree --file AndroidManifest.xml build/app/outputs/flutter-apk/app-debug.apk` gives

```
E: activity (line=31)
  A: …android:screenOrientation(0x0101001e)=1        ← enum 1 = portrait
    E: property (line=69)
      A: …android:name="android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY"
      A: …android:value=true
```

and the app launches and runs with it (window measured at `[0,0][1440,3200]`, i.e. the full portrait display).
Checking the **merged** manifest matters here: the property is an unusual element, and a source-level check
would not have shown whether the merge dropped it.

⚠️ **What is NOT verified: that the app actually refuses a rotation — because this device would not rotate.**
Five routes were tried, all of which left `mCurrentRotation=ROTATION_0`:

| route | result |
|---|---|
| `settings put system accelerometer_rotation 0` + `user_rotation 1` | writes confirmed by `settings get` (0, 1), display unmoved |
| `cmd window user-rotation lock 1` | no output, display unmoved |
| `wm user-rotation lock 1` (syntax confirmed via `wm help`) | display unmoved |
| screen power cycle (`input keyevent 26` ×2) to force a re-apply | display unmoved |
| relaunching the activity while the rotation was locked | window `[0,0][1440,3200]`, display still portrait |

So there was **no rotation to resist**, and this measurement cannot answer the question on this hardware/ROM
(rotation appears to be governed by MIUI, which also runs a cover-screen UI, `com.xiaomi.misubscreenui`). All
device settings were restored afterwards (`accelerometer_rotation=1`, `user_rotation=0`). The declaration is
correct per the platform documentation and is present in the installed APK; the on-device *behaviour* is
**untested**, and the untested part is precisely the tablet path, since this device reports **sw = 411dp**
(1440 × 3200 at 560 dpi) and is therefore outside the Android-16 change altogether.

### 5g. UI consistency: a role-based audit of every hard-coded inset and radius (2026-10-10)

**Method.** Rather than arguing about "there are too many different values", every `EdgeInsets.all(N)` and
`BorderRadius.circular(N)` in `lib/` was listed with its **role** — what widget it sits in, and whether that
widget is a top-level surface or nested inside another one. The question is not *how many values exist* but
*does the same role use the same value*.

**Two standards came out real**, both already majority-held:

| standard | uses | what it is |
|---|---|---|
| `EdgeInsets.all(14)` | 16 | the card-content inset — in two spellings that already agree: `Card > Padding(all(14))` and `Container(padding: all(14), decoration: softPanel(...))` |
| `BorderRadius.circular(8)` | 28 | the surface/control radius — `softPanel`'s decoration, `CardThemeData`, every `TextField`, and the ripples clipped to match it |

**The tier rule that emerged: top-level surface = 14, nested tonal block = 12.** Five genuine drifts were fixed
against it (the `fix(ui)` commit of 2026-10-10): `EmptyPanel` 16 → 14 (a *shared* widget — it occupies the
card slot, so one edit aligns every empty state), `graph_page_output.dart`'s marker panel 12 → 14, two
chart-frame radii 10 → 8 (`data_fit_cards.dart` — where the same role 50 lines below in the same file was
already 8 — and `regression_graph_sheet.dart`), and a nested dialog panel 10 → 12.

⚠️ **One edit was made and then reverted by a test, and that is the useful part.** `tool_widgets.dart`'s
category card was changed 12 → 14 under the rule above, and `tool_catalog_strings_test` went red at once: the
title row **no longer fits all eight English names**. That test reads the box width out of the render tree, so
those 4dp were guarded all along; the 12 is a **deliberate exception** (like `DetailMetric`'s 10). **A rule
yields to a measurement** — and a rule invented from a census is exactly the kind that has to.

**The other 11 outliers are genuinely different roles and are left alone**: 18 = the emphasis tier (all three
occurrences are the same highlighted primary-result panel), 12 = nested tinted blocks (4/4 consistent), 10 =
fixed-size tiles (the 78dp tool tile; `DetailMetric`, whose label cell is measured at 110.00 against a 109.1dp
longest string), 6 = the inset between a chart's border and its painted content.

**Removable weight found in the same pass** (evidence = reference counts, not opinion). ⚠️ **Status as of
2026-10-12: all four are gone** — `math_expression_text.dart` no longer exists on disk, and every symbol named
below measures **zero references** in `lib/` and `test/`. The table is kept as the record of *what went* and
what it cost, **not as a to-do list** — it read as one for a while, which is the same rot this document keeps
catching: a sentence that was true when written and false when read:

| candidate | evidence | what would be lost |
|---|---|---|
| `lib/features/calculator/presentation/widgets/math_expression_text.dart` (**702 lines**) + its own test | the only `lib/` file with **no importer anywhere in `lib/`**; `MathExpressionText` appears only in its own file and its own test. Superseded by `math_expression_view.dart` (230 lines), which 2 `lib/` files and ~28 tests do import | nothing user-visible |
| `NekoAppMark` (`app_chrome.dart`) | 2 hits in `lib/` — the class and its constructor; **zero call sites** | nothing user-visible |
| `NotesController.setNoteArchiveFilter` / `setNoteSort` / `setNoteTag` | zero references in `lib/`, `test/`, `android/`; superseded by `applyNoteFilters`, which the filter sheet does call — so no filter choice becomes unreachable | nothing |
| `MathResult.hasFractionTex` / `hasMixedTex` / `hasDmsText`, `ResultPresentation.hasFraction` | zero readers (the live siblings `hasTex`, `hasMixed` and `hasDms` are used) | a small dead API |

### 5h. One source of truth for colour: the app theme is now *derived* from the selected palette (2026-10-10)

**The mistake this fixes was made and corrected the same day.** Re-pointing the app's Material scheme at the
home page's palette (the `feat(ui)` commit) was first done by **copying the palette's literals** into
`app_theme.dart` — 94 lines duplicating values that already live in `calc_theme.dart`. That is the two-apps
problem again in a new form: the user can pick `lavenderMist` or `peachSugar`, and only the calculator would
have changed while every other screen stayed roseCream.

`AppTheme.light(CalcTheme base)` / `AppTheme.dark(CalcTheme base)` now hold **no colour literals at all**.
Every role reads a token (`primary` ← `display.indicatorFg`, `surface` ← `display.background`,
`scaffoldBackgroundColor` ← `keypadBackground`, `onSurface` ← `keys.functionFg`, `outlineVariant` ←
`keys.functionBg`, `secondaryContainer` ← `keys.variableBg`, …), roles outside the mapping come from
`ColorScheme.fromSeed(display.indicatorFg)`, and `dark()` reads `base.dark`. `lib/app.dart` resolves the theme
**once** — its existing `_calcTheme`, from `CalcTheme.resolve(settings.themeId)` — and feeds the *same* value
to both the Material theme and `CalcThemeScope`, so there is no second source of truth;
`calc_theme.dart` has no dependency back on `app_theme.dart`.

**The guard is a test, not a convention**: `test/shared/app_theme_follows_calc_theme_test.dart` walks
`CalcTheme.all`, asserts the Material scheme equals that theme's tokens, **and that the three primaries
differ** — so the day the derivation degrades back into a hard-coded palette it goes red. Measured:
`#AA5462` (roseCream) / `#6C5CB4` (lavenderMist) / `#98622F` (peachSugar).

⚠️ One call site had to change to compile: `tool_description_lines_test.dart` passed `AppTheme.light()` and now
passes `CalcTheme.fallback` — the palette it was already measuring against. **No assertion was touched**; that
test measures fonts and geometry, not colour.

**Verified on the device (2026-10-10).** Switching the theme to `lavenderMist` re-themed the **Settings page** —
a screen that never calls `CalcTheme` — its canvas, row icons and switches all went violet, and the picker's
own row then read 「薰衣草雾」. **That is precisely the case the old code could not produce**: the Material
scheme was pinned to roseCream literals, so only the calculator would have changed. Cycling the three themes
also **measurably** moved the calculator's display background (`#FFFBF6` peachSugar → `#FFFAF7` roseCream →
`#FBFAFF` lavenderMist), which is how the setting was restored to the original `roseCream` after the test —
with a **stop condition on the measured colour**, not on a count of taps (the first attempt had no `break` at
all and cycled straight past the target; the pixels are what caught it).

⚠️ **Verified on 2026-10-11 — by a route that needs no device.** `flutter test` renders in **software** (the
tester process runs with `--enable-software-rendering`), so a widget test can export the real render as a PNG:
`RepaintBoundary` around the widget, `tester.renderObject<RenderRepaintBoundary>(...).toImage()`,
`toByteData(format: ImageByteFormat.png)`. The test font is the stand-in (boxes), so **text metrics mean
nothing there — but layout and colour are the real ones**, which is exactly what was in question. Rendering
the structured tool detail screen under `ThemeMode.dark` and sampling its pixels gave:

| measured | share | is |
|---|---|---|
| `#1D191B` | 60.6 % | `display.background` (dark) |
| `#141114` | 27.1 % | `keypadBackground` (dark) |
| `#9E98A6` | 3.5 % | `display.statusFg` (dark) |
| `#E8A2AC` | 2.15 % | `display.indicatorFg` (dark) — the accent |
| `#EDE4E8` | 1.3 % | `keys.functionFg` (dark) — the ink |
| `#453828` | 1.05 % | `keys.variableBg` (dark) |

**No light-mode colour leaks**: every dominant colour is a roseCream *dark* token, and the four whose share is
0 % (`operatorBg`, `accentBg`, `destructiveBg`, `modifierBg`) are simply absent because that screen shows no
calculator keys. ⚠️ **My own untrained eye first read two of these as suspicious** — `#E8A2AC` as a leaking
"salmon bar" and `#453828` as a rogue "gold disc" — and sampling the pixels is what refuted it. **A second
instance of the same lesson as §5g's category colours: colour is a property of the combination, so look, but
then measure.** The one-off instrument was deleted after use (a test that writes PNGs to `/tmp` is not a test);
the recipe above is what to re-create.

⚠️ **Still not verified: the device's own dark rendering.** Two device routes were tried on 2026-10-11 and
**both were blocked by the device rather than by the code**: (a) the system switch — this ROM does not honour
`cmd uimode night yes` from adb (it reports `Night mode: no` before and after, exactly as it ignores the adb
rotation commands recorded in §5f); and (b) the app's own 主题模式 row — the taps stopped landing and the
captures stopped being produced at all, with `mCurrentFocus=null` and the screen asleep, i.e. **adb input no
longer reaches the UI**. The device was left in its natural state and verified so (`Night mode: no`); a
temporary `svc power stayon true` was reverted with `false`. **Route (b) is still the right one next time**,
because it is an app setting rather than a system one; it needs the device awake and unlocked.

### 5i. Multi-language: structurally sound; three gaps and one layering defect (audited 2026-10-10)

**Two languages** (`zh`, the fallback, and `en`), **24 named `…Strings` classes**, each an exhaustive `switch`
over `AppLanguage` with **no defaulted fields** — so a key missing for a language is a **compile error**, not a
runtime gap. Nine further files are Zh→En maps (Chinese key → English value, `?? key` fallback) where the
compiler cannot enforce completeness; tests do instead
(`tool_result_label_lengths_test.dart` asserts `en.labels.length == 720`). Switching rebuilds the tree from
`MaterialApp.builder` above the Navigator, and both `State` caches re-read in `didChangeDependencies` — **no
stale-language path was found**.

**Gaps, worst first** (measured, still open):

| site | what | note |
|---|---|---|
| `inline_expression_editor.dart:174` | `message: '粘贴计算详情'` on a paste `Tooltip` | **Chinese text in an English UI** — the only chrome string with no strings-table entry |
| `unit_picker_sheet.dart:165` | `const Text('to')` | an English connector inside the Chinese UI |
| `result_format_sheet.dart:135-141` | six English-only result-format labels | documented as deliberate HiPER vendor strings |
| **unit display names** — `app_unit_catalog.dart` (230 CJK lines, entries like `AppUnit('m', '米', '长度')`) | the **`CONV` sheet prints `unit.label`** (`unit_picker_sheet.dart:211`, `'${unit.symbol}  ${unit.label}'`), so an English interface lists Chinese unit names | ⚠️ **corrected 2026-10-11**: this row used to blame `core/units/tool_unit_conversion_units_{core,engineering}.dart` and claim "there is no separate display-name table". **Both halves were wrong.** Those two files (117 + 129 CJK lines) are the **parser's alias tables** — `{'米': 1, 'meter': 1, …}` — and they *must not* be translated; measured, they are also **still live**, because tool input parsing depends on them (`tool_detail_input_parsing.dart` 27 uses, `tool_detail_controller.dart` 19, via `splitUnitSuffix` / `splitByAliases` / `unitAliasesForTarget` — that is what lets a numeric field accept `1k`, `0.1u`, `104`). A **display-name table does exist** — `app_unit_catalog.dart` is it — it simply has no English side yet. So the fix is "give the display table an English side", not "separate two concerns". ⚠️ **And the gap grew more visible in batch two**: folding the 21 unit tools into one card made this sheet the **only** way to convert units |

⚠️ **The layering defect worth naming: domain-layer result objects carry user-facing prose.** A dozen-plus sites
(`calculator_submit_result.dart`, `tool_save_result.dart`, `calculator_save_result.dart`,
`recent_tool_action_result.dart`, `notes_clipboard_import.dart`, `notes_controller.dart`,
`backup_snapshot_validator.dart`, `data_backup_repository.dart`, `github_release_checker.dart`) build Chinese
sentences that reach the screen via `SnackBar(content: Text(result.message))`
(`calculator_key_dispatch.dart:236`) and `Text(result.message)` (`calculator_page_sheets.dart:345`). A domain
object that outlives the UI cannot be localised by a widget-level strings table; the fix is a **token or enum
on the result, translated at the presentation edge** — the shape the tool-result path already uses. Both cited
call sites have since been converted; converted vs remaining families are tracked below.

**First path done (2026-10-10).** The calculator submit path now has that shape: the domain result carries only
its `CalculatorSubmitStatus` token plus payloads — its unnamed constructor is **private**, so a variant whose
payload is missing cannot be constructed and the edge never renders half a sentence — the eight sentences live
in `calculator_strings.dart` (Chinese byte-identical, English added), and one new presentation function
`calculatorSubmitMessage(result, strings)` renders them where the `SnackBar` is built. The guard mirrors the
tool path's: a legacy-sentence table in both directions, an en-rendering check that forbids CJK, and a source
scan that fails if a wide literal reappears in the domain file.

**Second slice done (2026-10-11): the two save-receipt families.** `CalculatorSaveNoteResult` and
`ToolSaveResult` shed their `message` fields under the same shape. The tokens are the pre-existing
`CalculatorSaveNoteStatus` (calculator) and `ToolSaveStatus` × `ToolSaveTarget` (tools) — no new token type was
invented. The prose lives in `calculator_strings.dart` and `tools_strings.dart` (Chinese byte-identical,
English added), rendered at the edge by `calculatorSaveNoteMessage` / `toolSaveMessage` where the `SnackBar`s
are built (`calculator_page_sheets.dart` and the tool / text-tool / fit screens' save paths). One rule moved
to the edge because it is wording rather than outcome: an `inputInvalid` summary that is empty after trimming
drops the colon; `notWritten`/`superseded` deliberately share one cell. Each family carries the same guard
(legacy-sentence table both directions, en-rendering forbids CJK, source scan of the domain file). **Converted since this audit (third and
fourth slices, 2026-10-11):** the notes family (`notes_clipboard_import.dart`, `notes_delete_result.dart`),
`recent_tool_action_result.dart`, `github_release_checker.dart`, the backup-warning family in
`backup_snapshot_validator.dart` and the import-impact family in `data_backup_repository.dart` — **eight
families converted in all, not the sweep.**

**Re-measured 2026-10-11 (fifth slice included) — the earlier remainder list was wrong in two places, so
here is the measured state.** Checking every symbol this section used to name, plus a scan of each file for
non-comment CJK:

| file | measured now | verdict |
|---|---|---|
| `notes_controller.dart` | the **search-summary labels are done** (they moved to `notes_summary_message.dart` in the fifth slice). What is left is `'未命名笔记'` / `'历史结果'` / `'由计算历史保存，时间 …'` at `:317`, `:435`, `:438` | ⚠️ **not an unconverted screen string** — these are **generated note titles and descriptions written into the database**. Slice five found them, and translating them is a **data-language decision**, not an edge-translation job |
| `data_backup_repository.dart` | **no non-comment CJK at all** (all 42 CJK lines are comments) — its prose *was* converted | ✅ done |
| `backup_snapshot_validator.dart` | **converted in the sixth slice (2026-10-11)**: the empty-backup sentence is now a **token** thrown by the validator (`emptyBackupReplaceErrorToken`, resolved at the edge by `backupImportFailureMessage`) and the five table labels moved into `SettingsBackupStrings.backupTableLabels`, looked up by `backupTableLabel(tableName, strings)`; the validator keeps only the **keys** (`backupTableNames`) | ✅ done, except the technical `FormatException` sentences, which are deliberately out of scope |

So **every screen-copy remainder in this family is now converted**; the note titles are a decision about
**stored data**, and the `FormatException` family is technical messaging. Two honest consequences of the sixth
slice: the row-error messages now name a table by its **key** (`notes 第 2 条记录不是有效对象` rather than
`笔记…`), which is arguably more precise for a corrupt-row diagnostic but **is** a copy change; and the guard's
source scans were **proved non-vacuous** with a throwaway probe (56 literals scanned in the validator, 14 in
the repository, none of the moved strings present as literals, token present) before it was deleted.

### 5j. The same defect twice over: English cells copied from the Chinese ones, punctuation and all (2026-10-11)

While recovering the fifth layering slice, its own new guard caught **two** defects of one kind — an English
table cell transcribed from the Chinese one with the words changed but the **punctuation** left behind. Both
were found by measurement, not by reading, and **in both cases the test was right and the code was wrong**:

1. `summaryPartsSeparator` (en) was `' · '` — the Chinese separator verbatim. The guard asserts flatly that an
   English summary keeps no `·`, so it went red. Fixed to `', '`, which is the repo's own English convention
   (`calculator_controller_strings.dart:490`'s `listSeparator` and `settings_backup_strings.dart:300`'s
   `backupTableListSeparator` are both `', '` against a Chinese `'、'`).
2. `summarySearching` (en) was `'Searching “$query”'` — Chinese curly quotes. The ruler
   `containsWideOrFullwidth` (`test/shared/source_scan.dart:101`) flags `0x201C`/`0x201D` explicitly, so it
   went red too. Fixed to ASCII `"`.

**The same class is present elsewhere, and the counts are known.** Measured by running the ruler's own
character set over every `*_strings.dart` English value:

| rune | where the ruler stands | English cells |
|---|---|---|
| `“ ”` curly quotes | explicitly banned (`_typographicPunctuation`) | **3** — `notes_strings.dart:474` (`Delete “$title”? …`), `tools_strings.dart:622`, `:651` |
| `…` ellipsis | **also in that banned set** (`0x2026`) | **8** — `calculator_strings.dart:589/615/628/630`, `notes_strings.dart:435/518/522`, `tools_strings.dart:618` |

⚠️ **Those 11 are left as they are, deliberately.** Adding a guard that bans the whole set would force a
**style sweep across several tables**, and every one of those cells is pinned byte-for-byte by its own strings
test — a change of copy, not a bug fix. The curly quotes are the same defect as (2) and are the better
candidates if a sweep is ever wanted; the ellipsis is a **pervasive pre-existing convention** in this repo's
English copy and reversing it is a decision for the owner. Recorded rather than done, so that the finding is
not lost and nobody re-derives it.

### 5k. 「小而美」: what was cut, on what evidence, and what was deliberately kept (2026-10-11)

The user asked twice for fewer features (「可以删减一些不必要的功能」, then 「功能太多，要**小而美**」). The
work was driven by an **audit of the whole catalogue** (122 tools, 8 categories) whose brief was to find
*redundancy*, not to look busy — and its own conclusion was that **most of the 122 do distinct work: "there is
no evidence for a broad cull"**. That conclusion is part of the result.

**Cut, in two batches, each with the rule "no capability may become unreachable":**

| batch | what | effect |
|---|---|---|
| — | the 702-line dead renderer + its 369-line test, `NekoAppMark`, 3 dead setters, 4 unread getters | **−1285 lines** |
| one | `dbm` (a **strict subset** of `rms_peak`, which already accepts `dBm50`), `inflation` → `compound`, `proportion` → `scale_ratio` — in each case every number the old tool produced is still reachable, **including the corner cases** | catalogue 122 → 119 |
| two | **21 unit converters → one card** that opens the **same** `UnitPickerSheet` the `CONV` key opens (`ToolCapabilities.opensUnitSheet` → `tool_navigation.dart` → `AppShell._openUnitSheet` → the calculator page's own `_openUnitSheet()`): one sheet, one behaviour, no second implementation | catalogue 119 → **99** |

⚠️ **`temperature` was kept, and the reason is measured, not stylistic**: °C/°F are *deliberately absent* from
the unit table (`app_unit_catalog.dart:28` records that `_replaceDegree` means `5 °C` is not "5 degrees
Celsius" on the app side), and the symbol `'C'` is already taken by **coulomb**
(`AppUnit('C', '库仑', '电学')`) — so it is the one unit tool `CONV` cannot replace.

**Deliberately NOT cut, each with its reason** — recorded so that a later session does not re-derive this
audit:

- **`data_fit` (~3.7k lines, the largest single tool) — kept.** It looks like the regression sheet, but they do
  different jobs: one fits **data the user pastes in**, the other only the **stored dataset**. Removing either
  loses a real entry point. **Capability beats line count.**
- **The degenerate special cases** (`dcdc_feedback` = the divider with the input voltage fixed,
  `cylinder` = pressure × area with the bore fixed, `linear_equation` = the quadratic with `a = 0`,
  `free_fall` = kinematics with `a = g`) **and the resistor/capacitor/inductor trio** — merging them needs a
  **`choices` input primitive that does not exist** (`ToolInputDefinition` has no such field; the only input
  widget is a numeric `TextField`), and a numeric sentinel would **lose unit-tagged input** (`1k`, `0.1u`,
  `104`). Building a new primitive to remove one or two cards is a poor trade, and each merge also costs a
  dedicated entry point.
- **`discount`/`tax`, `checksum`/`fnv_crc`, `url_codec`/`query_params`** — the same marginal arithmetic.
- **The "textbook" tools** (`screw_lead`, `timer_555`, `pcb_current`, `half_life`, `ph`, `ideal_gas`,
  `uncertainty`, …) — they do distinct work; whether they are *wanted* is the owner's taste, not something the
  evidence decides. **Left alone.**

⚠️ Every removal moved **count gates** (catalogue size, label tables, site counts, literal counts, promoted
names) — each one to the **measured** new value with its derivation recorded in the test, and one stale
figure that was already wrong at HEAD was **corrected and labelled as such** rather than quietly overwritten.
**No gate was moved to make a red disappear.**

### 5l. The one open decision: note titles and descriptions are **stored prose** (recorded 2026-10-11)

`notes_controller.dart` composes `'未命名笔记'` (the fallback when a title is blank), `'历史结果'`, and
`'由计算历史保存，时间 …'` / `'计算工具: …'` when it saves a note — and those strings are **written into the
database**, not painted onto a screen. The fifth slice found this and correctly refused to translate them, and
so does this record: **a screen-level strings table cannot localise a value that outlives the screen.**

Why it is a decision rather than a task: a note's title is **user data**. It can be edited (hence the blank-
title fallback), it is exported in backups, and it is searchable — so it cannot simply be replaced by a token.
The three shapes available, with what each costs:

| shape | how it behaves | cost |
|---|---|---|
| **A. keep as-is** (today) | the title is frozen in the language it was created in | an English user sees Chinese titles for notes created in Chinese — but nothing is ever lost, and edits stay edit |
| **B. generated titles only** — store a `kind` + payload (`history`/`tool` + timestamp/source id) instead of the sentence, and render it at display time; keep a stored string **only** when the user has actually edited it | an English UI would show English auto-titles, and an edited title stays exactly what the user typed | a schema change plus a migration for existing rows; the two fields must be kept in sync on every save and on every later edit |
| **C. store a language tag** alongside the generated title | the stored text can be recognised as "generated, in language X" and re-rendered when the UI language differs | smaller than B, but the note's *name* still changes under the user when they switch language — which for a searchable, exportable, editable field is arguably worse than A |

**Decided and implemented 2026-10-11 — option A+, not B or C.** The three strings are now **generated in the
language the interface is in at save time** and still **stored as plain text**: `NotesStrings` gained
`untitledNote` / `historyNoteTitle` / `historyNoteDescription(timestamp)` (zh byte-identical, en added), the
controller carries a reassignable `NotesStrings strings` seeded by `NotesStrings.forCode(settings.languageCode)`
— the same shape the sibling `ToolDetailController.strings` / `ToolDetailStrings.forCode` already used, so no
new mechanism — and `NotesPage` now takes the `AppSettings` the shell already holds.

**Why A+ rather than B/C.** The title is **user data**: editable (hence the blank-title fallback), exported in
backups, and searchable. Turning it into a display-time token (B) would make a note's *name* change under the
user when they switch language — for a searchable, exportable, editable field that is worse than freezing it.
The defect was never "it is frozen"; it was "**it is frozen in Chinese regardless of the user's language**",
which is what A+ fixes. C was rejected for the same reason as B.

**Guarded by tests that would have caught the original bug**: a domain test asserts the **stored** title and
description are English when saving with the English table (and pinned zh sentences stay byte-identical); a
**widget** test saves a blank-titled note under `AppLanguageScope(en)` and asserts the fake database received
`'Untitled note'` — that one catches "the controller was fixed but the page was never wired"; and a source scan
proves `notes_controller.dart` no longer holds any of the three literals, with its non-vacuity checked against
the round-trip labels that are *deliberately* still Chinese.

### 5m. Why six conversion slices missed the biggest block: the guards' **scope**, and a **raw-string blind spot** (2026-10-11)

A repo-wide audit (prompted by the question "is any Chinese left that can reach an English screen?") returned
**four real leaks**, two of them large: the tools screen renders **result values** raw (`tool_widgets.dart:542`,
`tool_detail_output_section.dart:232` — the *label* in the same row already went through a table), the numeric
tools' **insight card** is Chinese wholesale (~600 literals across `tool_insights_*.dart`, rendered raw at
`tool_detail_output_section.dart:268`), the About box printed `预览版`, and a **third copy** of the note-title
fallback sat in the data layer (`app_database_rows.dart:225`, the import/restore path — the audit had found
only two).

**Two structural reasons, and both are worth more than the fixes.**

1. **The guards' scope stopped at the presentation subtrees.** Every existing Chinese-literal scan covers a
   `lib/features/*/presentation` tree (see the table in §5i's area). **`lib/core/**`, `lib/data/**`,
   `lib/domain/entities/**` and nearly all of `lib/domain/usecases/**` had no guard at all** — and that is
   precisely where the largest Chinese block lives. A guard that cannot see a subtree cannot fail on it, so six
   conversion slices could each be green while the domain layer stayed Chinese. *The lesson is about the
   scan's reach, not about the slices' diligence.*

2. ⚠️ **A raw string made a whole file partly invisible to the ruler.** When the new data-layer guard ran, it
   reported **bogus offenders**; the cause was `app_database_rows.dart:99`, which held
   `.replaceAll(r'\', r'\\')` — **a raw string ending in a backslash**. `stringLiterals` reads that backslash as
   escaping the closing quote and then drifts, treating a large block of following code as one string. So that
   file was **unreadable to any source scan**, which is how the third fallback survived every earlier sweep.
   It was rewritten as `.replaceAll('\\', '\\\\')` and the change was **proved semantics-preserving** with a
   throwaway Dart probe (identical rune lengths and identical `replaceAll` output). **Anyone adding a literal
   scan should check for this shape first** — a scanner that silently loses a file looks exactly like a clean
   file.

The new guards are deliberately narrow (`test/data/data_layer_source_guard_test.dart` scans three named files,
not a tree), carry exemption lists with reasons and a **dead-entry check that every exemption fires**, and prove
themselves **non-vacuous three ways** — including a permanent positive-control test and a perturb-and-revert
run. **A guard that has never been shown to fail is not yet known to be a guard.**

**All four were fixed the same day** (commits `1b9bb78` and `3bd2af3`). First the About box and the data-layer
twin — which turned out to have a **third** occurrence, and whose fix is a language-neutral `'…'` mark rather
than a translated default, because that layer is below the interface and *cannot* know the language; the
language-dependent composer stays the single one in `NotesController` (§5l). Then the two large ones: **225**
keys for the result values, and **367 whole sentences plus 90 payload templates** for the insight card. The
matcher had to be widened — the producers *compose* sentences from fragments, they do not look them up — so the
cuts became a backtracking candidate sequence, a payload that still holds a sentence descends one more layer,
and a glued value+unit is split by asking the tables; **the producers themselves were not touched**.

**Measured after**: 99 tools × every input profile → **3380 insight lines and 12610 value/unit cells through the
real lookups, 0 Han left, and 3343 of them genuinely changed language** (that last number is what makes the
sweep non-idling), with all 1117 distinct rendered pairs read by eye. Two **complementary** guards now cover
what the presentation-subtree guards could not reach: a **source** guard over **48 files** of `lib/domain/**`
(1668 literals covered, 5 notation-only, 12 exemptions — every one of which is checked to actually fire), and a
**behavioural sweep** that catches *composed* values no literal scan can see. Non-vacuity was proven by renaming
one map key and watching **both** guards go red, then reverting.

**The named debt was paid the same day** (commit `d12b9a4`), and the sweep to find it was systematic rather
than opportunistic: a `\p{Han}` scan of `lib/domain`, `lib/data` and `lib/application` for Chinese assigned to a
field that is displayed or stored returned exactly **two** groups — the clipboard-import drafts (the debt) and
the **tool catalogue** tables. The catalogue is **not a defect but the architecture**: `tool_widgets.dart`
records that a card shows `ToolCatalogStrings'` name rather than `tool.title`, "the latter being content data
… the two coincide in Chinese and differ in English" — the Chinese there is the content-side source of truth,
and every displayed string goes through a map that has an English side. **So the §5l class existed in exactly
two places, and both are now closed** — which is a better answer than the defect fix itself: it closes the
question "is there another one?" instead of leaving it to be stumbled on.

**The clipboard fix found one more instance than the audit had**: three draft builders, not two — the third
(`_parseHistoryBlock`'s preview, `'计算历史 · …'` / `'工具历史 · …'`) had not been spotted. It follows §5l's A+
shape (token + payload in the domain, sentence composed at the edge and still stored as plain text), with the
truncation and fallback rules preserved byte-identically (24/30, `\s+` folded, `'剪贴板内容'` / `'导入笔记'`),
the guard's exemption **reason rewritten** to say the debt is paid while the entry stays (the file still holds
the paste round-trip grammar), and **three independent proofs** that an English save yields an English title
(composer, controller save edge, and a widget test).

⚠️ **What genuinely remains**: the catalogue family's whole-file exemption (architecture, as above — not a
defect) and the nine clipboard round-trip labels, which are **input grammar read back by a parser**, not copy.

### 5n. The gap class that neither a source scan nor a composer test can see (found and closed 2026-10-11)

Converting the domain-prose families to "token + translate at the edge" gave each family a guard — the
legacy-sentence table, the en-no-CJK check, a source scan of the producer. **All of those can be green while the
screen is not wired to the composer at all.** A source scan checks that the *producer* hands over a token; a
composer test checks that the *composer* renders one; **neither looks at the call site, which is exactly where
the two meet.** The only thing that catches it is a **widget test that drives the real action and asserts the
visible sentence**.

Two instances were found — not by any guard, but by asking the question family by family:

| path | state before | closed by |
|---|---|---|
| `=` submit (`calculator_key_dispatch.dart`) | **no widget test at all**: composer pinned by `calculator_submit_result_test.dart`, tables by `calculator_strings_test.dart`, the screen by nothing — an earlier agent had flagged it as a known limitation | `56db335` — scope `en`, tap `✓` on an empty screen, assert the English sentence present and the Chinese absent |
| tool save (`text_tool_detail_screen.dart:315/:336`, `data_fit_actions.dart:316/:337`) | **Chinese side covered, English side not**: `tool_detail_screen_test.dart:388-403` and `:427-441`, `data_fit_tool_screen_test.dart:181-238` assert the Chinese receipts; the only English-scope test on those screens taps *Paste* and **never *Save***; a grep for the English receipts across `test/` returned none | `fda0409` — scope `en`, `Save` → `Note`, assert the English receipts |

**Both new tests were proved non-vacuous the same way**: hard-code the Chinese sentence at the call site, watch
the English test go red while the Chinese one stays green, then restore and verify `lib/` byte-identical.
**A wiring test that has never been shown to fail is not yet known to be a wiring test.**

⚠️ **This class cannot be guarded mechanically, and that is worth stating so nobody tries**: the call site looks
correct in every static sense, and the failure exists only at runtime, in the rendered text. The practical
answer is a per-path widget test — which is why **each converted family needs one**, and why *"the composer has a
guard"* is not the same claim as *"the path is covered"*.

⚠️ **And finding them took three failed proxies**: a grep for tests that *import* the composer (wrong — a widget
test need not import it), a keyword grep for `SnackBar|已保存|Saved` (a possible false negative), and a guess at
the receipt cells' names (**all four guesses did not exist** — the real ones are `saveHistorySaved` /
`saveNoteSaved` / `saveNothingToStore` / `saveNoteNotWritten`). **Reading the tests answered it in one pass.**
For questions about *test coverage*, a grep is a guess about the answer, not a measurement of it.

**The sweep finished the same day** (`56db335`, `fda0409`, `2ee7b0a`). Reading each remaining family's tests —
rather than grepping, which had failed three times — produced this measured coverage table:

| family | before | now |
|---|---|---|
| `=` submit | **no widget test at all** | ✓ both scopes |
| tool save | Chinese only | ✓ both scopes |
| recent-tool receipt | only the *empty-panel* copy was asserted, and that does not go through the composer; **no receipt assertion in either language** | ✓ both scopes |
| update check | default Chinese only | ✓ both scopes |
| backup | default Chinese only (composer, table and source guards all existed) | ✓ both scopes — and the impact sentence is asserted **twice**, because it legitimately appears in two places (the impact row and the blocking notice) |
| notes — import drafts | **already covered in both languages** | unchanged |
| notes — receipts | Chinese only | ✓ both scopes |
| notes — summary | **neither language** | ✓ both scopes |
| calculator save-note | only that the button is *tappable* — it was never tapped | ✓ both scopes (a fake clock carries the 5 s `engineTimeout`, so no wall-clock wait) |

⚠️ **One sub-gap is recorded as unreachable rather than papered over**: `backupImportFailureMessage`'s token
branch cannot be reached from the settings UI at all — the Replace button's enablement tests
`preview.totalRows > 0` while the validator throws that very token exactly when the total is **0**, i.e. the same
sum of the same snapshot. The precise reason is recorded here; **no test pretends otherwise**, because a test
that looks like it covers a path it cannot reach is worse than a documented gap.

**All ten new assertions were proved non-vacuous individually** — six perturbation rounds, each quoting its own
failure text: hard-code the Chinese at the call site, watch the **English test go red while the Chinese stays
green**, restore, then verify `lib/` byte-identical. **That is this section's whole point: for a wiring claim, the
only guard worth counting is the one that has been shown to fail.**

### 5o. The Kotlin/JNI bridge: audited for the first time (2026-10-12), and the first Kotlin tests

**Why it was audited.** Every computation crosses one bridge — Dart → `MethodChannel` → **Kotlin → libqalculate
(JNI, `android/app/libs/libqalculate-5.12.0.aar`)** — and that layer is **~1,700 lines with zero direct test
coverage**: `flutter test` fakes the platform side, so none of it executes in the suite. §1 of this file records
that engine *behaviour* needs a device; **the bridge's own correctness** is a separate question and had never
been asked.

**Headline: no PROVEN memory-safety or wrong-answer defect in the engine path.** The audit found the bridge
unusually disciplined and **said so with evidence**: one engine thread, only `Map<String, String>` across the
channel, `catch (Throwable)` (which is what covers `System.loadLibrary`'s `UnsatisfiedLinkError` — an `Error`,
not an `Exception`), every option/print object rebuilt per call, and the result `Map`'s keys matched
field-by-field against the Dart reader. On JNI references specifically: **no local-ref overflow** (each lookup is
a separate call whose native frame is popped on return), **no `NewGlobalRef`/`NewStringUTF` anywhere** in the
Kotlin (everything crosses through SWIG's own glue), and the `MathStructure`/`PrintOptions` objects that are
never `delete()`d carry ART finalizers — a deferral, not a leak.

**Two findings were fixed.**

| finding | what | fixed by |
|---|---|---|
| **PROVEN** | `MainActivity`'s `exportJson`/`importJson` called `startActivityForResult` **unguarded**, while the sibling `exportBytes` has always wrapped it. On a device with no activity handling `ACTION_CREATE_DOCUMENT`, that throws `ActivityNotFoundException`: the exception crosses the platform thread **and** `pendingResult` is left non-null forever, so **every later backup call returns `busy` — export and import are dead for the life of the process**. | `cf6d4c1` — same `try`/`catch` shape as the sibling, clearing the pending state and answering with a real error |
| **SUSPECTED** | the engine was held as an **Activity field** while `QalculateEngine`'s own class doc promises "the process therefore keeps exactly one `Calculator`". A system-initiated recreation ("Don't keep activities", low-memory) would build a **second engine and a second native thread** — the shared-state race that doc says was deliberately avoided. | `fc1585a` — moved into a nested `object` (one singleton per process); the field became a one-line getter, so **no call site changed** |

⚠️ **And the library itself is stricter than our doc comment was.** Looking up `Calculator`'s own reference on
2026-10-12 gives: "A calculator object must be created before any other Qalculate! class is used. **There should
never be more than one calculator object, accessed with `CALCULATOR`.**" So the per-Activity field was not merely
inconsistent with our own comment — it **violated the library's documented requirement**, and `fc1585a`'s
process-scoped singleton is what brings the bridge into line with it. (The same page also documents `busy()`,
"Returns true if the calculate or print thread is busy", and a section of "Functions for handling of threaded
calculations" — the machinery the finding above says we should adopt.)

**Two items were carried here.** One is fixed as of 2026-10-12 (below); the other still stands, and each is
recorded with its precondition and the smallest fix named — recorded rather than half-fixed:

- **A hung native call blocks every later evaluation.** One single-thread executor with an **unbounded** queue;
  `calculate` takes **no timeout** (only `print` gets `PRINT_TIMEOUT_MS = 2000`), and the bridge **never calls
  the engine's own `abort()`**. The consequence is quiet: Dart's 5 s `engineTimeout` falls back to the legacy
  parser, so the **UI looks fine while the native queue and CPU grow**.
  ⚠️ **The library's own documentation was looked up on 2026-10-12, and it settles the shape of the fix**:
  `Calculator::abort()` is documented as "Abort formatting, printing or evaluation (**after `startControl()` has
  been called**)" and — decisively — "This function **will normally be called from a thread** that checks for
  user input or other conditions". The same page says the `calculate` functions "**start the calculation in a
  separate thread**" and "The calculation can then be stopped with `abort()`", and offers `busy()` for "the
  calculate or print thread". **So aborting is not an invention and not a risk — it is the documented,
  intended use; what the bridge lacks is the engine's own threaded-calculation machinery (`startControl`), not a
  timer.** That converts this from "a design choice I declined to guess at" into **a documented path**:
  adopt the engine's threaded API rather than adding a timer to the hand-rolled executor.

  ⚠️ **Attempted on 2026-10-12, and reverted unshipped. What the attempt reached is kept here as a map**, so the
  next one starts from a design instead of from zero — and so the reason it was *not* shipped is on the record:

  - **Shape (Kotlin).** A separate `QalculateThreadedEvaluation` owns dispatch-and-wait: dispatch through the
    library's threaded `calculate` overload, **wait by polling the engine's own `busy()`** rather than with a
    timer, and stop by calling the engine's `abort()`.
  - **The request-id protocol — the part that is not obvious.** `abort()` hits **whatever the engine is running
    at that moment**, so an evaluation has to be **named** to be stopped: `requestId` becomes a **required**
    channel argument, incremented per call by Dart, and the native side calls `abort()` **only when the pending
    abort's id matches the running one** — a missing id is **rejected rather than invented**, the same rule the
    reader already applies to `angleMode`.
  - ⚠️ **"Stop" is best-effort, not a promise.** The evaluation may have already finished, or not yet started;
    a queued request **claims the abort when it launches**, so it dies at its first step instead of burning a
    full run. The Dart side's `abortInFlight` therefore returns nothing: the caller has already given up, and
    there is nothing left to decide from the result.
  - ✅ **Done separately (2026-10-12), without the threading change:** the wait responsibility now lives in its
    own mixin (`calculator_controller_engine_wait.dart`), which took `calculator_controller_evaluation.dart`
    from **798 to 753 lines** — real headroom under the 800-line rule, instead of a boundary the next change
    would collide with. ⚠️ The attempted version above measured **725**, because it also carried the threading
    work's other pieces; **753 is what this extraction alone yields**, and it is the number to check that file
    against. The order constraint held exactly as predicted: the mixin must precede `_CalculatorEvaluation` on
    the `with` list, and getting it wrong is a **compile error**. ⚠️ And the move caught its own trap: the
    original method carried an `@override` (it implements an abstract declaration in
    `calculator_controller_state.dart`), the moved copy first omitted it — **one missed annotation produced two
    warnings**, "overrides without the annotation" on the new side and "annotated but overriding nothing" on
    the old. Which is why the move had to be checked with `flutter analyze`, not just with a green suite.
  - ⚠️ **Why it was reverted rather than finished:** the change is **three-sided** (Kotlin threads, the channel
    protocol, the Dart wait), and **its seams cannot be verified here** — there is no device in this loop, and a
    JVM double stages *what a device would return*, which proves the double (§5o already records that
    limitation). Shipping an **unrun concurrency** change on the one path every calculation depends on is
    precisely what this document exists to prevent. Recorded as a retreat, not dressed up as progress.
  - ⚠️ **Process note, and it cost real work:** the attempt was stopped **while it was writing** — eleven files
    were touched between the check that showed a clean tree and the kill itself. Recovering meant restoring
    **eight files from HEAD** (with `git show HEAD:<path>` into a temp file and `mv`, so a wrong path cannot
    truncate a file) and deleting **three** that HEAD never had. **Stopping an agent is only cheap if it has not
    started writing** — the tree, not the agent's prose, is what has to be checked immediately before the kill.
- **`loadGlobalDefinitions() == false` is logged and dropped.** ✅ **Fixed (2026-10-12).** The file's own comment
  said the return value "must be recorded … 400-odd units and every constant vanish silently", but it never left
  logcat, so Dart could not tell "no units loaded" from a real answer. Both sides now exist, as this bullet said
  they had to: the engine records the verdict and puts **`definitionsLoaded`** on **both exits that carry a
  receipt** — the call-name guard (**the one a definitions-less engine actually hits**, since an empty symbol
  table makes every call name unknown) and the success map, read from one shared value so the two cannot drift;
  the catch map deliberately does not carry it. The Dart reader treats `'false'` as
  **`engine_definitions_unloaded`** and does so **before** the `ok` check, because `false` is the **root cause**
  and the guard's `ok=false` is only its consequence — and a *missing* key fails open, the same rule the reader
  already applied to `kind`. At the app layer, a definitions-unloaded reply whose fallback **also** fails now
  throws the verdict, so the user is told 「引擎没加载单位和常数，回落的解析器也读不出来」 instead of the
  misleading sentence the fallback would otherwise produce.
  ⚠️ **Verification level, stated plainly: unit level, not behaviour, and not on a device.** The Kotlin side is
  **13 JVM tests, 0 failures** (2 new) — re-run here with `--rerun-tasks`, `50 actionable tasks: 50 executed`,
  counts read from the result XMLs rather than from a report; the Dart side is covered at the reader, app and
  strings layers. ⚠️ The **success-map** key has no JVM test: reaching it needs a live `MathStructure`
  (`calculate`/`print` are native), and a double-staged tree would only prove the double — the limitation is
  written into the new Kotlin test file's own header.
  ⚠️ **The harness had to be fixed before any measurement was valid**, and the failure mode is worth keeping:
  host-JVM tests use the AAR's **stub** `android.jar`, where `android.util.Log.i` **throws** — and the evaluation
  path logs, so the first red run died on `Method e in android.util.Log not mocked` **from inside a catch**,
  i.e. on a sentence unrelated to the assertion. The measurement was void, not red. `unitTests.isReturnDefaultValues = true`
  (`android/app/build.gradle.kts`, host-JVM only, nothing in the APK) fixes the instrument, and it does **not**
  weaken the loud-double property recorded above: the AAR's SWIG glue is caught by a **real class** in
  `src/test/java/`, so a method the double lacks is still a `NoSuchMethodError`.

**And the layer gained its first tests.** `android/app/src/test/` now holds **11 JVM tests** over the *pure*
mapping logic (`QalculateOptions`'s option/print mapping, `QalculateResultKind`'s classification), plus a
**test-only JNI double** whose fully-qualified name matches the AAR's SWIG glue so that it shadows it on the unit
test classpath — **if it ever stopped shadowing, the failure is a loud `UnsatisfiedLinkError`, not a silent
pass**. Three things were **deliberately not tested**, and the reasons are the point: `QalculateResultPrints`'s
functions *are* native calls (faking them would mean asserting on my own canned strings — vacuous);
`conversionLanded`/`isPlainQuantity` need a live structure/dimension semantics; and `ENGINE_PRECISION` lives in
the lazy block that needs a real `Calculator`. ⚠️ **The tests' own epistemic boundary, stated in their report:
they prove *which values cross the JNI boundary*, not how libqalculate interprets them — that remains host-`qalc`
and device territory.**

⚠️ **Verification level of the two Android fixes, stated plainly: compile + tests, not behaviour.** Both were
verified by `flutter build apk --debug` succeeding and the Kotlin tests re-running green (`--rerun-tasks`, 50/50
tasks executed — a Gradle task reported `up-to-date` had fooled me once earlier, and §6's shape is exactly "an
action that did nothing looks like one that ran"). **Neither fix has a behavioural test**: instantiating
`MainActivity` (a `FlutterActivity`) on the JVM needs Robolectric, which this project does not carry.

### 5p. Is the release build's JNI path intact? — yes, and it corrected two of my own readings (2026-10-12)

The classic severe defect in any JNI app is "debug works, release crashes": R8 renames or strips the classes that
JNI resolves **by name**. This project ships a release build, so the question was worth asking — and answering it
corrected two things I had said.

1. **"Minification is off" — wrong.** A grep for `isMinifyEnabled` in `android/app/build.gradle.kts` returns
   nothing, and I read that as "not enabled". **`dexdump` on the built release APK says otherwise**: the DEX holds
   **662 class descriptors**, and under `com/nekorain/nekocalc` there is **only `MainActivity`** — the whole
   `…/nekocalc/qalculate/` package is absent because R8 **merged/inlined** classes that are referenced only by
   compiler-resolved code and never by name. That is *harmless by construction* (nothing looks them up by
   string), but it means the release build **is** optimised, and my grep-based reading was a third instance of
   "a grep that finds nothing is not a measurement of absence".
2. **The JNI-critical names survive — verified with a real DEX parser.** `dexdump` lists
   `'Lcom/jherkenhoff/libqalculate/libqalculateJNI;'` and `'Lcom/jherkenhoff/libqalculate/Calculator;'` **by their
   full names** in the release DEX, which is precisely the property JNI needs; the AAR most likely ships consumer
   keep rules. Combined with the earlier measurements — the release build **launches and runs**, and its startup
   smoke test makes an engine call — there is **no evidence of an R8/JNI defect**.

⚠️ **And the method lesson is worth more than the answer.** My first attempt probed the DEX with `strings` and
"found" the JNI classes while missing `QalculateEngine` — **a class I had edited the same day and knew was
compiled in**. That control failure is what exposed the method as unreliable (DEX stores its string pool in
length-prefixed chunks that `strings` cannot be trusted to respect), and the fixed method (`dexdump`, a real
parser) then produced both the presence of the JNI names and the absence of my own package. **A measurement whose
control fails is not a measurement** — and the only reason this entry exists at all is that `QalculateEngine`
showing up as "absent" was too absurd to accept.

### 5q. The cursor keys jumped to the ends because the selection was **invisible** — and it came back from disk (2026-10-12)

Reported from the device, in the user's words: 「计算器的左右键应该每次只动一个字，你现在直接就是首尾」. The keys
were not mis-bound — `◀`/`▶` did reach `moveCursorLeft()`/`moveCursorRight()`. The defect was what those methods
did with a **non-collapsed selection**: left collapsed it to `selection.start`, right to `selection.end`. On
screen that reads as a jump to the beginning, or as "nothing happened", because of an asymmetry worth naming:

- **The display band draws no selection highlight at all.** `MathExpressionView`'s only caret parameter is
  `cursorIndex` (`math_expression_view.dart:32,73`), and `int get cursorIndex => _selection.end`
  (`calculator_controller_state.dart:280`) — so a non-collapsed selection renders as **one caret at its end**,
  with nothing anywhere marking the other end.
- "Collapse to `selection.start`" therefore moved the caret from where the user could see it to a position no
  pixel had ever pointed at. And because the `cursorIndex` setter collapses too (`:282-284`), the jump happened
  **once per selection** — which is exactly the shape of 「每次都直接首尾」.

**And the selection arrives from the previous session.** With `restoreState` on, `_persistState` writes
`calculator_cursor` / `calculator_selection_start` / `calculator_selection_end`
(`calculator_controller_persistence.dart:459`); `_restoredSelection` rebuilds the range (`:514`, assigned at
`:52`) and `restoreIfEnabled()` assigns it post-frame from `calculator_page.dart:328`. A selection left behind by the last
session is thus back **at the first keypress after launch** — invisible, and surviving the very restart that
would have cleared it. This is §5n's shape in a new place: **the controller holds a state the screen cannot
express** — and here that state also outlives the process.

The fix is the narrowest of the three candidates: the keys **ignore a non-collapsed selection** and move one
character from the caret the user can actually see (`selection.end`), the setter collapsing it as a side effect.
The other two were rejected for not making the user's sentence true — "collapse to the edge, then move" still
teleports (`(1,4)` under `◀` lands at 0, not one character away), and "stop persisting the selection" does not
touch the in-session selection the inline editor creates via `onSelectionChanged` (`calculator_page.dart:498`),
so the keys would still jump in that state. **Range replacement is untouched**: whole-range editing lives in
`input`/`backspace` through `_replaceSelectionWith`, and its tests stayed green.

⚠️ **The boundary of this change, stated rather than left to be discovered.** The keypad is reachable while
the inline editor is open **on purpose** — `calculator_page.dart:483-488` says the keys writing into the
editor's selection "is the whole point of this editing interaction" — and inside that editor the selection
**is** drawn (it is a real `TextField`). So with a visible selection there, the keypad's `◀` now collapses it
to `selection.end - 1`, not to the selection's left edge, which is what a text field would do. That is a
deliberate trade-off: the rule became "one character from the caret", uniformly, because the alternative —
edge-collapse when the selection is visible, one character when it is not — makes the same key behave
differently depending on which surface holds focus, which is harder to predict than it is to explain. If the
editor case is ever judged more important than the uniformity, **that** is the sentence to revise, not the
keys. `_closeInlineEditor` (`:575-585`) only flips its two flags and never collapses the selection, so a range
selected in the editor does survive closing it — reaching the controller in exactly the state this section is
about.

**One existing test had been pinning the bug.** `cursor movement collapses a selection at the requested edge`
asserted exactly the old behaviour (`collapsed(2)` / `collapsed(5)` for selection `(2,5)`); it is now
`cursor movement with a selection moves one character from the caret`, expecting `collapsed(4)` / `collapsed(6)`.
Stated explicitly because "an existing expectation changed" and "a test was loosened to fit the code" are
different events, and the difference is only visible if someone writes it down.

⚠️ **The red was reproduced as a control, not taken from a report.** The pre-fix file was put back from
`git show HEAD:…`, the files re-run, and the three tests failed **with the predicted numbers** —
`Expected: <3> Actual: <1>`, `Expected: <5> Actual: <4>`, and the domain test's selection value — while the 29
other tests in those two files passed on both versions. The fixed file was then restored and verified by
sha256. That is §5o and §5p's discipline arriving from the other direction: an agent's "it was red before" is a
claim; **the control is the measurement.**

⚠️ **The install step has exactly one way to destroy user data, and this round walked up to it.** The first
rebuild of this fix used `--target-platform android-arm64` on its own, which emits `app-release.apk` at
**versionCode 2009** — while the device carried **4009** from the ABI-split APK installed during the smoke
test. ⚠️ **The two files are the same payload: `app-release.apk` and `app-arm64-v8a-release.apk` are both
34,289,489 bytes.** Only the number differs — and that number alone decides whether the install is an upgrade
or a refusal. It is the downgrade guard **§2:117-148** already owns (first met in the debug direction, and
scripted around in `tool/install_debug_over_release.sh`), and it creates the same temptation: the reflex that
clears the refusal is **uninstall, then install**, which takes history, notes and settings with it. What
resolves it is not a flag but **the right build**: each ABI carries its own versionCode (`armeabi-v7a` 3009,
`arm64-v8a` **4009**, `x86_64` 6009), so rebuilding the **same ABI split** lands on an equal number and
installs as an ordinary upgrade. The check costs two `aapt2 dump badging` reads, one per side, **before**
pressing install; `lastUpdateTime` moving (10:23:09 → 10:36:40) confirmed it afterwards. This paragraph is
short on purpose — §2 closes by noting it was re-derived the hard way once already, and re-telling it here
would be the same mistake in a new place.

⚠️ **The device's build predates this fix.** The APK installed during the release smoke test carries
`1.2.0-beta.1` / versionCode 4009, so the report and the fix sit on opposite sides of it. The point of
rebuilding and reinstalling in this round is that the fix should be **felt on the phone, not read in a
report** — a green suite is not a user pressing ◀. The rebuilt APK installed cleanly over the running one and
`am start -W` returned `Status: ok` with the process alive, so the release build launches — **and unlike an
earlier draft of this paragraph said, its UI *was* seen.** Two readings that looked like failures were
instrument errors, and both are worth keeping:

1. **"`mCurrentFocus=null`, so nothing is in front"** — wrong: `dumpsys window` prints **one focus line per
   display**, and `grep -m1` took the **sub-screen's** `null` while a later line held
   `Window{…com.nekorain.nekocalc/…}`. The window state was conclusive all along and better: `isVisible=true`,
   `isOnScreen=true`, `mObscured=false`, **`mDrawState=HAS_DRAWN`**.
2. **"the screen is asleep"** — true of the first capture only. And `screencap -d 0` / `-d 1` produce
   **0-byte files**: `-d` wants SurfaceFlinger's *physical* display id. The map, read rather than guessed:
   `4630946736638489730` = logical display 0, 1440×3200, `state ON` (the real panel);
   `4630946457913958275` = logical display 2, **126×294**, `state OFF` (Xiaomi's sub-screen).

Captured on the main panel, the release build shows the calculator with `12×12`, the result `= 144`, the
orange ◀ ▶ keys in the first row — and **a single caret bar at the end of the expression with no highlight
anywhere**, which is the exact asymmetry this section is about, now *seen* instead of argued.

⚠️ **Then the instrument broke, and that is what it is called.** Driving the app toward the user's scenario
(open the inline editor, select something), `screencap` on the main panel began failing — exit 1 and 0 bytes
in both PNG and raw mode — while the sub-screen kept capturing (777 B / 148,192 B) and the app's layers
stayed composed (`SurfaceFlinger --list` lists them) with the panel still `state ON`. **Cause not
established**, and the honest record is "the capture path failed", never "the app vanished". Two further
things came out of the attempt and are worth keeping:

- ⚠️ **A synthetic long-press in the editor does not select text** — it triggers the app's own
  `onPastePointerDown` affordance (「粘贴计算详情」). So a scripted gesture could not manufacture the
  non-collapsed selection, and **the key press this section is about remains the user's to make.**
- **Where a non-collapsed selection can come from is now a closed question**, searched rather than assumed:
  the live writers in `lib/` are the inline editor's `onSelectionChanged` (`calculator_page.dart:498`, from
  `_synchronizeToCalculator`, `inline_expression_editor.dart:92-103`) and the persisted restore
  (`calculator_controller_persistence.dart:510`). `selectAll()` had **no caller in `lib/`** — and has since been
  **removed, with the one test that used it**, since nothing on screen could reach it (§6's own rule about
  unreferenced code). `applyPastedText` collapses (`cursorIndex = expression.length`). The trigger set is those
  two, and that is what this section's explanation rests on — no more.

⚠️ **And one operational rule this round broke: the writer stopped touching the device.** A main panel that
refuses capture is what a `FLAG_SECURE` window on top looks like, and the screen had gone from asleep to
awake — both consistent with **the owner using the phone**. Synthetic taps and key events sent at that moment
are not harmless, so the device work stopped there and was **not** resumed. Anyone repeating this should
check who is holding the phone before driving it.

### 5r. The manual-QA block, audited bullet by bullet: **one real defect**, and a smaller device list (2026-10-12)

`docs/release_checklist.md`'s Manual QA section had never been executed on a device. Before asking a human to
run it, all **24 bullets** were audited against the suite: each bullet either names a test whose **assertion**
proves the behaviour, or is reported as **not proven**. The standard mattered more than the tally, because this
project has been bitten in both directions: §5p records a grep that found *nothing* being read as absence, and
the mirror image — a grep that finds *something* — is worth just as little. A first, cruder pass reported
"coverage exists in all six areas" (14–89 test files mention each keyword); **that number is not evidence**, and
the bullet-by-bullet audit replaced it. Evidence base: 25 test files green on 2026-10-12
(`flutter test --concurrency=16`), with ⚠️ `test/data/app_database_v7_test.dart` **self-skipping without
`libsqlite3`** (`:62-65`) — so the Data-layer rows below rest on the in-memory fakes, not on real SQLite.

**The headline is a defect, not a gap: the graph ignores the app's angle mode.**
`graph_models.dart` hard-coded `ExpressionParser(parsed, degreeMode: false)` — **line 98 when this was written;
the call now reads `degreeMode: degreeMode` at `:117`, see §5s** — while the calculator passes
`degreeMode: angleMode == 'DEG'` (`calculator_controller_evaluation.dart:735`; ⚠️ that number has moved **twice**
in one day — see the extraction note below, and prefer the symbol) and `GraphPage` could not even
reach the mode: its constructor took only `db`, `restoreState`, `reloadToken` (it takes `angleMode` as of §5s).
So under
DEG the curve, the markers solved on it (zeros, intersections, extrema), and the calculator **disagree on the
same input**. ⚠️ **The sharpest form of description rot found so far is not in the docs but in the code**: the
comment two lines above the defect (then `:95-96`, now `:111-117` — and finally true) claims the parser is
shared 「保证计算器和图形函数语义一致」 —
the comment asserted **exactly the property the code did not have**. Confirmed by reading, and fixed in this
round; it is the one item here that was **known-wrong** rather than **known-unguarded**.

**Two more findings, each worth its own paragraph.**

- ⚠️ **The checklist had drifted from the product.** Its bullet "Mathematical symbol display and
  function-expression display both work" names a mode that **no longer exists**: 「函数表达式」 is a legacy
  storage token migrated on read (`lib/application/app_settings.dart:32,89-92`). A tester following the wording
  would hunt for an option that is not there. Corrected in the checklist itself rather than left for the
  tester to trip over.
- ⚠️ **Destructive actions with zero coverage**: 清空历史 (clear history) and the graph row menu
  (add/edit/hide/delete) mutate state, and **no test drives either** — `clearHistory` is referenced only as a
  fake-db method and as display strings. This is §5n's class: not known-broken, **known-unguarded**.

**What this does to the device work.** The irreducible list is narrower than "six areas": what genuinely needs
a phone is **smoothness and immediacy** (fast input lag, `=` latency, pan/zoom, per-keystroke tool recompute),
**persistence across a real relaunch** (memory, favourites/recents — every existing test uses an in-memory
fake), and **rendered readability** (the fit chart in light/dark, which this project's own rule says needs a
render check, not a token comparison). The audit handed back **14 further items that are testable without a
device** — including one test that would have caught the graph defect as a *sequence*: tap DRG, type `sin(90)`,
press `=`, assert `1`.

**Postscript, same day: the notes-search suspicion is confirmed, and its shape is exact.** The audit listed it as
a suspicion, so it was read rather than left ambiguous. `_databaseNoteQuery` (`notes_controller.dart:245-254`)
hands the query to SQL **only** when it matches `^[A-Za-z0-9一-鿿]+(\s+…)*$` — plain words and CJK.
Anything else — a date such as `2026-05-12`, an engineering symbol, any punctuation — returns `null`, so the
repository is called **with no query at all** and hands back its **first page** (`limit: _notePageSize`,
`:263-269`); the filter at `:85` then runs over that page alone. A note that matches a date query on page 2+
**cannot be found**: the search looks empty rather than incomplete. ⚠️ The comment beside it (`:248-249`)
correctly explains why the SQL prefilter cannot carry dates — **that part is sound; what is missing is any
handling of the consequence.**

**Fixed (2026-10-12) — and the fix turned out not to need what this paragraph predicted.** The prediction was
that the existing test pinning the prefilter would have to change in the same commit; **it did not**, because
the decision itself is preserved: `_noteLoadLimit` still uses `_notePageSize` for empty and plain-text queries —
`loads the first note page instead of reading every matching note` is untouched and still green — and only a
query that **must** be filtered locally (dates, symbols, punctuation) raises the scan cap to
`_localFilterScanLimit` (1000). What changed is the consequence, not the decision. ⚠️ **Red before the fix,
measured against the unmodified controller**: `Expected: contains <151> / Actual: MappedListIterable<NoteItem,
int>:[]` — an **empty** result — while the two neighbouring assertions (default load still 100, no query still
reaching SQL) passed **in the same run**, which is what makes it the right red rather than a broken fixture.
The test lives in its own file (`test/domain/notes_search_reach_test.dart`) because it pins *reach* where the
other pins *how much is read* — and because folding it back pushed that file to **817 lines**, over this
project's 800-line rule; the rule's own answer is to split by responsibility rather than delete the reasoning.

### 5s. The graph angle-mode fix, and the decision it deliberately did **not** make (2026-10-12)

§5r's headline defect is fixed. What a future reader needs is not that fact but two others: **what the fix
rests on**, and **the choice it handed back instead of applying**.

- **The mode now travels on the `GraphFunction` itself** (a `degreeMode` field, `graph_models.dart`), because
  all four evaluating paths — the plotted curve, the **four marker builders** (11 `evaluate` call sites in
  `graph_marker_builders.dart`), the y-window fit, and the input preview's probe — hold **nothing but a
  `GraphFunction`**. There was no other context to thread, which is why the field, not a page-level argument,
  is the shape that reaches all of them. Settings arrive through the shell (`app_shell.dart:217`), and
  `didUpdateWidget` re-stamps every function and **drops stale markers** when the unit changes, so a live
  DEG↔RAD switch moves the curve rather than leaving the previous unit's zeros on screen.
- ⚠️ **`GraphFunctionExpressionDialog.degreeMode` is `required`**, so a preview silently rendered in radians is
  a **compile error** rather than something a reviewer has to catch — the same trick the parser already used
  (`ExpressionParser`'s `degreeMode` was already a required named parameter, which is why no construction site
  could be missed).
- ⚠️ **The decision that was deliberately left alone**, and the reason this paragraph exists: the **workspace
  wire format carries no angle information**. `encodeGraphWorkspace` writes version, viewport and functions
  {expression, visible, color}; the copy-text and free-text paste formats likewise. A graph saved under DEG and
  restored — or pasted — while the app is in RAD is therefore evaluated **under RAD**. Changing that needs a
  **format version bump plus a new line in the bilingual copy-text wire format**, and the angle unit is an
  **app-level setting**, so the behaviour is defensible as it stands. It is **pinned by a test** rather than
  left to chance (`graph_page_test.dart`: a `sin(x)` written in radians, restored under DEG, has exactly one
  zero). **If a future release wants per-function units, that test is the sentence to revise and this
  paragraph is the record of why it was not done now.**
- ⚠️ **The red evidence is reported as two different things, because they are two different things.** One file
  failed on a **real assertion** — settings' degree mode reaching the graph page, `sin(x)` on [-6,6] having one
  zero under degrees instead of five — and two files failed as **compile errors**, because they exercise API
  that did not exist before the fix. A compile error is not assertion evidence; dressing it up as such is the
  same error as reading a grep that found nothing (§5p). Both are stated, neither is inflated.

⚠️ **And every `file:line` in §5q, §5r and §5s was re-checked hours later — four had already moved.** Each
citation in these three sections was verified against the working tree on 2026-10-12, and four were stale:
`calculator_controller_evaluation.dart:762 → 780 → 735` (the definitions verdict's insertion moved it, and then
the **same afternoon's** extraction of the wait responsibility moved it again — so the count of "how many times
this one citation has been chased" is now **three**),
`graph_models.dart:98 → 117` (this very section's fix — the hard-coded call the sentence describes *is* the line
that changed), `calculator_controller_editing.dart:398 → 404` and `calculator_controller_persistence.dart:447 →
459` (the cursor fix's deletions). ⚠️ **The pattern is the point: the fixes moved the lines that document them.**
That is the same rot this project keeps finding in prose — a sentence that was true when written and false when
read — and it takes the same mitigation the code comments needed: **name the symbol wherever the line is
load-bearing**, and where a line number describes a state that no longer exists, **mark it as a former position**
(as done in §5r) rather than quietly updating it, so a reader can still tell "this moved" from "this was always
wrong".

### 5t. The colour literals that really are off-token — and the two that were my own miscount (2026-10-12)

The directive asks for **UI consistency**, and §5h's claim was narrow: `app_theme.dart` maps every Material role
to a `CalcTheme` token and holds **no colour literal** — that still measures true. But the same grep run over the
rest of `lib/` returns **12 files**, and a count is not a finding. Reading every hit split them three ways:

- **Legitimate palettes — not defects.** `calc_theme.dart`'s 144 literals are the **definitions** (six themes ×
  ~23 tokens); `category_visuals.dart` (9) and `fit_chart_painter.dart` (4) and `graph_models.dart` (7) are
  per-identity colours (tool categories, chart series, function curves) that a theme cannot supply.
- ⚠️ **Two hits were mine, not the code's.** `status_chips.dart`'s two are inside **comments**;
  `text_tool_web_strings.dart`'s four are **prose** — that file *documents* the `Color(0xAARRGGBB)` syntax the
  text tool accepts. A strings file appearing in a colour grep looks alarming right up until it is read.
  **"12 stray literals" would have been a false finding**; the read is what made it true.
- **Genuinely off-token — 7 sites in 5 files:** ⚠️ `Colors.amber` **four times** as the favourite star
  (`tool_widgets.dart:315,323`, `tools_home_page.dart:585`, `tool_detail_screen.dart:236`) — and the reason it
  survived is worth more than the finding: **a test pins it**
  (`tool_category_screen_test.dart` asserts `favoriteIcon.color == Colors.amber`), so the literal reads as
  deliberate. ⚠️ **Whether that is a defect or a decision is a design call, not a measurement.** A favourite
  star keeps a semantic amber in most apps, while this palette is thematic — so the question is whether
  "favourite" is a *semantic* colour (keep amber, and say so in the code) or a *thematic* one (give it a token
  per palette). What was **not** defensible was the state at the time of the audit: an amber literal that
  *looks* deliberate because a test asserts it, with no sentence anywhere recording which of the two it is
  meant to be. ✅ **Closed the same day — and the decision was "semantic", with no colour changed.** The star
  keeps amber: an amber star is the industry-wide "favourited" at a glance, while a per-palette accent would
  read as something else in the violet, ocean and warm-sand themes (this app themes its *state* colours —
  error, indicator — but "favourite" is a **convention**). What changed is that the choice is now **a named
  constant with its reasoning written beside it** (`favoriteStarColor` in `tool_widgets.dart`), and the test
  asserts **that constant** instead of the literal — so it can no longer be an accident that merely looks
  deliberate. ⚠️ **The lesson worth keeping is about this list's own shape:** what it recorded as a defect was
  never the hue, it was **the missing sentence** — a findings list can point straight at a decision and still
  be read as a to-do.
  ⚠️ **And the other two sites turned out not to be visible at all — a consequence the first draft of this
  paragraph asserted without checking.** `graph_function_expression_dialog.dart:54`'s `Color(0xFF1677FF)` is
  passed into the preview **probe** as the `GraphFunction`'s colour, and `GraphFunctionInputPreview` has **no
  colour field** — so nothing draws it. It is a **latent** off-palette value that would surface only if a
  future change renders that preview as a curve. `app_chrome.dart:279,284,285,291`'s `Colors.white` +
  `Color(0xFFD8D3FF)` + `Color(0xFFE8ECF7)` sit on **fallback** branches taken only when the scheme is absent —
  ⚠️ **whether that branch is ever taken is now answered — it is not.** `softPanel` (`app_chrome.dart:274`)
  takes a **nullable** `BuildContext? context` and falls back only when it is null, and **all fifteen call
  sites** in `lib/` and `test/` pass one. So those three literals are **never drawn**, and a colour comparison
  could not have found them either way. ✅ They are **kept, not deleted**: a nullable parameter is an API
  decision, and the honest record is "unreachable today" rather than a silent removal.
  ✅ **And the sentence further down — "none of them is a rendering bug now" — has now been looked at, for the
  one item that is visible.** The favourite star was rendered in the **violet** palette (`lavenderMist`: a widget
  test rendering the tools home with one favourite, at 2×, to a PNG) and **looked at on 2026-10-12**. The amber
  star reads as a **deliberate highlight** on an otherwise cool screen — exactly the convention this decision
  claims — and **not** as "something else", which was the only real question it faced. ⚠️ So the decision holds
  **visually**, not merely by argument. ⚠️ Two caveats, both stated on purpose: the PNG shows **tofu boxes** where
  text should be (the widget-test environment has no CJK font — **not** an app defect, said here before someone
  files it), and the rest of that sentence — the app's other screens — is still **reasoning, not looking** ✗. ⚠️ **And one attempt at the harness is recorded here so the
  next one starts slightly ahead of this:** a `test/features/favorite_star_render_test.dart` was written — render
  the tools home in `lavenderMist` with one favourite, assert the star's colour is `favoriteStarColor`, and write
  a PNG for a human to look at — and it **hung**. The cause was an incomplete minimal fake database: a method the
  page awaits went through `noSuchMethod`, so the future never completed and `pumpAndSettle` span to its timeout.
  ⚠️ **It was deleted rather than committed, and that is the point: a test that hangs is worse than no test** — it
  hangs every future suite. What the next attempt needs: the fake must implement **every** method the page awaits
  (two were not enough), and the rendering half (`RepaintBoundary` + `toImage`) was written but never reached.
  ⚠️ **A second attempt then produced the look — and was still deleted.** With the fake completed to the **six**
  methods `ToolUsageRepository` awaits, the assertions ran (the PNG is written *after* them, so **its existence
  is what proves they passed**) and produced the image described above.
  ⚠️ **Three variants were then tried, and every one of them hung — after the body had finished.**
  `pumpAndSettle` was replaced with two **bounded** pumps (its own documentation forbids it while a timer is
  pending, and this page owns a 70 ms debounce), the page was **unmounted** before the test ended, and the run was
  left to the framework's `--timeout 60s` instead of being killed by hand. Each variant produced the PNG and then
  hung; ⚠️ `--timeout` **never fired**, so the fake-async clock was stuck somewhere the test body could not reach.
  ⚠️ **The fourth attempt landed it — and the fix was the one this record had just named.** The image half was
  moved inside `tester.runAsync` (`dart:ui` futures kept **outside** the fake-async clock), and the test passes in
  **under a second** where the previous three hung. ✅ **So the pin is in place**:
  `test/features/favorite_star_render_test.dart` asserts that every favourite star's colour is
  `favoriteStarColor`, rendering the tools home in `lavenderMist` — the palette that is that decision's only real
  test — and the PNG it writes is the image described above. ⚠️ What made the fourth attempt cheap is worth
  stating on its own: **the failure had been written down with its evidence, and that record needed exactly one
  attempt to pay for itself.** The two corrections above — the "teardown" inference that reading the log refuted,
  and the hypothesis that replaced it — are the whole reason this took **four tries instead of staying open**.
  The honest split, then:
  **visible today = the four amber stars, and only if that star is judged thematic; latent = the other three.**
  The count said 7; reading says the consequence is 4 at most, and **none of them is a rendering bug now**.
- ⚠️ **Why this is recorded rather than fixed here:** not one of them is a rendering bug today — the app's own
  themes are in force, so these are **places where the palette can drift**, and a colour change is exactly the
  kind of claim this project says needs a **render check**, not a token swap in the dark. The list is written
  down so the pass that changes colours starts from a measured list instead of from a grep count.

### 5u. The documents that describe this project to outsiders, audited (2026-10-12)

The same move as §5r and §5t — measure what the prose claims — applied to the texts a reader outside this
project actually meets. **Three of them were wrong, and one of those was a privacy claim.**

- ⚠️ **`PRIVACY.md` omitted a permission.** Its permissions section said "the vibration permission only", while
  `AndroidManifest.xml` also declares `android.permission.INTERNET` — and that one is **used**: the
  user-initiated "check for updates" action in Settings fetches the public release list from GitHub
  (`github_release_checker.dart`). **A privacy policy that omits one of the permissions is worse than one that
  lists none** — it lets the reader believe they have seen them all. It now lists both, with what each is for.
- ⚠️ **The same false sentence stood in two more places** — `release_notes_v1.0.0.md` ("Removed unused network
  permission … remains offline") and `CHANGELOG.md`'s v1.0.0 entry. Both are **records**, so both keep the
  original line and carry a **dated correction beneath it** instead of being rewritten; and the CHANGELOG's
  `Unreleased` list gained a bullet, because being told something untrue about permissions is something a user
  should see acknowledged.
- ⚠️ **`file_structure.md` contradicted `.gitignore`** — twice. It said `.flutter/` is "not committed", while
  **51 of its files are tracked on purpose** (`.flutter/flutter_tools_gradle/` is referenced by path from
  `android/settings.gradle.kts`), and it listed that same directory under "generated files that are not
  committed". `.gitignore` had it right, and explained why.
- ⚠️ **`architecture.md` pointed at a directory that no longer exists** ("the old root `app/` native module …"),
  which sends a reader looking for something absent. The directory is not on disk at all.
- ✅ **And one was clean, measured rather than assumed:** `README.md`'s version and status claims match
  `pubspec.yaml` and `app_info.dart`, and its "three selectable colour themes … each with a light and a dark
  variant" matches the palette exactly — `calc_theme.dart`'s three light `CalcTheme`s (`roseCream`,
  `lavenderMist`, `peachSugar`) plus their three `_…Dark` constants, with the picker offering those three ids.

⚠️ **The shape worth keeping separate from rot:** three of these four were **not** stale-but-once-true. They
were **never true** — "removed the network permission" never happened. This document's whole vocabulary has been
about rot (§5s, §5t: true when written, false when read), and a sentence can also simply be **wrong on day
one**. Nothing distinguishes the two except reading the claim against the artifact it describes.

✅ **And the *current* release notes hold** — `docs/release_notes_v1.2.0-beta.1.md` was audited last, because
its claims are the ones a user reads *before installing*: its version matches `pubspec.yaml` and `app_info.dart`,
its ABI list matches the three split APKs actually built (4009 / 3009 / 6009), and its samplable bullets check out
one by one — 204 test files (the "broader coverage" claim), the controller split into **14 `part`s** (the
"decoupled" claim), and the structured result objects it names (`CalculatorSubmitResult`,
`BackupImportReport`, …) really exist. ⚠️ It does **not** mention the cursor-key fix — and that is **correct**:
the fix postdates this release and lives in the CHANGELOG's `Unreleased` list. A pre-release note should not
reach forward to work that came after it, and the absence reads as a gap only if you forget which side of the
release you are on.

### 5v. The capability register itself, audited — and it holds (2026-10-12)

`docs/comparison-with-hiper.md` is the 496-line, 88-row register of "what this app has that HiPER does not". It
is the closest thing this project has to an answer for 「超越 HiPER」, so it was measured the same way as §5u —
**against the artifacts it cites**, not read as prose:

- ✅ **No phantom citations.** Every file it names exists (`app_unit_catalog.dart`, `calculator_keypad.dart`,
  `arithmetic_steps.dart`, …). The one weak spot — `engine-capability-probe.md`, cited three times and living
  **inside the gitignored `.superpowers/` tree** — is **flagged by the document itself** (「仓库读者打不开」),
  and that self-limitation is what makes the rest of it usable.
- ✅ **A sample of six capabilities traces to real tests**, one by one: solving (`2x+1=7 → x=3`), LaTeX copy,
  the 120-symbol unit catalogue, graph zeros/intersections/extrema, multi-series data fit, and backup validation
  before import — each matched to the test files that pin it.
- ✅ **And it marks its own gaps**: 28 `未量` / `❌` / `⚠️` marks, an explicit rule at `:38` — 「`未量` 与 `❌` 是
  两种不同的状态」 — and at `:416` a row recorded as corrected from "未量" to a measured reading.

⚠️ **What this establishes, and what it does not, stated plainly:** it establishes that the register is
**accurate**, which is the only property of it measurable from inside this repository. It does **not** establish
that the app surpasses HiPER — that needs the other app, which is not here. **An accurate register is what makes
such a claim checkable later; it is not the claim.**

⚠️ **And this audit missed one — which is worth as much as what it found.** Its citation check covered `.dart` /
`.kt` / `.md` paths, so the register's row for 拍照解题 — whose evidence cell read **`hiper.txt:728-745`** — went
through untouched. **That file is no longer on disk**, and the manual's text is not in the scratch tree in any
other form (the one `.html` there matches `拍照` / `photo` / `OCR` / `camera` **zero** times). The *fact*
survives — the manual's lines 728–745 are a photo-solving section, and the register records it in two further
places — but its **provenance is gone**, so a reader cannot re-check it. ⚠️ **That is §5s's rot, found inside
the audit that was looking for rot**, and it was missed only because the check had a **narrower extension list
than the documents it was checking**. The row's own evidence cell now says so. ⚠️ The trade-off is the familiar
one: a narrow check cannot cry wolf (§6), and a narrow check also has blind spots — the honest move is to
**record the blind spot** rather than widen the check until it starts crying wolf.

### 5w. The shape behind three of today's findings: evidence pointing into the scratch tree (2026-10-12)

Three separate findings this day had **one shape** — a citation into the **gitignored** `.superpowers/` tree:

- **`hiper.txt:728-745`** (the register's photo-solving row): the file is **gone from disk** (§5v).
- **`HANDOVER.md`**: **nine** references, and the file is **neither tracked nor on disk** (§2's note).
- **"(真机截图)"** on three register rows: **no path at all**, so there was nothing to check even while the
  screenshots still existed.

So the tree was swept once: **26 tracked files** mention `.superpowers/`. ⚠️ **And the sweep's answer is
reassuring rather than damning** — the project's habit is already the right one. Most of those files say
「**逐字抄本在** `.superpowers/…`」: **the content is copied inline and the scratch path is cited as provenance**,
which is exactly the mitigation this section keeps prescribing. The failures were the exceptions: a pointer that
was the **only** record, a cited file that later **vanished**, and a screenshot referred to **without a name**.

⚠️ **The principle, stated once so it stops being rediscovered piecemeal:** evidence has to point at something
**tracked**, or the thing itself has to be **quoted where it is cited**. The scratch tree is a working surface,
not an archive — anything whose only copy lives there is **one cleanup away from being unverifiable**.

⚠️ **And the classification behind that claim needed measuring twice.** A first pass sorted the 26 files by
whether they contain the words 抄本 / 逐字 / verbatim / quote, and reported **21 quoted, 4 pointer-only**. Opening
those four: **all four targets still exist on disk**, and in each case the fact is already in the comment — e.g.
`roman_numeral_test.dart` says the values `400` / `900` / `1990` / `2026` / `3888` / `3999` were 「逐条量过」 and
cites the probe as *provenance*. So the heuristic had **false positives** (it keyed on one particular spelling of
"quoted" — 逐条 is not 逐字), and the honest count is: **every surviving citation either quotes its content, or
points at a file that is still there.** ⚠️ **Nothing in this repository is currently one cleanup away from being
unverifiable** — the three failures this section records (`hiper.txt`, `HANDOVER.md`, the unnamed screenshots) are
**historical**, and each is now marked where it was cited. ⚠️ **A word-matching heuristic is not a reading**: the
four files had to be opened to discover that the count had been wrong in the reassuring direction.

### 5x. Measurements written into prose, and whether anything recomputes them (2026-10-12)

Three findings this day were the same shape — **a measurement that exists only as a comment** — so the codebase
was swept for the two vocabularies those findings used, and every hit was checked for a test that recomputes it.

- **Colour vocabulary** (`ΔE` / `CIE76` / `WCAG` / `对比度`): **three** sites. Two now recompute —
  `fit_chart_series_contrast_test.dart` and `tool_identity_colors_test.dart` — and the third
  (`app_drawer.dart`'s 「两对颜色都是主题里配好对比度的」) is already backed by `calc_theme_test.dart`'s
  token-contrast rule. ⚠️ **Five figures did not reproduce, and are labelled as such rather than deleted:** the
  fit chart's amber **48.9 → 64.1** and green **75.3 → 109.0**, and the identity cards' adjacent-card
  **40.7 → 30.2** (under *both* pairings tried). Each belongs to an **earlier arrangement**; the *direction* of
  every claim still holds, and the comments now say which numbers may no longer be cited.
- **Size vocabulary** (`dp` / `px` / 宽 / 高): concentrated in **one** file, `calculator_display.dart`, and
  ⚠️ **already recomputed** — `calculator_display_test.dart` renders at exactly `panelHeight = 182`, measures the
  result row's natural height *at* that floor, and checks that the row does not move between 182 and 230.
  ✅ **And that file practised this section's rule before this section existed:** its comments keep two `176`s
  deliberately, with the reason written beside them — 「那是在 176 上观测到的事实，改成 182 就成了一个没量过的说法」.
- ⚠️ **A sweep is only as good as its vocabulary, and the first attempt proved it:** matching *any decimal
  number* returned noise (78 "hits" in a file that merely does arithmetic), while matching the **measurement
  words** returned three sites. **A count is not a reading** — the four pointer-only files in §5w had to be
  opened for exactly that reason, and there the count had been wrong in the reassuring direction.
- ⚠️ **A third vocabulary — the layout transcription — is *not* closed, and closing it is the best remaining item
  of this kind.** The keypad's fidelity to HiPER rests on the class comment in `hiper_keypad_number_rows.dart`,
  which records a **careful reading of two screenshots** (the vendor's current default, and this machine's device
  screenshot — two layout versions, with the vendor's own strings cited for why they differ).
  `keypad_definition_test.dart`'s per-cell snapshot pins **our** faces, but **not that they equal HiPER's**. ⚠️
  **The way to close it is clear, and it would be the first comparison this project runs *against* HiPER rather
  than *about* it:** transcribe the vendor's current default layout into a **tracked test fixture**, then assert
  our keypad equals it **cell for cell**, bands included. ⚠️ **Deliberately not attempted on 2026-10-12, at hour
  17.7:** the work *is* a careful transcription, and this day's demonstrated failure mode was exactly that — nine
  miscounted-indentation slips in one evening. **A test that enshrines a mis-transcription is worse than no test**,
  so the transcription is left for a sitting with attention to spare, and this paragraph is its brief.

## 6. Seven mechanical checks that exist because of repeated mistakes

All seven guard one of **four** shapes: an action that did nothing looks exactly like one that ran and had no
effect; a limit nobody is watching gets crossed without anything happening at all; a rule that lives in a file
nothing reads — so deleting it looks like nothing at all; or **a sentence that was true when written and false
when read**, which is what a citation becomes the moment someone edits the file it points at.

⚠️ The two newest (the 800-line cap and the portrait lock) come from **the user's own stated rules** rather than
from a mistake of mine, and the heading above is kept only because the failure mode is the same one: **a rule
that only memory enforces is a rule that breaks silently.** That is also why the portrait guard strips XML
comments before judging — the manifest's own comment *names* both strings it requires, so a raw substring check
would pass on a manifest whose attributes had been deleted.

⚠️ **The table's two device tools were audited on 2026-10-12, and both hold up by design.** They were re-read
because that day's device work produced two facts that *could* have made them stale — the `versionCode` split and
a credential failure on push. ⚠️ `install_debug_over_release.sh` **reads the installed `versionCode` off the
device** instead of hard-coding it (the `4009` in its header is *history*, not a constant), so the split can change
underneath it without the script going wrong; `pull_device_db.sh` carries the `-wal` handling its own row
describes. ⚠️ Recorded deliberately: **a clean audit of a tool is worth as much as a defect found in one** — it is
what stops the next person from "fixing" a script that is already right.

| Check | Guards against |
|---|---|
| `test/features/math_reachability_test.dart` | a file under `lib/core/math/` that **nothing references** |
| `test/features/new_text_tools_screen_test.dart` | a tool **registered but unreachable on screen** |
| `tool/pull_device_db.sh` | pulling the SQLite database **without its `-wal`** (reads a stale value) |
| `tool/install_debug_over_release.sh` | losing the device's debuggable build — it **sidesteps** the versionCode (build the debug variant at the installed one) instead of fighting the downgrade guard (§2) |
| `test/features/file_size_limit_test.dart` | a source file under `lib/`, `test/` or `android/app/src/` **drifting past the user's 800-line cap**. The cap was kept by memory alone until 2026-10-12, when two slips of mine came from the same shape — a new test pushed `notes_controller_test.dart` to **817 lines**, and `calculator_controller_evaluation.dart` sat at **798**, two lines from the edge. Survey that day: **nothing over the line, 36 files above 700** — one small change between the pressure and the breach. The guard's own reading is `wc -l`-identical on purpose (see its header): an instrument that miscounts by one line would cry wolf, and a guard that cries wolf gets switched off. |
| `test/features/manifest_portrait_lock_test.dart` | the **portrait lock** disappearing from `AndroidManifest.xml`. The user stated this rule twice (「不需要做屏幕旋转，**禁止屏幕旋转**」) and it lived only in that file, with nothing reading it. The manifest's own comment explains that `screenOrientation` **alone is not enough** under `targetSdk = 36`, so the guard asks for **both** halves — and it **strips XML comments first**, because that comment *names* both strings and a raw substring check would pass on a manifest whose attributes had been deleted. |
| `test/features/doc_citations_test.dart` | a `file:line` citation in the docs **pointing past the end of the file it names**. On 2026-10-12 one citation was chased **three times in a single day** — `762 → 780 → 735` in `calculator_controller_evaluation.dart` — because **the fixes are what move the lines that document them**. The judgement is one sentence (the file exists ∧ the cited line is greater than its length) and deliberately does **not** fire on a missing file (a historical mention is legitimate) or on a `762 → 780 → 735` chain (a record of movement, not a citation) — ⚠️ that second cell was a **measured** false positive in the first version of the sweep, and a guard that cries wolf gets switched off. |

⚠️ **Measuring trap, learned the hard way**: `meetsGuideline` reports failures **asynchronously** —
`expect(...)` does not throw. try/catch cannot be used to see whether it passes.
