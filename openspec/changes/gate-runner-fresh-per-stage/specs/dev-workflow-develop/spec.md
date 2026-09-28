## ADDED Requirements

### Requirement: G は段ごとに新しく起こし、SendMessage で再開しない

`plugins/dev-workflow/skills/develop/SKILL.md` の (4) は、G を段ごとに新しく spawn することを規定しなければならない（MUST）。1 体の G は次の 4 つの段のうち 1 つだけを担当する（MUST）。

| 段 | 本体が起こす時点 | G が読むファイル（`skills/pr-review-gate/` から） | 返しうる Status |
|---|---|---|---|
| 前提確認と重さ判定 | ゲートの開始、W の修正後の再レビュー、CI の見張りで `ready` になったあとの取り直し | `stages/prepare.md` | `needs-reviewer` / 保留 |
| 照合と振り分け | レビュー要約・補足レビューの結果・決める役の裁定を受け取ったとき、戻した指摘が順 3 だけの修正のあと | `stages/triage.md` | `次の段へ` / failed / 保留 / `needs-reviewer`（補足） / `needs-decider` / `review-incomplete` |
| 合格処理 | 照合と振り分けが止める指摘なしで終わったとき | `declarations.md` と `stages/pass.md`（保留を返すときだけ `stages/hold.md`） | passed / 保留 |
| 保留の解除 | 主の回答が届いたとき | `stages/hold.md` | 復帰手順の表どおり（別の段の作業に進むときは `次の段へ`） |

本体は G の起動指示に `段: <段の名前>` の 1 行を書かなければならない（MUST）。`skills/develop/SKILL.md` の (4) と `skills/develop/references/roles/gate-runner.md` は、G を SendMessage で再開する記述を持ってはならない（MUST NOT）。G への SendMessage は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の停止の指示だけに残し、その規則は decision-criteria.md にだけ書く（MUST）。`gate-runner.md` の「時点ごとに読むファイル」の表は、上の段の表に揃えなければならない（MUST）。

保留の解除の G は、復帰手順の表が別の段の作業（再レビュー・合格処理）に進むと示したとき、その作業を自分で行ってはならず（MUST NOT）、Status `次の段へ` と `次の段:` で返さなければならない（MUST）。

この要件は、develop の本体がレビュアーを起こす adapter 経路（起動指示が `レビュー経路: adapter`）に掛かる。従来経路の G はレビューを自分の起動の中で起こすので、前提確認と重さ判定から照合と振り分けまでを 1 体で続けてよい（MAY）。

#### Scenario: SendMessage による G の再開の記述が無い

- **WHEN** `plugins/dev-workflow/tests/` の develop の役割の bats が `skills/develop/SKILL.md` の (4) と `gate-runner.md` を検査する
- **THEN** 段ごとに新しい G を起こす記述と `段:` の行の指示があり、G を SendMessage で再開する記述が無い

#### Scenario: CI の見張りのあとの取り直し

- **WHEN** CI の見張りが `ready` になり、本体がゲートを取り直す
- **THEN** 本体は前提確認と重さ判定の G を新しく起こし、前の G を再開しない

### Requirement: Gate Result は段と次の段を持つ

`gate-runner.md` の Gate Result の共通欄は、`段: <前提確認と重さ判定|照合と振り分け|合格処理|保留の解除>` と `次の段: <段の名前|なし>` を持たなければならない（MUST）。Status には `次の段へ` を足す（MUST）。本体は Status と `次の段:` だけを見て次に起こす G の段を決め、段についての判断（止める指摘が残っているか、復帰手順がどこへ進むか）をしてはならない（MUST NOT）。

#### Scenario: 止める指摘が無いとき

- **WHEN** 照合と振り分けの G が止める指摘なしで終わる
- **THEN** G は Status `次の段へ`、`次の段: 合格処理` で返し、本体は合格処理の G を新しく起こす

### Requirement: 段と段の間の受け渡しは PR コメントを正とする

G は前の段の会話を持たない前提で動かなければならない（MUST）。段と段の間で渡すものは次の PR コメントに置く（MUST）。

| 渡すもの | 置き場所 | 書く G |
|---|---|---|
| 固定した HEAD | `レビュー重量:` コメントの `固定 HEAD: <SHA>` の行 | 前提確認と重さ判定 |
| レビューの三表 | 1 行目 `レビュー三表:` のコメント | 照合と振り分け |
| 振り分けの結果 | 既存の仕分けコメント | 照合と振り分け |

固定した HEAD の行を `対象 HEAD:` と書いてはならない（MUST NOT。auto-merge workflow がこの文字列を宣言の照合に使うため）。

本体は次の G の起動指示に、前の段の `## Gate Result` ブロックを要約し直さずそのまま貼り、段に固有の入力（レビュー要約・補足レビューの結果・決める役の裁定・主の回答・W の修正の要約）を足さなければならない（MUST）。起動指示と PR コメントが食い違ったら、G は PR コメントを正としなければならない（MUST）。

`gate-runner.md` の「再開」節は、段ごとの起動と入力（その段が読む PR コメントと、本体が渡すもの）を定める節に書き換えなければならない（MUST）。段の各ファイルの「G として動くとき（develop）」節にある再開の小節は、その段で起こされたときの入力として書き換える（MUST）。

#### Scenario: 補足レビューの結果を渡す

- **WHEN** 照合と振り分けの G が補足の `needs-reviewer` を返し、本体が補足レビューを起こして結果を受け取る
- **THEN** 本体は照合と振り分けの G を新しく起こし、前の Gate Result ブロックと補足レビューの結果を渡す。G は元の三表を `レビュー三表:` のコメントから読む

### Requirement: 周回は前の段から引き継ぐ

G は `周回:` を前の段の Gate Result の値から引き継がなければならない（MUST）。W の修正後の再レビューで起こされた前提確認と重さ判定の G だけが 1 増やす（MUST）。戻した指摘が順 3 だけの修正のあとは周を消費しない（`stages/triage.md` の既存規則のまま）。

#### Scenario: 再レビューの周

- **WHEN** 周回 1 で failed が返り、W の修正後に前提確認と重さ判定の G を起こす
- **THEN** その G の Gate Result は `周回: 2` を持つ

### Requirement: G が工程中断で返したら同じ段の新しい G を起こす

G が `工程中断:` で返したとき、本体は同じ段の新しい G を起こさなければならない（MUST）。起こしてよい条件は `decision-criteria.md` の「手渡しの許可」を参照し、`gate-runner.md` と SKILL.md に書き写してはならない（MUST NOT）。新しい G には前任の return 全文と、前任の起動指示に書いた入力を渡す（MUST）。

`scripts/subagent-context.sh` で G を測る記述は `gate-runner.md` と SKILL.md の (4) から無くし、再開前の計測は W だけに残す（MUST）。spawn の前の PR トークン上限の計測は変えない。

#### Scenario: 前任の入力を引き継ぐ

- **WHEN** 照合と振り分けの G が `工程中断:` で返す
- **THEN** 本体は照合と振り分けの G を新しく起こし、前任の return 全文と前任に渡したレビュー要約を渡す

### Requirement: G の名前と description は段を表す

本体は G を名前 `G-<PR>-<prepare|triage|pass|hold>-<n>`（`n` はその PR・その段で起こした回数）で spawn しなければならない（MUST）。description は `G: <段> for PR #N (#issue)` の形にし、先頭の `G:` を残さなければならない（MUST。`scripts/subagent-context-audit.sh --by-role` がこの接頭辞で G と判定するため）。

#### Scenario: 役割別集計で G と判定される

- **WHEN** `G: 照合と振り分け for PR #600 (#554)` の description で起こした G のトランスクリプトを `subagent-context-audit.sh --by-role` で集計する
- **THEN** G の行に数えられる

### Requirement: 「レビュー実行者:」コメントの段落は照合と振り分けの段に置く

レビュー要約を受け取った G が投稿する「レビュー実行者:」PR コメントの段落は、`skills/pr-review-gate/stages/triage.md` の「G として動くとき（develop）」節に置かなければならない（MUST）。`stages/prepare.md` に残してはならない（MUST NOT）。

#### Scenario: 段落の所在

- **WHEN** `stages/prepare.md` と `stages/triage.md` を読む
- **THEN** 「レビュー実行者:」コメントの段落は `stages/triage.md` にだけある

### Requirement: G の再開を前提にした既存要件の読み替え

既存要件のうち G の「再開」「SendMessage で G に渡す」「G を再開して再レビュー」と書いた箇所は、上の要件「G は段ごとに新しく起こし、SendMessage で再開しない」の表で、その時点に当たる段の G を新しく起こし、その起動指示に渡すものとして読まなければならない（MUST）。`レビュー経路: adapter` で起動済みの同一 G が行の無い再開指示でも adapter 経路を保つ規則は、再開が無いので `gate-runner.md`・SKILL.md・`plugins/dev-workflow/references/codex-develop.md` から消さなければならない（MUST）。本体がすべての G の起動指示に `レビュー経路: adapter` の 1 行を書く規則は変えない。

`stages/prepare.md` に置くとした「レビュー実行者:」PR コメントの段落は、上の要件「『レビュー実行者:』コメントの段落は照合と振り分けの段に置く」どおり `stages/triage.md` を指すものとして読む（MUST）。

この読み替えは、少なくとも次の既存要件に掛かる: 「1 ループは W→R1→W→G の順で回る」（修正後は G を再開して差分再レビュー）・「役割の指示書は references/roles/ に分かれている」（要約を G に SendMessage で渡す）・「役割のモデルは事前分類と残量モードで決める」（Scenario「再開前にコンテキスト量を測る」の G の部分は適用しない）・「G の needs-decider を受けた本体の動き」（裁定を SendMessage で渡して G を再開する）・「G はレビュー経路を起動指示の 1 行で判別する」（Scenario「adapter 経路で起動済みの G を行無しで再開」は再開が無いので適用しない）・「本体は adapter 経路の needs-reviewer で phase review の投げ先を選び直して記録する」（Claude の G は SendMessage で再開して渡す）・「G は段ごとに要るファイルだけを読む」・「既存要件が gate-runner.md に置いた内容のうち段に移したものは段のファイルを指す」（「レビュー実行者:」の段落の移し先と、再開節の移し先）。

#### Scenario: 裁定の渡し方

- **WHEN** 既存要件「G の needs-decider を受けた本体の動き」に従い、本体が決める役の裁定を受け取る
- **THEN** 本体は照合と振り分けの G を新しく起こし、前の Gate Result ブロックと裁定を起動指示で渡す

#### Scenario: adapter 経路の保持規則が無い

- **WHEN** `gate-runner.md`・SKILL.md・`references/codex-develop.md` を読む
- **THEN** 行の無い再開指示で adapter 経路を保つ規則が無く、G の起動指示に常に `レビュー経路: adapter` を書く規則は残っている

### Requirement: 段ごとの G で上限を超えないことを PR 本文に記録する

この変更の PR の本文は、その PR のゲートを本体が worktree 側の新しい `skills/develop/SKILL.md` と `gate-runner.md` に従って段ごとの G で回した結果として、G ごとの段と終了時のコンテキスト量、150K を超えた G の数、上限による手渡しの回数を記録しなければならない（MUST）。実行時に読まれるプラグインのキャッシュはマージ前の版なので、マージ前の版で測った値であることを本文に明記する（MUST）。

#### Scenario: 記録の確認

- **WHEN** この変更の PR 本文を読む
- **THEN** G ごとの段と終了時のコンテキスト量、150K を超えた G の数（期待値 0）、手渡しの回数（期待値 0）、マージ前の版で測った旨がある
