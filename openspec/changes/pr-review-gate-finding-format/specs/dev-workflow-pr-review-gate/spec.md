## ADDED Requirements

### Requirement: レビュアーの指摘に固定書式を課す

SKILL.md 手順 2-1 は、レビュアー（Codex CLI・Task サブエージェント）が書く指摘 1 件ごとの固定書式を規定しなければならない（MUST）。各指摘は次のフィールドを持つ（MUST）: 見出し（命令形 1 行・80 字以内）、深刻度（`blocking` / `should` / `nit`）、検証（`confirmed`＝実行・テストで裏取り済み / `plausible`＝推測・未検証）、根拠（深刻度が `blocking` のとき必須。記録先の受け入れ条件または PR が触れる openspec spec の原文の引用、または例外 3 種＝安全機構の穴・データ破壊・無言の機能不全のどれに当たるか）、場所（`file:line-range`、diff と重なる範囲で 10 行以内）、何が起きるか（入力・状態と誤動作、発生条件）、直し方（行レベルの置換コードか 3 行以内の手順で、そのとおりに直せば指摘が閉じるもの）。再レビューでは各指摘に状態（`fixed` / `unresolved` / `wontfix`）を足す（MUST）。

SKILL.md は深刻度 3 値の定義表を持たなければならない（MUST）: `blocking` は受け入れ条件または仕様の文に違反しマージすると壊れるもの、`should` は直すべきだがマージ後に issue で直せるもの、`nit` は好み・スタイル。

書式と深刻度の定義表は SKILL.md 手順 2-1 に 1 か所だけ置き（MUST）、レビュアーへの指示文に貼り付けられるブロックの形にする（MUST）。他のファイルは書式を再掲せず、このブロックを参照する（MUST NOT 再掲）。

#### Scenario: 書式の見出し語と深刻度 3 値がある

- **WHEN** SKILL.md 手順 2-1 を読む
- **THEN** 深刻度・検証・根拠・場所・何が起きるか・直し方の各欄と、`blocking` / `should` / `nit` の定義表がある

#### Scenario: 再レビューの状態欄がある

- **WHEN** SKILL.md の固定書式を読む
- **THEN** 再レビュー時に各指摘へ `fixed` / `unresolved` / `wontfix` の状態を足すことが書かれている

### Requirement: マージを止めるかの判定は全周共通にする

SKILL.md は、指摘がマージを止めるかどうかの判定を 1 か所に書かなければならない（MUST）。判定は全周（1 周目・2 周目・主の続行指示で開いた周）で同じでなければならない（MUST）: マージを止めるのは、深刻度が `blocking` で、根拠の引用を G が記録先の受け入れ条件または PR が触れる openspec spec（delta spec を含む）の原文と照合できた（または根拠が例外 3 種＝安全機構の穴・データ破壊・無言の機能不全に当たる）、かつ検証が `confirmed` の指摘だけとする。それ以外の指摘（`should`・`nit`・`plausible`・照合できない `blocking`）はマージを止めず、follow-up issue に回す（MUST）。レビュアーが付けた深刻度ラベルは参考にとどめ、G の照合を判定の根拠とする（MUST）。

周によって変わるのは、止める指摘が残ったときの動き方だけでなければならない（MUST）: 1 周目は `agent-review:failed` に付け替えて W が直す。2 周目と主の続行指示で開いた周は、収束ルールの「2 周目の終わりにやること」に従い `needs-approval` で止まる。SKILL.md は「一般則は 1 周目に適用し、2 周目からは収束ルールが優先する」のような、周によって判定を分ける記述を持ってはならない（MUST NOT）。

1 周目で failed にするとき、止めない指摘は failed の PR コメントに一覧で残し、follow-up issue はまだ切らない（SHALL）。follow-up issue は G が手順 3 へ進む時点で、未解決の止めない指摘について切り、URL を PR コメントに記録する（MUST）。

#### Scenario: 1 周目に should と plausible だけが残る

- **WHEN** 1 周目のレビューが `should` の指摘と `plausible` の `blocking` 指摘だけを返す
- **THEN** G は failed にせず、各指摘を follow-up issue に切って URL を PR コメントに記録し、手順 3 以降へ進む

#### Scenario: 1 周目に止める指摘がある

- **WHEN** 1 周目のレビューが、受け入れ条件の文を引用した `confirmed` の `blocking` 指摘を 1 件返す
- **THEN** G は `agent-review:failed` に付け替えて修正サイクルへ戻す

#### Scenario: 引用できない安全機構の穴

- **WHEN** 受け入れ条件と spec のどの文も引用できないが、根拠が安全機構の穴に当たり検証が `confirmed` の `blocking` 指摘が残る
- **THEN** その指摘はマージを止める指摘として扱われる

#### Scenario: 周ごとに判定を分ける文が残っていない

- **WHEN** SKILL.md を読む
- **THEN** 「この一般則は1周目に適用する」の文は無く、判定は 1 か所に書かれ、収束ルールの仕分けはその判定を参照している

### Requirement: レビュアーへの指示に全件列挙と再レビューの制限を含める

SKILL.md 手順 2-1 のレビュアー向け指示ブロックは、次を含まなければならない（MUST）: 1 周目は対象範囲に該当する指摘を全部列挙するまで止まらないこと。差分限定の再レビューは前回指摘の閉鎖確認（状態欄の付与）に限り、新規の指摘を出さないこと。方式の書き換え後の全体レビューでも、新規に出してよい深刻度は `blocking` だけであること。前回の「直し方」どおりに直した箇所を再指摘しないこと（直し方自体が誤っていた場合はレビュアー側の誤りとして `wontfix` 相当の記録にする）。

#### Scenario: 全件列挙の 1 文がある

- **WHEN** SKILL.md のレビュアー向け指示ブロックを読む
- **THEN** 「該当する指摘を全部列挙するまで止まらない」旨の 1 文がある

#### Scenario: 再レビューで新規 nit を出さない

- **WHEN** SKILL.md のレビュアー向け指示ブロックを読む
- **THEN** 再レビューでは新規の `nit` を出さず、全体レビューに戻っても新規に出してよいのは `blocking` だけと書かれている

### Requirement: Codex 経路と Task サブエージェント経路で同じ書式を渡す

`references/subagent-waiting.md` の Codex 指示文の雛形は、SKILL.md 手順 2-1 のレビュアー向け指示ブロックを貼ることの指示と、「該当する指摘を全部列挙するまで止まらない」の 1 文を含まなければならない（MUST）。`skills/develop/references/roles/gate-runner.md` の needs-reviewer の return payload は、レビュアーに渡す指示として同じブロックを指定する行を持たなければならない（MUST）。どちらも書式の欄や深刻度の定義を再掲してはならない（MUST NOT）。

#### Scenario: Codex の雛形が書式を要求する

- **WHEN** `subagent-waiting.md` の指示文雛形を読む
- **THEN** SKILL.md 手順 2-1 のブロックを貼る指示と全件列挙の 1 文がある

#### Scenario: needs-reviewer が書式を渡す

- **WHEN** gate-runner.md の needs-reviewer の payload を読む
- **THEN** レビュアーに渡す指示として SKILL.md 手順 2-1 のブロックを指定する行がある

### Requirement: codex exec でのルーブリック適用を実測して分岐する

この change の実装は、`codex exec` 直叩き（書式を指定しない指示文）で Codex 公式レビュールーブリック（`[P0]`〜`[P3]` の見出し・`priority`・`confidence_score`）が出力に適用されるかを実測し、結果を PR コメントに残さなければならない（MUST）。適用されない場合は、指示文に固定書式を書く経路（前の Requirement）だけで足りる。適用される場合は、SKILL.md に Codex の JSON（`priority` / `confidence_score` / `code_location`）から固定書式への対応表を置かなければならない（MUST）。どちらの場合も `confidence_score` を `confirmed` の代わりにしてはならない（MUST NOT）。

#### Scenario: 適用されない

- **WHEN** 実測で、出力に `[P0]`〜`[P3]`・`priority`・`confidence_score` のどれも現れない
- **THEN** 実測結果が PR コメントにあり、SKILL.md に対応表は無く、指示文の雛形が書式ブロックを要求している

#### Scenario: 適用される

- **WHEN** 実測で、出力にルーブリックの優先度または確信度が現れる
- **THEN** 実測結果が PR コメントにあり、SKILL.md に Codex の JSON から固定書式への対応表がある

### Requirement: 合格条件に判定を明記する

SKILL.md 手順 5 は、合格処理の前提として、最後のレビュー結果にマージを止める指摘（全周共通の判定で止まるもの＝`blocking` かつ `confirmed`）が 0 件であることを書かなければならない（MUST）。

#### Scenario: 手順 5 の合格条件

- **WHEN** SKILL.md 手順 5 を読む
- **THEN** 「`blocking` かつ `confirmed` が 0 件」であることが合格処理の条件として書かれている

### Requirement: レビュアーの要約受領の分岐を 1 か所に置く

`skills/develop/references/roles/gate-runner.md` は、レビュアーの要約を受け取ったときの分岐を再開節の「レビュアーの要約受領」の 1 か所に書かなければならない（MUST）。needs-reviewer 節は「レビュー実行者:」コメントの投稿を規定したうえで、以降の分岐はその再開節の記述に従うと参照し、無条件に「手順 3 以降を続ける」と指示してはならない（MUST NOT）。再開節の分岐は、指摘が無ければ手順 3 以降、指摘が残れば全周共通の判定を通し、止める指摘が無ければ follow-up issue に切って手順 3 以降、止める指摘があれば 1 周目は failed、2 周目と主の続行指示で開いた周は収束ルールの仕分けを記録して保留、とする（MUST）。

#### Scenario: needs-reviewer 節に無条件の継続指示が無い

- **WHEN** `grep -n "手順 3 以降を続ける" gate-runner.md` を実行する
- **THEN** 無条件の継続指示が返らない

#### Scenario: 2 周目に止める指摘が needs-reviewer 経路で残る

- **WHEN** 本体が spawn したレビュアーの 2 周目の要約に、止める指摘が 1 件残る
- **THEN** G は再開節の分岐に従って仕分けを PR コメントに記録し、Status を保留として return する

## MODIFIED Requirements

### Requirement: 2 周目終了時に残った指摘を違反文の引用で仕分ける

SKILL.md は、2 周目のレビュー結果を受け取った直後に、ゲート実行者（G。G を使わない運用ではゲートを回す側）が残った指摘ごとに「受け入れ条件または仕様の守備範囲のどの文に違反するか」を原文の引用で示す手順を規定しなければならない（MUST）。実行者（誰が）と時点（2 周目の結果を受け取った直後）を明記する（MUST）。指摘がマージを止めるかどうかは「マージを止めるかの判定は全周共通にする」Requirement の判定で決め、仕分けの手順は判定の文を言い換えて再掲せず参照する（MUST）。レビュアー（Codex・Task サブエージェント）が付けた深刻度ラベルは参考にとどめ、判定の根拠にしてはならない（MUST NOT）。引用元は記録先（issue または Draft PR 本文）の受け入れ条件と、この PR が触れる openspec の spec（change の delta spec を含む）に限る（MUST）。仕分けの結果（指摘ごとの引用・例外 3 種のどれか、または「引用なし」）は PR コメントに記録する（MUST）。PR が openspec に触れず記録先にも受け入れ条件の文が無いなど引用元が無いときは、G は引用元を広げず、残った指摘を全件「引用なし」として扱う（MUST）。

#### Scenario: 引用の実行者と時点が書かれている

- **WHEN** SKILL.md の収束ルールを読む
- **THEN** 2 周目の結果を受け取った直後に G が指摘ごとに違反文を引用すること、深刻度ラベルは参考にとどめること、止めるかどうかは全周共通の判定を参照することが書かれている

#### Scenario: 深刻度が高くても引用できなければ blocking にしない

- **WHEN** 2 周目に「高」の深刻度ラベルが付いた指摘が残り、受け入れ条件と spec のどの文にも違反を引用できず、例外 3 種にも当たらない
- **THEN** その指摘はマージを止める指摘として扱われず、follow-up issue 化に回る

### Requirement: 引用できない指摘は follow-up issue に切って passed の判定へ進む

SKILL.md は、2 周目終了時に全周共通の判定でマージを止めない指摘（違反文を引用できず例外 3 種にも当たらないもの、`plausible` のもの、`should`・`nit`）を follow-up issue に切り出し、その issue の URL を仕分けの PR コメントに記録したうえで、手順 3 以降（`passed` の判定）へ進むことを規定しなければならない（MUST）。止めない指摘を理由に 3 周目を開けてはならない（MUST NOT）。

#### Scenario: 残った指摘がすべて引用できない

- **WHEN** 2 周目終了時に残った指摘のどれにも違反文を引用できず、例外 3 種にも当たらない
- **THEN** G は各指摘を follow-up issue に切り、URL を PR コメントに記録し、3 周目に入らず手順 3 以降へ進む

### Requirement: 引用できる指摘が残ったら 3 周目に入らず主に上げる

SKILL.md は、2 周目終了時に全周共通の判定でマージを止める指摘が 1 件でも残った場合、3 周目に入らず、PR に `needs-approval` を付けて止まり、主に「続けるか、範囲外として閉じるか」の 1 択を出すことを規定しなければならない（MUST）。主への依頼には、引用した違反文（または例外 3 種のどれか）と対応する指摘を含める（MUST）。G や本体が自動で 3 周目を開けてはならない（MUST NOT）。この停止は無人運用（loop-dev-agent）でも同じく適用する（MUST）。3 周目は主が「続ける」と答えた場合にだけ開く（MUST）。主の続行指示で開いた周の終了時にも同じ仕分けを適用し、止める指摘が残れば再び `needs-approval` で止まる（MUST。主の回答なしに次の周へ進まない）。

SKILL.md 手順 6 の復帰表は、保留の種類として「2 周目キャップ」の行を持たなければならない（MUST）。その行は主の回答ごとに次を規定し、どちらの回答でも `needs-approval` を外すことを明示する（MUST）: 主が「続ける」と答えたら、主の回答リンクを PR コメントに記録し、`needs-approval` を外して `agent-review:failed` に付け替え、修正サイクルに戻して周回 3 以降に入る。主が「範囲外として閉じる」と答えたら、引用できた指摘も follow-up issue に切って URL を PR コメントに記録し、`needs-approval` を外して手順 3 以降へ進む。

#### Scenario: 引用できる指摘が 1 件残る

- **WHEN** 2 周目終了時に、受け入れ条件の 1 文に違反すると引用できる `confirmed` の `blocking` 指摘が 1 件残る
- **THEN** G は 3 周目に入らず `needs-approval` を付け、引用と指摘を添えて主に「続けるか、範囲外として閉じるか」を依頼し、Status を保留として return する

#### Scenario: 主が続けると答えた

- **WHEN** 2 周目キャップで保留中の PR に、主が「続ける」と回答する
- **THEN** G は回答リンクを PR コメントに記録し、`needs-approval` を外して `agent-review:failed` に付け替え、周回 3 として修正サイクルに戻す

#### Scenario: 主が範囲外として閉じると答えた

- **WHEN** 2 周目キャップで保留中の PR に、主が「範囲外として閉じる」と回答する
- **THEN** G は引用できた指摘も follow-up issue に切って URL を PR コメントに記録し、`needs-approval` を外して手順 3 以降へ進む

#### Scenario: 続行指示で開いた周の終わりにも止まる

- **WHEN** 主の続行指示で開いた 3 周目が終わり、止める指摘が残る
- **THEN** G は同じ仕分けを適用して再び `needs-approval` を付けて止まり、主の回答なしに 4 周目へ進まない

#### Scenario: 無人運用でも止まる

- **WHEN** loop-dev-agent の無人運用中に、2 周目終了時に止める指摘が残る
- **THEN** 対話運用と同じく `needs-approval` を付けて止まり、3 周目を自動で開けない
