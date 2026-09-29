## Why

develop の作業担当（W）は、1 回の起動で仕様づくり・実装と検証・仕上げのどれか 1 つしかしないのに、どの段でも `skills/develop/references/roles/worker.md`（13,416 字、約 14K トークン）を全部読んでいる。W は直近 10 日で 400 体以上起きており、使わない段の手順と、W ではなく本体が使う事前分類表を読む分が起動ごとに積み上がる。同じ理由で先に分けた pr-review-gate（#553）と同じ形で、W の指示書を段ごとに分ける（issue #556、エピック #511 の子）。

## What Changes

- `plugins/dev-workflow/skills/develop/references/roles/worker.md` を索引にする。索引は段の表（段の名前・工程・読むファイル）と、旧節から移し先への対応表だけを持ち、手順の本文とコードブロックを持たない。
- 手順の本文を `skills/develop/references/roles/worker/` の 4 本に移す: 全段で読む `common.md`（本体が渡すもの・W がしないこと・昇格トリップワイヤー・コンテキスト上限と手渡し。どの段でも要る規則を全段から読める位置に置く）、`spec.md`（仕様づくり: Draft PR の記録先の用意・仕様化判断と記録・分割判定・仕様化する場合）、`implement.md`（実装と検証: (3a)）、`finish.md`（仕上げ: (3b)）。段の割り方の確定案と、issue の当たりから変えた点（事前分類表と昇格トリップワイヤーの置き場所）の理由は design.md。
- 重要実装の事前分類表を、W が読まない独立ファイル `skills/develop/references/pre-classification.md` に移す。事前分類表を使うのは W を起こす本体と R1・G・pr-review-gate で、W 自身はモデルを選ばない。参照元（develop の SKILL.md・spec-reviewer.md・decision-criteria.md・pr-review-gate の `stages/triage.md`・`references/model-tiers.md`・README）のパスを付け替える。
- 本体は W の起動指示・再開指示・手渡しの起動指示に `段: spec|implement|finish` の 1 行を書く。W のエージェント定義 `agents/worker.md` の本文は、`common.md` と起動指示の `段:` が指す段のファイルを読むことを書く。
- W が 1 回の起動で読む指示書（`common.md` と段のファイル）の字数を段ごとに bats で出し、分割前の worker.md 全体（13,416 字）と並べて PR 本文に記録する（issue の受け入れ条件 1）。字数に上限は置かず、字数だけを理由に節の置き場所を決めない。
- issue の受け入れ条件 2（W の指示書の読み込み量の実測）は、変更後の指示書で動いた develop の 1 本の W を個体ごとに `subagent-context-audit.sh --by-role` で測り、分割前の W を同じ方法で測った値と並べて PR 本文に記録する。読み込み量に上限は置かない。指示書を数えられないパスから読んだ個体は、値ではなく測れなかった個体として理由とともに記録する。
- `worker.md` にあった本体向けの説明のうち「(3) をこれより細かく切らない」理由は、W が読まない develop の `SKILL.md` の (3) に移す。
- 手順の中身（規則・書式・コマンド）は変えない。同じ手順を 2 か所に書かない。
- `scripts/codex-develop.py` が Codex の W の phase（spec / implement / finish / explore / summarize）に渡す正本の一覧を、共通と段のファイルに付け替える。
- worker.md の文言を検査している既存 bats の参照先を、その文言が移ったファイルに 1 つずつ付け替える。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: W の指示書を索引・共通・段のファイルに分ける要件、段ごとの字数と W の個体ごとの読み込み量を分割前と並べて記録すること、事前分類表の置き場所、本体が W に `段:` を書く要件、Codex の W の phase に渡す正本の一覧、既存要件で worker.md に置くと定めた内容を移し先のファイルと読む読み替えを足す。
- `dev-workflow-role-agent-types`: 作業者の定義 `agents/worker.md` の本文が指す読み先を、`worker.md` から `common.md` と `段:` が指す段のファイルに変える。
- `dev-workflow-spec-review`: 既存要件が worker.md の仕様化判断の節・仕様化する場合の節と書いた箇所を `worker/spec.md` と読み、事前分類表を `pre-classification.md` と読む読み替えを足す。
- `dev-workflow-pr-review-gate`: 既存要件が worker.md の順 3 の一覧の段落と書いた箇所を `worker/implement.md` と読む読み替えを足す。
- `dev-workflow-subagent-waiting`: 既存要件が複製の worker.md に違反を差し込むと書いた箇所を、複製の `worker/implement.md` と読む読み替えを足す。

## Impact

- 編集: `plugins/dev-workflow/skills/develop/references/roles/worker.md`（索引化）、新規 `skills/develop/references/roles/worker/{common,spec,implement,finish}.md` と `skills/develop/references/pre-classification.md`、`agents/worker.md`、`skills/develop/SKILL.md`（`段:` の行・事前分類の参照先・(3) の理由）、`skills/develop/references/decision-criteria.md`・`references/roles/spec-reviewer.md`・`skills/pr-review-gate/stages/triage.md`・`skills/pr-review-gate/declarations.md`・`references/model-tiers.md`・`templates/escalation-tripwires.md`・`README.md` のうち worker.md のパスを指す行、`scripts/codex-develop.py`、`tests/*.bats` と `tests/test_codex_develop.py`・`tests/develop-worker-ci-checks.bats` の参照先、変更記録 `plugins/dev-workflow/changes/556.md`。
- 既存 spec の本文は書き換えず、読み替えの要件で扱う（作業者の定義本文だけは MODIFIED）。
- 常時注入の予算: `agents/worker.md` の `description` は変えないので、`tests/injection-budget.txt` は動かさない。
- W の工程の切り方（(1)・(3a)・(3b)）と、本体が W を名前付き spawn して SendMessage で再開する流れは変えない。
