## Context

#1310 で、`worker.md` の「旧節の移し先」の表を畳めない理由が、dev-workflow-develop の要件が索引に対応表を持つことを MUST にしていることだと分かった。さらに他の要件が「worker.md」と書いた箇所（dev-workflow-develop 自身の約 60 行を含む）が、この対応表の読み替えを前提にしている。

## Decisions

### 読み替えの要件は残さず削除し、名指しを直接書き直す

読み替えの要件を残すと、spec 側に対応表が残り続け、`worker.md` の表を消す理由が立たない。そこで対応表の要件は REMOVED にし、読み替えを前提にしていた名指しは、移し先のファイル名で書き直す（MODIFIED）。要件の削除と名指しの書き直しは同時でなければ、中間の状態で名指しが読めなくなるため、1 つの change にまとめる。

### 名指しごとの移し先は、旧対応表のとおりにする

旧対応表（dev-workflow-develop の削除する要件）の移し先を変えずに使う。複数の節を挙げていた名指し（「役割の指示書は references/roles/ に分かれている」の記録書式と事前分類表）は、中身ごとに `worker/spec.md`・`worker/common.md`・`pre-classification.md` に分けて書く。役割の指示書を列挙する要件（「worker.md・spec-reviewer.md・gate-runner.md の 3 つ」）は、旧表の注記どおり、要件が求める記述が実際にある 1 本（待ちの規約は `worker/implement.md`）を指す。

### 否定の形の要件は、掛かる範囲を要件ごとに直接書く

旧対応表の要件は、否定の形の要件（特定の記述が無いこと）を索引・`worker/` の 4 本・`pre-classification.md` の全部に掛けると定めていた。要件を削除するので、否定の形の要件（`/opsx:` の出現・`/wt-setup` の記述・閾値の再掲・事前分類を指す参照）は、その要件自身が `worker/` の 4 本（事前分類は索引と `worker/` の指示書）と書く。

### (3) をこれより細かく切らない箇条の Scenario

旧 Scenario「タスク単位のさらなる分割は禁止されている」は worker.md のコンテキスト上限の節を読むと書いていたが、その箇条は旧表のとおり SKILL.md の (3) に移っている。読む先を `skills/develop/SKILL.md` の (3) に直す（意味は変えない）。

### 変えない名指し

- `agents/worker.md`（エージェント定義）を指す名指しは別のファイルなので変えない
- 索引 `references/roles/worker.md` そのものを指す名指し（索引の要件・回帰テストの守備範囲・Codex の phase の正本・事前分類を索引に指さないという否定）は変えない
- 「分割前の worker.md 全体の字数」の履歴の記述は変えない

### loops-longrun-retirement の `roles/worker.md` の PR 本文の型

この要件は、旧 reference パスの grep が 0 件であることの説明で、PR 本文の型を指す箇所を挙げている。今の `worker/finish.md` の (3b) の手順 3 が、PR を用意するときに従う型として `plugins/dev-workflow/references/pr-body-format.md` を指している（`worker/spec.md` の Draft PR の本文の節は型を指さない）。旧 worker.md のこの内容は (3b) にあったので、移し先は `roles/worker/finish.md` と決めた。

## Risks / Trade-offs

- 書き直す要件が約 26 件と多い。機械的な書き換えだが、移し先の取り違えが起きうるので、レビューでは「旧対応表の移し先と一致しているか」と「移し先のファイルに、その要件が求める記述が実際にあるか」を見る

### Scenario の題名は変えない

openspec は MODIFIED の要件の Scenario を題名で突き合わせ、題名が変わると「元の Scenario を落とした」として検証が通らない。そのため「worker.md が …」の形の Scenario の題名 9 件は題名をそのまま残し、本文（WHEN・THEN）だけを移し先のファイル名に直す。題名に残る「worker.md」は読み替えの前提ではなく、W の指示書を指す呼び名である。題名まで直すなら要件ごと REMOVED して新しい題名で ADDED する手があるが、履歴が切れるので採らない。
