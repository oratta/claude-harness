> **実装後の訂正（2026-09-09、PR #256 のゲート指摘を受けて）**
>
> この change の記述のうち、次の 3 点は実装中に事実と食い違うことが判明したため、正本（`plugins/dev-workflow/references/subagent-waiting.md`）と main specs 側で訂正済み。この archive は承認時点の記録としてそのまま残す。
>
> 1. **companion 経路をこの change は「exit code でタイムアウトと完了を区別する」としているが、区別できない。** `codex-companion.mjs` の `handleStatus` は結果を出力して return するだけで `process.exitCode` を設定しないため、タイムアウトでも完了でも 0 を返す（実測）。訂正後は `--json` を付けて出力の `waitTimedOut` を見る
> 2. **完了マーカーを固定文字列 `__CODEX_DONE__` にすると、レビュー対象の文書がその文字列を含むだけでポーリングが誤成立する。** 実際に PR #256 自身のレビューで発生した。訂正後は実行ごとに一意な nonce を埋め、行頭アンカー付きの完全な形で照合する
> 3. **雛形の `$out` が定義されていなかった。** 起動と待ちは別々の Bash 呼び出しでシェル変数が引き継がれないため、訂正後は出力ファイルの作成を雛形に含め、待ち側にはパスを literal で書く
>
> あわせて、この change が置いた「正本 1 本・各指示書は禁止 1 行」の設計に対し `gate-runner.md` と `pr-review-gate/SKILL.md` が手順を再掲していた点も訂正し、再掲の禁止を退行検出で機械的に守る形にした。

## ADDED Requirements

### Requirement: サブエージェントは完了を待つためにターンを終えない
dev-workflow のサブエージェント（W / R1 / G）は、長時間処理（Codex レビュー・フルテスト・ビルド）の完了通知を待つ目的でターンを終えてはならない（MUST NOT）。名前付き background サブエージェントは idle になっても自分の背景タスクの完了では再起動されず、完了通知はキューに積まれるだけで新しいターンを起こさないためである。待ちは同一ターン内の前景ポーリングで行わなければならない（MUST）。Monitor ツールや `run_in_background` の「完了したら続きが動く」挙動に依存してはならない（MUST NOT）。ただし禁止されるのは待ち方であって起動方法ではなく、10 分を超えうる処理を `run_in_background` で起動すること自体は許可される（SHALL）。この禁止はサブエージェントに限られ、背景タスクの完了で再起動されるメインセッションには適用されない（SHALL）。

#### Scenario: Codex レビューの完了を待つ
- **WHEN** サブエージェントが `run_in_background` で Codex レビューを起動した
- **THEN** そのターンを終えずに、同一ターン内で前景の待ちループを呼んで完了を確認する

#### Scenario: 通知待ちでターンを終えようとする
- **WHEN** サブエージェントが「完了通知を待つ」旨のテキストだけを出してターンを終えようとする
- **THEN** 手順書がそれを禁止しており、代わりに前景ポーリングを繰り返す指示になっている

### Requirement: 完了シグナルを経路ごとに定める
待ちループの終了条件は、起動経路ごとに手順書が一意に定めなければならない（MUST）。実装者が検知方法を自分で発明してはならない（MUST NOT）。`codex exec` も `codex-companion.mjs` も出力に完了マーカーを書かないため、マーカーは起動側で付ける。

- **`codex exec` 直叩き経路**: 起動コマンドを `{ codex exec … ; echo "__CODEX_DONE__ rc=$?" ; } >> "$out" 2>&1` の形にし、ポーリングの終了条件を出力ファイル中の `__CODEX_DONE__` の出現とする（MUST）。`rc=` の値で成否を判定する（SHALL）
- **`codex-companion.mjs` 経路**: `status <job-id> --wait --timeout-ms 540000` の exit code と status 出力を終了条件とする（MUST）。タイムアウトで返ったのか完了で返ったのかを exit code で区別する（SHALL）

#### Scenario: codex exec を直叩きする
- **WHEN** サブエージェントが `codex exec` を `run_in_background` で起動する
- **THEN** 起動コマンドに `__CODEX_DONE__ rc=$?` を書き足す形が手順書に示され、ポーリングはそのマーカーの出現で終わる

#### Scenario: companion 経由で起動する
- **WHEN** サブエージェントが `codex-companion.mjs task` でジョブを投げる
- **THEN** 待ちは `status <job-id> --wait --timeout-ms 540000` の exit code で判定し、出力ファイルの内容を推測しない

### Requirement: 待ちは前景の有限ループを上限回数まで呼び直す
待ちループは Bash ツール呼び出しの `timeout` パラメータを明示した前景実行の中で、終了条件を持つ有限ループ（例: `until <完了シグナル>; do sleep <間隔>; done`）として書かなければならない（MUST）。1 回の呼び出しで完了しなければ、同じ呼び出しをもう一度発行して待ちを継続する（SHALL。1 回の Bash 呼び出しはターンの終わりではない）。行頭の裸の長時間 `sleep` は使わない（MUST NOT）が、ループ内の `sleep` は許可対象である。

**総待ちには上限を設けなければならない（MUST）。** 既定は前景ループ 3 回（540000 ms × 3 = 27 分）とする。上限に達しても完了しない場合は待ちをやめ、経路ごとの分岐に入らなければならない（MUST）。G は `needs-reviewer` を return し、根拠に「Codex タイムアウト（27 分）」と書く。これは `skills/pr-review-gate/SKILL.md` のフォールバック条件「未導入・サブスク切れ・タイムアウト」の「タイムアウト」の定義であり、この上限がフォールバックの発火点になる（SHALL）。W / R1 は待ちをやめて本体に return する。上限なしに待ち続けてはならない（MUST NOT。ジョブが死んで出力が来ない場合と、単に時間がかかっている場合を区別できなくなるため）。

#### Scenario: 1 回の待ちで完了しない
- **WHEN** 前景の待ちループがタイムアウトしても対象の処理が終わっていない
- **THEN** 同じ待ちループをもう一度呼び出し、ターンは継続したままである

#### Scenario: 上限回数まで待っても完了しない
- **WHEN** 前景ループを 3 回（合計 27 分）呼んでも完了シグナルが現れない
- **THEN** 待ちをやめ、G は `needs-reviewer`（根拠に「Codex タイムアウト（27 分）」）を return し、W / R1 は本体に return する

#### Scenario: 待ちに入る前の告知
- **WHEN** サブエージェントが長い待ちループに入る
- **THEN** これから最大何分待つか（1 回あたり 9 分・上限 27 分）を出力してからループに入る

### Requirement: 待ち値は Bash ツールの timeout パラメータにミリ秒で指定する
待ち値は Bash ツール呼び出しの `timeout` パラメータ（ミリ秒）に指定しなければならない（MUST）。シェルの `timeout(1)` コマンドを使ってはならない（MUST NOT。macOS の既定には GNU `timeout` が無く `gtimeout` になるため、環境依存になる）。Bash ツールの前景上限は 600000 ms であり、手順書が示す待ち値（Bash ツールの `timeout`、`codex-companion.mjs status --wait --timeout-ms`）はすべて 600000 未満でなければならない（MUST）。dev-workflow の既定値は 540000 ms（9 分）とし、上限ちょうどを指定して後処理ごと打ち切られることを避ける（SHALL）。

#### Scenario: 待ちループの示し方
- **WHEN** 手順書が待ちループを例示する
- **THEN** Bash ツールの入力の形（`command` に `until … do sleep … done`、`timeout` に 540000）で示され、シェルの `timeout` コマンドは現れない

#### Scenario: companion の待ち値
- **WHEN** 手順書が `codex-companion.mjs status <job-id> --wait --timeout-ms <値>` を示す
- **THEN** `<値>` は 600000 未満であり、既定として 540000 が示されている

### Requirement: 待ち方の契約は共有 references に 1 本置く
待ち方の正本は `plugins/dev-workflow/references/subagent-waiting.md` に置かなければならない（MUST）。W / R1 / G の各指示書と `skills/pr-review-gate/SKILL.md` は、禁止そのものを 1 行で書いたうえでこの正本を参照する（SHALL）。同じ待ち方の手順を複数のファイルに複製してはならない（MUST NOT）。

#### Scenario: 正本の所在
- **WHEN** サブエージェントが待ち方の詳細を知りたい
- **THEN** 自分の指示書にある 1 行から `references/subagent-waiting.md` に到達できる

### Requirement: 待ち方の退行を機械検出する
`plugins/dev-workflow/tests/subagent-waiting.bats` が、dev-workflow の手順書に対して次の 3 点を検査しなければならない（MUST）。

1. 待ちを背景タスクの完了通知や Monitor に委ねる指示が残っていないこと
2. 文書中に現れる `--timeout-ms <数値>` と `timeout: <数値>` の 2 パターンの数値がすべて前景上限未満であること。上限値はスイート内の 1 変数（`FOREGROUND_LIMIT_MS=600000`）にまとめ、出典（Claude Code の Bash ツールの前景上限）をコメントで書く（SHALL）。この 2 パターン以外の `timeout` の出現は検査対象にしない（無関係な出現が大半のため）
3. `skills/develop/references/roles/` 配下の各指示書に、待ちでターンを終えない旨の記述と `references/subagent-waiting.md` への参照があること

正本ファイル自身とテスト自身は禁止語を説明のために含むため、検査対象から除外する（SHALL）。

#### Scenario: 古い書き方に戻したとき
- **WHEN** 手順書の待ち値を 900000 に戻す、または待ちでターンを終える指示を書き戻す
- **THEN** `scripts/test.sh` が失敗し、どのファイルの何を直すかを示す

#### Scenario: 上限値の直し先
- **WHEN** ハーネス側の前景上限が変わる
- **THEN** スイート内の `FOREGROUND_LIMIT_MS` 1 か所を直せば検査全体が追随する
