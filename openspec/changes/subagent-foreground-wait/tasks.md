## 1. 退行ガード（テストを先に書く）

- [ ] 1.1 `tests/subagent-waiting.bats` を追加し、`skills/develop/references/roles/*.md` と `skills/pr-review-gate/SKILL.md` に「完了通知を待ってターンを終える」形の指示が残っていないことを検査する（正本 `references/subagent-waiting.md` と本テスト自身は検査対象から除外し、除外理由をコメントで書く）
- [ ] 1.2 同スイートに、dev-workflow 配下の `--timeout-ms` と Bash の `timeout` に書かれた数値がすべて 600000 未満であることの検査を追加する
- [ ] 1.3 同スイートに、`roles/worker.md` / `roles/spec-reviewer.md` / `roles/gate-runner.md` のそれぞれが待ちでターンを終えない旨と `references/subagent-waiting.md` への参照を含むことの検査を追加する
- [ ] 1.4 `scripts/test.sh subagent-waiting` を実行し、この時点で 1.1〜1.3 が Red になることを exit code 付きで確認する

## 2. 待ち方の正本を置く

- [ ] 2.1 `plugins/dev-workflow/references/subagent-waiting.md` を新規作成し、禁止（待つためにターンを終えない・Monitor / 完了通知に依存しない）、許可（background 起動そのもの・ループ内 `sleep`）、待ちループの雛形、前景上限 600000 ms と既定 540000 ms、メインセッションには適用しない旨を書く
- [ ] 2.2 `sleep` がハーネス側で拒否された場合の代替（呼び出しを短く刻んで回数を増やす）を 1 行添える

## 3. 手順書を書き換える

- [ ] 3.1 `roles/gate-runner.md` の Codex 起動行を、background 起動＋同一ターン内の前景ポーリング（`timeout` 540000 の `until` ループ、companion なら `--timeout-ms 540000`）に書き換え、正本への参照を添える
- [ ] 3.2 `skills/pr-review-gate/SKILL.md` の Codex 呼び出し規約を読み手別に書き分け（メインセッションは `--background`＋完了通知で可、サブエージェントは前景ポーリング必須）、`--timeout-ms 900000` を 540000 に直し、1 回で終わらなければ同じ呼び出しを繰り返す旨を書く
- [ ] 3.3 `roles/worker.md` に待ちでターンを終えない禁止 1 行と正本への参照を入れる
- [ ] 3.4 `roles/spec-reviewer.md` に同じ 1 行を入れる

## 4. 配布とテスト

- [ ] 4.1 `plugins/dev-workflow/.claude-plugin/plugin.json` のバージョンを上げる（テスト S131 が merge-base からの bump を要求する）
- [ ] 4.2 `scripts/test.sh` を全件実行し、exit code と要約をターン内に表示する
- [ ] 4.3 openspec の delta と本文の整合を確認する（`openspec validate` 相当 / `scripts/test.sh openspec`）

## 5. 動作確認と記録

- [ ] 5.1 変更後の develop 実行 1 回で、G の idle 通知の result 本文に「完了を待つ」系の文言が出ないことを親のトランスクリプトで確認し、証拠を PR に添える
- [ ] 5.2 `/opsx:verify` と `/opsx:archive` を通し、archive 済みの状態を PR に含める
