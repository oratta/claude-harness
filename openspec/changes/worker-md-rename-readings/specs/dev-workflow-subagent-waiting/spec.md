## MODIFIED Requirements

### Requirement: 実行時の検査が文言検査の素通りする違反を止めることを再現ケースで示す
`tests/subagent-stop-guard.bats` は、規約違反の待ち方（背景起動の後に終了通知を待たずにターンを終える）を表す合成トランスクリプトで hook が停止を拒否することを検査しなければならない（MUST）。あわせて、同じ違反を言い換えて指示書に書いた形を `subagent-waiting.bats` の文言検査が検出しないことを、同じスイートで対にして示さなければならない（MUST）。後者は、プラグインのディレクトリを `BATS_TEST_TMPDIR` に複製し、複製の `skills/develop/references/roles/worker/implement.md` に言い換えた違反を差し込み、その複製に対して既存の `subagent-waiting.bats` を実際に実行して exit 0 になることで示す（SHALL）。禁止語のリストを新しいスイートに写してはならない（MUST NOT。2 か所になると片方だけ古くなる）。実セッションでの再現（`claude -p --plugin-dir` で背景 `sleep` を起動してターンを終えるサブエージェントに拒否理由が届くこと）は、実行コマンドと出力を記録先に添付する（SHALL）。

#### Scenario: 文言検査は素通りし、実行時の検査は止める
- **WHEN** 待ちでターンを終える指示を禁止語を使わずに言い換えて複製の worker/implement.md に差し込み、その指示どおりに動いたトランスクリプトを用意する
- **THEN** 複製に対して走らせた `subagent-waiting.bats` は exit 0 で、`subagent-stop-guard.sh` はそのトランスクリプトでの停止を拒否する

#### Scenario: hooks.json の登録
- **WHEN** `hooks/hooks.json` を読む
- **THEN** `SubagentStop` に `${CLAUDE_PLUGIN_ROOT}/scripts/subagent-stop-guard.sh` が登録されており、既存の SessionStart / UserPromptSubmit / PreToolUse / PostToolUse のエントリは変わっていない

#### Scenario: 対の検査の差し込み先

- **WHEN** `tests/subagent-stop-guard.bats` の対の検査を読む
- **THEN** 複製の `skills/develop/references/roles/worker/implement.md` に言い換えた違反を差し込んでいる

#### Scenario: 待ちの規約の所在

- **WHEN** `worker/implement.md` の全経路共通の大原則を読む
- **THEN** 長時間処理の完了を待つ目的でターンを終えないことと、正本が `plugins/dev-workflow/references/subagent-waiting.md` であることが書かれている

## REMOVED Requirements

### Requirement: 待ちの規約を検査する W の指示書の読み替え

**Reason**: 読み替えの対象だった「worker.md」の名指しを、移し先のファイル名で直接書いたため（所在と差し込み先の Scenario は「実行時の検査が文言検査の素通りする違反を止めることを再現ケースで示す」に移した）

**Migration**: 他の要件が移し先のファイル名で直接書き直されたので、読み替えの規則は要らない。
