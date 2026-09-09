> **実装後の訂正（2026-09-09、PR #256 のゲート指摘を受けて）**
>
> この change の記述のうち、次の各点は実装後に事実と食い違うことが判明したため、正本（`plugins/dev-workflow/references/subagent-waiting.md`）と main specs 側で訂正済み。この archive は承認時点の記録としてそのまま残す。1〜3 はゲート 1 周目の指摘、4〜5 はその訂正自体に 2 周目で見つかった穴。
>
> 1. **companion 経路をこの change は「exit code でタイムアウトと完了を区別する」としているが、区別できない。** `codex-companion.mjs` の `handleStatus` は結果を出力して return するだけで `process.exitCode` を設定しないため、タイムアウトでも完了でも 0 を返す（実測）。訂正後は `--json` を付けて出力の `waitTimedOut` を見る
> 2. **完了マーカーを固定文字列 `__CODEX_DONE__` にすると、レビュー対象の文書がその文字列を含むだけでポーリングが誤成立する。** 実際に PR #256 自身のレビューで発生した。訂正後は実行ごとに一意な nonce を埋め、行頭アンカー付きの完全な形で照合する
> 3. **雛形の `$out` が定義されていなかった。** 起動と待ちは別々の Bash 呼び出しでシェル変数が引き継がれないため、訂正後は出力ファイルの作成を雛形に含め、待ち側にはパスを literal で書く
> 4. **その nonce を `date +%s` で作ると、並行して走るサブエージェント（G / W / R1）が同じ秒に衝突する。** 一方の完了マーカーが他方の未完了ジョブを完了扱いにする（落ちずに間違う）。加えて nonce を未エスケープのまま拡張正規表現に埋めていたため、メタ文字を含む nonce は別の文字列に誤マッチする（`a.b` が `axb` に一致）。訂正後は nonce を `uuidgen`（無い環境ではプロセス ID と `$RANDOM`）から作り、文字集合を英数字のみに制限したうえで、照合を行末までアンカーする（`^__CODEX_DONE_<nonce>__ rc=[0-9]+$`）
> 5. **起動の雛形がレビュー指示をダブルクォートに素で埋め込んでいた。** 指示文に `"` や `` ` `` や `$(...)` が入ると引数が壊れるか、意図しないコマンドが実行される。訂正後はレビュー指示をクォート付きヒアドキュメントでファイルに保存し、`codex exec … - < <プロンプトファイル>` で標準入力から渡す（`codex exec` が `-` で標準入力を読むことは `--help` と実測で確認済み）
>
> あわせて、この change が置いた「正本 1 本・各指示書は禁止 1 行」の設計に対し `gate-runner.md` と `pr-review-gate/SKILL.md` が手順を再掲していた点も訂正し、再掲の禁止を退行検出で機械的に守る形にした。

## MODIFIED Requirements

### Requirement: 役割の指示書は references/roles/ に分かれている
`skills/develop/references/roles/` に `worker.md`（W）・`spec-reviewer.md`（R1）・`gate-runner.md`（G）が存在しなければならない（MUST）。`worker.md` は仕様化判断の記録書式（1 行目 `^仕様化判断: (する|しない)$`）・仕様レビュー結果の記録書式・「重要実装の事前分類」表（聖域パス・マージ権限・層間契約・課金/法務）を含み（MUST）、この表がモデル事前分類の正本である（SHALL）。事前分類表の「1 周目」列は**実行役（W）の上限を `opus` とし、`fable` 行を持ってはならない**（MUST NOT。4 分類のいずれに当たっても W は `opus` 止まりで、聖域パスの `opus` は据え置き）。表には、読んで判断する役（R1・G が要求するレビュアー）が `fable` 相当の分類に当たるときは `subagent_type: dev-workflow:decider` で spawn し、`general-purpose` に `model: fable` を付けないことを明記しなければならない（MUST）。「層間契約だから判断が要る」ぶんは仕様化判断・R1 レビュー・本体の判断で吸収し、W は確定した内容を落とす作業だけを担うことを書く（SHALL）。`worker.md` の return には「指示のどこまでやって、どこで何が起きたか」を含める義務を書かなければならない（MUST。決める役の入力契約になるため）。

`spec-reviewer.md` は 5 観点（受け入れ条件の一意性・既存 spec との整合・固有値の直書き・前提の明記・相互整合）と 2 周キャップを含む（MUST）。`gate-runner.md` は pr-review-gate スキルを読んで手順 1〜5 を実行する指示と、G が孫を持てないための別コンテキストレビューの扱いを含む（MUST）: Codex は Bash から `codex exec -c approval_policy=never -c model_reasoning_effort=medium` または `codex-companion.mjs` を直接呼ぶ（slash command `/codex:adversarial-review` と `codex:codex-rescue` サブエージェントは G からは使えない）。Codex が使えない／light 判定のときは G が `needs-reviewer` を return し、本体が別のレビュアー（既定 `opus`。マージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。聖域パスだけでは上げない）を spawn してその要約を G に SendMessage で渡す。このため G も名前付きで spawn する（MUST）。`needs-reviewer` の return には light/full の判定と根拠・対象 PR 番号と HEAD SHA・レビュアーの推奨モデル（または `dev-workflow:decider` 指定）と根拠・受け入れ条件の所在を含め（MUST）、レビュー要約を受け取った G が「レビュー実行者:」の PR コメントを投稿して手順 3 以降を続ける（SHALL）。G の failed の return には pr-review-gate 手順 2-2 の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）を含めなければならない（MUST。本体が決める役 / 実行役のどちらを上げるかを決めるため）。

`worker.md`・`spec-reviewer.md`・`gate-runner.md` の 3 つはいずれも、長時間処理の完了通知を待つためにターンを終えてはならない旨を明記しなければならない（MUST）。待ち方の詳細の正本は `plugins/dev-workflow/references/subagent-waiting.md` とし、各指示書はそこを参照する（SHALL）。`spec-reviewer.md` の 1 行は、decider 経路で spawn される R1 が `Bash` を持たず待ちループ自体を実行できないため、「長い処理の完了を待つ目的でターンを終えない（decider 経路の R1 は待ちを伴う作業を持たない）」の形で書く（SHALL。読んだ R1 が実行できない手順を探しに行かないようにするため）。

`gate-runner.md` の Codex 起動手順は 2 経路をそれぞれ直さなければならない（MUST）。(a) `codex exec` 直叩き経路は、`run_in_background` での起動は残したまま、完了マーカー（`__CODEX_DONE__ rc=$?`）を起動コマンドに書き足し、そのマーカーを終了条件とする同一ターン内の前景ポーリングで待つ形にする。「出力ファイルを読め」だけで待ち方を書かない記述を残してはならない（MUST NOT）。(b) `codex-companion.mjs` 経路は `status <job-id> --wait --timeout-ms` を 540000 に直し、1 回で終わらなければ同じ呼び出しを繰り返す旨を書く。どちらの経路も総待ちの上限（前景ループ 3 回 = 27 分）に達したら待ちをやめ、`needs-reviewer`（根拠に「Codex タイムアウト（27 分）」）を return する（MUST）。前景の待ち値は Bash ツールの `timeout` パラメータにミリ秒で指定し、Bash ツールの前景上限（600000 ms）未満でなければならない（MUST）。シェルの `timeout(1)` コマンドを使ってはならない（MUST NOT）。

#### Scenario: worker.md に記録書式と事前分類表がある
- **WHEN** `references/roles/worker.md` を読む
- **THEN** `^仕様化判断: (する|しない)$` の書式、`gh` で記録先にコメントする手順、4 分類の事前分類表（「1 周目」列がすべて `opus` で `fable` 行が無い）、レビュアーの fable は `dev-workflow:decider` 経由であること、return に「指示のどこまでやって、どこで何が起きたか」を書く義務が書かれている

#### Scenario: spec-reviewer.md に 5 観点と 2 周キャップがある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** 5 観点がすべて列挙され、2 周で確定し 3 周目の例外を設けないことが書かれている

#### Scenario: gate-runner.md は pr-review-gate を手順書として参照する
- **WHEN** `references/roles/gate-runner.md` を読む
- **THEN** pr-review-gate スキルを読んで手順 1〜5 を実行すること、Codex は `codex exec` / `codex-companion.mjs` を Bash で呼ぶこと、Codex が使えないときは `needs-reviewer`（判定・HEAD SHA・推奨モデル・受け入れ条件の所在を含む）を return して本体にレビュアーの spawn を委ねること、failed の return に原因分類を含めることが書かれている、Codex の完了確認を (a) `codex exec` 直叩きと (b) companion の 2 経路それぞれについて同一ターン内の前景ポーリングで行うこと、待ち値が 600000 ms 未満であること、総待ちの上限に達したら `needs-reviewer` を return することが書かれている

#### Scenario: 3 つの指示書に待ちでターンを終えない禁止がある
- **WHEN** `references/roles/` 配下の `worker.md` / `spec-reviewer.md` / `gate-runner.md` をそれぞれ読む
- **THEN** どのファイルにも「完了通知を待つためにターンを終えない」旨の記述があり、待ち方の正本として `references/subagent-waiting.md` が参照されている

#### Scenario: spec-reviewer.md の 1 行は decider 経路を踏まえている
- **WHEN** `references/roles/spec-reviewer.md` の待ちに関する 1 行を読む
- **THEN** 禁止が書かれたうえで、decider 経路の R1 は待ちを伴う作業を持たない旨が添えられており、実行できない待ちループの手順を探しに行かずに済む
