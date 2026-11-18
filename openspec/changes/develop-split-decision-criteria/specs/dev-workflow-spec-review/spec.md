## MODIFIED Requirements

### Requirement: 仕様化要否の判定結果を固定書式で issue に記録する
develop スキルの W の指示書（`references/roles/worker/spec.md`。記録する前に実装へ進まない規則は `references/roles/worker/common.md`「実装に入る前の確認」）は、仕様化要否を判定した直後に、その結果を記録先（元 issue。issue が無い場合は Draft PR）のコメントとして記録する手順を明記しなければならない（MUST）。コメントの 1 行目は正規表現 `^仕様化判断: (する|しない)$` に完全一致し（装飾・全角コロン・末尾句点を含めない）（MUST）、2 行目以降に判定理由（`references/spec-decision.md` のどの条件に当たったか）を書く（MUST）。同接頭辞のコメントが複数あるときは作成日時が最新の 1 件を正とし（SHALL）、この記録は interactive / unmanned の両モードで行い（MUST）、記録せずに分割判定・実装へ進んではならない（MUST NOT）。後続の照合で PR から元 issue を解決する規則（PR 本文中で最初に現れる `Closes #N` / `Fixes #N` / `Refs #N`、大文字小文字不問。見つからなければ PR 自身のコメントを見る）は `references/roles/spec-reviewer.md` の「判断記録の契約」に定義する（SHALL）。

#### Scenario: worker/spec.md に記録手順と正規表現がある
- **WHEN** `references/roles/worker/spec.md` の仕様化判断の節を読む
- **THEN** `^仕様化判断: (する|しない)$` の書式と、`gh` で記録先にコメントする手順、記録前に先へ進まない旨が書かれている

#### Scenario: unmanned でも免除されない
- **WHEN** SKILL.md の実行モード表または unmanned に関する記述を読む
- **THEN** 判定記録が unmanned でも必須であることが書かれている

#### Scenario: 複数記録時の選択規則と PR→issue の解決規則がある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** 同接頭辞のコメントが複数あるときは最新 1 件を正とする規則と、PR 本文の最初の `Closes` / `Fixes` / `Refs #N` で元 issue を解決し、無ければ PR 自身のコメントを見る規則が書かれている

### Requirement: 仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く
develop スキルは、仕様化判断が「する」になった変更のうち、既存の仕様の文言を実装に合わせて直すだけの変更に、成果物を仕様の差分 1 ファイルだけにして R1 の仕様レビューを省く通し方（以下「文言合わせの通し方」）を持たなければならない（MUST）。対象・当てる条件・省くものの正本は `references/spec-decision.md` の Step B に置き（MUST）、W の手順は `references/roles/worker/spec.md` に、記録の書式は `references/roles/spec-reviewer.md` の「判断記録の契約」に置く（MUST）。対象・当てる条件の正本は `spec-decision.md`、記録の書式の正本は `spec-reviewer.md` とし、`worker/spec.md` は正本を指して要約だけを書く。要約が正本と食い違ってはならない（MUST NOT）。

**対象**: 次をすべて満たす変更に限る（MUST）。①`openspec/specs/` の既存の要件の文を、実装に合わせて直すだけである ②新しい要件を足さない・要件を消さない・要件の名前を変えない（差分は `## MODIFIED Requirements` だけで書ける） ③設計の選択が無い（直し方が 1 つに決まっている） ④直す要件が 1 つの capability の spec に収まる（差分が 1 ファイルになる）。

**当てる条件**: 記録先の受け入れ条件（issue 本文。Draft PR が記録先なら PR 本文）に「どの仕様のどの文をどう直すか」が書けていること（MUST）。直す要件ごとに、spec のパス（または capability 名）・要件名・直し方の 3 つが受け入れ条件から読み取れるときに「書けている」とする（SHALL）。書けていない変更と、対象の①〜④のどれかを満たすか迷う変更には当ててはならず（MUST NOT）、これまでどおり artifact 一式（proposal / design / tasks / specs）を作って R1 のレビューを受ける（MUST）。この扱いは interactive と unmanned で同じにする（MUST）。

**記録**: 仕様化判断のコメントの 1 行目（`^仕様化判断: (する|しない)$`）は変えてはならない（MUST NOT）。文言合わせの通し方を当てるとき、W は同じコメントの 2 行目以降に、正規表現 `^通し方: 文言合わせ$` に完全一致する行を 1 行と、直す要件ごとに `直す文: <spec のパス>「<要件名>」— <どう直すか>` の形の行を 1 行ずつ書かなければならない（MUST）。`通し方:` の行が無い「する」は、これまでどおり artifact 一式と R1 のレビューを要する判断として扱う（MUST）。

**成果物と工程**: 文言合わせの通し方では、W は `openspec new change <change-name>` のあと `openspec/changes/<change-name>/specs/<capability>/spec.md` の 1 ファイルだけを書き、proposal・design・tasks を作ってはならない（MUST NOT。`openspec new change` が作る `.openspec.yaml` は成果物に数えない）。差分は `## MODIFIED Requirements` だけを持つ（MUST）。`tasks.md` が無いので、W は作業項目と項目ごとの `触る範囲:` を (1) の return に書く（MUST）。本体は R1 を spawn してはならず（MUST NOT）、記録先に `仕様レビュー:` のコメントは投稿されない。W は R1 の APPROVE を待たずに、本体の再開指示を受けて実装に入る（SHALL）。`references/roles/worker/common.md` の「実装に入る前の確認」は、R1 の APPROVE を確認してから実装に入る規則の例外として、記録先の最新の仕様化判断のコメントに `通し方: 文言合わせ` の行があるときは APPROVE を求めないことを書かなければならない（MUST）。仕様の差分は実装後レビュー（pr-review-gate）が PR diff の一部として見る（SHALL）。

**途中で対象から外れたとき**: 仕様を書く途中か実装の途中で、対象の①〜④のどれかを満たさないと分かったら（新しい要件が要る・設計の選択が出た・2 つ以上の capability に広がった）、W は手を止めて return し、`通し方:` の行の無い仕様化判断を投稿し直してから artifact 一式を作り、R1 のレビューを受けなければならない（MUST）。R1 を一度起こした change を、あとから文言合わせの通し方に切り替えてはならない（MUST NOT）。

この判定の守備範囲は次のとおりとする。①入力の出どころは、記録先の受け入れ条件と、W が書く仕様化判断のコメントである。W は協力的だが、受け入れ条件を甘く読んで「書けている」とすることがある前提で扱う。②拾いたい誤りは、受け入れ条件に直す文が書かれていない変更に当てること、新しい要件を足す変更や設計の選択がある変更に当てること、R1 に差し戻された change を切り替えて仕様レビューを避けることである。③次はこの判定を通ることを許す: 受け入れ条件の指定があいまいで、W が「書けている」と読んだ変更。`## MODIFIED Requirements` の中で要件の文を落とす・直す範囲より広く書き換える差分（見るのは実装後レビューだけになる。主が受け入れたリスク）。R1 の差し戻しのあとの切り替え（指示書で禁じるが、機械では止めない）。④ここに挙げた以外の通り方は見つけるたびに条件を足し、穴を塞ぎ切ることを完了条件にしない。

#### Scenario: decision-criteria.md の Step B に通し方が書かれている
- **WHEN** `references/spec-decision.md` の「Step B」の節を読む
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
- **WHEN** `references/roles/worker/spec.md` と `references/spec-decision.md` の文言合わせの通し方の記述を読む
- **THEN** R1 を一度起こした change をあとから文言合わせの通し方に切り替えてはならないことが書かれている

### Requirement: 些細な修正は軽い通し方で新しいテストと W の起動を省く
develop スキルは、仕様化判断が「しない」になる変更のうち、typo・lint 指摘の修正・コメントの修正・フォーマットの変更・ワンライナー fix・挙動を変えない設定値の変更のどれか 1 種類だけでできていて、既存のテストかチェックのコマンドで確かめられる変更に、新しいテストの作成と W の起動を省く通し方（以下「軽い通し方」）を持たなければならない（MUST）。記録先・仕様化判断の記録・pr-review-gate は省いてはならない（MUST NOT）。当てる条件・省くもの・残すものの正本は `references/light-path.md` に置き（MUST）、記録の書式の正本は `references/roles/spec-reviewer.md` の「判断記録の契約」に置く（MUST）。

#### Scenario: Step B に軽い通し方の小節がある
- **WHEN** `references/light-path.md` を読む
- **THEN** 「仕様化しない（コード直行）」の小節と同じ並びに軽い通し方の小節があり、当てる条件（6 種類のどれか 1 つだけ・既存のテストかチェックで確かめられる）・省くもの（新しいテストの作成と W の起動）・残すもの（記録先・判断の記録・pr-review-gate）の 3 点が書かれている

#### Scenario: 6 種類に入らない「しない」の変更には当てない
- **WHEN** 変更が振る舞いの変わらない内部リファクタ、依存の版上げ、または受け入れ条件が明記された機械的な振る舞い変更である
- **THEN** 軽い通し方は当たらず、これまでどおり W を起こし、テストを書く

#### Scenario: 確かめる既存のチェックが無い変更には当てない
- **WHEN** 変更は typo の修正だけだが、変更を確かめる既存のテストもチェックのコマンドも無い
- **THEN** 軽い通し方は当たらず、これまでどおり W を起こし、テストを書く

### Requirement: テスト作成の必須の例外は軽い通し方だけにする
`references/spec-decision.md` の「どの判定でも変えないもの」は、テスト作成が必須であることを残したうえで、例外が軽い通し方だけであることと、軽い通し方では `確かめ方:` の既存のテストかチェックを走らせることが新しいテストの代わりになることを書かなければならない（MUST）。W が起こされる経路では、どの判定でもテスト作成を省いてはならない（MUST NOT）。

#### Scenario: 必須の行に例外が書かれている
- **WHEN** `references/spec-decision.md` の「どの判定でも変えないもの」を読む
- **THEN** 「テスト作成は全経路で必須」の文と同じ段落に、例外が軽い通し方だけであることと、`確かめ方:` のコマンドを走らせることが代わりになることが書かれている

### Requirement: 軽い通し方では本体が直し、仕様宣言までを行ってから G を起こす
軽い通し方では、本体は (1)〜(3) の W を起こさず、判断の記録のあとに自分で直し、`確かめ方:` のコマンドを走らせて終了コード 0 を確かめ、commit・push し、PR を Draft のまま用意し（issue が記録先なら `Closes #<issue>` を本文に書く）、仕様宣言を「変更なし＋理由」形で投稿してから、unmanned を除き (4) の G を起こさなければならない（MUST）。unmanned では G を起こさず `agent-review:pending` を付けてサイクルを終えなければならない（MUST）。手順の正本は `references/light-path.md` に置く（MUST）。

#### Scenario: 本体の手順が書かれている
- **WHEN** `references/light-path.md` を読む
- **THEN** 判断の記録・直す・`確かめ方:` のコマンドを走らせる・commit と push・Draft の PR・「変更なし＋理由」形の仕様宣言・G を起こす、の順の手順が書かれている

### Requirement: 軽い通し方はどのモードでも同じ条件で当て、迷ったら当てない
本体は、W を `段: spec` で起こす前に、記録先の本文（記録先がまだ無い会話の依頼では、本体が依頼から整理した受け入れ条件）から軽い通し方を当てるかを決めなければならない（MUST）。当てるか迷ったら当ててはならず（MUST NOT）、これまでどおり W を起こす。当てるかどうかを主に聞いてはならない（MUST NOT）。interactive・channel・unmanned で同じ条件を使い（SHALL）、unmanned では本体が Draft PR の作成と `agent-review:pending` の付与を行う（SHALL）。

#### Scenario: 迷ったら W を起こす
- **WHEN** 本体が、変更が 6 種類のどれか 1 つに収まるか、既存のチェックで確かめられるかを決めきれない
- **THEN** 本体は主に聞かず、軽い通し方を当てずに W を `段: spec` で起こす

#### Scenario: unmanned でも同じ条件で当たる
- **WHEN** `references/light-path.md` を読む
- **THEN** interactive・channel・unmanned で同じ条件を使うことと、unmanned では本体が Draft PR の作成と `agent-review:pending` の付与を行うことが書かれている
