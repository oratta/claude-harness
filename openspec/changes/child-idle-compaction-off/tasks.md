# Tasks

## 1. 子の起動コマンドでアイドル時のコンパクトを切る

- [x] 1.1 `agent_setup` が組み立てる起動コマンドを `<cmd> --settings '{"idleCompaction":false}' --model '<model>'` にし、`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` の前置きと `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` の読み取り・検査を消す。冒頭のコメントの `launch` の説明も新しい形に直す。確認: `bats plugins/dev-workflow/tests/epic-dispatch.bats -f 'launch'` が通る（1.2 の期待値で）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:46-55（冒頭のコメントの launch）、plugins/dev-workflow/scripts/epic-dispatch.sh:429-449（agent_setup・agent_cmd_for）
- [x] 1.2 起動コマンドの期待値を新しい形に直し、`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` の上書き・空・数字以外の 3 件のテストを「設定しても起動コマンドが変わらず `launched 11` で exit 0」の 1 件に置き換える。`--command` に `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` が無いことも確かめる。`reply` の起動し直しのテスト（端末が無い子・`EPIC_DISPATCH_CLAUDE_CMD` などに従う起動し直し・誤った値で orca を呼ばない）も新しい形と変数の扱いに合わせる。確認: `bats plugins/dev-workflow/tests/epic-dispatch.bats` が通る。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:607-661（launch の呼び出し順・シェルの端末の使い回し）、plugins/dev-workflow/tests/epic-dispatch.bats:706-766（EPIC_DISPATCH_MODEL / CLAUDE_CMD / IDLE_COMPACT のテスト）、plugins/dev-workflow/tests/epic-dispatch.bats:768-781（terminal create の失敗。778 行目の `grep -qF 'cld --model'` は新しい形で隣り合わないので `cld --settings` に置き換える）、plugins/dev-workflow/tests/epic-dispatch.bats:3987-4007（reply の起動し直し）、plugins/dev-workflow/tests/epic-dispatch.bats:4171-4180（reply の誤った値）

## 2. wait --resolve の起動し直しの判定を子の表に合わせる

- [x] 2.1 `decide_relaunch` を「トランスクリプトがちょうど 1 本・最後の assistant の時刻が読める・そこから `EPIC_DISPATCH_RELAUNCH_IDLE_SEC` 秒以上なら 1」にし、`compact_boundary` と `subagent-context.sh` の会話量を見ないようにする。`wait` の引数の検査から `EPIC_DISPATCH_RELAUNCH_MIN_TOKENS` を消す。冒頭のコメントの `wait --resolve` の説明も直す。確認: 2.2 のテストが通る。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:179-184（冒頭のコメントの wait --resolve）、plugins/dev-workflow/scripts/epic-dispatch.sh:1024-1063（decide_relaunch）、plugins/dev-workflow/scripts/epic-dispatch.sh:1233-1237（wait の --resolve の検査）
- [x] 2.2 `wait --resolve relaunch` のテストを delta spec の Scenario に合わせる: 60 分以上・150,000 以上で `relaunched`（据え置き）、60 分以上・150,000 未満で `relaunched`、60 分以上・コンパクトありで `relaunched`、60 分未満で `sent`、トランスクリプト 0 本・2 本で `sent`、`EPIC_DISPATCH_RELAUNCH_IDLE_SEC` の誤りで exit 1、`EPIC_DISPATCH_RELAUNCH_MIN_TOKENS=150k` を付けても exit 1 にならず `relaunched`。確認: `bats plugins/dev-workflow/tests/epic-dispatch.bats -f 'wait --resolve relaunch'` が通る。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:4730-4825（トランスクリプトの用意と wait --resolve relaunch の 5 件）

## 3. 規則のファイルと epic.md を直す

- [x] 3.1 `reply-after-idle.md` を書き直す: 冒頭の説明（子はアイドル時のコンパクトを切ること）、「閾値」の表を「子: `--settings '{"idleCompaction":false}'` を `launch` が付ける（そのプロセスだけ・通常の自動コンパクトは止めない・v2.1.290 以降）／親: 120,000 を主の起動コマンドが入れる」に、`settings.json` に置かないこと、「そのまま送るか、起動し直すか」の表を子の 3 行（端末が無い／60 分未満／60 分以上）にして根拠（コンパクトされた子は `SKILL.md` の中身を持たない・費用の差 約 $0.5・3.2%・#1039 を #1323 で覆した）を書く。判定に使う事実を子と親に分け、`wait --resolve` の段落から `EPIC_DISPATCH_RELAUNCH_MIN_TOKENS` を消す。「親への適用」に親の表（今の 60 分未満／コンパクトあり／150,000 以上か未満の 4 行）と子と分ける理由（親の監視の `wait` が途切れる）を置き、復元の表はそのまま残す。「根拠と、この数字の限り」と「再集計」は親の値の根拠として残す（子の閾値の比較の行は親の分だけに絞る）。#1324 の範囲（キャッシュ維持の声かけ・親の `wait` の短い待ち直し）は書かない。確認: 3.3 のテストが通る。触る範囲: plugins/dev-workflow/skills/develop/references/reply-after-idle.md:1-70
- [x] 3.2 `references/epic.md` の子の起動コマンドを書いた 3 か所を直す: `nested` の説明の起動コマンドの形、起動コマンドの説明（閾値の前置きと `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` の文を `--settings '{"idleCompaction":false}'` の文に）、「`epic-dispatch.sh` が足すのは `--model` だけ」を `--settings` と `--model` に。返事の前に `reply-after-idle.md` で決める文の「親の閾値の付け方もそこにある」は残す。確認: `grep -c 'CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS\|EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS' plugins/dev-workflow/skills/develop/references/epic.md` が 0、3.3 のテストが通る。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:29（nested を受けたセッション）、plugins/dev-workflow/skills/develop/references/epic.md:107（子セッションの起動コマンド）、plugins/dev-workflow/skills/develop/references/epic.md:111（足すのは --model だけ）、plugins/dev-workflow/skills/develop/references/epic.md:113（返事の前の規則）
- [x] 3.3 規則のファイルと epic.md の文面のテストを delta spec の Scenario に合わせる: 子の切り方と `settings.json` に置かないこと、子の 3 行と根拠、親の値・親の表・分ける理由・復元・hook と 39k・#1264・再集計、`epic.md` に `--settings '{"idleCompaction":false}'` があり 2 つの変数名が無いこと。`develop-skill.bats` の `EPIC_DISPATCH_RELAUNCH_MIN_TOKENS` を求める行を消す（`EPIC_DISPATCH_RELAUNCH_IDLE_SEC` は残す）。確認: `bats plugins/dev-workflow/tests/epic-dispatch.bats plugins/dev-workflow/tests/develop-skill.bats` が通る。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3889-3940（reply-after-idle の 4 件と skill の Orca 経路の 1 件）、plugins/dev-workflow/tests/develop-skill.bats:1127-1131

## 4. 変更の記録と全体の確認

- [x] 4.1 変更の記録を書く（何を変えたか・#1039 を覆した理由・設定キーの確かめ方と issue のコメントの URL・2 つの環境変数を消したこと・`SKILL.md` ではなく `references/epic.md` を直した理由・要る Claude Code の版・マージ後の実機での確かめ方）。版は上げない。確認: ファイルがあり、`plugin.json` の `version` が変わっていない。触る範囲: plugins/dev-workflow/changes/1323.md（新規）
- [x] 4.2 全体の確認: `grep -rn 'CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS\|EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS\|EPIC_DISPATCH_RELAUNCH_MIN_TOKENS' plugins/ --exclude-dir=changes` の残りが、`reply-after-idle.md` の親の閾値の説明と、変数を読まないことを確かめるテストだけであること。`bats plugins/dev-workflow/tests/` と `bats tests/` が通ること（`tests/injection-budget.bats` を含む）。`openspec validate child-idle-compaction-off --type change --strict` が通ること。触る範囲: なし（確認だけ）

## Workflow follow-up

- R1 の仕様レビューの APPROVE を記録先で確かめてから 1 に入る
- (3b) で change を archive し、Draft PR を作って pr-review-gate を通す
