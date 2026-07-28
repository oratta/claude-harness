## 1. SKILL.md へのプロセス停止ステップ追加

- [x] 1.1 `plugins/worktree/skills/wt-clean/SKILL.md` に共通ヘルパー `kill_devserver_under "$WT"` の bash 実装（`lsof +D` 検出 → シェル/エディタ除外 → SIGTERM → 3秒待機 → 生存確認 → SIGKILL フォールバック → ログ表示）を Step B-🟢 の直前に 1 箇所だけ定義する
- [x] 1.2 `lsof` が使えない場合に `pgrep -f "$WT"` へフォールバックする分岐と、フォールバック使用のログ表示を実装に含める
- [x] 1.3 Step B-🟢（自動削除）の `git worktree remove "$WT" --force` の直前に `kill_devserver_under "$WT"` 呼び出しを追加する
- [x] 1.4 Step B-🟡（LLM 退避後削除）の `git worktree remove "$WT" --force` の直前に `kill_devserver_under "$WT"` 呼び出しを追加する
- [x] 1.5 Pass 2 の 🔴 破棄削除・🟡 dirty 破棄・🔴 マージ後削除、各 `git worktree remove` 呼び出しの直前に `kill_devserver_under "$WT"` 呼び出しを追加する（3 箇所）
- [x] 1.6 「## 🔴 Active worktree の強制破棄」節の手順リストにプロセス停止ステップを明記する

## 2. 自己検証・参照ドキュメントの更新

- [x] 2.1 `plugins/worktree/references/wt-clean-verification.md` に「削除対象 worktree 配下のプロセス残留なし」の確認項目を追加する
- [x] 2.2 `plugins/worktree/skills/wt-clean/SKILL.md` の `## 自己検証` 節にプロセス残留チェックの参照を追加する

## 3. テスト

- [x] 3.1 `plugins/worktree/tests/` に新しい bats テストファイル（例: `devserver-kill.bats`）を追加し、`kill_devserver_under` の定義・`lsof +D` 使用・SIGTERM→SIGKILL フォールバック・シェル除外リスト・5 箇所全てへの適用が SKILL.md に記載されていることを検証する
- [x] 3.2 `bats plugins/worktree/tests/*.bats` を実行し、新規テストが全て pass することを確認する（既存の pre-existing failure 2 件＝version 期待値・古い文言チェックは本 change のスコープ外のため無視してよいが、新規に増やさないこと）

## 4. バージョン更新・仕上げ

- [x] 4.1 `plugins/worktree/.claude-plugin/plugin.json` の version を bump する
- [x] 4.2 `openspec/changes/wt-clean-devserver-kill/tasks.md` の全項目にチェックを入れ、`opsx:verify` で実装が spec と一致することを確認する
