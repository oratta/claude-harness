## MODIFIED Requirements

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
