---
name: safe-plan-exit
description: Plan mode を終了して承認を求めるとき（ExitPlanMode を呼ぶ前）に使う。Opus 4.8 で ExitPlanMode の tool-call XML ラッパーが壊れ、承認が表示されない事故を防ぐ。トリガー: plan mode 終了, ExitPlanMode, プラン承認, exit plan mode, 承認依頼が表示されない
---

# Safe Plan Exit

Plan mode を抜けて承認を求めるときの手順。Opus 4.8 で `ExitPlanMode` の
tool-call XML ラッパーが壊れ、`<invoke name="ExitPlanMode">...` 相当が
本文にテキストとして漏れて、プラン／承認が画面に表示されない事故が観測されている。
主因は `allowedPrompts` に大きなネスト JSON を積むこと。複雑な構造化引数ほど
生成が不安定になる。

## ルール

1. **`allowedPrompts` は省略するか最小に。** 実行したい Bash を事前に全部
   列挙しない。実行時に都度承認する。どうしても列挙するなら 1〜2 個の短い
   prompt に絞る。
2. **プラン本文は `ExitPlanMode` の引数ではなく地の文（通常の応答テキスト）に
   書く。** ExitPlanMode の呼び出し自体は可能な限り軽く保つ。
3. **そもそも plan mode が不要な作業では使わない。** 可逆な通常変更は auto で
   進める（不可逆・破壊的・多サービス横断・要件が真に曖昧、のときだけ plan mode）。
4. **漏れたら呼び直す。** `<invoke name="ExitPlanMode">` がテキストとして本文に
   出てしまったら、それはラッパー破損のサイン。`allowedPrompts` を空にして
   ExitPlanMode を呼び直す。

## チェックリスト

- [ ] `allowedPrompts` は空 or 最小（1〜2個）か
- [ ] プラン本文は地の文に書いたか
- [ ] この作業は本当に plan mode が必要か（可逆なら不要）
