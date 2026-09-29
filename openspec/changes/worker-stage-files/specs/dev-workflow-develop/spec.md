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

この要件の回帰テスト（`plugins/dev-workflow/tests/develop-worker-stages.bats`）の守備範囲は次のとおりとする。入力は索引 `references/roles/worker.md`・`worker/` の 4 本・`references/pre-classification.md` のファイルの中身で、拾うのは、索引の中のコードブロック・段の表が指すファイルの不在・段ごとの字数の合計が 7,000 を超えること・同じ `## ` 見出し行が 2 ファイル以上にあること、である。次はテストを通ってしまい、この要件の回帰テストでは止めない: 見出しを変えて同じ節を別のファイルに書いたもの、見出し以外の本文で規則を言い換えて再掲したもの、移すときに規則・書式・コマンド・閾値の文言を変えたもの、W が段のファイル以外（`decision-criteria.md` の節など）を読む分。これらは PR レビューで見る。この穴をテストで塞ぎ切ることは完了条件にしない。

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

本体は W の起動指示・SendMessage による再開指示・手渡しの起動指示に、`段: spec` / `段: implement` / `段: finish` のいずれか 1 行を書かなければならない（MUST）。`段:` の値は、その起動・再開で本体が W に指示する工程で決めなければならない（MUST）: (1) の spawn と R1 の REQUEST_CHANGES を受けた再開は `spec`、(3a) の再開と G の failed や CI の見張りの `fix` を受けて直させる再開は `implement`、(3b) の再開は `finish` とする。手渡しの起動指示も同じ規則で決める: 前任が工程の途中で止まり（前任の return の 1 行目が `工程完了:` でない）、後任に同じ工程を続けさせるときは前任が担っていた段、前任が工程を終えて（1 行目が `工程完了:`）return したあとに交代させるときは、本体が後任に次に指示する工程の段とする（MUST。例: (3a) を終えた前任の後任に (3b) を指示するなら `finish`、(1) を終えた前任の後任に R1 の REQUEST_CHANGES の修正を指示するなら `spec`）。次に指示する工程は、既存要件「W の (3) は 2 回の return に分かれる」のとおり本体が自分の指示した工程から決め、前任の return の工程名の文字列から決めてはならない（MUST NOT）。develop の `SKILL.md` はこの対応を書かなければならない（MUST）。

仕様化しないと判定した W に、本体が同じコンテキストのまま (3a) へ進むよう指示したときは、W は `worker/implement.md` を読んでから進まなければならない（MUST）。`worker/spec.md` はこれを書かなければならない（MUST）。

#### Scenario: SKILL.md が段の値を書く

- **WHEN** develop の `SKILL.md` の 1 ループを読む
- **THEN** `段: spec`・`段: implement`・`段: finish` がそれぞれ、対応する W の起動・再開の場面とともに書かれている

#### Scenario: 手渡しで同じ工程を続けさせる

- **WHEN** 本体が (3a) の途中で `工程中断:` を返した前任の後任を起こし、(3a) を続けさせる
- **THEN** 後任の起動指示の `段:` は `implement` である

#### Scenario: 工程を終えた前任の後任に次の工程を指示する

- **WHEN** 本体が `工程完了: 実装＋verify` を返した前任の代わりに後任を起こし、(3b) を指示する
- **THEN** 後任の起動指示の `段:` は `finish` で、前任が担っていた `implement` ではない

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

### Requirement: W の指示書の読み込み量は個体ごとに測り、8K を超えたら主の判断に回す

この変更の PR では、W の指示書の読み込み量が W の個体ごとに 8,000 トークン以下であることを、`plugins/dev-workflow/scripts/subagent-context-audit.sh --by-role` で測った値で示さなければならない（MUST。issue #556 の受け入れ条件 2）。受け入れ条件 2 を「記録すれば足りる」に改めてはならない（MUST NOT）。

計測対象は、変更後の指示書（索引・`worker/` の段のファイル）で動いた develop の 1 本に現れた W の全個体（(1) の spawn・SendMessage で再開された個体・手渡しの後任を含む）とする（MUST）。`by_role.W.docs_median` は W の個体ごとの合計の中央値（同スクリプト冒頭のコメント）なので、担当全体の `docs_median` を個体の値の代わりにしてはならない（MUST NOT）。個体の値は、その個体の `agent-<id>.jsonl` と `agent-<id>.meta.json` だけを `<作業用ディレクトリ>/<任意>/<任意>/subagents/` に置き、その作業用ディレクトリを `--projects` に、別の作業用ファイルを `--cache` に渡して `--refresh` 付きで実行し、`by_role.W.count` が 1 であることを確かめてから読んだ `by_role.W.docs_median` とする（MUST）。

計測が有効なのは、その個体が変更後の指示書を、同スクリプトが指示書の Read として数えるパス（`INSTR_RE`。`plugins/cache/oratta-claude-harness/` を含み `.md` で終わる）から読んだ場合だけである。変更前の指示書を読んだ個体（この issue 自身の develop の W など）と、変更後の指示書をこのパスの外から読んだ個体（数えられない分だけ値が小さく出る）は、計測対象の値として使ってはならず（MUST NOT）、未計測として扱わなければならない（MUST）。

計測対象の全個体が 8,000 以下なら受け入れ条件 2 を満たす。1 個体でも 8,000 を超えたとき、または未計測の個体が残るとき（計測を行えなかったときを含む）は受け入れ条件 2 の未達として扱い、PR 本文に個体ごとの値と内訳（その個体が Read した指示書のファイル名と字数）・超過や未計測を解消する手段を切った follow-up issue の URL を書き、G は pr-review-gate のリスク宣言に同じ未達を載せて主の判断に回さなければならない（MUST）。未達の記録を書いたことをもって受け入れ条件 2 を満たしたと扱ってはならない（MUST NOT）。

#### Scenario: 個体ごとの値が PR 本文にある

- **WHEN** この変更の PR 本文の受け入れ条件 2 の節を読む
- **THEN** 計測対象の W の個体ごとに agent id・担った工程・`by_role.W.count` が 1 だったこと・値・8,000 との比較が並んでおり、担当全体の `docs_median` だけで判定していない

#### Scenario: 1 個体でも超えたとき

- **WHEN** 計測対象の W のうち 1 個体の値が 8,000 を超えた
- **THEN** PR 本文にその個体の値と内訳と follow-up issue の URL があり、リスク宣言に受け入れ条件 2 の未達が載り、受け入れ条件 2 を満たしたとは書かれていない

#### Scenario: 数えられないパスから読んだ個体

- **WHEN** 計測に使った W が変更後の指示書を `plugins/cache/oratta-claude-harness/` を含まないパス（worktree の中など）から読んでいた
- **THEN** その個体の値は計測対象に使われず、未計測として受け入れ条件 2 の未達の扱いになっている
