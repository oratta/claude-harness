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
> 7. **6 で足した「雛形を抽出して実際に実行する」検査を `sh` と `bash` だけで走らせていたのは、実行環境の取り違えだった。** サブエージェントが雛形を走らせる Claude Code の Bash ツールのシェルは `zsh` である（`ps -p $$ -o comm=` が `/bin/zsh`。この機の `/bin/sh` は bash 3.2.57 の sh モードで別物）。16 文字に整えた `$RANDOM` 版を 10 個連結して 1 プロセスで走らせると、`sh` と `bash` は 10 個とも別の値を返す（サブシェルごとに再シードするため）のに対し、`zsh` は 10 個とも同じ値を返す。そのため「重複検査は乱数版を落とせない」という 6 の直後に書いた実測所見は、対象シェルに `zsh` を含めていなかったことによる誤りだった。訂正後は実行時の重複検査の対象に `zsh` を加え（無い環境ではそのシェルだけ飛ばす）、正本にも「同じ雛形がシェルによって通ったり壊れたりすること自体が、乱数を一意性の根拠にしない理由である」と書き足した
>
> あわせて、この change が置いた「正本 1 本・各指示書は禁止 1 行」の設計に対し `gate-runner.md` と `pr-review-gate/SKILL.md` が手順を再掲していた点も訂正し、再掲の禁止を退行検出で機械的に守る形にした。

## Why

2026-09-08 に PR のゲート実行者（G）が 5 回止まり、合計約 4 時間の停止をオーナーの一言で毎回起こす必要があった（flatmate #579 / #580 / #581、claude-harness #252）。原因はハングではなく手順書で、G が Codex レビューやフルテストを `run_in_background` で起動したあと「完了通知を待つ」という素のテキストでターンを終えていた。名前付き background サブエージェントは idle になると自分の背景タスクの完了では再起動されないため、完了通知はキューに積まれるだけで新しいターンを起こさない。dev-workflow の手順書にはターンを終えずに 10 分より長く待つ方法がどこにも書かれていない。

## What Changes

- サブエージェント（W / R1 / G）に対して「完了を待つためにターンを終えない」禁止を明文化し、代わりの待ち方（前景 Bash の有限 `until` ループを、同一ターン内で必要な回数だけ呼び直す）を規定する
- 待ちの終了条件（完了シグナル）を起動経路ごとに定める。`codex exec` 直叩きは起動コマンドに完了マーカーを書き足し、companion 経由は `status --wait` の exit code を使う
- 総待ちの上限（前景ループ 3 回 = 27 分）と超過時の分岐を定める。これが pr-review-gate のフォールバック条件にある「タイムアウト」の定義になる
- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` の Codex レビュー起動手順を 2 経路それぞれ書き換える
- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` の Codex 呼び出し規約を読み手（メインセッション / サブエージェント）で書き分け、`--timeout-ms 900000` を 540000 に直し、「最長 15 分待てる」のような前景上限を超える待ちを示唆する散文を消す
- `roles/worker.md` と `roles/spec-reviewer.md` にも同じ禁止を 1 行入れる
- 上記の退行を機械検出する bats スイートを `plugins/dev-workflow/tests/` に追加する

## Capabilities

### New Capabilities
- `dev-workflow-subagent-waiting`: サブエージェントが長時間処理の完了を待つ方法の契約（ターンを終えない・完了シグナルの定義・前景ポーリング・前景上限 600000 ms・総待ちの上限と分岐）と、その正本の置き場

### Modified Capabilities
- `dev-workflow-develop`: 役割の指示書（`references/roles/`）が持つべき内容に「待ち方の禁止 1 行」が加わり、G の Codex 起動手順が 2 経路とも前景ポーリングに変わる
- `dev-workflow-pr-review-gate`: Codex 呼び出し規約が読み手別に分かれ、`--timeout-ms` の指定値の上限とフォールバック条件「タイムアウト」の定義が入る
- `dev-workflow-shared-references`: `plugins/dev-workflow/references/` に置く契約が 4 本から 5 本になり（`subagent-waiting.md` を追加）、dev-workflow 内の複数スキルが読む契約もここに置く旨が加わる

## Impact

- `plugins/dev-workflow/references/subagent-waiting.md`（新規・正本）
- `plugins/dev-workflow/README.md`（`references/` の表に 1 行追加。`dev-workflow-shared-references` の MUST）
- `plugins/dev-workflow/skills/develop/references/roles/{gate-runner,worker,spec-reviewer}.md`
- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`
- `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json`（バージョン bump と同期。S131 が merge-base からの bump を、S130 が marketplace エントリとの一致を要求する）
- `plugins/dev-workflow/tests/subagent-waiting.bats`（新規）
- 振る舞いへの影響は「エージェントの行動規約」。実行時のコード変更は無い
