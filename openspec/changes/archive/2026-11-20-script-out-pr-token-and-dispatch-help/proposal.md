## Why

develop の手順書には、決まった入力から決まった出力が出る処理が文章と埋め込みの bash で書かれており、Claude Code は scripts を読まずに実行するので、スクリプトに出せばその分の文章がコンテキストに入らなくなる（#1686、エピック #1682 の子）。2026-11-18 の調査で見つかった 5 候補のうち、今回は次の 2 つだけを出す。

- PR トークンの計測: `codex-records.sh` と `pr-token-budget.sh` の連結と `--codex-home` の組み立てを本体が手で行っている
- `epic-dispatch.sh` の出力語の意味: `epic-loop.md` が文章で説明し、スクリプトの使い方はサブコマンド名と引数だけを出す

残り 3 候補（実行モードの判定、片付け・待ちの前の確認、マージ待ちの決める役への入力の列挙）は編集対象が増えレビューが広がるので、PR 本文に挙げて #1686 で続ける。

## What Changes

- 薄いラッパー `scripts/pr-token-measure.sh` を足す。記録先番号と repo を受け、`codex-records.sh` と `pr-token-budget.sh` を同じ順でつなぎ、`pr-token-budget.sh` の stdout と exit code（0 / 2）をそのまま返す。`codex-records.sh` が失敗したら `pr-token-budget.sh` を呼ばず exit 1
- `skills/develop/references/pr-token-budget.md` の計測手順を、この 1 コマンドの呼び方に置き換える
- `epic-dispatch.sh --help`（`-h`）を足し、サブコマンドごとの出力語・終了コード・`child-log` の列・同時上限の既定値・起動コマンドの組み立てを stdout に出す。exit 0。既存の使い方（stderr・exit 1）は変えない
- `skills/develop/references/epic-loop.md` から出力語の説明を消し、「止まって主に報告する／進む」の分類表と `--help` への参照だけにする
- `epic-dispatch.sh` 3 行目のコメントが指す `epic.md「回し方」`（分割で無くなった節）を `epic-loop.md` に直す
- 手順書の字数を前後で記録し、予算ファイル（`tests/develop-orchestrator-reference-budget.txt`・`tests/develop-epic-scene-budget.txt`）を実測に合わせて下げる

## Capabilities

### Modified Capabilities
- `dev-workflow-pr-token-budget`: 計測が 1 コマンドで呼べる
- `dev-workflow-develop`: `epic-dispatch.sh` が `--help` で出力語の意味を出す

## Impact

`plugins/dev-workflow/scripts/`（新規 1、`epic-dispatch.sh`）、`plugins/dev-workflow/tests/`（新規 bats 1、`epic-dispatch.bats`、`develop-skill.bats` の該当断言）、`skills/develop/references/`（`pr-token-budget.md`、`epic-loop.md`）、`tests/` の予算ファイル、`tests/develop_startup_contract.py`。既存スクリプトの出力語・終了コードと hook 本体は変えない。
