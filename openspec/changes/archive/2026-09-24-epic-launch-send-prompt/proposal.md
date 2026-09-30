## Why

`epic-dispatch.sh launch` は `orca worktree create ... --agent claude --prompt "<指示>" --json` の終了コードだけで `launched` を出している。2026-09-24 に flatmate エピック #755 の子 3 件と harness エピック #420 の子 3 件（#458・#430・#441）を起動したところ、6 件とも Claude Code は立ち上がったが入力欄が空のまま止まり、最初の指示 `/develop #<子>` が実行されなかった（issue #458）。親は `launched` を受け取って `wait` に入るので、子が何もしないまま最長 6 時間（`EPIC_DISPATCH_TIMEOUT` の既定）待ち続け、オーナーが気づくまで分からなかった。同じ子に親が `orca terminal send --text <指示> --enter --wait-submit 15 --json` で送り直すと、6 件とも `stages: [input_accepted, turn_started]` を返して動き出した。

## What Changes

- `launch` は `orca worktree create` に `--prompt` を渡さない。create の JSON 出力から子の Claude Code が動いている端末のハンドル（`result.agentTerminalHandle`、無ければ `result.startupTerminal.handle`）を取り出し、`orca terminal wait --terminal <handle> --for tui-idle` で起動の完了を待ってから、`orca terminal send --terminal <handle> --text <指示> --enter --wait-submit <秒> --json` で最初の指示を送る
- `launched <N>` の意味を「ワークツリーを作れた」から「最初の指示が子の入力欄に送られ、ターンの開始（`turn_started`）まで確かめられた」に変える。create の失敗、ハンドルが取れない、起動完了待ちの失敗、送信の失敗、送信結果に `turn_started` が無いのどれかなら `failed <N>`
- `failed <N>` のとき、指示を手で送り直すためのコマンド（ハンドルと指示文を埋めた `orca terminal send ...`）を stderr に出す。ワークツリーは残るので再実行では `skipped <N>` になり、指示は送られない（送り直しは人か親がそのコマンドで行う）
- 送信の観測時間と起動完了待ちの上限を環境変数（`EPIC_DISPATCH_SUBMIT_WAIT`・`EPIC_DISPATCH_READY_TIMEOUT_MS`）で変えられるようにする
- `plugins/dev-workflow/skills/develop/SKILL.md` の Orca 経路の説明の `launched` / `failed` の意味を、上の変更に合わせて最小限直す
- `plugins/dev-workflow/tests/epic-dispatch.bats` の `orca` スタブに `terminal wait` と `terminal send` を足し、成功・失敗のシナリオを確かめる

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の `launch` の呼び出し順（`--prompt` を外し、`terminal wait` と `terminal send` を足す）と、`launched` / `failed` の判定条件を変える

## Impact

- 変更: `plugins/dev-workflow/scripts/epic-dispatch.sh`（`cmd_launch` のみ。`route` と `wait` は変えない）、`plugins/dev-workflow/tests/epic-dispatch.bats`、`plugins/dev-workflow/skills/develop/SKILL.md`（Orca 経路の `launch` の出力の説明）
- 変更記録: `plugins/dev-workflow/changes/458.md`（版は上げない）
- `orca` が無い環境・Orca 管理外のワークツリーでは振る舞いが変わらない（`route` がサブエージェント方式を返す）
- `launch` は子 1 件あたり、起動完了待ちと送信の観測のぶん（既定で最長およそ 90 秒）長くかかる
- やらないこと: エピック並列起動の深さ制限（#460）、`skipped` の子に指示だけ送り直すサブコマンドの追加、子の PR の自動マージ
