## 1. テスト先行（Red）

- [x] 1.1 `plugins/loops/tests/pre-push-merged-pr-guard.bats` を作成し、SKILL.md Step 6 の sh コードブロックを抽出して実行可能なフックとして取り出すヘルパーを書く
- [x] 1.2 `gh` スタブ（merged/open の件数と exit code を環境変数で制御）を PATH に差し込む仕組みをテストに用意する
- [x] 1.3 振る舞いテストを書く: (a) merged>0 ∧ open==0 で exit 1、(b) merged==0 で exit 0、(c) merged>0 ∧ open>0 で exit 0、(d) gh 失敗で exit 0（fail-open）、(e) local_sha 全ゼロで exit 0、(f) `PREPUSH_ALLOW_MERGED=1` で exit 0、(g) main/master 直 push で exit 1、(h) `PREPUSH_ALLOW_MERGED=1` でも main 直 push は exit 1
- [x] 1.4 記述テストを書く: 拒否メッセージに `PREPUSH_ALLOW_MERGED=1` の案内が含まれる／SKILL.md に fail-open 方針と再適用手順が明記されている／レシピがマージ済み PR チェックに言及している／plugin.json の version が 0.17.0 より大きい
- [x] 1.5 テストを実行して Red を確認する（exit code を表示）

## 2. 実装（Green）

- [x] 2.1 `plugins/loops/skills/loops-dev-agent-install/SKILL.md` Step 6 のフックテンプレートを拡張する（削除 push の early continue → main/master 拒否 → バイパス判定 → gh 2 回呼び出し → merged>0 ∧ open==0 で exit 1）
- [x] 2.2 Step 6 に fail-open 方針・多層防御の位置づけ・`PREPUSH_ALLOW_MERGED=1` の説明を追記する
- [x] 2.3 SKILL.md に導入済み repo への再適用手順（Step 6 のみ再実行）を追記する
- [x] 2.4 `plugins/loops/recipes/loop-dev-agent.md` のガード説明にマージ済み PR チェックへの言及を追加する
- [x] 2.5 `plugins/loops/.claude-plugin/plugin.json` の version を 0.18.0 に上げる
- [x] 2.6 テストを実行して Green を確認する（exit code を表示）

## 3. 動作確認（実 repo）

- [x] 3.1 SKILL.md から抽出したフックを一時 `core.hooksPath` に配線して検証し、検証後に設定を元（未設定）へ戻す（本 repo は agent-loop 未導入で `.githooks/` を持たないため、untracked ファイルを残さない）
- [x] 3.2 マージ済み PR のブランチ（#48 `oratta/pr-issue-llm-1`）への push が拒否されることを確認する（`git push --dry-run` でも pre-push は実行されるため、remote を一切変更せずに拒否を確認できる）
- [x] 3.3 現在の作業ブランチ（open PR あり）への push が通ることを確認する
- [x] 3.4 `PREPUSH_ALLOW_MERGED=1` でバイパスできることを確認する

## 4. 仕上げ

- [x] 4.1 `/opsx:verify` で artifact と実装の整合を検証する
- [ ] 4.2 PR 本文を `plugins/loops/references/pr-body-format.md` の 5 節構成で更新し、Ready for Review に切り替える
