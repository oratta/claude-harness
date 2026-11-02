## Context

自動マージの処理（`.github/workflows/auto-merge.yml`。原本は `plugins/dev-workflow/templates/auto-merge/`）は、5 条件（`agent-review:passed`・合格の HEAD 束縛・CI green・聖域パス非接触・`AUTOMERGE_PAUSED` 未設定）を満たし、見送りラベル（`BLOCKING_LABELS` の `human-merge`・`needs-human-merge`・`human-only`・`needs-approval`）が 1 つも無い PR だけを、検証した HEAD の SHA にピンしてマージする。聖域パスに触れた PR には処理自身が `human-merge` を付けて以後見送る。

主の決定（#1030「決定（主、2026-10-15）」）は、見送りラベル付きの PR を 3 つに分けた。ラベルなしは今どおり、見送りラベル付きは親が合理性と危険の低さを見てマージしてよい、マージ条件そのもの（`.github/workflows/`・`plugins/dev-workflow/skills/pr-review-gate/`・`plugins/dev-workflow/templates/auto-merge/`）に触れる PR は必ず主がマージする。

制約:
- `docs/auto-merge.md` は「マージの実行権は常に自動マージの処理の側。LLM が `gh pr merge` や merge API を直接叩くのは禁止」とする。`rules/git-commit-policy.md` は直接マージに主の明示承認を求める。原本の `.claude/settings.json` は `Bash(gh pr merge:*)` を deny する
- ワークフローは `pull_request_target` で main 側の定義だけが動き、PR head を checkout しない（`scripts/test-auto-merge-workflow.sh` が静的に固定）
- 原本と展開先は `SACRED` の行（とそのコメント）だけが違う。テストは両方に同じ検査を当てる
- 親の手順と判断の基準は #1054 が作る（この change の範囲外）。#1034（PR #1050）の `parent-pass-criteria.md` は止まった子の判断の基準で、マージの可否は扱わない

## Goals / Non-Goals

**Goals:**
- 親の判断を、自動マージの処理が決定論的な条件で受け取れるようにする
- マージ条件そのものに触れる PR は、親の判断があっても処理の側のパス判定でマージしない
- 既存の条件（CI green・SHA ピン・緊急停止・合格の HEAD 束縛・マージ直前の取り直し）を、親の判断で外れる経路にも同じに効かせる

**Non-Goals:**
- 親がいつ・何を見て判断するか（#1054）
- `human-merge` 以外の見送りラベルを親の判断で外すこと
- 印を付けられる者を技術的に絞ること（主の資格情報で動くセッションはどれも付けられる。`agent-review:passed` と同じ信頼の置き方として主が受け入れた）
- 原本を使う他のリポへの展開し直し

## Decisions

### 1. 親が直接マージせず、親の判断を自動マージの処理が受け取る

代わりの案は、親が REST の merge API を SHA ピンで直接叩く経路だった。採らない理由:
- CI green・SHA ピン・rename 元まで見る聖域判定・マージ直前の取り直しを、親の手順で作り直すことになり、処理と手順の 2 か所で条件がずれていく
- 緊急停止（`AUTOMERGE_PAUSED`）は処理の run の冒頭で効くもので、親の直接マージには効かない。主がスマホから止める手段が抜ける
- マージ条件そのもののパスを守るのが LLM の判断だけになる
- `docs/auto-merge.md` の原則・`rules/git-commit-policy.md`（聖域）・原本の deny の 3 つを書き換えることになる

受け取る形なら、親は印を残すだけで、マージするかは main 側で動く処理が決める。

### 2. 印はラベルと HEAD に結びついたコメントの 2 つにする

- ラベル `parent-merge-approved`: ラベル即応（`pull_request_target: labeled`）の引き金にする。ジョブの `if:` に、このラベル名でも走る条件を足す（`if:` は節約であって防御線ではない、という既存の扱いは変えない）
- コメント: 1 行目がちょうど `親のマージ判断: 可`、本文のどこかの行がちょうど `親が見た HEAD: <40 桁 SHA>`。今の HEAD と一致しない印は数えない（親が見たあとに push されたコミットを親の判断で入れない）。ラベルは PR 番号にしか結びつかないので、HEAD への結びつきはコメントが持つ
- キーを `対象 HEAD:` にしないのは、既存の合格の HEAD 束縛（コメント本文に `対象 HEAD: <SHA>` を含むかを `grep -F` で見る）を親のコメントが満たしてしまうため。`親が見た HEAD:` は `対象 HEAD:` を部分文字列として含まない
- 投稿者は `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のものだけ数える（develop の「親エピックからの注意書き」と同じ線）
- コメントは `gh api --paginate --slurp` で JSON のまま取り、`jq 'add // []'` で 1 つの配列にしてから絞る（`HEAD_SHA` は 40 桁の 16 進であることを先に確かめ、`--arg` で渡す）。本文は `gsub("\r";"")` で `\r` を取り除いてから行に割る（Web UI から投稿したコメントは改行が `\r\n` になり、完全一致が外れるため）。判定はマーカー `# >>> parent-merge-judgment` 〜 `# <<< parent-merge-judgment` で囲んだ 1 か所に置き、bats でスタブの `gh` を当てて挙動を試せるようにする。取得に失敗したら印が無いものとして扱う（fail-closed）

### 3. 外す条件は 4 つすべて

`PARENT_OK=true` になるのは次をすべて満たすときだけ:
1. 印（ラベルとコメント）がある
2. `human-merge` が付いていて、ほかの見送りラベルが 1 つも無い（印が先に付いた PR は、初回の run で聖域判定が `human-merge` を付けて見送り、次の run でこの条件を満たす）
3. `DIFF_FILES`（filename と previous_filename）が `SACRED` に 1 つ以上一致する（`human-merge` が聖域接触で付いたものであることを、処理がパスで確かめ直す。手で付けた留保は外さない）
4. `DIFF_FILES` が `MERGE_CONDITION` に 1 つも一致しない

処理の流れは、見送りラベルの判定より前に変更ファイルの一覧と `PARENT_OK` を求め、見送りラベルの判定では `PARENT_OK` のときだけ `human-merge` を飛ばし、聖域判定では `PARENT_OK` のときだけ `human-merge` を付けて見送る代わりに進む。`PARENT_OK` で進んだことはログに 1 行出す。`DRY_RUN` でも同じ判定をしてログに出す。

### 4. `MERGE_CONDITION` は `SACRED` の部分集合として別に持つ

- 展開先（claude-harness）: `^\.github/workflows/|^plugins/dev-workflow/skills/pr-review-gate/|^plugins/dev-workflow/templates/auto-merge/`
- 原本: `^\.github/workflows/`（リポ固有のマージ条件があればマーカー `# >>> merge-condition-paths` の間に足す）。既定のままでも動くので、README では必ず差し替える 3 点に入れず、任意の差し替えとして書く
- テストで、`MERGE_CONDITION` に一致する代表パスがすべて `SACRED` にも一致すること、`rules/`・`CLAUDE.md`・`plugins/*/hooks/`・`tests/injection-budget.txt`（claude-harness のみ）が `MERGE_CONDITION` に一致しないことを固定する
- `tests/injection-budget.txt` は主の決定表どおりマージ条件に入れない（主が 2026-10-15 に確認）

### 5. マージ直前の取り直しにも同じ判定を当てる

`pre-merge-recheck` ではラベルを取り直して見送りラベルを見直している。ここでも `parent-merge-judgment` の判定をやり直し、`PARENT_OK` でなければ `human-merge` を見送りに数える（判定後に印のラベルが外された・見送りラベルが足されたときに止まる）。

## Risks / Trade-offs

- [子のセッションが自分で印を付ける] → 技術的には止められない（主の資格情報で動くため）。手順書の規則（#1054）で親だけが付けると定め、マージ条件のパスは処理が止める。主はこの信頼の置き方を受け入れた
- [印のコメントを偽の投稿者が書く] → `author_association` で OWNER・MEMBER・COLLABORATOR に絞る
- [親の判断のあとに push された未確認のコミットが入る] → `親が見た HEAD:` の一致と SHA ピンで止まる
- [処理の変更自体が判定を緩める] → この PR はマージ条件そのものに触れるので `human-merge` が付き、親の判断でも外れず、主がマージする。テストで外す条件 4 つのそれぞれを欠いた fixture がマージに進まないことを固定する
- [聖域に触れる PR に人が手で付けた `human-merge` が親の判断で外れる] → 処理が付けたものと区別できない。`docs/auto-merge.md` に「親の判断からも外したいときは `human-only` か `needs-approval` を付ける」と書く
- [原本を使う他のリポでは印が効かない] → 印を付けても見送られたままで、マージされない側に倒れる。#1054 の親の手順が対象リポの `auto-merge.yml` に `parent-merge-approved` の語があるかで経路の有無を見分ける

## Migration Plan

1. この PR を主がマージする（`.github/workflows/` に触れるので自動では入らない）
2. マージ後、次の `pull_request_target` の run から新しい判定が効く。ラベルは親が初めて付けたときに作られる（処理側でも `gh label create` で作っておく）
3. 戻すときは revert PR（`revert-pr.yml`）でこの PR を戻す。戻したあとは印が無視され、`human-merge` 付きの PR は今までどおり見送られる

## Open Questions

なし（親の手順と基準は #1054 で決める）
