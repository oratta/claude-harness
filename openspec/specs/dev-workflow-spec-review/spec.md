# dev-workflow-spec-review Specification

## Purpose
develop スキルが、仕様化要否の判断を機械照合できる書式で記録先（元 issue、無ければ Draft PR）に残し、書いた仕様（openspec の change artifact）を実装前に別コンテキストが審査してから実装に入ることを規定する。longrun の Build Contract レビューを dev-workflow のパイプラインに置き直したもの。

## Requirements

### Requirement: 仕様化要否の判定結果を固定書式で issue に記録する
develop スキルの W の指示書（`references/roles/worker/spec.md`。記録する前に実装へ進まない規則は `references/roles/worker/common.md`「実装に入る前の確認」）は、仕様化要否を判定した直後に、その結果を記録先（元 issue。issue が無い場合は Draft PR）のコメントとして記録する手順を明記しなければならない（MUST）。コメントの 1 行目は正規表現 `^仕様化判断: (する|しない)$` に完全一致し（装飾・全角コロン・末尾句点を含めない）（MUST）、2 行目以降に判定理由（`references/decision-criteria.md` のどの条件に当たったか）を書く（MUST）。同接頭辞のコメントが複数あるときは作成日時が最新の 1 件を正とし（SHALL）、この記録は interactive / unmanned の両モードで行い（MUST）、記録せずに分割判定・実装へ進んではならない（MUST NOT）。後続の照合で PR から元 issue を解決する規則（PR 本文中で最初に現れる `Closes #N` / `Fixes #N` / `Refs #N`、大文字小文字不問。見つからなければ PR 自身のコメントを見る）は `references/roles/spec-reviewer.md` の「判断記録の契約」に定義する（SHALL）。

#### Scenario: worker/spec.md に記録手順と正規表現がある
- **WHEN** `references/roles/worker/spec.md` の仕様化判断の節を読む
- **THEN** `^仕様化判断: (する|しない)$` の書式と、`gh` で記録先にコメントする手順、記録前に先へ進まない旨が書かれている

#### Scenario: unmanned でも免除されない
- **WHEN** SKILL.md の実行モード表または unmanned に関する記述を読む
- **THEN** 判定記録が unmanned でも必須であることが書かれている

#### Scenario: 複数記録時の選択規則と PR→issue の解決規則がある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** 同接頭辞のコメントが複数あるときは最新 1 件を正とする規則と、PR 本文の最初の `Closes` / `Fixes` / `Refs #N` で元 issue を解決し、無ければ PR 自身のコメントを見る規則が書かれている

### Requirement: 書いた仕様は実装前に別コンテキストがレビューする
develop スキルは、仕様化経路で、W が openspec CLI（`openspec new change` と artifact の直書き）で artifact を生成して return した直後・W を再開して実装に着手する前に、本体が spawn する R1（`references/roles/spec-reviewer.md` を読む、実装と別コンテキストのサブエージェント）による仕様レビューを挟まなければならない（MUST）。本体や主が W の起動前に `/opsx:ff` などで change を作っていた場合も、W がそれを確かめて return したあと同じ仕様レビューを挟む（SHALL）。レビューの入力は change ディレクトリの artifact・記録先の受け入れ条件・関連する既存 `openspec/specs/`（`grep` で当たりを付けた範囲）とし（MUST）、観点・出力書式は `references/roles/spec-reviewer.md` を正本とする（SHALL）。R1 が `APPROVE` を返し記録されるまで W を実装に進めてはならない（MUST NOT）。

例外は文言合わせの通し方（「仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く」Requirement）だけとする（MUST）。記録先の最新の仕様化判断のコメントに `^通し方: 文言合わせ$` に完全一致する行があるとき、本体は R1 を spawn せず、W を実装に進める（SHALL）。本体は W の return の文面ではなく、記録先のコメントでこの行を確かめなければならない（MUST）。行が無ければ R1 を挟む（MUST）。

#### Scenario: 1 ループにレビューが挟まっている
- **WHEN** SKILL.md の 1 ループを読む
- **THEN** W の change の作成（`openspec new change`）と W の再開（実装）の間に R1 の仕様レビューがあり、`references/roles/spec-reviewer.md` を参照し、APPROVE の記録まで実装に進まない旨が書かれている

#### Scenario: worker/spec.md の仕様化する場合の節と worker/common.md の実装に入る前の確認にレビューがある
- **WHEN** `references/roles/worker/spec.md` の仕様化する場合の節と、`references/roles/worker/common.md` の「実装に入る前の確認」の節を読む
- **THEN** `openspec new change` と artifact の直書きの後に本体へ return して仕様レビューを受けることと、R1 の APPROVE が記録されるまで実装に進まないことが書かれている

#### Scenario: 文言合わせの通し方では R1 を挟まない
- **WHEN** 記録先の最新の仕様化判断のコメントが 1 行目 `仕様化判断: する` で、2 行目以降に `通し方: 文言合わせ` の行を持つ
- **THEN** 本体は R1 を spawn せず、記録先のコメントでその行を確かめたうえで W を `段: implement` で再開する

#### Scenario: 通し方の行が無ければ R1 を挟む
- **WHEN** W が「文言合わせで進める」と return したが、記録先の最新の仕様化判断のコメントに `通し方: 文言合わせ` の行が無い
- **THEN** 本体は W を実装に進めず、W を `段: spec` で再開して仕様化判断を投稿し直させる

### Requirement: 仕様レビューの観点は既存 spec との整合と受け入れ条件の一意性を含む
`references/roles/spec-reviewer.md` は、レビュアーが検査する観点として少なくとも次の 6 つを含まなければならない（MUST）: ①受け入れ条件（Scenario の WHEN/THEN）が一意に決まりテスト可能か ②既存 `openspec/specs/` の要件と衝突・重複しないか（衝突時は spec パスと要件名を挙げる） ③リポ固有の値（時刻・名前・パス）が config や引数に出されているか ④導入先・前提環境（プラグイン・CLI・権限）が書かれているか ⑤proposal / specs / design / tasks の相互整合 ⑥守備範囲の明記。レビュアーは読み取り専用で仕様ファイルを変更してはならず（MUST NOT）、既存 spec は `grep` で当たりを付けてから該当ファイルだけ読む（SHALL）。

⑥の守備範囲の明記は、入力を検査・判定する要件（検査・lint・ゲート・パーサ・バリデータのように、入力を受け取って通す／落とす／分類する振る舞いを定める要件）だけに求める（MUST）。対象の要件には「何から守るか」と「何は守らないか」の両方を書いた段落がなければならず、片方でも欠けていればレビュアーはその欠落を BLOCKER とし、`REQUEST_CHANGES` で差し戻す（MUST）。入力の検査を含まない要件には守備範囲を求めてはならない（MUST NOT）。検査の対象はレビュー対象の change の delta spec が追加（ADDED）または改定（MODIFIED）する要件に限り、change が触れない既存 `openspec/specs/` の要件に遡って守備範囲を求めてはならない（MUST NOT）。spec-reviewer.md は、⑥の対象の限定と欠落時の `REQUEST_CHANGES` を、観点を列挙する同じ節に書かなければならない（MUST）。

この観点の守備範囲は、仕様を書く側（主と Claude）が検査系の要件に守備範囲の段落を書き忘れることを実装前に拾うことである。守備範囲の段落に書かれた範囲そのものが妥当かどうか（守るべき入力を守らない側に入れていないか）は、この観点では判定しない。ある要件が「入力を検査・判定する要件」に当たるかの判断はレビュアーに委ね、判断が割れた場合の扱いは 2 周キャップと `needs-approval` の既存規定に従う。

#### Scenario: spec-reviewer.md に 6 観点がある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** 上記 6 観点がすべて列挙され、既存 spec との衝突時に spec パスと要件名を挙げる指示がある

#### Scenario: 守備範囲の観点は対象と差し戻しを同じ節に書く
- **WHEN** `references/roles/spec-reviewer.md` のレビュー観点の節を読む
- **THEN** 同じ節の中に「守備範囲」の語、対象を入力を検査・判定する要件に限る記述、守備範囲が無ければ `REQUEST_CHANGES` で差し戻す記述の 3 つがある

#### Scenario: 守備範囲の観点を欠いた spec-reviewer.md は退行検査で落ちる
- **WHEN** `references/roles/spec-reviewer.md` のレビュー観点の節から守備範囲の観点を消した状態で `scripts/test.sh develop-roles` を実行する
- **THEN** 守備範囲の観点を検査するテストが fail する

#### Scenario: 遡及しないことが書かれている
- **WHEN** `references/roles/spec-reviewer.md` のレビュー観点の節を読む
- **THEN** 同じ節の中に文字列 `遡及しない` があり、守備範囲の検査対象が change の追加・改定する要件に限られることが書かれている

#### Scenario: 読み取り専用と grep 先行が書かれている
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** レビュアーが仕様ファイルを変更しないこと、既存 spec を全読みせず grep で当たりを付けることが書かれている

### Requirement: 仕様レビューは 2 周で確定し結果を issue に記録する
仕様レビューは初回と修正後の差分再レビュー 1 回の計 2 周を既定とする（MUST）。3 周目以降の周も差分再レビューとし、前の周の指摘が閉じたかと、修正で新たに生じた矛盾だけを見る（MUST）。

2 周目以降の周の終わりに BLOCKER が残ったら（R1 の結果が `REQUEST_CHANGES`）、本体は主に聞く前に、決める役（`subagent_type: dev-workflow:decider`）に残った BLOCKER の直し方の判定を依頼しなければならない（MUST。判定役・入力・返答の 1 行目・判定の記録と事後報告の書式は `dev-workflow-develop` の「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement が正本）。判定が「決まっている」で、PR トークン上限の計測が exit 2 でなければ、本体は主に聞かずに W を再開して artifact を直させ、R1 に次の周の差分再レビューをさせる（MUST）。interactive と unmanned で同じに扱う（MUST）。

主に聞くのは次の 2 つのときだけとする（MUST）: ①直し方の判定が「選び直しが要る」（設計の選択肢が複数ある・記録先の範囲を変える・前の周で「決まっている」とした直し方で閉じなかった。入力不足で判定が出なかったときも含む） ②PR トークン上限の計測が exit 2（`scripts/pr-token-budget.sh` が上限超を返した）。①のときは記録先に `needs-approval` ラベルを付けて経緯をコメントし（MUST）、interactive モードでは本体が AskUserQuestion で判断を仰ぎ、unmanned モードではそのサイクルを終了する（MUST）。②のときは `skills/develop/SKILL.md`「PR トークン上限」の exit 2 の手順に従う（MUST）。この 2 つは方針を主に聞くときの数で、指摘の条件を聞く問い（`dev-workflow-develop` の「仕様レビューの残った指摘は直し方の判定の前に条件を確かめる」Requirement）は数えない（SHALL）。

判定結果は記録先のコメントとして記録しなければならず（MUST）、その書式は `references/roles/spec-reviewer.md` に置く（SHALL）。コメントの 1 行目は正規表現 `^仕様レビュー: (APPROVE|REQUEST_CHANGES)$` に完全一致し、2 行目以降に周回数・レビュアーのモデル・残課題を書く（MUST）。

投稿者は R1 の spawn 方法で分かれる（SHALL）。`general-purpose` に `model` を明示して spawn した R1 は、従来どおり自分で `gh issue comment` / `gh pr comment` を実行して投稿する。`subagent_type: dev-workflow:decider` で spawn した R1 は `Bash` を持たず投稿できないため、**本体が R1 の return を同じ書式で代理投稿しなければならない**（MUST）。代理投稿でも書式・記録先・「APPROVE が記録されるまで実装に進まない」の判定は変わってはならない（MUST NOT）。同様に decider として起こした R1 は記録先を `gh` で読めないため、**呼び出し側が記録先の本文と関連コメント（受け入れ条件・`仕様化判断:` の記録）を入力文に貼り付けなければならない**（MUST）。`references/roles/spec-reviewer.md` は、レビュアーへの入力と結果の記録の節にこの 2 経路（自分で投稿する場合と本体が代理投稿する場合）を書き分けなければならない（MUST）。

#### Scenario: 2 周の既定と直し方の判定による続行が書かれている
- **WHEN** SKILL.md または `references/roles/spec-reviewer.md` を読む
- **THEN** 既定 2 周・差分限定の再レビュー・2 周目以降の周の終わりに BLOCKER が残れば決める役の直し方の判定を通すこと・残った BLOCKER がすべて直し方の決まったもので PR トークン上限の内側なら主に聞かず次の周を回すこと・主に聞くのは「方針の選び直しが要る」と「PR トークン上限を超える（`pr-token-budget.sh` が exit 2）」の 2 つだけであることが書かれ、「3 周目の例外は設けない」の文は無い

#### Scenario: 直し方が決まっている BLOCKER だけが残る
- **WHEN** 2 周目の R1 の結果が `REQUEST_CHANGES` で、決める役の返答の 1 行目が `裁定: 可` で、PR トークン上限の計測が exit 0
- **THEN** 本体は `needs-approval` を付けず主にも聞かずに、判定の記録を記録先に投稿して W を `段: spec` で再開し、R1 に 3 周目の差分再レビューをさせ、3 周目の結果を受け取ったら事後報告を記録先に投稿する

#### Scenario: 方針の選び直しが要る BLOCKER が残る
- **WHEN** 2 周目以降の周の終わりに残った BLOCKER について、決める役の返答の 1 行目が `裁定: 否`
- **THEN** 本体は判定の記録を記録先に投稿したうえで `needs-approval` を付けて経緯をコメントし、interactive は AskUserQuestion、unmanned はサイクル終了とする

#### Scenario: 続行の前にトークン上限を超えている
- **WHEN** 直し方の判定が「決まっている」だったが、W を再開する前の PR トークン上限の計測が exit 2
- **THEN** 本体は W を再開せず、PR トークン上限の exit 2 の手順で主に「続けるか、範囲外として閉じるか」を問う

#### Scenario: 結果コメントの書式と投稿手順が spec-reviewer.md にある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** `^仕様レビュー: (APPROVE|REQUEST_CHANGES)$` の書式と、周回数・モデル・残課題を含めて記録先にコメントする手順が書かれている

#### Scenario: decider として起こした R1 は本体が代理投稿する
- **WHEN** 本体が R1 を `subagent_type: dev-workflow:decider` で spawn し、R1 が判定を return する
- **THEN** R1 は `gh` を実行せず判定と理由を return し、本体が同じ 1 行目書式で記録先にコメントする

#### Scenario: decider として起こした R1 には記録先の本文が入力で渡る
- **WHEN** `references/roles/spec-reviewer.md` の「レビュアーへの入力」を読む
- **THEN** decider 経路では記録先の本文と関連コメントを呼び出し側が入力文に貼ること、`gh` で自分で取りに行かないことが書かれている

### Requirement: 仕様レビュアーのモデルは役割で選ぶ
R1 は本体が `model` を明示して spawn しなければならない（MUST）。既定は中位ティア（`opus`）とし（SHALL）、仕様が `references/pre-classification.md` の「重要実装の事前分類」表のマージ権限・層間契約・課金/法務に当たる場合は、`model: fable` を付けた `general-purpose` ではなく `subagent_type: dev-workflow:decider` で spawn しなければならない（MUST。聖域パスだけでは上げない。分類表の正本は `pre-classification.md` であり、この要件に再掲しない）。`general-purpose` などの実行役の種別に `model: fable` を付ける spawn は `scripts/agent-model-guard.sh` に拒否される（SHALL）。残量モードは `dev-workflow-execution-strategy` の規定に従い、`FABLE_BUDGET_MODE=reserve` は自動実行のみ、`exhausted` は全経路で `opus` を上限とする（MUST）。

#### Scenario: モデル明示と既定 opus が書かれている
- **WHEN** SKILL.md の「モデル」節または `references/roles/spec-reviewer.md` を読む
- **THEN** `model` を明示すること、既定が `opus` であること、マージ権限・層間契約・課金/法務に当たれば `dev-workflow:decider` で spawn し、聖域パスだけでは上げないことが書かれている

#### Scenario: 残量モードの扱いが既存規定と一致する
- **WHEN** SKILL.md または `references/roles/spec-reviewer.md` の残量モードの記述を読む
- **THEN** `reserve` は自動実行のみ、`exhausted` は全経路で `opus` 上限、と書き分けられている

#### Scenario: R1 のモデル選択が指す表

- **WHEN** `references/roles/spec-reviewer.md` のモデルの箇条を読む
- **THEN** 事前分類表の参照先が `references/pre-classification.md` である

### Requirement: 仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く
develop スキルは、仕様化判断が「する」になった変更のうち、既存の仕様の文言を実装に合わせて直すだけの変更に、成果物を仕様の差分 1 ファイルだけにして R1 の仕様レビューを省く通し方（以下「文言合わせの通し方」）を持たなければならない（MUST）。対象・当てる条件・省くものの正本は `references/decision-criteria.md` の Step B に置き（MUST）、W の手順は `references/roles/worker/spec.md` に、記録の書式は `references/roles/spec-reviewer.md` の「判断記録の契約」に置く（MUST）。対象・当てる条件の正本は `decision-criteria.md`、記録の書式の正本は `spec-reviewer.md` とし、`worker/spec.md` は正本を指して要約だけを書く。要約が正本と食い違ってはならない（MUST NOT）。

**対象**: 次をすべて満たす変更に限る（MUST）。①`openspec/specs/` の既存の要件の文を、実装に合わせて直すだけである ②新しい要件を足さない・要件を消さない・要件の名前を変えない（差分は `## MODIFIED Requirements` だけで書ける） ③設計の選択が無い（直し方が 1 つに決まっている） ④直す要件が 1 つの capability の spec に収まる（差分が 1 ファイルになる）。

**当てる条件**: 記録先の受け入れ条件（issue 本文。Draft PR が記録先なら PR 本文）に「どの仕様のどの文をどう直すか」が書けていること（MUST）。直す要件ごとに、spec のパス（または capability 名）・要件名・直し方の 3 つが受け入れ条件から読み取れるときに「書けている」とする（SHALL）。書けていない変更と、対象の①〜④のどれかを満たすか迷う変更には当ててはならず（MUST NOT）、これまでどおり artifact 一式（proposal / design / tasks / specs）を作って R1 のレビューを受ける（MUST）。この扱いは interactive と unmanned で同じにする（MUST）。

**記録**: 仕様化判断のコメントの 1 行目（`^仕様化判断: (する|しない)$`）は変えてはならない（MUST NOT）。文言合わせの通し方を当てるとき、W は同じコメントの 2 行目以降に、正規表現 `^通し方: 文言合わせ$` に完全一致する行を 1 行と、直す要件ごとに `直す文: <spec のパス>「<要件名>」— <どう直すか>` の形の行を 1 行ずつ書かなければならない（MUST）。`通し方:` の行が無い「する」は、これまでどおり artifact 一式と R1 のレビューを要する判断として扱う（MUST）。

**成果物と工程**: 文言合わせの通し方では、W は `openspec new change <change-name>` のあと `openspec/changes/<change-name>/specs/<capability>/spec.md` の 1 ファイルだけを書き、proposal・design・tasks を作ってはならない（MUST NOT。`openspec new change` が作る `.openspec.yaml` は成果物に数えない）。差分は `## MODIFIED Requirements` だけを持つ（MUST）。`tasks.md` が無いので、W は作業項目と項目ごとの `触る範囲:` を (1) の return に書く（MUST）。本体は R1 を spawn してはならず（MUST NOT）、記録先に `仕様レビュー:` のコメントは投稿されない。W は R1 の APPROVE を待たずに、本体の再開指示を受けて実装に入る（SHALL）。`references/roles/worker/common.md` の「実装に入る前の確認」は、R1 の APPROVE を確認してから実装に入る規則の例外として、記録先の最新の仕様化判断のコメントに `通し方: 文言合わせ` の行があるときは APPROVE を求めないことを書かなければならない（MUST）。仕様の差分は実装後レビュー（pr-review-gate）が PR diff の一部として見る（SHALL）。

**途中で対象から外れたとき**: 仕様を書く途中か実装の途中で、対象の①〜④のどれかを満たさないと分かったら（新しい要件が要る・設計の選択が出た・2 つ以上の capability に広がった）、W は手を止めて return し、`通し方:` の行の無い仕様化判断を投稿し直してから artifact 一式を作り、R1 のレビューを受けなければならない（MUST）。R1 を一度起こした change を、あとから文言合わせの通し方に切り替えてはならない（MUST NOT）。

この判定の守備範囲は次のとおりとする。①入力の出どころは、記録先の受け入れ条件と、W が書く仕様化判断のコメントである。W は協力的だが、受け入れ条件を甘く読んで「書けている」とすることがある前提で扱う。②拾いたい誤りは、受け入れ条件に直す文が書かれていない変更に当てること、新しい要件を足す変更や設計の選択がある変更に当てること、R1 に差し戻された change を切り替えて仕様レビューを避けることである。③次はこの判定を通ることを許す: 受け入れ条件の指定があいまいで、W が「書けている」と読んだ変更。`## MODIFIED Requirements` の中で要件の文を落とす・直す範囲より広く書き換える差分（見るのは実装後レビューだけになる。主が受け入れたリスク）。R1 の差し戻しのあとの切り替え（指示書で禁じるが、機械では止めない）。④ここに挙げた以外の通り方は見つけるたびに条件を足し、穴を塞ぎ切ることを完了条件にしない。

#### Scenario: decision-criteria.md の Step B に通し方が書かれている
- **WHEN** `references/decision-criteria.md` の「Step B」の節を読む
- **THEN** 文言合わせの通し方の小節があり、成果物が仕様の差分 1 ファイルだけであること、R1 の仕様レビューを省くこと、当てる条件が「どの仕様のどの文をどう直すか」が記録先の受け入れ条件に書けていることであること、書けていなければ artifact 一式と R1 に戻すこと、`通し方: 文言合わせ` の行で記録することが書かれている

#### Scenario: worker/spec.md が同じ通し方の手順を持つ
- **WHEN** `references/roles/worker/spec.md` を読む
- **THEN** 仕様化判断のコメントの 2 行目以降に `通し方: 文言合わせ` と `直す文:` の行を書くこと、`specs/<capability>/spec.md` の 1 ファイルだけを書いて proposal・design・tasks を作らないこと、作業項目と `触る範囲:` を return に書くこと、R1 のレビューを受けずに本体の再開を待つことが書かれている

#### Scenario: spec-reviewer.md の判断記録の契約に通し方の行がある
- **WHEN** `references/roles/spec-reviewer.md` の「判断記録の契約」の節を読む
- **THEN** 表に `^通し方: 文言合わせ$` の行の規則と `直す文:` の行の形があり、この行がある判断では R1 を起こさず `仕様レビュー:` のコメントが無いことが書かれている

#### Scenario: worker/common.md の実装前の確認に例外が書かれている
- **WHEN** `references/roles/worker/common.md` の「実装に入る前の確認」の節を読む
- **THEN** R1 の APPROVE が記録されるまで実装に進まない規則と、記録先の最新の仕様化判断のコメントに `通し方: 文言合わせ` の行があるときは APPROVE を求めない例外の両方が書かれている

#### Scenario: 受け入れ条件に直す文が書かれていない
- **WHEN** 既存の要件の文言を直す変更で、記録先の受け入れ条件から spec のパス・要件名・直し方のどれかが読み取れない
- **THEN** W は `通し方:` の行を書かずに `仕様化判断: する` を記録し、artifact 一式を作って R1 のレビューを受ける

#### Scenario: 途中で新しい要件が要ると分かった
- **WHEN** 文言合わせの通し方で進めている W が、直すには新しい要件を足す必要があると分かった
- **THEN** W は手を止めて return し、`通し方:` の行の無い `仕様化判断: する` を投稿し直して artifact 一式を作り、R1 のレビューを受ける

#### Scenario: R1 に差し戻された change は切り替えない
- **WHEN** `references/roles/worker/spec.md` と `references/decision-criteria.md` の文言合わせの通し方の記述を読む
- **THEN** R1 を一度起こした change をあとから文言合わせの通し方に切り替えてはならないことが書かれている

### Requirement: 仕様レビューの BLOCKER は指摘の条件がいつ成り立つかを決めてから残す

`references/roles/spec-reviewer.md` は BLOCKER を残す前の段を持つ（MUST）。R1 は全周で、指摘の「こういう条件だと、こうなる」の条件がいつ成り立つかを決め、次の表で分ける（MUST）。分け方は `stages/triage.md` の段 B と同じとする（SHALL）。

| その条件が成り立つのは | 扱い |
|---|---|
| 条件を書けない | 捨てる。理由を 1 行残す |
| いまのエピック（無ければ記録先）の範囲で成り立つ | BLOCKER に残す |
| 後で成り立つ | NOTE に条件を書く |
| 成り立つ予定が無い | 捨てる。条件と理由を 1 行残す |
| R1 が決められない | BLOCKER に残し `条件の問い:` を添える |

#### Scenario: 段の表と根拠の規則が書かれている
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** 「条件がいつ成り立つか」の語と上の 5 行の表があり、根拠がエピックと記録先の本文・受け入れ条件・コード・`## 条件の答え` の行に限られ、`stages/triage.md` の段 B を指している

#### Scenario: 同じ枠を別アカウントで使い回す指摘は捨てる（flatmate #702）
- **WHEN** 指摘が「同じ枠を別アカウントで使い回すと、使い回したあとの使用量の帰属が分からなくなる」で、`## 条件の答え` に「新しいアカウントは新しい枠を作る。同じ枠を別アカウントで使い回さない」の行がある
- **THEN** R1 は条件が「成り立つ予定が無い」と決め、BLOCKER に残さず、結果コメントの `捨てた指摘:` の行に条件と理由を書く。ほかに BLOCKER が無ければ結果は APPROVE になる

#### Scenario: 条件を書けない指摘は捨てる
- **WHEN** 指摘の「こうなる」の条件を R1 が書けない
- **THEN** R1 はその指摘を BLOCKER に残さず、結果コメントの `捨てた指摘:` の行に理由を書く

#### Scenario: 後で成り立つ条件は BLOCKER にしない
- **WHEN** 指摘の条件が、受け入れ条件の範囲の外で、エピックの本文に後の配布として書かれた環境でだけ成り立つ
- **THEN** R1 はその指摘を BLOCKER に残さず、NOTE に成り立つ条件を書く

### Requirement: 仕様の文書そのものの欠陥は条件の段で落とさない

仕様の文書そのものの欠陥（観点 1 の Scenario の WHEN/THEN が一意に決まらない・観点 2 の既存 spec と衝突する・観点 4 の前提環境が書かれていない・観点 5 の artifact どうしが食い違う・観点 6 の守備範囲の段落が欠ける）は、この change を実装するときに必ず成り立つので、「いまの範囲で成り立つ」に当たる（MUST）。この列挙は網羅であり、ここに無い指摘は表に通す（MUST）。観点 3 の指摘は条件（別の環境で動かす）を持つので表に通す（MUST）。

#### Scenario: 文書そのものの欠陥は条件の段で落ちない
- **WHEN** delta spec の検査系の要件に守備範囲の段落が無い
- **THEN** R1 はこの欠陥を「いまの範囲で成り立つ」に当てて BLOCKER に残し、`REQUEST_CHANGES` を返す

### Requirement: 条件の段の根拠はエピックと記録先の本文・受け入れ条件・コード・条件の答えに限る

R1 が自分で決めるときの根拠は、エピックと記録先の本文、受け入れ条件、コード、本文の節 `## 条件の答え` の行に限る（MUST）。change の artifact に書かれた想定は主の答えではないので、根拠にしてはならない（MUST NOT）。節に答えの行があるのに条件が決まらないときは、問いを付け直さず「いまの範囲で成り立つ」に当てる（MUST）。

#### Scenario: artifact の想定を根拠にしない
- **WHEN** 成り立たない根拠が change の design.md の想定にしか書かれていない
- **THEN** R1 はその想定を根拠にせず、「R1 が決められない」に当てる

### Requirement: R1 が決められない条件は問いとして返す

`条件の問い:` の行は条件についての問いにし、指摘を直すか・捨ててよいかを問うてはならない（MUST NOT）。R1 は読み取り専用のままとし、問いを主に聞かず、`## 条件の答え` を書かず、issue を作らない（MUST NOT）。

#### Scenario: 運用が根拠に書かれていなければ条件を問う
- **WHEN** 同じ指摘で、エピックと記録先の本文・受け入れ条件・コード・`## 条件の答え` のどこにも、同じ枠を別アカウントで使い回すかが書かれていない
- **THEN** R1 はその指摘を BLOCKER に残し、`条件の問い:` の行に「同じ枠を別アカウントで使い回すことは、今回あるか。今回は無くても後であるか」の形の問いを添える

### Requirement: 本体は条件の答えを R1 の依頼文に入れる

本体は R1 を起こすとき（当て直しを含む）、エピックの本文（エピックの子でなければ記録先の本文）の節 `## 条件の答え` の行を依頼文に入れなければならない（MUST。経路によらない）。`dev-workflow:decider` で起こす経路では、エピックの本文も入力文に貼らなければならない（MUST）。

#### Scenario: 条件の答えが依頼文に入る
- **WHEN** 本体が記録先のエピックの本文に節 `## 条件の答え` がある状態で R1 を起こす
- **THEN** R1 の依頼文に節の行があり、`general-purpose` の経路でも `dev-workflow:decider` の経路でも同じである

### Requirement: R1 の結果に条件の判定と捨てた指摘を書く

結果の書式は、残した BLOCKER ごとに条件と、成り立つ判定と、根拠を書く形にする（MUST。問いの添えられた指摘は根拠の代わりに `条件の問い:` を書く）。捨てた指摘は、結果コメントの 2 行目以降に `捨てた指摘:` の行で書く（MUST）。この行は周回数や残課題と同じ本文の中身で、照合に使わない（SHALL）。

#### Scenario: 結果の書式が書かれている
- **WHEN** `references/roles/spec-reviewer.md` の出力書式と結果の記録の節を読む
- **THEN** BLOCKER ごとに条件・成り立つ判定・根拠を書くことと、`捨てた指摘:` の行を結果コメントに書くことが書かれている

### Requirement: 条件の段の守備範囲

`references/roles/spec-reviewer.md` は条件の段の守備範囲を書かなければならない（MUST）。この段の守備範囲は、起きる予定の無い場面への指摘が BLOCKER のまま残り、周回と主への確認を増やすことを防ぐことである。想定する入力の出どころは R1 自身が見つけた指摘で、拾いたい誤りは、運用上成り立たない条件や書けない条件で実装を止めることである。通ることを許す入力の例として、根拠の範囲では決められない条件は BLOCKER に残り、R1 が根拠を読み違えて「いまの範囲で成り立つ」と判定した指摘もそのまま残る（後者は直し方の判定と主の答えで拾う）。判定の誤りが 1 件も無いことをこの段の完了条件にしない。

#### Scenario: 守備範囲が書かれている
- **WHEN** `references/roles/spec-reviewer.md` の条件の段の節を読む
- **THEN** 守備範囲として、指摘の出どころ・拾いたい誤り・通すことを許す例・判定の誤りが 1 件も無いことを完了条件にしないことが書かれている
