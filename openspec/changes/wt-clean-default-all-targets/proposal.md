# wt-clean-default-all-targets — 引数なし時の対象選択 UI を廃止し全件デフォルト化

## Why

`wt-clean` を引数なしで起動すると、リストアップ後に `AskUserQuestion` で「全て / 個別に選ぶ / キャンセル」を毎回聞いていた。実運用ではほぼ常に「全て」を選ぶだけで、この質問は形式的な 1 クリックにしかなっていない。さらに、この対象選択の対話でセッションが止まり、処理が途中で終わってしまう事故が発生している（「1 個止まって終わっていない」）。

`wt-clean-auto-flow` で per-target 確認を廃止し「実行して放っておいたら終わっている」体験に寄せたが、入口の対象選択 UI が残っているとその体験が損なわれる。破壊判断が必要な 🔴 / dirty は Pass 2 の判断バッチで確認されるため、全件をデフォルト対象にしても安全性は Pass 2 の対話で担保される。対象を絞りたい場合は既存の位置引数 `<path|branch>` で指定できる（この経路は変更しない）。

## What Changes

- **引数なし時の対象選択 UI（`AskUserQuestion` 3 択 + multiSelect バッチ）を廃止する（BREAKING）**。引数なし（および `--keep` / `--no-sync` のみで位置引数がない場合）は、リストアップした全 worktree（メインリポ自身を除く）を確認なしで `TARGETS` にし、そのまま Pass 1 へ進む。
- **リストアップは維持する**が、その意味を「対象選択のための提示」から「これから全件を処理することの通知」に変更する。遅延診断（色を出さない・軽量表示のみ）の性質は不変。
- worktree が 0 件のときは「対象の worktree がありません」と表示して終了する。
- 位置引数による対象スコープ（`wt-clean <path|branch>`）・引数解決の中断ロジック・Pass 1/Pass 2 の処理・破壊操作の絶対禁則（dirty 破棄・🔴 破棄/マージは Pass 2 回答後の別ターン）は**すべて不変**。
- フラグは増やさない（`--keep` / `--no-sync` のみ維持）。

## Capabilities

### Modified Capabilities

- `wt-clean-target-selection`: 「引数なし時は対象選択 UI で TARGETS を選ばせる」要件を削除し、「引数なし時は全 worktree をデフォルト対象にする（対象選択 UI なし）」に置き換える。リストアップ要件は文言を「対象選択後に診断」から「全件確定後に診断」へ調整する。

## Impact

- **コード/スキル**: `plugins/worktree/skills/wt-clean/SKILL.md`（正本・Step A-2 と設計の核・フロー図・オプション節）、`plugins/worktree/commands/wt-clean.md`（frontmatter description 同期）、`plugins/worktree/.claude-plugin/plugin.json`（version 2.3.0 → 2.4.0 + description）。SKILL.md version 3.0.0 → 3.1.0。
- **spec**: `wt-clean-target-selection` の delta（REMOVED 1 / ADDED 1 / MODIFIED 1）。`wt-clean-auto-flow`（未 archive）とは別要件を触るため衝突しない。
- **ユーザー体験**: 引数なし `wt-clean` が対象選択で止まらなくなり、全件を即処理する。誤って全件対象にしても 🟢/🟡 の安全処理と 🔴/dirty の Pass 2 確認に正しく振り分けられるため、破壊操作は引き続き明示確認なしには実行されない。対象を絞るには位置引数を使う。
