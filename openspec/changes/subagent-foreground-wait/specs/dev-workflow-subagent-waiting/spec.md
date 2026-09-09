## ADDED Requirements

### Requirement: サブエージェントは完了を待つためにターンを終えない
dev-workflow のサブエージェント（W / R1 / G）は、長時間処理（Codex レビュー・フルテスト・ビルド）の完了通知を待つ目的でターンを終えてはならない（MUST NOT）。名前付き background サブエージェントは idle になっても自分の背景タスクの完了では再起動されず、完了通知はキューに積まれるだけで新しいターンを起こさないためである。待ちは同一ターン内の前景ポーリングで行わなければならない（MUST）。Monitor ツールや `run_in_background` の「完了したら続きが動く」挙動に依存してはならない（MUST NOT）。ただし禁止されるのは待ち方であって起動方法ではなく、10 分を超えうる処理を `run_in_background` で起動すること自体は許可される（SHALL）。この禁止はサブエージェントに限られ、背景タスクの完了で再起動されるメインセッションには適用されない（SHALL）。

#### Scenario: Codex レビューの完了を待つ
- **WHEN** サブエージェントが `run_in_background` で Codex レビューを起動した
- **THEN** そのターンを終えずに、同一ターン内で前景の待ちループを呼んで完了を確認する

#### Scenario: 通知待ちでターンを終えようとする
- **WHEN** サブエージェントが「完了通知を待つ」旨のテキストだけを出してターンを終えようとする
- **THEN** 手順書がそれを禁止しており、代わりに前景ポーリングを繰り返す指示になっている

### Requirement: 待ちは前景の有限ループを必要な回数呼び直す
待ちループは `timeout` を明示した前景 Bash 呼び出しの中で、終了条件を持つ有限ループ（例: `until <条件>; do sleep <間隔>; done`）として書かなければならない（MUST）。1 回の呼び出しで完了しなければ、同じ呼び出しをもう一度発行して待ちを継続する（SHALL。1 回の Bash 呼び出しはターンの終わりではない）。行頭の裸の長時間 `sleep` は使わない（MUST NOT）が、ループ内の `sleep` は許可対象である。

#### Scenario: 1 回の待ちで完了しない
- **WHEN** 前景の待ちループがタイムアウトしても対象の処理が終わっていない
- **THEN** 同じ待ちループをもう一度呼び出し、ターンは継続したままである

#### Scenario: 待ちに入る前の告知
- **WHEN** サブエージェントが長い待ちループに入る
- **THEN** これから最大何分待つかを出力してからループに入る

### Requirement: 前景の待ち値は Bash の前景上限未満である
前景 Bash 呼び出しの上限は 600000 ms であり、手順書が指定する待ち値（Bash の `timeout`、`codex-companion.mjs status --wait --timeout-ms` など）はすべて 600000 未満でなければならない（MUST）。dev-workflow の既定値は 540000 ms（9 分）とし、上限ちょうどを指定して後処理ごと打ち切られることを避ける（SHALL）。

#### Scenario: companion の待ち値
- **WHEN** 手順書が `codex-companion.mjs status <job-id> --wait --timeout-ms <値>` を示す
- **THEN** `<値>` は 600000 未満であり、既定として 540000 が示されている

### Requirement: 待ち方の契約は共有 references に 1 本置く
待ち方の正本は `plugins/dev-workflow/references/subagent-waiting.md` に置かなければならない（MUST）。W / R1 / G の各指示書と `skills/pr-review-gate/SKILL.md` は、禁止そのものを 1 行で書いたうえでこの正本を参照する（SHALL）。同じ待ち方の手順を複数のファイルに複製してはならない（MUST NOT）。

#### Scenario: 正本の所在
- **WHEN** サブエージェントが待ち方の詳細を知りたい
- **THEN** 自分の指示書にある 1 行から `references/subagent-waiting.md` に到達できる

### Requirement: 待ち方の退行を機械検出する
`tests/` 配下の bats スイートが、dev-workflow の手順書に対して次の 3 点を検査しなければならない（MUST）: 待ちを背景タスクの完了通知に委ねる指示が残っていないこと、`--timeout-ms` および Bash の `timeout` として書かれた値がすべて 600000 未満であること、`skills/develop/references/roles/` 配下の各指示書に待ちでターンを終えない旨の記述があること。正本ファイル自身とテスト自身は禁止語を説明のために含むため、検査対象から除外する（SHALL）。

#### Scenario: 古い書き方に戻したとき
- **WHEN** 手順書の待ち値を 900000 に戻す、または待ちでターンを終える指示を書き戻す
- **THEN** `scripts/test.sh` が失敗し、どのファイルの何を直すかを示す
