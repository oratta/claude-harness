# wt-clean-auto-flow — 確認の前倒しとノンブロッキング自動処理

## Why

現状の `wt-clean` は 1 対象ごとに AskUserQuestion で確認するため、対象が N 件あると走行中に N 回ブロックする。実際にはほとんどの対象が 🟢 Safe（マージ済み・クリーン・LLM なし）であり、確認は形式的な「削除 / スキップ」の 1 クリックにしかなっていない。ユーザーの期待は「実行して放っておいたら作業が終わっている」であり、per-target 確認はその妨げになっている。

一方で、過去に「作業中 worktree の誤削除」事故が起きた経緯があるため、無条件の全自動化はしない。安全性は「確認の回数」ではなく「分類の厳格さ（LLM→🟡 強制、squash 3 重検証、実ブランチ名判定）と LLM 退避の実在検証」で担保し、確認が本質的に必要な操作（dirty 破棄・🔴 マージ/破棄）だけを残す。

## What Changes

- **Step B を 2 パス構成に再編（BREAKING: per-target 確認の廃止）**:
  - **Pass 1（ノンブロッキング自動処理）**: 診断して 🟢 Safe → 確認なしで即削除（`--keep` 時は即再利用化）。🟡 で dirty なし（LLM のみ）→ LLM 退避 → 退避物の実在検証 → 確認なしで即削除。🔴 または dirty あり → その場では触らず `DEFERRED` キューに積んで次へ進む。
  - **Pass 2（判断バッチ）**: `DEFERRED` が空ならそのまま Step C へ。非空なら全対象の状況（未マージコミット一覧・dirty stat・LLM 有無）を提示し、AskUserQuestion でまとめて選択させる（1 対象 1 問、1 回最大 4 問でバッチ分割）。回答後の別ターンでマージ / スキップ / 破棄を逐次実行する。
- **承認モデルの変更**: 🟢 / 🟡（LLM 退避検証済み・dirty なし）の削除は「Step A で TARGETS に含めた」ことを承認とみなし、追加確認しない。ただし削除直前に診断根拠（マージ済み判定の根拠）を必ず表示する（無音削除の禁止）。
- **絶対禁則 1 の改訂**: 「全破壊操作に AskUserQuestion 必須」→「dirty 破棄・🔴 破棄削除・🔴 マージは AskUserQuestion 回答後の別ターン必須。🟢 / 🟡（退避検証済み）の削除は Step A の対象確定を承認として自動実行可」。禁則 2（LLM あり→🟡 強制）・3（実ブランチ名判定）・4（LLM 保全先の実在検証）は不変。禁則 4 に「退避検証の成功が自動削除の前提。検証失敗時は削除せず HELD」を明文化。
- **マージ・競合・サニティの実行ロジックは不変**: `git merge --no-ff`、競合時の自動 abort 禁止、マージ都度サニティチェック、`--keep` 時のマージ後通常削除フォールバックは Pass 2 内でそのまま維持。
- フラグは増やさない（`--keep` / `--no-sync` のみ維持）。

## Capabilities

### Modified Capabilities

- `wt-clean-target-selection`: 逐次処理ループの「カテゴリ別対話処理」を「Pass 1 自動処理 + Pass 2 判断バッチ」に変更。🟢 / 🟡（LLM のみ）の確認要件を削除し、代わりに削除直前の診断根拠表示と LLM 退避検証を要件化。
- `wt-clean-merge-active`: 🔴 の確認タイミングを「診断時にその場で」から「Pass 1 完了後の判断バッチでまとめて」に変更。選択肢の内容・出し分け（dirty / detached でマージ除外）・マージ実行・競合ハンドリング・都度サニティは維持。

## Impact

- **コード/スキル**: `plugins/worktree/skills/wt-clean/SKILL.md`（正本）、`plugins/worktree/commands/wt-clean.md`（frontmatter description の同期）、`plugins/worktree/.claude-plugin/plugin.json`（version 2.2.1 → 2.3.0 + description）。
- **spec**: `wt-clean-target-selection` / `wt-clean-merge-active` の delta。
- **ユーザー体験**: 🟢 / 🟡（LLM のみ）が黙って消えるようになる（BREAKING）。誤って TARGETS に含めた場合の防波堤が per-target 確認から Step A の選択に移るため、Step A の「全て」選択の重みが増す。診断根拠の直前表示と Step C レポートで事後追跡可能性を確保する。
- **安全性の担保**: 過去事故（LLM ログのみに成果が残る worktree の誤削除）は禁則 2（LLM→🟡）+ 退避検証で引き続き防がれる。dirty 破棄と未マージ破棄は引き続き明示確認なしには実行されない。
