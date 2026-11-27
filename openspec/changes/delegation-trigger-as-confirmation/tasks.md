# Tasks

## 1. 照合スクリプト

- [ ] 1.1 `owner-reply-check.sh` に `--delegated-trigger <セッション ID> <uuid> <委任の記録の作成日時> <きっかけの全文>` を足す（引数 4 個、`not-found` → `not-owner` → `not-before-record` → `not-same` → `not-adjacent`、きっかけの全文が空白をまとめて空なら exit 2）。冒頭の使い方・出力・終了コードの説明も直す。確かめ方: 1.3 の bats が通る。触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:1-60（冒頭の説明）、plugins/dev-workflow/scripts/owner-reply-check.sh:62-110（引数の解釈と検査）、plugins/dev-workflow/scripts/owner-reply-check.sh:383-404（`delegated()` と振り分け）
- [ ] 1.2 `--delegated` の 5 番目の引数に `-` を受け、`-` のときは `not-before` を確かめない（`-` でも日時でもなければ exit 2）。確かめ方: 1.3 の bats が通り、既存の `--delegated` の bats が変わらず通る。触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:62-110、plugins/dev-workflow/scripts/owner-reply-check.sh:383-404
- [ ] 1.3 `owner-reply-delegated-scenario.bats` に、dev-workflow-owner-reply-check の要件「owner-reply-check.sh --delegated-trigger は、きっかけの発言を委任の確認として確かめる」「きっかけの形の委任の合否を、会話ログで機械的に固定する」の Scenario と、`--delegated` の `-`・引数の不備の Scenario を足す（2026-11-09 の #2058 の並びを `-` で通し、日時で `not-before` になることを含む）。確かめ方: `bats plugins/dev-workflow/tests/owner-reply-delegated-scenario.bats plugins/dev-workflow/tests/owner-reply-check.bats plugins/dev-workflow/tests/owner-reply-relayed-scenario.bats` が通る。触る範囲: plugins/dev-workflow/tests/owner-reply-delegated-scenario.bats:1-259（ログの組み立て 1-86、シナリオ 87-150、個々の落ち方 151-259）

## 2. develop の手順書（委任の受け方・有効性・効く止まり・送り方・子の受け方）

- [ ] 2.1 `epic-delegation.md` の記録の定型に、きっかけの形の `主の委任: リスク許容`（4 行目の `期間:` の定型、5 行目の `きっかけ:` は全文で本文の終わりまで・`なし` 不可）を足し、「委任が有効か」の①を 3 つの形に直し、4 行目で形を見分けることを書く。「確認・期間・失効」にきっかけの形の確認を書く。「委任が効く止まり」のリスク許容の③から委任の確認との前後を外し、最後の「委任の確認より前の止まり」を聖域の変更・破壊的な git 操作の止まりに限る。確かめ方: 2.4 の bats が通る。触る範囲: plugins/dev-workflow/skills/develop/references/epic-delegation.md:5-34
- [ ] 2.2 `epic-stop.md` の「主の委任」を直す: 委任の受け方（リスク許容はきっかけの形で同じターンに記録・問わずに事後の報告・間に合わないか照合が通らなければ問いの形。論点なしの止まりは今どおり問いの形）、確認の場所（きっかけの形は `--delegated-trigger` を親が先に回す）、委任で送る（確認の場所を残した同じターンに、いま主の返事待ちのリスク許容の止まりの子を見て送る）、守備範囲。確かめ方: 2.4 の bats が通る。触る範囲: plugins/dev-workflow/skills/develop/references/epic-stop.md:19-29
- [ ] 2.3 `epic-child-stop.md` の「親から届いた返事」の `[主の委任: …]` の段を直す: 委任の記録の 4 行目で形を見分け、問いの形はリスク許容の止まりで停止の記録の引数 `-`・聖域の変更と破壊的な git 操作の止まりで作成日時の `--delegated`、きっかけの形は `--delegated-trigger`（リスク許容の止まりだけ）。REASON の例に `not-same` を足す。確かめ方: 2.4 の bats が通る。触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:54
- [ ] 2.4 `develop-skill.bats` の主の委任のテストを直し、足す（きっかけの形の記録の定型 1〜4 行目、きっかけの形では問わない・間に合わなければ問いの形、確認の場所を残す前の `--delegated-trigger`、確認直後に止まっている子へ送ること、③に委任の確認との前後が無いこと、子の照合の選び方と `-`）。確かめ方: `bats plugins/dev-workflow/tests/develop-skill.bats` が通る。触る範囲: plugins/dev-workflow/tests/develop-skill.bats:1222-1335（主の委任のテスト群）

## 3. pr-review-gate（聖域）

- [ ] 3.1 `authenticity-delegated.md` を直す: 入口の説明に、きっかけの形の記録でも同じ行を追記することを書き、手順 4 を記録の形で分ける（問いの形は `--delegated … -`、きっかけの形は `--delegated-trigger … <きっかけ: の値>`）。REASON の一覧と真正性確認の行（使った照合の名前）・合格させない条件・守備範囲を、dev-workflow-pr-review-gate の差分どおりにする。`--relayed` を使わない文は残す。確かめ方: 3.4 の bats が通る。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/authenticity-delegated.md:1-31
- [ ] 3.2 `carryover.md` の条件 3 の委任の形の確かめ直しを、元の委任の記録の形で照合を選ぶ文にする（`--delegated` は停止の記録の引数 `-`、きっかけの形は `--delegated-trigger`）。確かめ方: 3.4 の bats が通る。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/carryover.md:39
- [ ] 3.3 `hold-resume.md` のリスク許容待ちの行の「`owner-reply-check.sh --delegated` の終了コード 0 を確かめて渡したもの」を、記録の形に合った照合（`--delegated` か `--delegated-trigger`）の終了コード 0 にする。確かめ方: 3.4 の bats が通る。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold-resume.md:9
- [ ] 3.4 `pr-review-gate-skill.bats` の委任の形のテストを直し、足す（手順 4 の 2 つの照合の呼び出しの文字列、真正性確認の行 2 種、REASON の一覧、3-c の確かめ直しの選び方、hold-resume の行）。確かめ方: `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` が通る。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:2151-2251

## 4. 記録と全体の確認

- [ ] 4.1 変更の記録 `plugins/dev-workflow/changes/1609.md` を書く（何を変えたか・受け入れること〔主の会話の 1 回の発言で、以後と、そのとき止まっていたリスク許容が親経由で通る〕・戻し方〔差分を戻す。投稿済みのきっかけの形の記録は `主の委任: 取り消し` で止まる〕・聖域に触れること）。確かめ方: ファイルがあり、ほかの `changes/*.md` と同じ形。触る範囲: plugins/dev-workflow/changes/1609.md（新規）
- [ ] 4.2 dev-workflow の bats 一式と shellcheck を通す。確かめ方: `bats plugins/dev-workflow/tests/` と `shellcheck plugins/dev-workflow/scripts/owner-reply-check.sh` が通る。触る範囲: なし（確認だけ）

## Workflow follow-up

- archive のときに `openspec/specs/` の 3 つの capability へ差分を反映する
- PR は聖域（マージ条件のパス）に触れるので、マージは主が行う
