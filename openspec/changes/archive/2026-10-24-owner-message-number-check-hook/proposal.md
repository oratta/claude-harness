# Proposal

## Why

正本 `output-styles/readable.md` の節 3 は、主（判断を下す人間のオーナー）に判断・確認・操作を求める発言で「issue・PR の番号で物を指さず中身で書き、番号は末尾の URL にだけ置く」と決めている（#1176 で入れ、#1209 で今の文言に直した）。それでも、1 行目が「PR #1712 のリスクを許容しますか？」でリポ名もリンクも無い報告が送られた（2026-10-22）。文章の決まりだけでは守られず、今ある #1184 の hook（`unclear-reply-rephrase.sh`）は主が「わからん」と返したあとにしか働かないので、1 往復の無駄が残る。ターンを終える時点で発言を機械で見て、番号が残っているかリンクが無ければ書き直させる。

## What Changes

- dev-workflow に Stop hook のスクリプト `scripts/owner-message-number-check.sh` を足し、`hooks/hooks.json` に `Stop` のエントリとして登録する（dev-workflow が `Stop` を持つのは初めて）
- hook は、メインセッションのターンの終わりに直前の発言の本文を読み、主に判断・確認・操作を求める発言（1 行目が質問で終わる、または区切りより上の最後の行が答え方）だけを対象にする。`主がすること: なし` で始まる報告は対象にしない
- 対象の発言で、区切り（`---` の行）より上の本文に `#数字` があるか、本文に `#数字` を書いたのに issue・PR のフル URL が 1 本も無いとき、`{"decision":"block","reason":…}` で差し戻す。理由には、どの行のどの番号か（またはリンクが無いこと）を示し、書き直し方は正本の節 3 を指す（正本の文言は写さない）
- 差し戻しは 1 ターンに 1 回まで（Claude Code が渡す `stop_hook_active` が真なら通す）
- 環境変数 `DEV_WORKFLOW_OWNER_NUMBER_CHECK=off` で全解除できる
- bats を足し、`claude -p --plugin-dir` で実機の差し戻しを 1 回確かめる
- 正本 `output-styles/readable.md` と `rules/communication-style.md` は変えない

## Capabilities

### New Capabilities

- `dev-workflow-owner-message-number-check`: メインセッションの Stop で、主に判断・確認・操作を求める発言に issue・PR の番号が区切りより上に残っているか、番号を書いたのにリンクが無いときに、1 ターンに 1 回だけ差し戻す規則

### Modified Capabilities

（なし。`dev-workflow-unclear-reply-rephrase` の要件は変えない。正本の文言を持つ capability `owner-question-style` も変えない）

## Impact

- 追加: `plugins/dev-workflow/scripts/owner-message-number-check.sh`、`plugins/dev-workflow/tests/owner-message-number-check.bats`、`plugins/dev-workflow/changes/1215.md`
- 変更: `plugins/dev-workflow/hooks/hooks.json`（`Stop` のキーを足す。既存のエントリは変えない）
- 変更（既存テスト）: `plugins/dev-workflow/tests/subagent-stop-guard.bats` の hooks.json のイベント名の集合を完全一致で固定するテストに `Stop` を足す（足さないと必ず落ちる）。`plugins/dev-workflow/tests/hook-python-invocation.bats` と `tests/hook-python-isolation.bats` の、Python 本体を `-c` で渡す hook の手書きの一覧に新しいスクリプトを足す
- 常時注入の予算（`tests/injection-budget.txt`）は動かない（rules・output-styles・description を変えない）
- 公開版と個人版の仕分け（`docs/public-private-split.md`）は行 `plugins/dev-workflow/` の公開版に入り、行を足さない
- dev-workflow を入れた環境の全メインセッション（`claude -p` で起動した子のセッションを含む）のターンの終わりに走る
