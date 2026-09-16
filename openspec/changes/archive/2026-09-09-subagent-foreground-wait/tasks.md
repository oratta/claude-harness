> **実装後の訂正（2026-09-09、PR #256 のゲート指摘を受けて）**
>
> この change の記述のうち、次の各点は実装後に事実と食い違うことが判明したため、正本（`plugins/dev-workflow/references/subagent-waiting.md`）と main specs 側で訂正済み。この archive は承認時点の記録としてそのまま残す。1〜3 はゲート 1 周目の指摘、4〜5 はその訂正自体に 2 周目で見つかった穴。
>
> 1. **companion 経路をこの change は「exit code でタイムアウトと完了を区別する」としているが、区別できない。** `codex-companion.mjs` の `handleStatus` は結果を出力して return するだけで `process.exitCode` を設定しないため、タイムアウトでも完了でも 0 を返す（実測）。訂正後は `--json` を付けて出力の `waitTimedOut` を見る
> 2. **完了マーカーを固定文字列 `__CODEX_DONE__` にすると、レビュー対象の文書がその文字列を含むだけでポーリングが誤成立する。** 実際に PR #256 自身のレビューで発生した。訂正後は実行ごとに一意な nonce を埋め、行頭アンカー付きの完全な形で照合する
> 3. **雛形の `$out` が定義されていなかった。** 起動と待ちは別々の Bash 呼び出しでシェル変数が引き継がれないため、訂正後は出力ファイルの作成を雛形に含め、待ち側にはパスを literal で書く
> 4. **その nonce を `date +%s` で作ると、並行して走るサブエージェント（G / W / R1）が同じ秒に衝突する。** 一方の完了マーカーが他方の未完了ジョブを完了扱いにする（落ちずに間違う）。加えて nonce を未エスケープのまま拡張正規表現に埋めていたため、メタ文字を含む nonce は別の文字列に誤マッチする（`a.b` が `axb` に一致）。訂正後は nonce を `uuidgen`（無い環境ではプロセス ID と `$RANDOM`）から作り、文字集合を英数字のみに制限したうえで、照合を行末までアンカーする（`^__CODEX_DONE_<nonce>__ rc=[0-9]+$`）
> 5. **起動の雛形がレビュー指示をダブルクォートに素で埋め込んでいた。** 指示文に `"` や `` ` `` や `$(...)` が入ると引数が壊れるか、意図しないコマンドが実行される。訂正後はレビュー指示をクォート付きヒアドキュメントでファイルに保存し、`codex exec … - < <プロンプトファイル>` で標準入力から渡す（`codex exec` が `-` で標準入力を読むことは `--help` と実測で確認済み）
> 6. **`uuidgen` が無い環境のフォールバック `$RANDOM` は、同一プロセス内で 5 回とも同じ値を返した。** 複数のコマンド置換サブシェルが同じ乱数状態を継承するため。乱数も `uuidgen` も「たぶん被らない値」を作るだけで、被っていないことは誰も確認していない。訂正後は一意性を排他生成（`mktemp -d` = `mkdtemp(3)` の `O_EXCL`）に置き、フォールバック経路を持たず、生成直後に非空・英数字のみ・16 文字以上を検証して外れたら起動前に非 0 で終了する。プロンプトとログも固定パス（`/tmp/codex-prompt-…`）をやめ、生成した専用ディレクトリの配下に置く。この穴が 3 周続けて残ったのは雛形を文言でしか検査していなかったためなので、退行検出に「雛形を抽出して実際に実行する」検査を足した（4〜5 は 2 周目、6 は 3〜4 周目の指摘）
>
> あわせて、この change が置いた「正本 1 本・各指示書は禁止 1 行」の設計に対し `gate-runner.md` と `pr-review-gate/SKILL.md` が手順を再掲していた点も訂正し、再掲の禁止を退行検出で機械的に守る形にした。

## 1. 退行ガード（テストを先に書く）

- [x] 1.1 `plugins/dev-workflow/tests/subagent-waiting.bats` を追加し、`skills/develop/references/roles/*.md` と `skills/pr-review-gate/SKILL.md` に「完了通知や Monitor に待ちを委ねる」形の指示が残っていないことを検査する（正本 `references/subagent-waiting.md` と本テスト自身は禁止語を説明のために含むので検査対象から除外し、除外理由をコメントで書く）
- [x] 1.2 同スイートに、`plugins/dev-workflow` 配下の文書に現れる `--timeout-ms <数値>` と `timeout: <数値>` の 2 パターンの数値がすべて上限未満であることの検査を追加する。上限は 1 変数 `FOREGROUND_LIMIT_MS=600000` にまとめ、出典（Claude Code の Bash ツールの前景上限）をコメントで書く。この 2 パターン以外の裸の `timeout` は検査対象にしない
- [x] 1.3 同スイートに、`roles/worker.md` / `roles/spec-reviewer.md` / `roles/gate-runner.md` のそれぞれが待ちでターンを終えない旨と `references/subagent-waiting.md` への参照を含むことの検査を追加する
- [x] 1.4 新規 .bats を `git add -N` してから `scripts/test.sh subagent-waiting` を実行し（`scripts/test.sh` は `git ls-files -- '*.bats'` で対象を集めるため untracked のままだとフィルタに一致しない）、1.1〜1.3 が Red になることを exit code と落ちたテスト名付きで確認する

## 2. 待ち方の正本を置く

- [x] 2.1 `plugins/dev-workflow/references/subagent-waiting.md` を新規作成し、禁止（待つためにターンを終えない・Monitor / 完了通知に依存しない）、許可（background 起動そのもの・ループ内 `sleep`）、待ちループの雛形を Bash ツールの入力の形（`command` と `timeout: 540000` の組）で示す。シェルの `timeout(1)` を使わない理由（単位が秒・macOS 既定に GNU 版が無い）も書く
- [x] 2.2 完了シグナルを経路ごとに書く。(a) `codex exec` 直叩きは起動コマンドを `{ codex exec … ; echo "__CODEX_DONE__ rc=$?" ; } >> "$out" 2>&1` にしてマーカーの出現を終了条件にする、(b) companion 経由は `status <job-id> --wait --timeout-ms 540000` の exit code を終了条件にする
- [x] 2.3 総待ちの上限（前景ループ 3 回 = 27 分）と超過時の分岐（G は `needs-reviewer` を return し根拠に「Codex タイムアウト（27 分）」、W / R1 は本体に return）を書く。これが pr-review-gate のフォールバック条件「タイムアウト」の定義であることを明記する
- [x] 2.4 メインセッションにはこの禁止が適用されない旨と、`sleep` がハーネス側で拒否された場合の代替（ポーリング間隔を短く刻んで呼び出し回数を増やす）を 1 行ずつ添える
- [x] 2.5 `plugins/dev-workflow/README.md` の `references/` の表に `subagent-waiting.md` の行を 1 行説明付きで追加する（`dev-workflow-shared-references` の MUST）
- [x] 2.6 既存の退行ガード `plugins/dev-workflow/tests/shared-references.bats` を共有契約 5 本に更新する（実在チェック・README 名指しチェック・冒頭コメント。delta で追加した Scenario「5 契約が実在する」「README が置き場の規約と 5 本を説明している」の裏取り）

## 3. 手順書を書き換える

- [x] 3.1 `roles/gate-runner.md:17` の (a) `codex exec` 直叩き経路を書き換える。`run_in_background` での起動は残し、完了マーカー `__CODEX_DONE__ rc=$?` を起動コマンドに書き足し、そのマーカーを終了条件とする前景ポーリング（`timeout: 540000`）で待つ形にする
- [x] 3.2 `roles/gate-runner.md:17` の (b) companion 経路を書き換える。`--timeout-ms 900000` を 540000 に直し、1 回で終わらなければ同じ呼び出しを繰り返すこと、上限 3 回で `needs-reviewer` を return することを書く。両経路から正本への参照を添える
- [x] 3.3 `skills/pr-review-gate/SKILL.md` の Codex 呼び出し規約を読み手別に書き分ける（メインセッションは `--background`＋完了通知で可、サブエージェントは前景ポーリング必須）。あわせて `:106` の見出し文を「前景 1 回で完走させようとする呼び方の禁止」と「前景ポーリングでの完了確認の必須」が区別できる形に書き直す
- [x] 3.4 同 SKILL.md の `--timeout-ms 900000` を 540000 に直し、`:110` の「1回の呼び出しで最長 15 分待てる」を削除して、1 回で終わらなければ繰り返すこと・上限 27 分でフォールバックに入ることに置き換える。`--timeout-ms` の既定が 4 分なので必ず明示する、という既存の注意は残す
- [x] 3.5 `roles/worker.md` に待ちでターンを終えない禁止 1 行と正本への参照を入れる
- [x] 3.6 `roles/spec-reviewer.md` に同じ 1 行を入れる。decider 経路の R1 は `Bash` を持たず待ちを伴う作業を持たない旨を添える

## 4. 配布とテスト

- [x] 4.1 `plugins/dev-workflow/.claude-plugin/plugin.json` のバージョンを上げ、`.claude-plugin/marketplace.json` の dev-workflow エントリの version を同じ値に揃える（S131 が merge-base からの bump を、S130 が両者の一致を要求する）
- [x] 4.2 `scripts/test.sh subagent-waiting` を実行し、1.1〜1.3 が Green になることを exit code 付きで確認する
- [x] 4.3 `scripts/test.sh` を全件実行し、exit code と要約をターン内に表示する

## 5. 動作確認と記録

- [ ] 5.1 **本体が確認する**（W は検証できない）。変更後の develop 実行 1 回で、G の idle 通知の result 本文に「完了を待つ」系の文言が出ないことを親のトランスクリプトで確認し、証拠を PR に添える
- [x] 5.2 `/opsx:verify` と `/opsx:archive` を通し、archive された `openspec/specs/dev-workflow-subagent-waiting/spec.md` の `## Purpose` を 1 行で書く（既定の `TBD - created by archiving …` を残さない）。archive 済みの状態を PR に含める
