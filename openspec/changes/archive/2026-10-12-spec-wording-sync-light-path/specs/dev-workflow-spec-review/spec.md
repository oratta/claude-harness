## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: 書いた仕様は実装前に別コンテキストがレビューする
develop スキルは、仕様化経路で、W が openspec CLI（`openspec new change` と artifact の直書き）で artifact を生成して return した直後・W を再開して実装に着手する前に、本体が spawn する R1（`references/roles/spec-reviewer.md` を読む、実装と別コンテキストのサブエージェント）による仕様レビューを挟まなければならない（MUST）。本体や主が W の起動前に `/opsx:ff` などで change を作っていた場合も、W がそれを確かめて return したあと同じ仕様レビューを挟む（SHALL）。レビューの入力は change ディレクトリの artifact・記録先の受け入れ条件・関連する既存 `openspec/specs/`（`grep` で当たりを付けた範囲）とし（MUST）、観点・出力書式は `references/roles/spec-reviewer.md` を正本とする（SHALL）。R1 が `APPROVE` を返し記録されるまで W を実装に進めてはならない（MUST NOT）。

例外は文言合わせの通し方（「仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く」Requirement）だけとする（MUST）。記録先の最新の仕様化判断のコメントに `^通し方: 文言合わせ$` に完全一致する行があるとき、本体は R1 を spawn せず、W を実装に進める（SHALL）。本体は W の return の文面ではなく、記録先のコメントでこの行を確かめなければならない（MUST）。行が無ければ R1 を挟む（MUST）。

#### Scenario: 1 ループにレビューが挟まっている
- **WHEN** SKILL.md の 1 ループを読む
- **THEN** W の change の作成（`openspec new change`）と W の再開（実装）の間に R1 の仕様レビューがあり、`references/roles/spec-reviewer.md` を参照し、APPROVE の記録まで実装に進まない旨が書かれている

#### Scenario: worker.md の仕様化の節にもレビューがある
- **WHEN** `references/roles/worker.md` の仕様化する場合の節を読む
- **THEN** `openspec new change` と artifact の直書きの後に本体へ return して仕様レビューを受けることと、R1 の APPROVE が記録されるまで実装に進まないことが書かれている

#### Scenario: 文言合わせの通し方では R1 を挟まない
- **WHEN** 記録先の最新の仕様化判断のコメントが 1 行目 `仕様化判断: する` で、2 行目以降に `通し方: 文言合わせ` の行を持つ
- **THEN** 本体は R1 を spawn せず、記録先のコメントでその行を確かめたうえで W を `段: implement` で再開する

#### Scenario: 通し方の行が無ければ R1 を挟む
- **WHEN** W が「文言合わせで進める」と return したが、記録先の最新の仕様化判断のコメントに `通し方: 文言合わせ` の行が無い
- **THEN** 本体は W を実装に進めず、W を `段: spec` で再開して仕様化判断を投稿し直させる
