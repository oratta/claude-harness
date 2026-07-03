# Tasks: worktree-command-dedup

## 1. SKILL.md 正の保全確認（正の一本化先の確定）

- [x] 1.1 `plugins/worktree/skills/wt-clean/SKILL.md` が squash 検出（検証 A: 実ツリー差分 / 検証 B: `git cherry` / 検証 C: `gh pr` MERGED）と「実ツリー差分を優先」「`SQUASHED` 非空は 🟢/🟡、`AHEAD_COUNT>0` でも 🔴 にしない」を備えていることを確認する（本 change では SKILL.md を書き換えない前提の基準点）
- [x] 1.2 `plugins/worktree/skills/wt-clean/SKILL.md` が AskUserQuestion 別ターン実行の絶対禁則（「AskUserQuestion ツール呼び出しと削除 Bash を同一ターンの並列ツール呼び出しに含めてはならない」）を備えていることを確認する
- [x] 1.3 `plugins/worktree/skills/wt-setup/SKILL.md` が Step 1-6 の正（スクリプト実行・`.worktreeinclude` 生成・依存インストール・Draft PR・完了レポート・後続作業）を備えていることを確認する

## 2. wt-clean コマンドのラッパー化

- [x] 2.1 `plugins/worktree/commands/wt-clean.md` の frontmatter（`name` / `description` / `allowed-tools`）を維持し、`allowed-tools` に `Read, Bash, AskUserQuestion` を含む必要ツール一式が残ることを確認する
- [x] 2.2 本文を、`${CLAUDE_PLUGIN_ROOT}/skills/wt-clean/SKILL.md` を Read tool で読み込みメインセッションでインライン実行する薄いラッパーに置換する（`plugins/lr/commands/e.md` 方式）。`CLAUDE_PLUGIN_ROOT` 未設定時の marketplace / installed 探索フォールバックを含める
- [x] 2.3 診断分類表・Step 0-C の実行フロー本文・squash 検出ロジック（検証 A/B/C・`git cherry`・`TREE_DIFF`・`SQUASHED`）の重複コピーを command から完全に除去する
- [x] 2.4 `$ARGUMENTS`（位置引数 / `--keep` / `--no-sync`）を SKILL.md の実行にそのまま透過する旨を本文に明記する

## 3. wt-setup コマンドのラッパー化

- [x] 3.1 `plugins/worktree/commands/wt-setup.md` の frontmatter（`name` / `description` / `argument-hint` / `allowed-tools`）を維持する
- [x] 3.2 本文を、`${CLAUDE_PLUGIN_ROOT}/skills/wt-setup/SKILL.md` を Read tool で読み込みインライン実行する薄いラッパーに置換する。`CLAUDE_PLUGIN_ROOT` 未設定時の探索フォールバックを含める
- [x] 3.3 Step 1-6 の手順本文（`wt-setup.sh` 呼び出しブロック・`.worktreeinclude` 生成の分類ルール本文・`gh pr create --draft` の Draft PR ブートストラップ手順）の重複コピーを command から完全に除去する
- [x] 3.4 `$ARGUMENTS`（`--with-pr` フラグ + 後続作業指示）を SKILL.md の実行にそのまま透過する旨を本文に明記する

## 4. wt-setup.sh の実挙動確認と文書化（付録 D-3）

- [x] 4.1 `find . -path "./$pattern" -type f` の展開挙動を実挙動確認する（`.env.*` など既定パターンが直下のみ一致し、サブディレクトリを想定していないこと）。問題がなければ直下想定である旨のコメントを `wt-setup.sh` の該当箇所に追記、取りこぼしが確認されたら修正する
- [x] 4.2 `.claude/settings.local.json` を worktree に symlink する処理の是非を実挙動確認する。同一マシン・同一ユーザー内での権限設定共有として妥当なら理由コメントを追記して現状維持、問題が確認されたら symlink 対象から外す等の修正をする
- [x] 4.3 `bash -n plugins/worktree/scripts/wt-setup.sh` の構文検証が PASS することを確認する

## 5. テスト

- [x] 5.1 `plugins/worktree/tests/` を新設し、bats テストを追加する（既存 tests ディレクトリは無いため新規作成）
- [x] 5.2 wt-clean ラッパーの検証: `commands/wt-clean.md` が `skills/wt-clean/SKILL.md` の Read 指示を含み、診断分類表（`🟢 Safe` 等）・squash 手順本文（`検証A` / `TREE_DIFF` 等）を含まないことを grep で検証する
- [x] 5.3 wt-setup ラッパーの検証: `commands/wt-setup.md` が `skills/wt-setup/SKILL.md` の Read 指示を含み、Step 1-6 手順本文（`wt-setup.sh` 呼び出し・Draft PR 手順）を含まないことを grep で検証する
- [x] 5.4 frontmatter 維持の検証: `commands/wt-clean.md` の `allowed-tools` に `AskUserQuestion` があること、`commands/wt-setup.md` に `argument-hint` があることを grep で検証する
- [x] 5.5 SKILL.md 保全の検証: `skills/wt-clean/SKILL.md` に検証 A/B/C・「実ツリー差分を優先」・AskUserQuestion 別ターン絶対禁則の文言が残存することを grep で検証する
- [x] 5.6 `find plugins/worktree -name '*.bats' -print0 | xargs -0 bats` が全 PASS することを確認する

## 6. バージョン同期

- [x] 6.1 `plugins/worktree/.claude-plugin/plugin.json` の version を 2.1.1 → 2.2.0 に bump する（marketplace.json の同期は change-7 が担当。本 change は marketplace.json に触れない）
- [x] 6.2 `jq . plugins/worktree/.claude-plugin/plugin.json` の JSON 構文検証が PASS することを確認する

## 7. 統合確認

- [x] 7.1 受け入れ条件 10 の確認: `plugins/worktree/commands/wt-clean.md` と `wt-setup.md` に診断分類表・手順本文の重複コピーが無く、SKILL.md を Read するラッパー構造になっていることを確認する
- [x] 7.2 command 経由と skill 経由で同一の診断フローになること（command 側に SKILL.md と異なる別フロー定義が残っていないこと）を確認する
- [x] 7.3 `/wt-clean`（引数なし・選択画面まで）と `/wt-setup`（引数なし）の smoke 起動で、ラッパーが SKILL.md を読み込んでフローを開始することを確認する
