## 1. 先に起こす issue と確認

- [ ] 1.1 flatmate の `scripts/agent-status.sh` の `read_harness_rules_state`（`$CLAUDE_DIR/rules` 直下の symlink を数える）を、新しい張り先（`rules/claude-harness/`）でも「配線あり」と数えるように直す issue を flatmate に起こす（この change では直さない）。issue 番号を PR 本文に書く 触れる範囲: scripts/ なし（起票のみ）

## 2. sync.sh

- [ ] 2.1 `link_dir` に「この harness の根」「旧位置の掃除先」を渡せるようにし、公開版の張り先を `$CLAUDE_DIR/rules/claude-harness` にする。新位置に張ったあとで旧位置の公開版を指す symlink を消す 触れる範囲: scripts/sync.sh:61-117、scripts/sync.sh:119-120
- [ ] 2.2 dirty 判定つき ff-only pull を関数にし、overlay の clone にも使う 触れる範囲: scripts/sync.sh:37-58
- [ ] 2.3 overlay の探索（`.harness-overlay`、名前の検証、重複名の扱い）と、overlay の rules を `claude-harness/<名前>/`、output-styles を直下に張る。冒頭のコメント（挙動の節）を直す。個人版の名前を書かない（`tests/public-names` が見る） 触れる範囲: scripts/sync.sh:1-33、scripts/sync.sh:119-123

## 3. テスト

- [ ] 3.1 `tests/rules-sync.bats` の既存テストを新しい張り先に直す。仕様の各シナリオ（新位置・旧位置の移行・overlay・不正名・overlay 無しで標準エラー空・同名ルール・output style の同名・掃除）に対応するテストを足す。テスト名は ASCII のみ 触れる範囲: tests/rules-sync.bats:1-80（新規テストは末尾に追加）

## 4. 文書

- [ ] 4.1 `rules/README.md` の「導入・更新」節に、張り先のサブディレクトリ・overlay の印のファイル・同名ルールの扱い（両方読まれる、食い違う内容は書かない）・output style は公開版優先を書く。個人版の名前は書かない 触れる範囲: rules/README.md:7-30
- [ ] 4.2 `docs/worktree-recovery.md` の `~/.claude/rules/*.md` の記述を新しい張り先に合わせる 触れる範囲: docs/worktree-recovery.md:12-14
- [ ] 4.3 変更記録 `plugins/dev-workflow/changes/1130.md`（版は上げない。changes/ の置き場の既存例に合わせる） 触れる範囲: plugins/dev-workflow/changes/1130.md（新規）

## 5. 個人版リポジトリ側（別 PR。このリポジトリの worktree の外）

- [ ] 5.1 個人版の根に `.harness-overlay`（中身 `oratta` の 1 行）を置き、README の `ln -sfn ... ~/.claude/rules/harness-dev.md` の手順を、sync.sh が張る説明に直す。記録先はこの issue

## 6. 確かめ方（PR に書く）

- [ ] 6.1 マージ後、marketplace の clone で `scripts/sync.sh` を 1 回走らせる（開発用 clone や worktree の sync.sh は走らせない）。`ls -l ~/.claude/rules/claude-harness ~/.claude/rules/claude-harness/oratta` で出どころが見え、`~/.claude/rules` 直下に公開版の symlink が残っていないこと
- [ ] 6.2 別の cwd で `claude -p --model haiku` に、公開版のルール 1 本と個人版のルール 1 本（`harness-dev.md`）の冒頭の文を答えさせる。スキルは `claude -p "/weekly-report が使えるか"` のような 1 問、hook は `/hooks` の一覧で確認する
- [ ] 6.3 客の Mac の模擬: 使い捨ての `CLAUDE_CONFIG_DIR` で overlay 無しの `scripts/sync.sh --no-pull` が標準エラー空・終了コード 0（テストが同じことを見る）
