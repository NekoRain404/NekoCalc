import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 中文：**界面锁死在竖屏，而且锁的那两件东西必须在场。**
///
///       这是用户明说两次的硬规矩（「不需要做屏幕旋转，**禁止屏幕旋转**」）。它此前只写在 manifest 里，
///       没有任何检查看着它——而 manifest 自己也写着：**只写 `screenOrientation` 是不够的**
///       （`targetSdk = 36` 下系统可以忽略它），官方的退出开关是那条
///       `android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY`。**两件缺一不可**，
///       所以这条检查两件都问，判据的形状照着 manifest 里那段注释写：少任何一件都算不合格，
///       而不是"有 `screenOrientation` 就算过"。
///
///       ⚠️ **判据先把 XML 注释剥掉再判。** 这一条不是洁癖：manifest 里那段**注释本身就写着这两个名字**
///       （这正是它解释"为什么两件都要"的方式）。若判据直接在原文上做子串查找，那么**属性被删掉、注释
///       还留着**的时候它会**照绿**——一个对着注释通过的护栏，比没有护栏更坏：它给人一种锁还在的错觉。
///       下面的边界用例专门钉这一格。
///
///       ⚠️ 判据提成纯函数，是为了能用合成 manifest 证明它**真的会响**。**护栏本身也要能被验证。**
/// English: **the UI is locked to portrait, and both halves of that lock must be present.**
///
///          This is a rule the user stated twice (「…禁止屏幕旋转」). Until now it lived only in the
///          manifest, with nothing watching it — and the manifest itself records that
///          **`screenOrientation` alone is not enough** (under `targetSdk = 36` the system may ignore it);
///          the documented opt-out is the `android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY`
///          property. **Both are required**, so this check asks for both, matching the shape of that comment:
///          missing either half fails, rather than "has `screenOrientation` and therefore passes".
///
///          ⚠️ **The judgement strips XML comments first.** That is not fussiness: the manifest's own comment
///          **names both of these strings** (that is how it explains why both are needed). A substring search
///          over the raw text would therefore **pass while the attribute is gone and only the comment
///          remains** — a guard that passes on a comment is worse than no guard, because it creates the
///          impression the lock is still there. The boundary case below pins exactly that cell.
///
///          ⚠️ The judgement is a pure function so synthetic manifests can prove it **really fires**. **The
///          guard itself has to be verifiable.**
void main() {
  test('锁屏判据：缺任一件都不合格，两件齐了才过；**只有注释提到它们不算数**', () {
    const both = '<activity android:screenOrientation="portrait">'
        '<property android:name='
        '"android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY" /></activity>';
    const onlyOrientation =
        '<activity android:screenOrientation="portrait" />';
    const neither = '<activity />';

    expect(rotationLockProblems(both), isEmpty);
    expect(rotationLockProblems(onlyOrientation), hasLength(1),
        reason: '只有 screenOrientation 就判合格，等于把 manifest 那段注释说的"半锁"当成锁好了');
    expect(rotationLockProblems(neither), hasLength(2));

    // 中文：**这一格是这条护栏真正的理由。** 两个名字都出现在注释里、属性一个都没有——
    //       对着原文做子串查找会放它过去，而这正是"锁看起来还在、其实已经没了"。
    // English: **this cell is the reason this guard exists.** Both names appear in a comment and neither
    //          attribute is present — a raw substring search would let it through, which is exactly "the
    //          lock looks present while it is gone".
    const commentsOnly = '<activity>'
        '<!-- android:screenOrientation="portrait" and'
        ' android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY are required -->'
        '</activity>';
    expect(rotationLockProblems(commentsOnly), hasLength(2),
        reason: '对着注释通过——护栏给人一种锁还在的错觉，比没有护栏更坏');
  });

  test('真实 manifest 两件都在', () {
    final file = File('android/app/src/main/AndroidManifest.xml');
    expect(file.existsSync(), isTrue, reason: 'manifest 不在，这条检查的前提就不成立');
    final text = file.readAsStringSync();
    expect(text.contains('<activity'), isTrue,
        reason: '读到的文件里连 <activity> 都没有，这条检查多半根本没读对地方');

    expect(rotationLockProblems(text), isEmpty,
        reason: '竖屏锁少了一件——用户的规矩是「禁止屏幕旋转」');
  });
}

const portraitAttribute = 'android:screenOrientation="portrait"';
const restrictedResizabilityProperty =
    'android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY';

/// 中文：**判据只有这几句**：返回两份锁里缺掉的那些（空列表 = 合格），顺序固定、便于断言与阅读。
///       注释先剥掉——理由见文件头那一格。
/// English: **the judgement, in full**: whichever halves of the lock are missing (empty list = compliant),
///          in a fixed order so it can be asserted and read. Comments are stripped first — see the file
///          header for why that cell exists.
List<String> rotationLockProblems(String manifest) {
  final stripped = stripXmlComments(manifest);
  return [
    if (!stripped.contains(portraitAttribute)) '缺少 $portraitAttribute',
    if (!stripped.contains(restrictedResizabilityProperty))
      '缺少 $restrictedResizabilityProperty'
          '（`screenOrientation` 单独不够，见 manifest 里的注释）',
  ];
}

/// 中文：去掉 XML 注释的唯一读法。公开出来是因为"判据读的是剥掉注释之后的文本"这件事本身就是判据的一部分。
/// English: the single reading of "drop the XML comments", public because *that the judgement reads
///          comment-stripped text* is itself part of the judgement.
String stripXmlComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
