## Why

2026-10-23 11:03、主はエピック #1038 の親のタブで「このエピックの子が求めるリスク許容は、親が全部答えて」と任せた（記録 https://github.com/oratta/claude-harness/issues/1038#issuecomment-6363422938 ）。その 2 分後に子 #1245 が PR #1265 のリスク許容を求めて止まり（停止の記録 https://github.com/oratta/claude-harness/issues/1245#issuecomment-6363448774 、11:05:03）、親は委任の発言の場所を添えて「許容する」を送ったが、子の `owner-reply-check.sh --relayed` は `REASON=not-after` で落とした。`--relayed` は「主の発言が停止の記録より後」で「そのあいだに親がその停止の記録の URL を書いて主に報告した」ことを求めるので、止まる前に述べた包括的な委任は、どの子の停止に対しても必ず落ちる。

結果として、主は任せたあとも子が止まるたびに子のタブを開いて打ち直している。任せた意思を機械的に確かめられる形で一度受け取り、その後に止まった子へ効かせる経路が要る。ただしリスク許容はゲートの通過条件なので、委任が主本人の発言であること・効く範囲（どのエピックの・どの種類の止まりか）・期間・取り消しを、エージェントの判断に頼らず確かめられる形で決める。

## What Changes

- **委任の記録と主の確認**: 主が親のタブで任せる旨を述べたら、親はそれだけを委任として扱わず、エピックの issue に決まった書式の委任の記録（1 行目 `主の委任: リスク許容`。範囲と期間は仕様で決めた定型の文）を投稿し、その URL を本文に書いて主に確認を求める。主がその直後に別の発言を挟まずに答えた発言を「委任の確認」とする。範囲は主が自由に述べた文ではなく、主が確認した定型の記録で決まる
- **`owner-reply-check.sh --delegated`** を足す: `--delegated <親のセッション ID> <uuid> <委任の記録の作成日時> <委任の記録の URL> <停止の記録の作成日時>`。その uuid の行が主の発言の 9 条件を満たすこと、委任の記録より後であること、そのあいだに親が委任の記録の URL を書いた発言があり、URL を書いた最後の親の発言とその行のあいだに別の主の発言が無いこと、その行が停止の記録より前であることを確かめる。落ちたときの理由は `not-found`・`not-owner`・`not-after`・`not-asked`・`not-direct`・`not-before`
- **親の送り方**（develop の `references/epic.md` 手順 8）: 有効な委任があり、子の止まりが PR のリスク許容で子の推奨が「許容する」のときだけ、主に上げずに `reply --as owner` で `許容する（主の委任による。停止の記録: <URL>） [主の委任: セッション <ID> / uuid <uuid> / 記録 <委任の記録の URL>]` を送り、エピックに 1 行残す。それ以外は今どおり主に上げる
- **子の受け取り方**（develop の `references/epic-child-stop.md`）: 末尾が `[主の委任: …]` の返事は `--delegated` と委任の記録の GitHub 上の確認（エピックの issue のコメントであること・投稿者・最新の `主の委任:` であること・編集されていないこと・エピックが開いていること・自分がそのエピックの子であること・自分の停止の推奨が許容であること）を通したときだけ G に渡す。通らなければ今どおり主に子のタブで打ってもらう
- **ゲートの合格条件**（pr-review-gate `stages/pass.md` 手順 5・`stages/hold.md` の手順 3-c と手順 6）: 記録の形 `主の回答: 許容 — 親経由で受領（委任）（…）` と、その真正性確認（`--delegated` の終了コード 0 と GitHub 上の確認の再実行）を足す。引き継ぎのときは委任がまだ有効かを確かめ直す
- 既存の `--relayed`（主が止まりへの報告を見て直接答えた経路）は変えない。委任より前に別の子・別の PR だけを名指しした主の発言は、どちらの経路でも今どおり落ちる
- `scripts/epic-dispatch.sh` は変えない（委任の返事も `reply --as owner` で送る）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-owner-reply-check`: `--delegated` の使い方と、その合否を固定する bats の要件を足す
- `dev-workflow-develop`: 親が委任の記録を作って主に確認を求めること、委任で返事を送る条件と書式、子が委任の返事を確かめてから G に渡すことを足す
- `dev-workflow-pr-review-gate`: 合格条件に、主の委任で親経由に受けた許容（`親経由で受領（委任）`）の記録と真正性確認を足し、引き継ぎの元として扱う条件を足す

## Impact

- `plugins/dev-workflow/scripts/owner-reply-check.sh`（`--delegated` の追加。既定・`--locate`・`--relayed` の動きは変えない）と、新しい bats `plugins/dev-workflow/tests/owner-reply-delegated-scenario.bats`
- `plugins/dev-workflow/skills/develop/references/epic.md`（手順 8 に委任の記録と委任での送り方）・`references/epic-child-stop.md`（「親から届いた返事」に委任の返事の受け取り方）
- `plugins/dev-workflow/skills/pr-review-gate/stages/pass.md`（手順 5）・`stages/hold.md`（手順 3-c の引き継ぎと手順 6 の復帰手順の表）
- 文面を固定している bats（`tests/develop-skill.bats`・`tests/pr-review-gate-skill.bats`）に、足した文の検査を足す
- `plugins/dev-workflow/changes/1293.md`（変更の記録）
- `references/parent-pass-criteria.md` は変えない（兄弟の子 #1253・#1270・#1271・#1280 が同時に触っている。委任は「親の判断で通す」ではなく「主の許容を届ける」経路なので、手順 8 の側に置く）
