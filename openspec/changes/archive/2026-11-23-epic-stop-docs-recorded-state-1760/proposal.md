## Why

#1744 で親の `wait --watch-stopped` が子の状態の記録（`turn_input` / `turn_state`）だけで止まりを決めるようになった。しかし親が読む手順書 `epic-stop.md` 手順 8 と `reply-after-idle.md` の子の表は、その形（主が子のタブで始めたターンには何もしない・状態の記録が無いターンは止まりにしない）を書いておらず、手順 8 は返事の送り方でも `reply` の自動判定（#1742）と重複する手分類を残している。親が手順書を読んで、見張りが返さなくなった止まりを自分で探しに行くおそれがある。

## What Changes

- `epic-stop.md` 手順 8: `stopped` は状態の記録だけで決まること、主が子のタブで始めたターンは返事・端末を閉じる・起動し直すのどれもしないこと、状態の記録が無いターンを止まりとして扱わず `--resolve` の判断にも回さないことを書く。`reply --as owner` の送り方から、親が表で分類して `--relaunch` を足す指示を外し、自動判定に任せると書く（手順 8 の主の答えの段落と、委任で送る段落の 2 か所）
- `reply-after-idle.md` の子の表: 表の対象が上の形で決まった止まりの子だけであること、表は上から順に読み最初に当たった行で決めることを書く
- 要件「Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる」を、手順書に合わせて直す（上の 2 点と Scenario 1 つの追加）
- 振る舞い（スクリプト）は変えない。版は上げない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 要件「Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる」

## Impact

- `plugins/dev-workflow/skills/develop/references/epic-stop.md`、`plugins/dev-workflow/skills/develop/references/reply-after-idle.md`
- `openspec/specs/dev-workflow-develop/spec.md`（archive 時）
- 手順書の語句を検査する `plugins/dev-workflow/tests/develop-skill.bats` の期待値（`reply-after-idle` の表の行を検査するもの）
- 変更の記録 `plugins/dev-workflow/changes/1760.md`
