## 1. スクリプトのテストを先に直す（bats）

- [x] 1.1 期待が変わる既存の 4 件を直す。テスト名と期待の両方を変える。確かめ方: 2.7 のあとで全件 ok
  - 「evidence file changed by main -> exit 1」: 終了コード 0・`CARRYOVER=yes`・`EVIDENCE_MAIN_ONLY=evidence.txt`・`NG:` 行なし。PR が evidence.txt に触れていない形のまま
  - 「non-merge commit on top of prev HEAD -> exit 1」: 終了コード 0・`PR_COMMITS=1`・`NG:` 行なし
  - 「#694: outside-allowlist resolution plus a non-merge commit -> exit 1」: 終了コード 3・`CARRYOVER=if-rereviewed`
  - 「#694: outside-allowlist resolution plus evidence changed by main -> exit 1」: 終了コード 3・`RESOLVED_OUTSIDE_ALLOWLIST=` と `EVIDENCE_MAIN_ONLY=` の両方
  - 「#478: running from a subdirectory」: PR 自身の commit で evidence.txt を書き換える形に変え（前の HEAD では PR はこのファイルに触れていない）、終了コード 4・`EVIDENCE_PR_CHANGED=evidence.txt`

  触る範囲: plugins/dev-workflow/tests/risk-carryover-check.bats:100-117（2 件）、:226-248（#694 の 2 件）、:287-294（サブディレクトリ）
- [x] 1.2 PR 自身の差分の比較のケースを足す。足すケースは次の 6 つ
  - PR が evidence.txt の 1 行を変え、main が同じファイルの離れた行を変えて衝突なしで取り込む: 終了コード 0・`EVIDENCE_MAIN_ONLY=`
  - main が PR の変えた行から 2 行離れた行を変える（文脈の 3 行に入る）: 終了コード 0
  - PR 自身の commit が PR の足した行を書き換える: 終了コード 4・`CARRYOVER=if-judged`・`EVIDENCE_PR_CHANGED=evidence.txt`・`EVIDENCE_DIFF_LINES=2`（1 行削除と 1 行追加）・`NG:` 行なし
  - PR 自身の commit で変えてから同じ中身に戻す: 終了コード 0
  - 衝突解消で PR の足した行の中身が変わる: 終了コード 4
  - 4 と許可リスト外の衝突解消が重なる: 終了コード 4、両方の行が出る

  共通の準備として、PR 側で evidence.txt を複数行にして 1 行変える関数を足す。確かめ方: 2.7 で全件 ok。触る範囲: plugins/dev-workflow/tests/risk-carryover-check.bats:32-56（関数の並び）、:181-198 の後ろ（「other JSON files」テストの直後に新しいケースを並べる）
- [x] 1.3 `NG:` に残るものを足す: バイナリの根拠ファイルが前後で変わった（終了コード 1・`NG:` がそのファイルを示す）。新しい HEAD と base の merge-base が 1 つに決まらない（main と pr を互いにマージした criss-cross merge で、main が根拠ファイルを変えている。終了コード 1・`NG:` が merge-base を示す）。根拠ファイルに触れないときの出力に `PR_COMMITS=0`・`EVIDENCE_DIFF_LINES=0` があることを、今の「main merged without conflict」テストに足す。確かめ方: 2.7 で全件 ok。触る範囲: plugins/dev-workflow/tests/risk-carryover-check.bats:62-71、:119-128（「merge of a non-main branch」の近くにバイナリのケース）
- [x] 1.4 先頭コメントに #1238 と、PR 自身の差分で判定することを書く。確かめ方: 目視。触る範囲: plugins/dev-workflow/tests/risk-carryover-check.bats:1-7

## 2. スクリプトを直す

- [x] 2.1 判定 2 の merge commit でない commit を `NG:` から外し、件数を数える。merge commit の条件は残す。確かめ方: 1.1 の non-merge のケース。触る範囲: plugins/dev-workflow/scripts/risk-carryover-check.sh:66-69（変数の宣言）、:106-127（`set_list` のループ。111-113 が今の NG）
- [x] 2.2 PR 自身の差分を取り出す関数を足す。比べ方は design.md の決定 2 のとおり
  - 引数は HEAD とファイル
  - `git merge-base --all <HEAD> <base>` が 1 件でなければ失敗を返す
  - `git diff -U0 --no-color --no-ext-diff --no-textconv <mb> <HEAD> -- <f>` を awk に通し、最初の `@@` より後ろの `-`・`+`・`\` で始まる行だけを出す

  確かめ方: 1.2 のケース。触る範囲: plugins/dev-workflow/scripts/risk-carryover-check.sh:71-101（関数の並び。`allowed` の後ろ）
- [x] 2.3 判定 4 を直す: 根拠ファイルごとに次の順で判定する
  1. 前後の diff が空なら次のファイルへ進む
  2. `git diff --numstat` がバイナリを示せば `NG:`
  3. 前後の PR 自身の差分が一致すれば `EVIDENCE_MAIN_ONLY` に積む
  4. 一致しなければ `EVIDENCE_PR_CHANGED` に積み、numstat の追加と削除を合計に足す
  5. merge-base が決まらなければ `NG:`

  前後どちらにも無いときの終了コード 2 は残す。確かめ方: 1.1〜1.3。触る範囲: plugins/dev-workflow/scripts/risk-carryover-check.sh:144-157
- [x] 2.4 出力と終了コードを直す
  - 出力: `CARRYOVER=yes|if-rereviewed|if-judged|no`、`MAIN_MERGES=`、`PR_COMMITS=`、`RESOLVED_FILES=`、`RESOLVED_OUTSIDE_ALLOWLIST=`、`EVIDENCE_MAIN_ONLY=`、`EVIDENCE_PR_CHANGED=`、`EVIDENCE_DIFF_LINES=`、`NG:`
  - 優先順は 1 → 4 → 3 → 0
  - 空配列の展開は Bash 3.2 向けに `${arr[@]+"${arr[@]}"}` 形を使う

  確かめ方: 「runs under /bin/bash」テストを含め全件 ok。触る範囲: plugins/dev-workflow/scripts/risk-carryover-check.sh:159-175
- [x] 2.5 冒頭コメントを直す。対象は、判定 2・判定 4・PR 自身の差分の定義と比べ方・出力・終了コード 4 の意味（スクリプトは引き継げるかを決めない）。確かめ方: 目視でスクリプトの動きと一致すること。触る範囲: plugins/dev-workflow/scripts/risk-carryover-check.sh:1-29
- [x] 2.6 `bash -n` と `shellcheck`（あれば）を通す。確かめ方: どちらも終了コード 0。触る範囲: plugins/dev-workflow/scripts/risk-carryover-check.sh 全体（確認のみ）
- [x] 2.7 `bats plugins/dev-workflow/tests/risk-carryover-check.bats` を手元で回す（触ったファイルに対応する bats だけ。全体は CI に任せる）。確かめ方: 全件 ok。触る範囲: なし（実行のみ）

## 3. 3-c の文面と書式を直す（hold.md は 3-c だけ）

- [x] 3.1 3-c の冒頭の目的の文を直す。直す先は「main の取り込みや PR 自身の修正で HEAD が動いても、リスク宣言の中身（リスク内容・発生条件・影響範囲と戻し方）が前と同じなら、一度許容したリスクを主に聞き直さない。判定の基準はファイルが変わったかではなくリスクの中身が同じか」の趣旨。確かめ方: 3.6 の bats。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:19
- [x] 3.2 スクリプトの呼び方のブロックの説明を直す
  - 出力: `CARRYOVER=if-judged`・`PR_COMMITS=`・`EVIDENCE_MAIN_ONLY=`・`EVIDENCE_PR_CHANGED=`・`EVIDENCE_DIFF_LINES=` を足す
  - 終了コード: `4 = 根拠ファイルの PR 自身の差分が前後で違う（いまは主に聞く）` を足す
  - 判定の要約: 「根拠ファイルが前後の HEAD で同一」を「根拠ファイルの PR 自身の差分が前後で同じ」に直す

  確かめ方: 3.6 の bats。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:25-31（bash ブロック）、:35（条件 1 の括弧の説明）
- [x] 3.3 条件 1 の後ろか、引き継げないときの段落に、終了コード 4 の扱いを書く。中身は「終了コード 4 は条件 1 を満たさない。引き継がず手順 6 で主に聞き、`EVIDENCE_PR_CHANGED=` の行を引き継げなかった理由として質問に添える」。確かめ方: 3.6 の bats。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:35、:53
- [x] 3.4 追記 4 行のうち `引き継ぎの根拠:` の行に、PR 自身の commit `<PR_COMMITS の値>` 件の欄を足す。「根拠ファイルの diff は空」は「根拠ファイル <diff は空 または main からの変更だけ: EVIDENCE_MAIN_ONLY のファイル>」に直す。行頭と 4 行の構造、終了コード `<0 または 3>` の書き方は変えない。確かめ方: 3.6 の bats と、既存の「4 appended lines」テストが通る。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:44-49
- [x] 3.5 次の 2 つを `git diff` で確かめる。3-c 以外の節（手順 6・復帰の表）を変えていないこと。`pass.md` の合格条件の表と `gate-runner.md` が 3-c を参照するだけで、条件や書式を写していないこと（写していなければ変えない）。確かめ方: `git diff --stat` に hold.md 以外の skills の文面が出ない。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:65、plugins/dev-workflow/skills/develop/references/roles/gate-runner.md（読むだけ）
- [x] 3.6 文面検査の bats を足す・直す
  - 3-c の冒頭に「リスクの中身」と「PR 自身の修正」がある
  - 呼び方のブロックに `if-judged`・`EVIDENCE_PR_CHANGED=`・`EVIDENCE_MAIN_ONLY=`・`PR_COMMITS=`・`4 = ` がある
  - 手順 6 へ進む文に `EVIDENCE_PR_CHANGED=` がある
  - 引き継ぎの根拠の行に `PR 自身の commit` と `EVIDENCE_MAIN_ONLY` がある

  既存の #694 の検査語（`終了コード <0 または 3>` など）は残す。`bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` を手元で回す。確かめ方: 全件 ok。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:1153-1236（carryover のテストの並び。末尾に足す）

## 4. 変更の記録と公開版の検査

- [x] 4.1 `plugins/dev-workflow/changes/1238.md` を書く（版は上げない）。中身は次の 4 つ
  - 何を直したか: 判定 2・判定 4・終了コード 4・3-c
  - BREAKING: 終了コード 1 だったものが 0・3・4 になる
  - 本文の前提との食い違い（判定 2）
  - 後続の change `risk-carryover-decider-judge` が終了コード 4 を判定役に渡すこと

  確かめ方: ファイルがあり、既存の changes の書き方（見出し 1 行と箇条書き）に揃っている。触る範囲: plugins/dev-workflow/changes/1238.md（新規）
- [x] 4.2 公開版に書いてはいけない語を検査する。対象は触ったファイル（オーナーの固有名・アカウント名・PC の絶対パス）。`bash plugins/dev-workflow/scripts/forbidden-words-check.sh` を手元で回すか、CI に任せる。部品を足していないので `docs/public-private-split.md` は変えない。確かめ方: 検査が通る。触る範囲: 触ったファイル全体（確認のみ）
- [x] 4.3 `openspec validate risk-carryover-pr-own-diff --type change --strict` を通す。確かめ方: `is valid`。触る範囲: openspec/changes/risk-carryover-pr-own-diff/（確認のみ）

## Workflow follow-up

- (3b) で archive・Draft PR（本文に `Refs #1238`。Closes を書かない）・仕様宣言
- 後続の change `risk-carryover-decider-judge` を別 PR で回す（終了コード 4 を `dev-workflow:decider`・`model: opus` に比べさせる経路、判定役に渡す行数の上限（案 100 行）、develop の本体が判定役を起こす経路）
