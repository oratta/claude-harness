# Proposal

## Why

1 本目の change `epic-wait-detect-stop-from-log`（PR #1466）で、親の `wait` は子の会話ログから止まりに気づけるようになった。残っている子の `mark stopped` / `mark resumed` と、止まるたびの `子の停止: 主の返事待ち` の記録は、気づかせるためだけの手順になっている。手順を読まない子や読んでも当てはめない子がいるので（oratta/mac-mini-migration#33）、2026-10-26 の主の決定（#1382）どおり、この義務をなくす。

記録だけは PR のリスク許容で残す。`stages/pass.md` の「親経由で受領」「親経由で受領（委任）」の真正性確認が、記録の URL と投稿時刻を使うため。

## What Changes

この change は #1382 の 2 本目で最後の change。受け入れ条件の 2 件目と 3 件目を満たす。

- `references/epic-child-stop.md` を書き換え、`mark stopped` / `mark resumed` の手順と出力の扱いをなくす。親からの返事を受けるときの `mark resumed` もなくす
- `子の停止: 主の返事待ち` の記録を残す場面を、PR のリスク許容の返事を待つときだけにする。記録の 7 項目の形は変えない
- これまで記録の `止まった理由:` で分岐していた定型の止まり（マージ待ち・PR トークン上限・CI の見張り）は、子が最後の発言の末尾に `止まった理由:` の行を書き、親は `child-log --last` の全文からその行を読む形にする
- `止まった理由:` の行がある止まりは、判断のモデルも親も問いでないとして落とさない（`stop-judge.sh` が形の崩れとして扱う）
- `epic-dispatch.sh mark` の 4 種の受け付けは変えない。`stopped` / `resumed` は手順書から呼ばれなくなるが、更新前の版で動く子のために残す

範囲外:

- `stages/pass.md` の親経由の受領と `owner-reply-check.sh --relayed` / `--delegated` の変更
- `wait` の検知の条件、`--resolve` の出力の形の変更
- follow-up の #1541〜#1545 の中身。ただし `epic.md` 手順 8 の `dismiss` の条件には `止まった理由:` の行が無いことだけを足す。#1541 が求める `.questions`・`unreadable` の条件は足さない

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 子の止まりの手順、親からの返事の受け方、記録を残す場面、手順 8 の定型の止まりの読み方、マージ待ち・PR トークン上限・CI の上限の入力、`問いではない` の条件、`mark` の位置づけを変える
- `dev-workflow-ci-watch`: エピックの子が CI の見張りとマージ待ちで止まるときの渡し方を変える
- `dev-workflow-pr-token-budget`: 別セッション方式の子が見込みを書く場所を変える

## Impact

- `plugins/dev-workflow/skills/develop/references/`: `epic-child-stop.md`（書き換え）、`epic.md`（手順 2・5・7・8、マージ待ち・PR トークン上限の子）、`parent-pass-criteria.md`、`parent-merge-criteria.md`
- `plugins/dev-workflow/skills/develop/SKILL.md`、`plugins/dev-workflow/references/ci-watch.md`
- `plugins/dev-workflow/scripts/`: `stop-judge.sh`（`問いではない` の拒否）、`epic-dispatch.sh`（ヘッダーのコメント）
- `plugins/dev-workflow/tests/`: 手順書の文言の検査の更新と、`stop-judge` の検査の追加
