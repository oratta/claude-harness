# Design

## Context

`skills/develop/references/decision-criteria.md`（19,689 字）は、W の仕様化判断（Step B・Step C）、本体の軽い通し方と CI 修正からの戻し方、残量モードと共有枠モード、コンテキスト上限（本体の測り方と手渡しの許可、W と G の宣言の書式）を 1 ファイルに持つ。`worker/common.md` と `roles/gate-runner.md` が「return を書く前にこの節を読め」と指すので、W と G は全文を読む。切り出し前の場面ごとの字数（wc -m）は、W の段 spec 31,860・implement 29,974・finish 37,310、G の起動で共通に読む分 33,571（記録: issue #1683 の仕様化判断のコメント）。

制約:

- 動きは変えない（エピック #1682 の方針）。照合スクリプトとゲートが読む 1 行目（`工程完了:` / `工程中断:`・`仕様化判断:`・`仕様レビュー:`・`直し方の判定:`・`主に聞かずに回した周:`）、守備範囲の段落、`subagent-waiting.md` の雛形のコードは変えない
- `skills/pr-review-gate/` 配下と `roles/gate-runner.md` の本文は #1687 だけが触る。この change では参照先のパスの付け替えだけ
- エピックの「主が決めたこと」により、手順書の文言の検査は「develop 配下の手順書のどこかにあること」に弱めてよく、場所の守りは場面ごとの字数の予算で代える

## Goals / Non-Goals

**Goals**

- W（どの段でも）と G が `decision-criteria.md` を読む指示が無くなる
- W と G が読む宣言の書式が、分ける前と一字一句同じ
- 残量モードと共有枠モードの優先順位の表が 1 ファイルだけにある
- W が段ごとに読むファイルの合計に予算がある

**Non-Goals**

- G の段のファイル（`skills/pr-review-gate/stages/`）を割ること・`gate-runner.md` の本文を縮めること（#1687）
- SKILL.md から場面限定の節を外すこと（#1685）。SKILL.md は参照先のパスだけ直す
- 減った量を合否に使うこと

## Decisions

### 1. 本体向けのコンテキスト上限の規則は `decision-criteria.md` に残し、W と G の宣言だけを新しい `return-declaration.md` に出す

`decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の節は、本体が読む部分（2 経路・閾値の環境変数の表・再開前チェックの測り方・上限超のときの扱い・手渡しの許可・どちらの書式にも一致しない return の扱い・idle と return の違い・前任が動作中に交代させる場合・停止確認を待つ間・終端・途中計測の仕組み・fail-open）を残す。W と G が return を書くときに要る部分（宣言義務の 2 つの書式とバックグラウンドコマンドの但し書き、通知を受けたら、強制停止に当たったら（W と G ができないことと return に書くこと）、途中停止したときの 1 行目、G が強制停止に当たったとき）を `skills/develop/references/return-declaration.md` に移す。一字一句変えないのは、宣言義務の箇条（`工程完了:` / `工程中断:` の 2 つの書式の行と、バックグラウンドコマンドが終わっていなければ `工程完了:` にしないという但し書きの段落）に限る（受け入れ条件「宣言の書式が分ける前と一字一句同じ」が指すのはここ）。閾値の数値と環境変数名は `decision-criteria.md` の表にだけ置き、`return-declaration.md` は「通知」「強制停止」の語で書く（値は SubagentStart の hook が注入する）。

そのため、宣言義務の箇条以外の移す文（通知を受けたら・強制停止に当たったら・途中停止したときの 1 行目・G が強制停止に当たったとき）には、規則の中身を変えない次の 3 種類の置き換えだけを行う。

| 置き換え | 前（今の `decision-criteria.md` の例） | 後 |
|---|---|---|
| ①環境変数名 | 「（上の表の `DEV_WORKFLOW_CONTEXT_CAP` 超）」「（`DEV_WORKFLOW_CONTEXT_HARD_CAP` 超）」 | 「（通知。閾値は `decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の表）」の形 |
| ②同じファイルの中を指す参照 | 「上の『手渡しの許可』の条件①」 | 「`decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の『手渡しの許可』の条件①」 |
| ③規則に混ざった経緯 | 「#269 で『`git` の一部だけ通す』方式が 2 周連続で実機迂回されたため…」 | 削り、「受理する経路を残さない」の規則だけを残す |

確かめ方は 3 つ。(a) 宣言義務の箇条は、分ける前の行を `grep -F` で `return-declaration.md` に探し、全行が見つかる。(b) `return-declaration.md` に `DEV_WORKFLOW_` と、移す前のファイルの中を指す「上の表」「上の「手渡しの許可」」の句が無いことを bats で確かめる（`develop-roles.bats` に足す）。(c) ①〜③で置き換えた箇所は、置き換える前と後の文を対にした表を PR 本文に載せ、PR レビューで規則の中身が変わっていないかを見る（言い換えの正しさは機械では見られない）。

- 他の案: 本体向けの部分も新しいファイル（例 `context-cap.md`）に出し、`decision-criteria.md` を Step B・Step C だけにする。採らない理由: 「手渡しの許可」「コンテキスト上限（サブエージェントの手渡し）」を名指しする参照が SKILL.md・`handover.md`・`gate-runner.md`・openspec の要件 10 件以上にあり、本体向けの部分の置き場所を変えると全部を付け替えることになる。本体が読む規則の置き場所は今のままでよく、W と G が読む部分だけを外せば目的に足りる
- 見出し: `decision-criteria.md` の節の見出し「コンテキスト上限（サブエージェントの手渡し）」は変えない（既存の参照がそのまま生きる）。節の冒頭に「W と G が return に書く宣言の書式は `return-declaration.md`」の 1 行を置く

### 2. Step B と Step C は新しい `spec-decision.md` に出す

W の段 spec は Step B・Step C の判定基準を使う。`decision-criteria.md` に残すと W がまた本体向けの規則ごと読むので、Step B（「仕様化する」「仕様化しない」「仕様化するが軽く通す（仕様の文言合わせ）」「判定したら必ず記録する」「どの判定でも変えないもの」「判定に迷ったら」）・Step C・「判定に使わない材料」を `skills/develop/references/spec-decision.md` に移す。小節の見出しは変えない（`Step B「仕様化するが軽く通す（仕様の文言合わせ）」` などの参照は、ファイル名だけ替えれば生きる）。`worker/spec.md` はこのファイルを読むよう指し、Step B・Step C と同じ内容の要約（判定の箇条書き・文言合わせの対象と当てる条件・分割判定の箇条書き）を参照 1 行に置き換える。spec.md に残すのは W の手順（記録のコマンド・`openspec new change` の進め方・複数 change に割れたときのモード別の動き）だけ。

- 他の案: Step B・Step C を `worker/spec.md` に統合して正本にする。採らない理由: 本体（軽い通し方の判定の前提、interactive で主に聞くとき）と R1（`spec-reviewer.md` の判断記録の契約）と pr-review-gate の `declarations.md` も Step B を指しており、W の指示書を他の役の正本にすると読み手が混ざる

### 3. 軽い通し方と CI 修正からの戻し方は `light-path.md` に出し、`handover.md` との重複は `handover.md` に寄せる

Step B の「仕様化しないが軽く通す（軽い通し方）」の小節（当てる条件・本体の手順・途中で外れたとき・G の failed からの戻し方・CI 見張りの fix からの戻し方・守備範囲）を `skills/develop/references/light-path.md` に移す。小節の太字の見出し（`**CI 見張りの fix からの戻し方**` など）は変えない。CI 見張りの fix からの戻し方のうち、「通常判断で W を把握しない本体」の段落と「起動／再開前に最新の可を不可として投稿し…」の段落は `handover.md`「CI 見張りの修正担当の引き継ぎ」の「W を把握しない本体の読取りと停止先」「起動／再開前の無効化と再許可」と同じ規則なので、`light-path.md` には分岐と `handover.md` の節名への参照だけを残す。`handover.md` 側の文は変えない（そちらが既に手順を細かく持つ）。`handover.md` の「decision-criteria.md の新規 spec 起動へ」の参照は `light-path.md` に付け替える。

- 他の案: `handover.md` 側を削って `light-path.md` に寄せる。採らない理由: `handover.md` の手順は CI 見張りの共有手順（`ci-watch.md`）からも参照され、通常経路（軽い通し方でない）の引き継ぎも扱う。軽い通し方のファイルに通常経路の手順を置くと、通常経路の本体が軽い通し方のファイルを読むことになる

### 4. 残量モードと共有枠モードの優先順位を 1 つの表にして `decision-criteria.md` に置く

今の `decision-criteria.md` は Fable 残量モードの表と共有枠モードの表を別々に持ち、「食い違うときは共有枠モードの下限が勝つ」を文で書いている。一方、`spec-reviewer.md`・`gate-runner.md`・`worker/common.md`・`pre-classification.md` は「①共有枠モード ②事前分類 ③Fable 残量モード」の優先順位を文で言い換えている。`decision-criteria.md` に優先順位の表（行: 共有枠モード → 事前分類 → Fable 残量モードの順。列: 値・効果）を 1 つ置き、2 つの表と「共有枠モードの下限が勝つ」の文をこの表に畳む。値ごとの効果の文（`abundant` が既定を上げない等）は表のセルに残す（`session-tripwires.sh` が注入する効果の文と一致している必要がある要件があるため、文を変えない）。`pre-classification.md`・`spec-reviewer.md`・`worker/common.md`・`plugins/dev-workflow/references/model-tiers.md` は優先順位を言い換えず、「残量モードと共有枠モードの適用は `request` が行う。優先順位の表は `decision-criteria.md`」の 1 行にする。`gate-runner.md` の同じ言い換えは本文なので残す（#1687 で直す。この change では参照先のパスだけ）。

- 置き場所の他の案: 新しいファイル（例 `budget-modes.md`）に出す。採らない理由: 読み手は本体（SKILL.md「モデル」）と `codex-develop.py request` の説明で、どちらも本体側。`decision-criteria.md` は分けたあと本体だけが読むファイルになるので、そこに置けば読む場面を増やさずに済み、既存の要件（`model-tier-resolution`「残量モードを格に適用する」など）の参照も生きる

### 5. 手渡し規則の逐語検査は正本を 2 か所に広げる

`tests/lib/handoff-verbatim.py` の正本を、(a) `decision-criteria.md` の「コンテキスト上限（サブエージェントの手渡し）」節と、(b) `return-declaration.md` の全文の 2 つにする。どちらの正本の一文（40 字以上）も、自分以外の追跡ファイル（もう片方の正本を含む）に逐語であれば落ちる。文が 20 件未満で緑にしない下限は 2 つの合計で数える（分けたあと (a) だけでは 20 件を割りうるため）。どちらかが読めなければ失敗（exit 2）。

### 6. 文言の検査は develop 配下の手順書のどこかにあることを確かめる形に直す

文を別ファイルへ移した箇所の検査だけを直す（移していない文の検査は変えない）。`develop-roles.bats` の `gate_all` / `worker_all` の前例にならい、検査の対象を「develop 配下の手順書を cat でつないだもの」（`skills/develop/SKILL.md`・`skills/develop/references/` 配下の `*.md`・`plugins/dev-workflow/references/*.md`・`templates/escalation-tripwires.md`）にする共通の関数を `tests/lib/` に置き、各 bats から読む。「この文が無いこと」を確かめる否定の検査は、対象を広げると意味が変わるので、移した先のファイルを足すだけにする。

### 7. W が段ごとに読むファイルの合計に予算を置く

`tests/develop-worker-stage-budget.txt`（新規。1 行 1 段: `<段> <バイト数>`）と `tests/develop-worker-stage-budget.bats`（新規）。段ごとに読むファイルは bats に固定で書く:

| 段 | 読むファイル（`plugins/dev-workflow/` から） |
|---|---|
| spec | `agents/worker.md`・`skills/develop/references/roles/worker/common.md`・`worker/spec.md`・`skills/develop/references/spec-decision.md`・`skills/develop/references/return-declaration.md` |
| implement | `agents/worker.md`・`common.md`・`worker/implement.md`・`return-declaration.md` |
| finish | `agents/worker.md`・`common.md`・`worker/finish.md`・`skills/pr-review-gate/declarations.md`・`return-declaration.md` |

単位は既存の `tests/develop-startup-budget.bats` と同じくバイト数（`wc -c`。`wc -m` はロケールで値が変わり、CI と手元でずれる）。判定も同じく上下両方向（実測が予算を超えたら落ちる。予算が実測の 1.1 倍を超えても落ちる）。固定の一覧が手順書とずれないよう、`common.md` が `return-declaration.md` を、`worker/spec.md` が `spec-decision.md` を、`worker/finish.md` が `declarations.md` を名指ししていることと、W の段のファイルと `common.md` が `decision-criteria.md` を読むよう指していないことも同じ bats で確かめる。PR 本文とエピックへの記録は `wc -m`（字数）で書く（受け入れ条件の言葉に合わせる。予算の判定とは単位が違うことを PR 本文に書く）。G の段ごとの予算は #1687 の範囲なので置かない。

### 8. 1 change・1 PR にまとめる

Step C の「独立した設計判断が 1 つ以内」には厳密には当たらない（決定 1〜7 は切り出しの配置・優先順位の表の集約・文言の検査の対象・予算の方式に分かれる）が、1 change・1 PR のまま進める（本体の判断。記録先 #1683 に記録済み）。根拠は 3 つ。この issue はエピック #1682 の主が切った子 1 件で、受け入れ条件が「切り出し前後の字数を PR 本文に記録する」など 1 本の PR を前提にしている。後続の子（#1685 の SKILL.md の縮小、#1687 の `gate-runner.md` と pr-review-gate 配下）がこの子のマージを前提にしており、さらに割ると後続の待ちが増える。決定 1〜7 はどれも同じ `decision-criteria.md` を割る作業で、分けると同じファイルの同じ節を順に書き換えることになる。

- 他の案: change を分け（例: 宣言の切り出し／Step B・Step C の切り出し／軽い通し方の切り出し／優先順位の表／予算）、同じ `decision-criteria.md` を順に割る。採らない理由: どの change も同じファイルの隣り合う節を消すので、後の change は前の change のマージを待ってから書き直すことになり、文言の検査の共通の関数（決定 6）も最初の change に入れないと後の change が使えない。受け入れ条件の前後の字数も change ごとに測り直すことになり、エピックへの記録が 1 回で済まない

## Risks / Trade-offs

- **予算は同じ字数での入れ替えを止めない**: 本体向けの規則が同じ字数ぶん W のファイルに入れ替わっても落ちない。エピックの「主が決めたこと」で受け入れた残り。逐語検査と仕様レビューが一部を拾う
- **文言の検査を弱めると、文が develop 配下の別の場面のファイルへ移っても落ちない**: 場所の守りは W の段の予算で代える。本体の場面（SKILL.md）の予算は既存の `develop-startup-budget.bats` が持つ。G の場面の予算は #1687 で足す
- **`gate-runner.md` の本文に残る優先順位の言い換え**: #1687 で直すまで、優先順位の文が `decision-criteria.md` の表と `gate-runner.md` の 2 か所にある。表が変わったときに `gate-runner.md` が取り残されうる。#1687 の範囲として issue に書かれている
- **Codex の phase に付ける正本が変わる**: `decision-criteria.md` の代わりに `return-declaration.md`（spec はさらに `spec-decision.md`）を付ける。decider の phase も同じく `return-declaration.md` にする（decider は Step B を使わず、残量モードの適用は `request` が済ませているため）。Codex 側に `decision-criteria.md` の本体向けの規則が渡らなくなるが、Codex の phase は本体の役をしないので使わない

## Migration Plan

文書の付け替えだけで、状態や設定の移行は無い。キャッシュ済みの古いプラグインを読んだ W や G は旧 `decision-criteria.md` の節を探すが、新しい `decision-criteria.md` にも同じ見出しの節が残り、宣言の書式への 1 行の参照があるので、`return-declaration.md` に辿り着ける。
