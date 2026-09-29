## ADDED Requirements

### Requirement: W の指示書は索引・共通・段のファイルに分かれている

`plugins/dev-workflow/skills/develop/references/roles/worker.md` は索引でなければならない（MUST）。索引は、段の表（段の名前 `spec` / `implement` / `finish`・日本語名・担う工程・読むファイル）と、旧 worker.md の節から移し先への対応表だけを持ち、手順の本文とコードブロック（```）を持ってはならない（MUST NOT）。

W の手順の本文は `skills/develop/references/roles/worker/` の次の 4 本に置かなければならない（MUST）:

- `common.md`（全段で読む）: 本体が渡すもの（`段:` の行を含む）・W がしないこと・コンテキスト上限と手渡し（「(3) をこれより細かく切らない」の箇条を除く）
- `spec.md`（仕様づくり。(1) と R1 の差し戻しの修正）: 記録先の用意（Draft PR を記録先にする場合）・仕様化判断と記録・分割判定・仕様化する場合
- `implement.md`（実装と検証。(3a) と、G の failed や CI の見張りの `fix` を受けた修正）: (3a) 実装＋verify・昇格トリップワイヤー
- `finish.md`（仕上げ。(3b)）: (3b) archive＋PR＋仕様宣言

段ごとに、`common.md` とその段のファイルの字数（改行を含む Unicode の文字数）の合計は 7,000 以下でなければならない（MUST）。`worker/` の 4 本・索引・`references/pre-classification.md` の `## ` 見出しは、このうち 1 ファイルにだけなければならない（MUST。同じ節を 2 か所に書かない）。移すときに手順の中身（規則・書式・コマンド・閾値）を変えてはならない（MUST NOT）。段をまたぐ参照はファイル名と節名で書き、中身を言い換えて再掲してはならない（MUST NOT）。

「(3) をこれより細かく切らない」の箇条（手渡しの固定分と、実装の途中で交代させたときに後任が Red のテストから再出発する理由）は、develop の `SKILL.md` の (3) に置かなければならない（MUST）。SKILL.md はこれを理由の正本として持ち、worker.md を理由の正本として指してはならない（MUST NOT）。

#### Scenario: 索引が中身を持たない

- **WHEN** `references/roles/worker.md` を読む
- **THEN** コードブロックが無く、段の表の `spec` / `implement` / `finish` の各行がそれぞれ `worker/spec.md` / `worker/implement.md` / `worker/finish.md` の 1 つだけを指し、そのファイルと `worker/common.md` が実在する

#### Scenario: どの段でも 7,000 字以下

- **WHEN** `spec` / `implement` / `finish` のそれぞれについて、`worker/common.md` とその段のファイルの文字数を合計する
- **THEN** どの合計も 7,000 以下である

#### Scenario: 同じ節が 2 か所に無い

- **WHEN** `worker/` の 4 本・索引・`references/pre-classification.md` の `## ` 見出しを集める
- **THEN** 同じ見出し行が 2 ファイル以上に無い

#### Scenario: (3) を細かく切らない理由は SKILL.md にある

- **WHEN** develop の `SKILL.md` の (3) と `worker/common.md` を読む
- **THEN** SKILL.md の (3) に手渡しの固定分と Red のテストから再出発する理由が書かれ、`worker/common.md` にその箇条が無い

### Requirement: 事前分類表は W が読まないファイルに置く

重要実装の事前分類（聖域パス・マージ権限・層間契約・課金/法務の表と、W の上限・読んで判断する役の種別・残量モードの優先の説明）は、`plugins/dev-workflow/skills/develop/references/pre-classification.md` に置かなければならない（MUST）。このファイルが事前分類の正本であり、`worker/` の 4 本と索引に表を再掲してはならない（MUST NOT）。

事前分類を参照する次の箇所は `references/pre-classification.md` を指さなければならず（MUST）、事前分類について `references/roles/worker.md` を指してはならない（MUST NOT）: develop の `SKILL.md` の (1) の spawn の行と「モデル」の役割表・`references/roles/spec-reviewer.md`・`references/decision-criteria.md` の残量モード表・pr-review-gate の `stages/triage.md`・`plugins/dev-workflow/references/model-tiers.md`・`plugins/dev-workflow/README.md`。

#### Scenario: 表が 1 か所にある

- **WHEN** `references/pre-classification.md` と `worker/` の 4 本と索引を読む
- **THEN** 事前分類表の 4 行は `pre-classification.md` にだけある

#### Scenario: 参照元が新しい置き場所を指す

- **WHEN** 上に挙げた参照元の、事前分類に触れる行を読む
- **THEN** どれも `pre-classification.md` を指し、事前分類について `roles/worker.md` を指す行が無い

### Requirement: 本体は W の起動指示と再開指示に段を書く

本体は W の起動指示・SendMessage による再開指示・手渡しの起動指示に、`段: spec` / `段: implement` / `段: finish` のいずれか 1 行を書かなければならない（MUST）。(1) の spawn と R1 の REQUEST_CHANGES を受けた再開は `spec`、(3a) の再開と G の failed や CI の見張りの `fix` を受けて直させる再開は `implement`、(3b) の再開は `finish`、手渡しは前任が担っていた段とする（MUST）。develop の `SKILL.md` はこの対応を書かなければならない（MUST）。

仕様化しないと判定した W に、本体が同じコンテキストのまま (3a) へ進むよう指示したときは、W は `worker/implement.md` を読んでから進まなければならない（MUST）。`worker/spec.md` はこれを書かなければならない（MUST）。

#### Scenario: SKILL.md が段の値を書く

- **WHEN** develop の `SKILL.md` の 1 ループを読む
- **THEN** `段: spec`・`段: implement`・`段: finish` がそれぞれ、対応する W の起動・再開の場面とともに書かれている

#### Scenario: 仕様化しない経路でそのまま進むとき

- **WHEN** `worker/spec.md` の仕様化しないと判定した場合の段落を読む
- **THEN** 本体が同じコンテキストで (3a) へ進むよう指示したら `worker/implement.md` を読んでから進むことが書かれている

### Requirement: Codex の W の phase には共通と段のファイルを正本として渡す

`plugins/dev-workflow/scripts/codex-develop.py` は、Codex の W の phase に次の正本を付けなければならない（MUST）: `spec` は `skills/develop/references/roles/worker/common.md` と `worker/spec.md`、`implement` と `finish` は `worker/common.md` とそれぞれ `worker/implement.md`・`worker/finish.md`、`explore` と `summarize` は `worker/common.md` だけ。`skills/develop/references/decision-criteria.md` を付けることは変えない（MUST）。索引 `roles/worker.md` を正本として付けてはならない（MUST NOT）。

#### Scenario: phase ごとの正本

- **WHEN** `codex-develop.py request` で `spec` / `implement` / `finish` / `explore` / `summarize` の依頼を作り、prompt の `CANONICAL SOURCE` 行を読む
- **THEN** 上の組み合わせのファイルが付き、`skills/develop/references/roles/worker.md` は付いていない

### Requirement: 既存要件が worker.md に置いた内容は移し先のファイルを指す

既存要件（この capability と他の capability のもの）が `skills/develop/references/roles/worker.md`（「W の指示書」「worker.md」と書いたものを含む）に置く・含む・書く・明記すると定めた内容、およびその節を読むと定めた WHEN は、次の対応表の移し先を指すものとして読まなければならない（MUST）。

| 旧 worker.md の節 | 移し先 |
|---|---|
| 冒頭（本体が渡すもの） | `references/roles/worker/common.md` |
| W がしないこと | `references/roles/worker/common.md` |
| 記録先の用意（Draft PR を記録先にする場合） | `references/roles/worker/spec.md` |
| 仕様化判断と記録 | `references/roles/worker/spec.md` |
| 分割判定 | `references/roles/worker/spec.md` |
| 仕様化する場合（(1) の終わり） | `references/roles/worker/spec.md` |
| (3a) 実装＋verify（全経路共通の大原則・順 3 の一覧の段落・(3a) の return を含む） | `references/roles/worker/implement.md` |
| 昇格トリップワイヤー | `references/roles/worker/implement.md` |
| (3b) archive＋PR＋仕様宣言 | `references/roles/worker/finish.md` |
| 重要実装の事前分類 | `references/pre-classification.md` |
| コンテキスト上限と手渡し（「(3) をこれより細かく切らない」を除く） | `references/roles/worker/common.md` |
| 「(3) をこれより細かく切らない」の箇条 | develop の `SKILL.md` の (3) |

既存要件のうち否定の形のもの（worker.md に特定の記述が無いこと・特定の行にしか出てはならないこと）は、索引・`worker/` の 4 本・`references/pre-classification.md` の全部に掛けなければならない（MUST）。「`worker.md`・`spec-reviewer.md`・`gate-runner.md` の 3 つ」のように役割の指示書を列挙する要件の worker.md は、`worker/` の 4 本の集まりを指し、要件が求める記述は上の対応表でその内容が移った 1 本にあればよい（MUST。4 本すべてに同じ記述を置いてはならない）。

#### Scenario: 節を読む WHEN の読み替え

- **WHEN** 既存要件の Scenario が「`references/roles/worker.md` の『コンテキスト上限と手渡し』の節を読む」と書いている
- **THEN** `worker/common.md` の同じ節を読んで判定する

#### Scenario: 否定の要件の読み替え

- **WHEN** 既存要件が「`worker.md` に W が `/wt-setup` を呼ぶ記述が無い」と定めている
- **THEN** 索引・`worker/` の 4 本・`pre-classification.md` のどれにもその記述が無いことで判定する

#### Scenario: 読み込み量の実測

- **WHEN** この変更を develop で PR にし、`scripts/subagent-context-audit.sh --by-role` で W の `docs_median` を測る
- **THEN** 実測値とファイルごとの内訳が PR 本文に記録されている
