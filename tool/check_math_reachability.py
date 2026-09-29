#!/usr/bin/env python3
"""中文：**报告 `lib/core/math/` 下有哪些文件没有任何调用方。**

       ⚠️ **这个脚本是被我自己的一次错误逼出来的。** 本会话里我三次栽在同一个形状上——
       **动手之前没去看已经有的东西**（拿 CLI 当库、把中止的脚本当成跑完了、
       没读 `docs/release_checklist.md` 就说"本仓还没有发布流程"）。
       而其中有一次的具体形态是：**写好一个纯函数、跑完测试、然后就忘了把它接出去**。
       `arithmetic_steps.dart` 就这样在那里放了一轮，直到我手写一遍 grep 才发现。

       **手写一遍 grep 是会忘的，脚本不会。** 所以把它固化在这里：
       每次加完 `lib/core/math/` 下的新文件跑一下，**没有调用方的会列出来**。

       退出码：有未接出去的文件时 **1**，否则 0 —— 这样它可以进流水线。
English: **reports which files under `lib/core/math/` have no callers.**

          ⚠️ **This script exists because of a mistake of mine.** Three times in one session I failed the
          same way — **didn't look at what the repository already had** (took the CLI for the library,
          treated an aborted script as finished, claimed there was no release process without reading
          `docs/release_checklist.md`). One of those had a concrete shape: **write a pure function, run its
          tests, then forget to wire it up.** `arithmetic_steps.dart` sat there for a whole round until I
          hand-wrote a grep and found it.

          **A hand-written grep gets forgotten; a script does not.** So it lives here: run it after adding
          anything under `lib/core/math/` and **anything with no caller is listed.**

          Exit code: **1** when something is unreachable, 0 otherwise — so it can go into a pipeline.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MATH = ROOT / 'lib' / 'core' / 'math'
CONSUMERS = [ROOT / 'lib' / 'application', ROOT / 'lib' / 'features']

def consumers_source() -> str:
    parts = []
    for base in CONSUMERS:
        for path in base.rglob('*.dart'):
            parts.append(path.read_text(encoding='utf-8'))
    return '\n'.join(parts)

def main() -> int:
    haystack = consumers_source()
    unreachable = []
    for path in sorted(MATH.glob('*.dart')):
        name = path.name
        # 中文：`part of` 的文件不是独立的库（它们由宿主文件被引用），跳过。
        text = path.read_text(encoding='utf-8')
        if re.search(r'^\s*part of ', text, re.M):
            continue
        if name in haystack:
            continue
        unreachable.append(name)
    if unreachable:
        print('⚠️  `lib/core/math/` 下这些文件在 lib/application 与 lib/features 里没有任何引用：')
        for name in unreachable:
            print(f'    {name}')
        print('   （写好纯函数之后忘了接出去，是本项目反复踩的一类；见脚本文件头。）')
        return 1
    print('✅ `lib/core/math/` 下每一个文件都有调用方。')
    return 0

if __name__ == '__main__':
    sys.exit(main())
