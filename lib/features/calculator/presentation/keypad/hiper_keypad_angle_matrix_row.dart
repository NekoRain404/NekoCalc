part of 'hiper_keypad.dart';

/// 中文：**行 2——DRG / x⇔E / 矩阵 / 求和 / 求积 / 相机**，连同它那一横带的五格提示。
///
///       **这条缝为什么在这里。** 它是**一整行**，而这一组的两次拆分用的都是同一条规矩：缝落在
///       **区域之间**（`hiper_keypad.dart` 的文件头自己写着「两次拆的都是数据，缝落在区域之间或
///       横带的性质之间」）。功能键区那三行横带只有提示的行（1、2、4）原先住在一个文件里，而本行
///       的份量是另外两行合计的近两倍——最近两轮的全部改动（`▸DRG` 点亮、`MTRX` 点亮、`FSE` 退回
///       提示、📷 重新量过布局版本）也都落在这六格上，每一处都带着自己那一段来源与实测。把它整行
///       搬到自己的文件里，下一次动这一行的人不必先绕过另外两行的档案；留在这里的两行与行序表
///       （`_functionRows`）不变。
///
///       **行序仍由 `_functionRows` 一处说了算**（它在 `hiper_keypad_function_rows.dart` 里，
///       名字 `_angleAndAggregateRow` 就写在那张表上）：本文件只是内容，缺一个或改一个名字都是
///       编译错误——这条缝由编译器守着，不靠注释。**搬的只是位置，六颗键、五格提示与它们的
///       id 一个字都没有动。**
///
/// English: **row 2 — DRG / x⇔E / matrix / Σ / Π / camera**, together with its band's five hints.
///
///          **Why the seam is here.** It is **one whole row**, and both earlier splits in this group
///          used the same rule: the seam falls **between regions** (`hiper_keypad.dart`'s own head
///          says "both times what got split is the data, along a region boundary or along the nature
///          of the band"). The three hint-only-band rows of the function half (1, 2, 4) used to share
///          one file, and this row alone is nearly twice the other two put together — the last two
///          rounds' entire work (`▸DRG` lit, `MTRX` lit, `FSE` demoted to a hint, the camera's layout
///          version re-measured) landed on these six cells, each carrying its own provenance and
///          measurements. Moving the row whole into its own file means the next change to it does not
///          have to walk past two other rows' dossiers; the two rows that stay and the row-order table
///          (`_functionRows`) do not move.
///
///          **The row order is still decided in one place** (`_functionRows` in
///          `hiper_keypad_function_rows.dart`, where the name `_angleAndAggregateRow` is written): this
///          file is content only, and a missing or renamed row is a compile error — the compiler
///          guards this seam, not a comment. **Only the position moved: the six keys, the five hints
///          and their ids did not change by one character.**

// 中文：行 2——DRG / x⇔E / 矩阵 / 求和 / 求积 / 相机。
//       上方标签：▸DRG（**`▸DRG` 的 SHIFT 提示，已点亮**——HiPER 那一格是 `TO_DRG`
//       「换算角度单位」，与本行下方 `DRG` 那颗键的「切换角度单位」**是两个命令**：前者换算**当前
//       显示的那个数**、先问源单位与目标单位，后者换的是**模式**。本轮建起了前者：`openAngleConvert`
//       打开一个面板，选好源与目标之后把整条表达式换成 `<值> <源单位> to <目标单位>`。来源、理由与
//       被拒绝的 `grad` 写在下面 `DRG` 那颗键的长注释里），
//       FSE（**`x⇔E` 的 SHIFT 提示，已接上**——上一轮它被做成横带里一颗可点的 `InlineKey`，
//       本轮按来源退回提示，理由见下面 `x⇔E` 那颗键上的长注释。那一维在 HiPER 上有五档——
//       Normal / Fixed / Scientific / Engineering / Engineering SI，**本应用只接得上三档**
//       （Normal / Scientific / Engineering），缺的两档与理由写在
//       `calculator_controller_notation.dart` 的文件头上，缺就是缺。上方的键 `x⇔E` 的**基准**
//       管的是结果**形式**那一维，SHIFT 才是记法——两维不是一件事）、
//       MTRX（**矩阵键的 SHIFT 提示，本轮真的点亮了**——HiPER 那一格是 `MATRIX_MENU`
//       「矩阵与向量菜单」，本轮建起了这个菜单：`openMatrixMenu` 打开一个面板，面板里四项各插一条
//       围着 `matrix(2,2,1,2,3,4)` 的完整调用；同一份实测里也量出 `rank`/`trace`/`echelon` 三个
//       必须拒绝的名字，它们在面板里是灰的。来源、理由与被拒绝的那三个写在下面矩阵键的长注释里）、
//       Π（Σ 的 SHIFT 提示，已接上）、d/dx（∫dx 的 SHIFT 提示，
//       **已接上**：SHIFT 态下按 `∫dx` 插的是 `diff(x^2,x)`，实参顺序是引擎自己的，不是 HiPER
//       手册那套——两槽而不是四槽的理由在 `calculator_key_dispatch.dart` 的 `ins:diff` 那一段）、
//       相机键上方无标签。**📷 本身仍未点亮，理由来自 HiPER
//       自己的字符串**：`command.name.CAMERA` = "Expression recognition"；`cameraWindow.policy.info`
//       写明选区图像**会被发往服务器**、由第三方模型 Pix2Text 识别（`recognitionWindow.pix2text`），
//       `cameraWindow.proVersion` 说这是 Pro 专属。本机没有可分发的识别器，本机 OCR 只会产出
//       **看似正确、实则错误**的表达式，故保持禁用（见相机键报告 camera-key-report.md）。
//
//       **一处实测更正（本轮）：这一格跟的是厂商当前的默认键盘，不是本机那张截图——所以相机键留在原位。**
//       两张图都对，差的是**布局版本**：
//       1. **厂商官网的当前主屏截图**（`https://hiperlabs.eu/screenshots.html` →
//          `assets/img/01 calculator.png`，本轮自己下载、逐格读过）：第 2 行第 6 格是**相机键**
//          （上方无标签），而 `CNST`/`CONV` 落在 `1`/`2` 的横带上——与本表**逐格一致**。
//       2. **本机那张 1440×3200 真机截图**（`~/Downloads/04_媒体/…cz.hipercalc.p.jpg`）量到的是**另一个
//          布局**：第 6 格是 `CONV`、`CNST` 是它的第二功能（横带那一格），`1`/`2` 上方是 `gcd`/`lcm`。
//       3. **厂商自己的字符串把这件事说明白了**（`cameraWindow.cameraRevoked.info` /
//          `cameraWindow.permissionRevoked.text`）："If you want to use the former keyboard layout with
//          the `<key:CONST>` and `<key:CONV>` keys **in their original positions**, … select the
//          **Custom / Version 10 keyboard**."——本机截图那一版就是 Version 10；当前默认布局把
//          `CONST`/`CONV` 挪到 `1`/`2` 的横带、把原来那一格给了相机键。
//       所以**这颗 `📷` 不是本应用自加的**（本表的出处是规格书第 24 行那张从厂商官方手册 PDF v12.0
//       解出的网格），把它从这一格删掉会让本表与厂商**当前**键位出现新的偏差。**结论：留原位、仍禁用。**
//
//       **一处更正（更早一轮实测）**：本注释过去写着「HiPER 的 `▸` 只是装饰」。**那句话不成立**，
//       换掉它的是三条量出来的事实，写在各颗键的注释里：`▸` 是这个**换算家族**的名字的一部分
//       （厂商自己的更新日志把 `▸BASE` 写成一个函数名，U+25B8），不是「这是一颗按钮」的记号——
//       带它的 `►DRG` 与不带它的 `FSE`/`MTRX`/`Π`/`d/dx` 在截图上**逐像素同一种画法**
//       （字形核心 (159,161,168)、无胶囊底），而横带里每一颗**真按钮**都戴着胶囊底。
//       **本轮把 `▸` 按这个名字画进键面**：横带那一格与 `DRG` 的 SHIFT 键面都写 `▸DRG`，四个进制胶囊
//       写 `▸BIN`/`▸OCT`/`▸DEC`/`▸HEX`（依据与逐格读数在 `hiper_keypad_number_rows.dart` 行 7 那一段）。
//       这一处键面偏差到此关掉；`CONV`/`CNST` 不带 `▸`，两处都照厂商的写法。
// English: Row 2 — DRG / x⇔E / matrix / summation / product / camera.
//          Band above: ▸DRG (**the SHIFT hint of `DRG`, wired** — on HiPER that cell is
//          `TO_DRG`, "Convert Angular Units", which is **a different command** from the `DRG` key
//          below it in the same row: the former converts **the number currently displayed**, after
//          asking for a source and a target unit, while the latter switches the **mode**. This round
//          builds the former: `openAngleConvert` opens a sheet, and once a source and a target are
//          chosen it replaces the whole expression with `<value> <source unit> to <target unit>`.
//          The sources, the reasons and the refused `grad` are in the long note on the `DRG` key
//          below), FSE (**the SHIFT hint of `x⇔E`, wired** — the previous round made it a tappable
//          `InlineKey` in this band; this round puts it back to a hint per the sources, and the
//          reasoning is on the `x⇔E` key's long note below. On HiPER that dimension has five
//          positions — Normal / Fixed / Scientific / Engineering / Engineering SI — and **this app
//          can only reach three** (Normal / Scientific / Engineering); the two that are missing, and
//          why, are on the file head of `calculator_controller_notation.dart`. Missing is missing.
//          The **base** action of the key under it, `x⇔E`, owns the result **form** dimension; the
//          notation dimension sits on SHIFT — two different things), MTRX (**the matrix key's SHIFT
//          hint, really lit this round** — on HiPER that cell is `MATRIX_MENU`, "Matrix and Vector
//          Menu", and this round builds that menu: `openMatrixMenu` opens a sheet whose four entries
//          each insert a complete call around `matrix(2,2,1,2,3,4)`. The same set of measurements also
//          produced the three names that must be refused, `rank`/`trace`/`echelon`, which are the sheet's
//          grey rows. Sources, reasoning and those three are in the long note on the matrix key below),
//          Π (hint of Σ, now wired), d/dx (hint of ∫dx, **now
//          wired**: under SHIFT the `∫dx` key inserts `diff(x^2,x)`, in the engine's own argument
//          order rather than the manual's — the note on `ins:diff` in `calculator_key_dispatch.dart`
//          says why two slots and not four); the camera key has no hint. **📷 itself stays unlit, on
//          HiPER's own strings**: `command.name.CAMERA` is "Expression recognition";
//          `cameraWindow.policy.info` says the cropped image **is sent to a server** for the
//          third-party Pix2Text model to recognize (`recognitionWindow.pix2text`), and
//          `cameraWindow.proVersion` marks it Pro-only. No such recognizer exists here, and a local
//          OCR would only yield a **plausible but wrong** expression — so it stays disabled (see
//          camera-key-report.md).
//
//          **One measured correction (this round): this cell follows the vendor's *current* default
//          keyboard, not the device screenshot — so the camera key stays where it is.** Both pictures
//          are right; what differs is the **layout version**:
//          1. **The vendor's current main-screen screenshot** (`https://hiperlabs.eu/screenshots.html`
//             → `assets/img/01 calculator.png`, downloaded and read cell by cell this round): row 2's
//             sixth cell is the **camera key** (nothing above it), and `CNST`/`CONV` sit on the `1`/`2`
//             band cells — **cell for cell the same as this table**.
//          2. **The device screenshot on this machine** (the 1440×3200 file cited above) measured a
//             **different layout**: that cell is `CONV` with `CNST` as its second function, and `1`/`2`
//             carry `gcd`/`lcm` above them.
//          3. **The vendor's own strings settle it** (`cameraWindow.cameraRevoked.info` /
//             `cameraWindow.permissionRevoked.text`): "If you want to use the former keyboard layout
//             with the `<key:CONST>` and `<key:CONV>` keys **in their original positions**, … select
//             the **Custom / Version 10 keyboard**." The device screenshot is that Version 10 layout;
//             the current default moved `CONST`/`CONV` onto the `1`/`2` band and gave their old cell to
//             the camera key.
//          So **this `📷` was not added by this app** (the table's provenance is the grid on line 24 of
//          the spec, decoded from the vendor's official manual PDF v12.0), and deleting it from this
//          cell would open a **new** deviation from the vendor's current keypad. **Conclusion: it stays
//          in place, and stays disabled.**
//
//          **One correction (measured a round earlier)**: this note used to say "HiPER's `▸` is
//          decoration". **That sentence does not hold**, and three measured facts replace it (they
//          are written out on the keys themselves): `▸` is part of the **name of the conversion
//          family** (the vendor's own release note spells the name of one of them `▸BASE`, U+25B8) —
//          it is **not** a "this is a button" marker, because a cell carrying it (`►DRG`) and cells
//          that do not (`FSE`/`MTRX`/`Π`/`d/dx`) are drawn **pixel for pixel the same way** (glyph
//          core (159,161,168), no capsule), while every real band **button** wears a capsule.
//          **This round draws the `▸` that name asks for**: the band cell and the `DRG` key's SHIFT
//          face both read `▸DRG`, and the four base pills read `▸BIN`/`▸OCT`/`▸DEC`/`▸HEX` (the evidence
//          and the cell-by-cell readings are in the row-7 note of `hiper_keypad_number_rows.dart`).
//          That key-face deviation is closed; `CONV`/`CNST` carry no `▸` and are written as the vendor
//          writes them.
const KeypadRow _angleAndAggregateRow = KeypadRow(
  keys: <KeypadKey>[
    // 中文：**`DRG` 的 SHIFT 功能是 `TO_DRG`「换算角度单位」——与这颗键的基准不是同一个动作，
    //       本轮真的点亮了**（`openAngleConvert`）。下面按顺序说清楚三件事。
    //
    //       **一、HiPER 上它是 `DRG` 的第二功能，不是一颗独立的键。** 四条来源（上一轮量的，本轮
    //       一条都没动——它们是这一格**挂在这里**的理由，与它能不能点亮无关）：
    //       1. **位置**：1440×3200 原图（`~/Downloads/04_媒体/Screenshot_2026-05-12-13-11-45-205_cz.hipercalc.p.jpg`）
    //          第 2 行横带 `y=1225..1310`，六格字形列中心 `128.0 / 364.5 / 602.0 / 838.0 / 1075.5 /
    //          1311.5`，下方主键 `y=1314..1437` 的列中心 `127.5 / 364.0 / 601.0 / 838.0 / 1074.5 /
    //          1311.0`——**六格对六键，最大差 1.0 px**（列宽 238 px）。`►DRG` 与 `DRG` 差 **0.5 px**。
    //       2. **HiPER 自己给这个位置下了定义**：`quickTour.page.SECOND_FUNCTION.text2` = "The key's
    //          second function is displayed in the label above."；手册 v12.0 §SHIFT 第 517–525 行
    //          （`https://hiperlabs.eu/assets/raw/hipercalc-manual-12.0.pdf`，`pdftotext -layout`
    //          后即此行号）"Symbols of these secondary functions are displayed above their keys."。
    //       3. **画法**：横带里每一颗**真按钮**都戴浅色胶囊底（四个进制胶囊：字块占满整格宽，
    //          亮像素占比 0.21–0.61），每一格**第二功能记号**都是平排文字（亮像素占比 0.02–0.09）。
    //          `►DRG` 是平排文字（0.052），字形核心 **(159,161,168)**——与 `FSE`/`MTRX`/`Π`/`d/dx`/
    //          `CNST`/`hyp`/`sin⁻¹`/`logₓy`/`lim`/`x³`/`n!`/`gcd` **逐个像素同值**，也就是与所有
    //          已被认定的第二功能记号同一种画法。
    //       4. **`▸` 不是「这是一颗按钮」的记号。** 厂商自己的更新日志把这一族的名字写成
    //          **`▸BASE`（U+25B8）函数**（`msgctxt "releaseNotes"`，厂商字符串表第 8888 行：
    //          "\\u25B8BASE function available in custom keyboards"——本轮重新取回核对过，
    //          地址与抄本见 `.superpowers/backup/mtrx-drg-report.md:150`；抽取文件
    //          `/tmp/hiper_en.po` 在本机 `/tmp`、已不存在），而同一族在**展开布局**里是 `►DEG`/`►RAD`/`►GRAD`
    //          三颗键——展开布局**没有 SHIFT 键、也没有第二功能**（手册 §SHIFT："Expanded and pocket
    //          layouts do not have SHIFT key and all functions are accessible by 'one click'"）。
    //          所以这个箭头属于**换算命令的名字**，不属于控件的种类。（**`►GRAD` 那颗键的拼法正是
    //          下面面板里灰掉的那一行**：引擎里的 `grad` 不是一个角，见第三条。）
    //
    //       **二、它是什么动作：`TO_DRG`，与 `DRG` 是两个命令。** `command.name.DRG` = "Switch
    //       Angular Units"（手册："Use DRG key (or DEG etc. in expanded layout) to switch among these
    //       units."、"Cycle by DRG until RAD angular unit is checked"），`command.name.TO_DRG` =
    //       "Convert Angular Units"，手册第 678 行把后者说全了：**"►DRG key in compact layout opens
    //       the menu to choose source and target angular units and converts the current display
    //       number."** ——一个换的是**模式**，一个换的是**当前显示的那个数**，并且要选源与目标。
    //       （`x⇔E`/`FSE` 是同一种「相邻两条命令」的形状，上一轮已核。）
    //
    //       **三、本轮点亮它靠的是什么，以及上一轮那两句错话。** 这个动作今天做得了，是因为翻译层
    //       开了一条**只有一个形状**的窄路（`engine_expression.dart` 的 `_angleConversion`：
    //       `<值> <角度单位> to <角度单位>`，两侧都是写出来的单位词），六个角度拼法逐个量过
    //       （表在 `app_unit_catalog.dart` 的 `kAngleUnits` 上）。面板、取舍与 `grad` 那一行灰格的
    //       凭据在 `calculator_page_angle_sheet.dart` 的文件头上。
    //
    //       **上一轮的注释在这里写着「源单位说不出来、反方向（→ 度）不存在」——本轮实测把这两句都
    //       改掉了，两处都留在这里免得下一轮再抄一遍：**
    //       - **「反方向不存在」是假的。** 引擎一直做得了 `90 rad to deg`（实测 = `5156.620156°`）；
    //         过去过不去的是**应用这一侧**（`deg` 不是可插入单位拼法），不是引擎做不到。
    //       - **「`90 to deg` 只是贴了个记号、值一个字节没变」只在 DEG 下成立。** 同一个输入在 RAD 下
    //         实测是 `5156.620156°`（引擎把 90 读成弧度）、在 GRA 下是 `90.00000000 d·°` 那一族。
    //         正确的说法是「**不写源单位时，源单位就是当前角度模式**」——`90 to rad` 在三档下分别是
    //         `1.570796327 rad` / `90 rad` / `1.413716694 rad`。**这正是本应用新面板永远把源单位写
    //         出来的理由**（写全了，答案与角度模式无关：`90 deg to rad` 三档同答）。
    //       - 那份「`degrees`/`radians` 过不去」的读数今天仍然成立（那两个拼法不在应用的单位表里），
    //         但它们**不是引擎读不懂**（实测 `90 degrees to rad` = `1.570796327 rad`），而是本应用
    //         没有给它们拼法——与 `zorkmid` 那一类同一条路。
    //
    //       **基准动作 `angleMode` 一格未动**：那颗键按下去仍然是 DEG↔RAD 的模式开关，不换算任何数，
    //       也不碰表达式（本文件下面那段与 `calculator_key_dispatch.dart` 的 `angleMode` case 都没动）。
    // English: **`DRG`'s SHIFT function is `TO_DRG`, "Convert Angular Units" — not the same action as
    //          this key's base, and really lit this round** (`openAngleConvert`). Three things, in
    //          order.
    //
    //          **1. On HiPER it is `DRG`'s second function, not a key of its own.** Four sources
    //          (measured last round and untouched by this one — they are why the cell is **mounted
    //          here**, which is independent of whether it can light up):
    //          1. **Position**: on the 1440×3200 original cited above, the six glyph column centres
    //             of row 2's band (`y=1225..1310`) are `128.0 / 364.5 / 602.0 / 838.0 / 1075.5 /
    //             1311.5` and those of the keys below (`y=1314..1437`) are `127.5 / 364.0 / 601.0 /
    //             838.0 / 1074.5 / 1311.0` — **six cells over six keys, largest gap 1.0 px** (column
    //             width 238 px). `►DRG` sits **0.5 px** from `DRG`.
    //          2. **HiPER defines what that position means**: `quickTour.page.SECOND_FUNCTION.text2` =
    //             "The key's second function is displayed in the label above."; the manual's SHIFT
    //             section (`hipercalc-manual.txt:517`) "Symbols of these secondary functions are
    //             displayed above their keys."
    //          3. **How it is drawn**: every real band **button** wears a light capsule (the four
    //             base pills: the glyph block spans the whole cell, light-pixel fraction 0.21–0.61),
    //             while every **second-function symbol** is plain text (0.02–0.09). `►DRG` is plain
    //             text (0.052) with glyph core **(159,161,168)** — the same value, pixel for pixel, as
    //             `FSE`/`MTRX`/`Π`/`d/dx`/`CNST`/`hyp`/`sin⁻¹`/`logₓy`/`lim`/`x³`/`n!`/`gcd`, i.e. the
    //             drawing every already-established second-function symbol has.
    //          4. **`▸` is not a "this is a button" marker.** The vendor's own release notes spell the
    //             family's name as the **`▸BASE` (U+25B8) function** (`msgctxt "releaseNotes"`, line
    //             8888 of the vendor string table: "\\u25B8BASE function available in custom
    //             keyboards" — re-fetched and checked this round; address and copy in
    //             `.superpowers/backup/mtrx-drg-report.md:150`, and the extracted file
    //             `/tmp/hiper_en.po` was on this machine's `/tmp`, gone), and the same family appears
    //             in the **expanded** layout as `►DEG`/`►RAD`/`►GRAD` keys — a layout that **has no
    //             SHIFT key and no second functions at all** (manual §SHIFT: "Expanded and pocket
    //             layouts do not have SHIFT key and all functions are accessible by 'one click'").
    //             The arrow belongs to the conversion commands' **names**, not to the kind of widget.
    //             (**`►GRAD`'s spelling is exactly the grey row in the sheet below**: `grad` is not an
    //             angle in the engine — see item 3.)
    //
    //          **2. What the action is: `TO_DRG`, a second command.** `command.name.DRG` = "Switch
    //          Angular Units" (the manual: "Use DRG key (or DEG etc. in expanded layout) to switch
    //          among these units." and "Cycle by DRG until RAD angular unit is checked"), while
    //          `command.name.TO_DRG` = "Convert Angular Units", which the manual states in full on
    //          line 678: **"►DRG key in compact layout opens the menu to choose source and target
    //          angular units and converts the current display number."** — one switches the **mode**,
    //          the other converts **the number currently displayed**, after asking for a source and a
    //          target. (`x⇔E`/`FSE` are the same "two neighbouring commands" shape, checked last
    //          round.)
    //
    //          **3. What lights it up this round, and the two false sentences that were here.** This
    //          action is reachable today because the translation opened a narrow path with **exactly
    //          one shape** (`_angleConversion` in `engine_expression.dart`:
    //          `<value> <angle unit> to <angle unit>`, both sides written-out unit words), with all six
    //          angle spellings measured (the table is on `kAngleUnits` in `app_unit_catalog.dart`). The
    //          sheet, the trade-offs and the evidence behind the grey `grad` row are in
    //          `calculator_page_angle_sheet.dart`'s file head.
    //
    //          **Last round's note said here that "the source unit cannot be stated" and "the other
    //          direction (→ degrees) does not exist" — this round's measurements replaced both, and
    //          both corrections stay here so the next round does not copy them again:**
    //          - **"the other direction does not exist" is false.** The engine has always done
    //            `90 rad to deg` (measured = `5156.620156°`); what did not exist was the spelling on
    //            **this app's** side (`deg` was not an insertable unit), not the engine's ability.
    //          - **"`90 to deg` merely attaches a symbol and the value does not move a byte" holds under
    //            DEG only.** The same input under RAD measures `5156.620156°` (the engine reads 90 as
    //            radians) and under GRA it is in the `90.00000000 d·°` family. The right sentence is
    //            "**with no source unit written, the source unit is the current angle mode**" —
    //            `90 to rad` is `1.570796327 rad` / `90 rad` / `1.413716694 rad` under the three modes.
    //            **That is exactly why this app's new sheet always writes the source unit out** (written
    //            out, the answer does not depend on the angle mode: `90 deg to rad` answers the same
    //            under all three).
    //          - The old reading that `degrees`/`radians` cannot get through still holds (those two
    //            spellings are not in this app's unit table), but they are **not** cases of the engine
    //            failing to read them (measured: `90 degrees to rad` = `1.570796327 rad`) — this app
    //            simply gives them no spelling, the same road as `zorkmid`.
    //
    //          **The base action `angleMode` has not moved a cell**: that key still switches the
    //          DEG↔RAD mode, converts no number and touches no expression (neither the note below this
    //          one nor the `angleMode` case in `calculator_key_dispatch.dart` was touched).
    KeypadKey(
      base: KeyVariant(label: 'DRG', id: 'angleMode'),
      category: KeyCategory.function,
      // 中文：**SHIFT 变体的键面补上 `▸`**：HiPER 把这个换算家族的名字写成 `▸DRG`（U+25B8，见本行
      //       上面那一段与 `hiper_keypad_number_rows.dart` 四个进制胶囊同一次更正），而本应用这一格
      //       过去写的是不带 `▸` 的 `DRG`——横带那条提示与这颗键的 SHIFT 键面是同一个名字，两处一起补。
      //       **基准 `angleMode` 的键面仍是 `DRG`**：HiPER 两颗键上写的也是不带 `▸` 的 `DRG`。
      // English: **the SHIFT variant's face gains the `▸`**: HiPER spells this conversion family's name
      //          `▸DRG` (U+25B8; see the note above this row and the same correction applied to the
      //          four base pills in `hiper_keypad_number_rows.dart`), while this app used to write a
      //          bare `DRG` here — the band hint and this key's SHIFT face are one and the same name,
      //          so both change together. **The base `angleMode` face stays `DRG`**: HiPER's two keys
      //          are written `DRG` without the arrow as well.
      shift: KeyVariant(label: '▸DRG', id: 'openAngleConvert', enabled: true),
    ),
    // 中文：**`FSE` 是这一颗键的 SHIFT 功能**——不是横带里独立的键。上一轮把它做成了横带里
    //       一颗可点的 `InlineKey`，那是错的，本轮按来源改回来。三条来源，各自独立：
    //
    //       1. **真机截图**（本机 `~/Downloads/04_媒体/Screenshot_2026-05-12-13-11-45-205_cz.hipercalc.p.jpg`，
    //          1440×3200，今天仍在，量它）：`FSE` 印在 `x⇔E` **正上方、水平居中对齐**；
    //          同一张图上 `▸DRG`/`MTRX`/`Π`/`d/dx`/`CNST` 也各自压在 `DRG`/矩阵/`Σ`/`∫dx`/`CONV` 上方。
    //          **注意它是较早的 Version 10 键盘布局**（第 2 行第 6 格写 `CONV`/`CNST`），不是厂商
    //          当前的键位（当前那一格是相机键，见 `keypad-fidelity-report.md` §1.2）；`FSE` 压在
    //          `x⇔E` 正上方这一条在厂商**当前**主屏截图上同样成立——`https://hiperlabs.eu/screenshots.html`
    //          → `assets/img/01 calculator.png`，今天仍可取回。
    //          ⚠️ **从前这里引的是裁图 `/tmp/hiper_row2.png`：它已不存在，而且它本身是残缺的**——
    //          `HANDOVER.md` 第五节逐字写着它「都是残缺的——里面既没有第 3 行也没有第 4 行（两轮都
    //          踩过）」，并要人去量原始整图；要量就量上面那张原图。
    //       2. **HiPER 自己写了这条规则**（`msgctxt "quickTour.page.SECOND_FUNCTION.text2"` 今天仍能从
    //          `https://weblate.a4tune.com/download/hiper-scientific-calculator/application/en/` 取回
    //          自查，抄本见 `.superpowers/backup/fse-placement-report.md:33`；抽取文件 `/tmp/hiper_en.po`
    //          在本机 `/tmp`，已不存在）：
    //          *"The key's second function is displayed in the label above."* —— 键上方的标签
    //          **就是**那颗键的第二功能。同一条 `text` 还说第二功能要靠 `SHIFT` 键进入。
    //          手册同页写着 "Symbols of these secondary functions are displayed above their keys"。
    //       3. **两条命令是分开的**：`command.name.CHANGE_EXPR` = "Result Format"（`x⇔E` 的基准，
    //          `resultFormat.info2` 说 "press `<key:CHANGE_EXPR>` key or tap on the result"），
    //          `command.name.FSE` = "Number Notation"。`id` 相邻但**是两个命令**。
    //
    //       所以这里挂的是 `shift`，键面文字与横带里那条提示都是 `FSE`——`Π`/`MTRX`/`d/dx`
    //       同一种形状，也同一条不变式：**横带那一格是纯提示、不可点**，一个动作只有一个 id 入口。
    //       上一轮 `d/dx` 那组测试把这条不变式写成了断言（`calculator_ddiff_key_test.dart`），
    //       `FSE` 现在受同一条约束。
    //
    //       **基准动作逐字节未动**：`resultForm`，结果**形式**那一维（`x⇔E` 的循环）。`FSE` 是
    //       另一维——数字**记法**。HiPER 手册自己就把这两段分成 "RESULT FORMAT" 与 "NOTATIONS" 两节。
    // English: **`FSE` is a SHIFT function of this key** — not a key of its own in the band. The
    //          previous round made it a tappable `InlineKey` in the band; that was wrong and this
    //          round puts it back where the sources put it. Three independent sources:
    //
    //          1. **The device screenshot** (on this machine, 1440×3200, still here — measure it):
    //             `FSE` is printed **directly above `x⇔E`, horizontally centred on it**; the same
    //             shot puts `▸DRG`/`MTRX`/`Π`/`d/dx`/`CNST` over `DRG`/matrix/`Σ`/`∫dx`/`CONV` the
    //             same way. **It is the older Version 10 keyboard layout** (cell 6 of row 2 reads
    //             `CONV`/`CNST`), not the vendor's current keypad (that cell is the camera key now;
    //             see `keypad-fidelity-report.md` §1.2) — and `FSE` above `x⇔E` holds on the
    //             vendor's **current** main-screen shot too:
    //             `https://hiperlabs.eu/screenshots.html` → `assets/img/01 calculator.png`, still
    //             fetchable today.
    //             ⚠️ **The crop cited here used to be `/tmp/hiper_row2.png`: it is gone, and it was
    //             incomplete anyway** — section 5 of `HANDOVER.md` says of it, verbatim, that they
    //             are all incomplete and that "里面既没有第 3 行也没有第 4 行（两轮都踩过）" (a
    //             translation: there is neither row 3 nor row 4 in them, and two rounds were burned
    //             on that). Measure the original above instead.
    //          2. **HiPER states the rule itself** (`msgctxt "quickTour.page.SECOND_FUNCTION.text2"`
    //             can still be fetched and checked today from
    //             `https://weblate.a4tune.com/download/hiper-scientific-calculator/application/en/`,
    //             with a copy in `.superpowers/backup/fse-placement-report.md:33`; the extracted file
    //             `/tmp/hiper_en.po` was on this machine's `/tmp`, gone): *"The key's second function
    //             is displayed in the label above."* The label above a key **is** that key's second
    //             function, and the sibling string says the `SHIFT` key is how you reach it. The
    //             manual's own page says "Symbols of these secondary functions are displayed above
    //             their keys".
    //          3. **Two separate commands**: `command.name.CHANGE_EXPR` = "Result Format" (the base
    //             of `x⇔E`; `resultFormat.info2` says "press `<key:CHANGE_EXPR>` key or tap on the
    //             result") and `command.name.FSE` = "Number Notation" — adjacent ids, **two commands**.
    //
    //          So the variant goes on `shift`, with `FSE` as both the variant's face and the band's
    //          hint — the shape `Π`/`MTRX`/`d/dx` already have, and the same invariant with it: **the
    //          band cell is a plain hint and is not tappable**, one action has exactly one id
    //          entrance. The `d/dx` group wrote that invariant down as an assertion
    //          (`calculator_ddiff_key_test.dart`); `FSE` is under it now too.
    //
    //          **The base action has not moved by a byte**: `resultForm`, the result **form**
    //          dimension. `FSE` is another dimension — number **notation**. HiPER's manual splits
    //          them into its own two sections, "RESULT FORMAT" and "NOTATIONS".
    KeypadKey(
      base: KeyVariant(label: 'x⇔E', id: 'resultForm'),
      category: KeyCategory.function,
      shift: KeyVariant(label: 'FSE', id: 'notationCycle'),
    ),
    // 中文：**矩阵键的 SHIFT 功能是 `MATRIX_MENU`「矩阵与向量菜单」——与基准的「插入一个矩阵」
    //       不是同一个动作。本轮它从「挂上但禁用」变成**真的点亮**（`openMatrixMenu`）。**
    //       下面按顺序说清楚三件事。
    //
    //       **一、HiPER 上 `MTRX` 是这颗键的第二功能，不是一颗独立的键。** 与 `DRG` 那一格同样
    //       四条来源：位置（本格字形列中心 602.0，下方键面 601.0，差 1.0 px，与其它五格同一条
    //       1:1 对照）、`quickTour.page.SECOND_FUNCTION.text2` 那条通则、画法（平排文字，字形核心
    //       (159,161,168)、无胶囊底，与所有第二功能记号同值）、以及 `▸` 只属于换算命令的名字
    //       （见 `DRG` 那颗键的注释）。**HiPER 上这颗键的键面是矩阵图标 `[▦]`，不是 `MTRX`**——
    //       `MTRX` 是它上方那一格的字。
    //
    //       **本轮把那条偏差关掉了：键面改成画厂商那张图。** 这条记账在规格书第 1796 行写着
    //       「未做、记为没做」，本文件这一行也写着同一句话——**两句都到此为止**。读数如下，两张图
    //       都是本轮自己在**原图**上量的（⚠️ 从前引的 `/tmp/hiper_row2.png` 是残缺裁图，
    //       `HANDOVER.md` 第五节记着它「里面既没有第 3 行也没有第 4 行」，不要再拿它当来源）：
    //
    //       **来源一：本机那张 1440×3200 真机图**（`~/Downloads/04_媒体/Screenshot_2026-05-12-13-11-45-205_cz.hipercalc.p.jpg`，本轮重新量）。
    //       这一格键面 x 490..712（宽 223）、y 1314..1437（高 124）；键面上的字形外框
    //       **x 543..660（宽 118）、y 1332..1417（高 86）**，即键面的 0.529 × 0.694，
    //       字形中心 (601.5, 1374.5) 对键面中心 (601.0, 1375.5)——**横竖都居中**。
    //       字形颜色 **(46,46,46)**，与同一行 `DRG`/`x⇔E`/`Σ` 的键面前景色同值（不是横带那条
    //       提示的 (159,161,168)：这颗键上键面与横带本来就不同一种画法）。
    //       结构（把外框归一成 118×86，原点左上）：
    //       - **两个方括号**：竖笔 x 0..5、上下臂各 6 厚、各自伸到 x 17 与 x 101（右侧镜像），
    //         竖向占满 0..86；笔宽实测 5–6 px，两个括号与四个方格同一种笔宽。
    //       - **四个空心方格**：每个**外框 21×30**（量到 x 575..595、y 1340..1369 是左上一个），
    //         左列 x 32、右列 x 64、上行 y 8、下行 y 48——**列距 11、行距 10**，方格上下各内缩 8。
    //       比例：**86 / 45 = 1.91**（同一行 `DRG` 的大写高 45 px），图形是同一行文字的近两倍高。
    //       **来源二：厂商官网当前主屏截图**（`https://hiperlabs.eu/screenshots.html` →
    //       `assets/img/01 calculator.png`，本轮下载的是 554×975 那份）：同一格键面 x 212..272、
    //       y 371..404，字形 x 228..256（宽 29）、y 377..398（高 22），是键面高的 **0.647**，
    //       与同一行 `DRG` 的 12 px 大写高比是 **1.83**。**两张图同一画法**（0.694 与 0.647 的差
    //       只是两张图的缩放），也同一句话：那一格的字是 `MTRX`、键面是这张图。
    //
    //       **为什么用 `CustomPaint` 而不是一个 Unicode 字符。** 本应用画「非文字键面」只有两条
    //       现成的路：相机键把 `📷` 当**一个字符**写进 `label`、`D°M'S` 把 `°`/`′`/`″` 写成
    //       正排文字。这张图两条都走不了——**Unicode 里没有「方括号包着 2×2 四个空心方格」这个
    //       码位**：§Geometric Shapes 里最近的两个是 `▦`（U+25A6「带正交网格填充的方块」）与
    //       `⊞`（U+229E「带加号的方块」），都是**一个**方块，不是四个，更不带括号；而
    //       `FittedBox` 那条路是 `maxLines: 1`，两行文字也排不出来。所以这一格走第三条路：
    //       `KeyFaceIcon`（数据里点名「这一格的键面是一张图」）+ `KeyFaceIconView`（渲染层画它，
    //       在 `calculator_keypad.dart`）。**不拿字符近似**，因此也没有「哪里像、哪里不像」要交代：
    //       画的就是量到的那两条括号与四个 21×30 的空心方格。
    //
    //       **横带那一格一个字都没动**（仍是 `ShiftLabel('MTRX')`）：厂商两张图上它都是 `MTRX`，
    //       而 HiPER 自己写着第二功能显示在键**上方**的标签里
    //       （`quickTour.page.SECOND_FUNCTION.text2`）。键面改图形之后，整块键盘上 `MTRX`
    //       这个词**只剩横带这一处**——本项目自己记过的「两处同名、读起来像重复的标签」也到此为止。
    //
    //       **二、它是什么动作：`MATRIX_MENU`，与 `MATRIX` 是两个命令。**
    //       `command.name.MATRIX` = "Matrix"，帮助原文："Press the `<key:MATRIX>` key to insert a
    //       matrix into an expression."；`command.name.MATRIX_MENU` = **"Matrix and Vector Menu"**，
    //       手册第 941 行："**Press the MTRX key to open a menu with matrix functions.**"，
    //       `quickTour.page.MATRIX.text2` = "Press the `<key:MATRIX_MENU>` key to see matrix
    //       operations."，厂商更新日志（9.1）另有一条："Matrix inverse added to MTRX menu"。
    //       一个把矩阵插进表达式，一个**打开一个矩阵函数的菜单**——本应用现在打开后者
    //       （面板在 `calculator_page_matrix_sheet.dart`，插入走主屏的 `_pressKey`）。
    //
    //       **三、这一格原来为什么禁用，以及本轮凭什么点亮。** 上一轮禁用是 fail closed，凭据是
    //       一份实测：菜单里会插的那类调用，**应用自己的翻译层**一条也过不去（词表里没有那些名字），
    //       而旧解析器连被包住的那半条也读不了（`ExpressionParser('matrix(2,2,1,2,3,4)')` 抛
    //       `FormatException: matrix needs 1 argument`）——所以从菜单里插出去的每一条都只会得到一条
    //       错误，得不到值。**本轮缺口补上了**：`det`/`transpose`/`inv`/`identity` 进了词表
    //       （名字与意思都在宿主上量过，整张表在 `app_engine_vocabulary_identifiers.dart`），
    //       引擎那一侧本来就不是瓶颈（`det(matrix(2,2,1,2,3,4))` = `−2`、`transpose(…)` =
    //       `[1  3; 2  4]`、`inv(…)` = `[−2  1; 1.5  −0.5]`、`identity(2)` = `[1  0; 0  1]`）。
    //
    //       **同一份实测里也量出了三个必须拒绝的名字**（`rank`/`trace`/`echelon`，成因两种：
    //       `rank` 是引擎里真有的函数却把矩阵原样还回来；`trace`/`echelon` 引擎里根本没有，
    //       于是词被拆成符号、印出来带单位）。它们**不进词表**，在面板里是**灰的**、旁边写着为什么。
    //
    //       **基准动作 `ins:matrix` 一格未动**（仍是 `matrix(2,2,1,2,3,4)`，引擎实测印成
    //       `[1  2; 3  4]`）。**本注释过去写的是「已接上」**，那在当时是一句不成立的话（代码里从来没有
    //       这个变体）；上一轮换成「挂上但禁用」，本轮才真的接上。
    //
    //       **这条拒绝写成了断言**：`test/features/calculator_drg_matrix_band_keys_test.dart` 与
    //       `test/features/calculator_matrix_menu_test.dart` 钉住上面两张表——哪一天引擎把那三个
    //       名字答对了，那些断言会变红。
    // English: **The matrix key's SHIFT function is `MATRIX_MENU`, "Matrix and Vector Menu" — not
    //          the same action as the base "insert a matrix". This round it goes from "mounted but
    //          disabled" to **really lit** (`openMatrixMenu`).** Three things, in order.
    //
    //          **1. On HiPER `MTRX` is this key's second function, not a key of its own.** The same
    //          four sources as the `DRG` cell: position (this cell's glyph column centre is 602.0
    //          against the key face's 601.0, a 1.0 px gap inside the same six-over-six 1:1 mapping),
    //          the `quickTour.page.SECOND_FUNCTION.text2` rule, the drawing (plain text, glyph core
    //          (159,161,168), no capsule — the same values every second-function symbol has), and the
    //          fact that `▸` belongs to the names of conversion commands only (see the `DRG` key's
    //          note). **On HiPER this key's face is the matrix icon `[▦]`, not `MTRX`** — `MTRX` is
    //          the text of the cell above it.
    //
    //          **This round closes that deviation: the face now draws the vendor's figure.** Line
    //          1796 of the spec book has this on the record as "未做、记为没做" (not done, recorded as
    //          such), and this file carried the same sentence — **both end here.** The readings
    //          below were taken this round off the **originals** (⚠️ the `/tmp/hiper_row2.png` cited
    //          in earlier rounds was an incomplete crop; section 5 of `HANDOVER.md` records that it
    //          had "neither row 3 nor row 4 in it", so it is not a source to return to):
    //
    //          **Source one: this machine's 1440×3200 device screenshot** (path above; re-measured
    //          this round). This cell's key face is x 490..712 (223 wide), y 1314..1437 (124 tall);
    //          the glyph on it has a bounding box of **x 543..660 (118 wide), y 1332..1417 (86
    //          tall)** — 0.529 × 0.694 of the key face — with its centre at (601.5, 1374.5) against
    //          the face's (601.0, 1375.5), i.e. **centred both ways**. The glyph's colour is
    //          **(46,46,46)**, the same value as the face foregrounds of `DRG`/`x⇔E`/`Σ` in the same
    //          row — and *not* the band hint's (159,161,168): on this key the face and the band above
    //          were never the same drawing to begin with. Its structure (box normalised to 118×86,
    //          origin top-left):
    //          - **Two brackets**: stem x 0..5, each arm 6 thick, reaching x 17 and x 101 (the right
    //            one mirrored), spanning the full 0..86 vertically; the stroke measures 5–6 px, one
    //            weight for both brackets and all four squares.
    //          - **Four hollow squares**, each an **outer 21×30** (measured at x 575..595, y
    //            1340..1369 for the top-left one), left column x 32, right column x 64, top row y 8,
    //            bottom row y 48 — **11 between columns, 10 between rows**, the squares inset 8 top
    //            and bottom.
    //          Proportions: **86 / 45 = 1.91** (against `DRG`'s 45 px capitals in the same row), so
    //          the figure is nearly twice as tall as the text beside it.
    //
    //          **Source two: the vendor's current main-screen screenshot**
    //          (`https://hiperlabs.eu/screenshots.html` → `assets/img/01 calculator.png`; the copy
    //          downloaded this round is 554×975). The same cell's key face is x 212..272, y 371..404
    //          and the glyph is x 228..256 (29 wide), y 377..398 (22 tall) — **0.647** of the face
    //          height, and **1.83** against `DRG`'s 12 px capitals in that row. **Both pictures show
    //          one and the same drawing** (0.694 against 0.647 is just the two pictures' scale), and
    //          both say the same thing: the cell's text is `MTRX`, the key's face is this figure.
    //
    //          **Why a `CustomPaint` rather than a Unicode character.** This app has exactly two
    //          existing roads for a "non-text face": the camera key writes `📷` as **one character**
    //          into `label`, and `D°M'S` writes `°`/`′`/`″` as ordinary text. This figure can take
    //          neither — **Unicode has no code point for "brackets around a 2×2 grid of hollow
    //          squares"**: the nearest in the Geometric Shapes block are `▦` (U+25A6, "square with
    //          orthogonal crosshatch fill") and `⊞` (U+229E, "squared plus"), and both are **one**
    //          square rather than four, with no brackets at all — while the `FittedBox` road is
    //          `maxLines: 1` and cannot lay out two lines either. So this cell takes a third road:
    //          `KeyFaceIcon` (the data naming "this cell's face is a figure") plus
    //          `KeyFaceIconView` (the rendering layer that draws it, in `calculator_keypad.dart`).
    //          **Nothing is approximated with a character**, so there is no "close but not quite" to
    //          declare: what gets drawn is the measured two brackets and four 21×30 hollow squares.
    //
    //          **The band cell above has not moved a character** (still `ShiftLabel('MTRX')`): both
    //          vendor pictures read `MTRX` there, and HiPER's own rule is that a second function is
    //          displayed in the label **above** its key (`quickTour.page.SECOND_FUNCTION.text2`).
    //          With the face now a figure, the word `MTRX` appears **only in that band cell** on the
    //          whole keypad — and the "two places carrying the same name, reading like a duplicated
    //          label" that this project itself recorded ends there too.
    //
    //          **2. What the action is: `MATRIX_MENU`, a second command.**
    //          `command.name.MATRIX` = "Matrix" (its help: "Press the `<key:MATRIX>` key to insert a
    //          matrix into an expression."), while `command.name.MATRIX_MENU` = **"Matrix and Vector
    //          Menu"**, manual line 941: "**Press the MTRX key to open a menu with matrix
    //          functions.**", `quickTour.page.MATRIX.text2` = "Press the `<key:MATRIX_MENU>` key to
    //          see matrix operations.", and the vendor's release notes (9.1) add "Matrix inverse
    //          added to MTRX menu". One inserts a matrix into the expression; the other **opens a menu
    //          of matrix functions** — and this app now opens the latter (the sheet is in
    //          `calculator_page_matrix_sheet.dart`, and insertion travels the screen's `_pressKey`).
    //
    //          **3. Why this cell was disabled before, and what lights it now.** Last round's disabled
    //          flag was fail closed, on a measurement: not one of the calls such a menu would insert
    //          got through **this app's own translation layer** (the vocabulary had none of those
    //          names), and the legacy parser cannot even read the wrapped half
    //          (`ExpressionParser('matrix(2,2,1,2,3,4)')` throws
    //          `FormatException: matrix needs 1 argument`) — so everything inserted from such a menu
    //          could only come back as an error, never as a value. **This round closes that gap**:
    //          `det`/`transpose`/`inv`/`identity` entered the vocabulary (name and meaning both
    //          measured on the host; the whole table is on `app_engine_vocabulary_identifiers.dart`),
    //          and the engine side was never the bottleneck (`det(matrix(2,2,1,2,3,4))` = `−2`,
    //          `transpose(…)` = `[1  3; 2  4]`, `inv(…)` = `[−2  1; 1.5  −0.5]`, `identity(2)` =
    //          `[1  0; 0  1]`).
    //
    //          **The same set of measurements also produced three names that must be refused**
    //          (`rank`/`trace`/`echelon`, from two causes: `rank` is a real engine function that hands
    //          the matrix straight back, while `trace`/`echelon` are not names the engine has at all,
    //          so the word is taken apart into symbols and prints with units). They **do not enter the
    //          vocabulary** and appear in the sheet **greyed**, with the reason on their own row.
    //
    //          **The base action `ins:matrix` has not moved a cell** (still `matrix(2,2,1,2,3,4)`, which
    //          the engine prints as `[1  2; 3  4]`). **This note used to read "已接上" ("wired")**, a
    //          sentence that was already false when it was written (the variant has never existed in the
    //          code); last round replaced it with "mounted but disabled", and this round really wires it.
    //
    //          **The refusal is written down as assertions**:
    //          `test/features/calculator_drg_matrix_band_keys_test.dart` and
    //          `test/features/calculator_matrix_menu_test.dart` pin both tables above — the day the
    //          engine answers those three names correctly, those assertions go red.
    KeypadKey(
      // 中文：**这一格的基准变体是本轮唯一改动的键位数据**：多了 `icon: KeyFaceIcon.matrix`
      //       ——键面从此画那张图，不再写 `MTRX` 四个字母（上面那一段就是这件事的全部读数）。
      //       `label` **仍是 `MTRX`**：它是这颗键的**名字**，横带里的提示、逐格快照与词表条目
      //       都还叫它这个名字，名字与画法在 `KeyVariant` 里本来就是两栏。
      //       **`shift` 变体一个字没动**：它的 `MTRX` 是第二功能的名字（横带里那条提示），而键面
      //       只画基准变体（`calculator_keypad.dart` 的类注释写着为什么不换键面）——所以给它
      //       `icon` 会是一栏永远不画的数据。
      // English: **This cell's base variant is the round's only change to keypad data**: it gains
      //          `icon: KeyFaceIcon.matrix`, so the face draws that figure instead of the four
      //          letters `MTRX` (the section above is every reading behind it). `label` **is still
      //          `MTRX`**: it is this key's **name**, and the band hint, the per-cell snapshot and
      //          the vocabulary entries all call it by that name — name and drawing are two separate
      //          fields on `KeyVariant` to begin with. **The `shift` variant has not moved a
      //          character**: its `MTRX` is the second function's name (the band's hint), and a face
      //          only ever draws the base variant (the class comment in `calculator_keypad.dart`
      //          says why), so an `icon` there would be a field nothing draws.
      base: KeyVariant(
        label: 'MTRX',
        id: 'ins:matrix',
        icon: KeyFaceIcon.matrix,
      ),
      category: KeyCategory.function,
      shift: KeyVariant(label: 'MTRX', id: 'openMatrixMenu'),
    ),
    KeypadKey(
      base: KeyVariant(label: 'Σ', id: 'ins:sum'),
      category: KeyCategory.function,
      shift: KeyVariant(label: 'Π', id: 'ins:product'),
    ),
    KeypadKey(
      base: KeyVariant(label: '∫dx', id: 'ins:integrate'),
      category: KeyCategory.function,
      shift: KeyVariant(label: 'd/dx', id: 'ins:diff'),
    ),
    KeypadKey(
      base: KeyVariant(label: '📷', id: 'dis:camera', enabled: false),
      category: KeyCategory.disabled,
    ),
  ],
  labels: <KeypadLabel?>[
    // 中文：横带里那一格的字是 **`▸DRG`**，带 U+25B8——`▸` 是这个换算家族名字的一部分（见
    //       `hiper_keypad_number_rows.dart` 四个进制胶囊上那一次更正），不是「这是一颗按钮」的记号。
    //       `CONV`/`CNST` 不带 `▸`（厂商当前截图里那两格逐字如此），本应用也照写。
    // English: the band cell reads **`▸DRG`**, with U+25B8 — the arrow is part of this conversion
    //          family's name (see the correction on the four base pills in
    //          `hiper_keypad_number_rows.dart`), not a "this is a button" marker. `CONV`/`CNST` carry
    //          no `▸` (verbatim from the vendor's current screenshot), and this app writes them so.
    ShiftLabel('▸DRG'),
    // 中文：**`FSE` 是一句提示，不是一颗键**——它压在 `x⇔E` 正上方，而那正是 HiPER
    //       自己给第二功能定的位置（`quickTour.page.SECOND_FUNCTION.text2`：
    //       *"The key's second function is displayed in the label above."*）。动作挂在上面那颗键的
    //       `shift` 上，见它的注释。**上一轮这里是 `InlineKey`**，那是主会话 brief 让「把它接成一个
    //       真控件」的结果——本轮按来源退回。同一个动作不能有两个 id 入口（键 id 全局唯一），
    //       这条不变式在 `calculator_ddiff_key_test.dart` 里已经是断言，`FSE` 与它同一形状。
    //       横带里真正的键是四个进制胶囊（手册第 1791 行："Press ►BIN , ►OCT , ►DEC and ►HEX keys"，
    //       真机图上它们也戴着胶囊底色）与 `hyp`（手册第 701 行："press hyp key"）。
    // English: **`FSE` is a hint, not a key** — it sits directly above `x⇔E`, which is exactly where
    //          HiPER puts a second function (`quickTour.page.SECOND_FUNCTION.text2`: *"The key's
    //          second function is displayed in the label above."*). The action hangs on the `shift`
    //          variant of the key above it; see that key's note. **This cell was an `InlineKey` last
    //          round**, the result of a brief that asked for it to be "wired as a real control"; this
    //          round it goes back to what the sources say. One action must not have two id entrances
    //          (key ids are globally unique) — the `d/dx` group already made that invariant an
    //          assertion, and `FSE` has the same shape. The band's real keys are the four base pills
    //          (manual line 1791: "Press ►BIN , ►OCT , ►DEC and ►HEX keys", and on the real screenshot
    //          they wear a capsule background) and `hyp` (manual line 701: "press hyp key").
    ShiftLabel('FSE'),
    // 中文：**这一格的字一个字都没动。** 厂商两张图上它都是 `MTRX`，厂商自己又写着第二功能
    //       显示在键**上方**的标签里（`quickTour.page.SECOND_FUNCTION.text2`）——所以这一格是
    //       「词」那一处，下方键面这一轮改成了「图」那一处（见那颗键的长注释）。
    //       **这也是整块键盘上 `MTRX` 唯一出现的地方**：改之前横带与键面各写一次，本项目自己
    //       把那记成「读起来像重复的标签」，那一条到此为止。逐格快照里它仍是 `hint:MTRX`。
    // English: **This cell's text has not moved a character.** Both vendor pictures read `MTRX`
    //          there, and the vendor's own rule is that a second function is displayed in the label
    //          **above** its key (`quickTour.page.SECOND_FUNCTION.text2`) — so this is the "word"
    //          half, while the key face below became the "figure" half this round (see that key's long
    //          note). **It is also the only place `MTRX` appears on the whole keypad**: before this
    //          round the band and the face each wrote it once, which this project recorded as reading
    //          like a duplicated label, and that entry ends here. In the per-cell snapshot it is
    //          still `hint:MTRX`.
    ShiftLabel('MTRX'),
    ShiftLabel('Π'),
    ShiftLabel('d/dx'),
    null,
  ],
);
