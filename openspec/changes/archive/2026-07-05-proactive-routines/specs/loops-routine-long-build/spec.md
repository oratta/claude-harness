# loops-routine-long-build Specification (Delta)

## ADDED Requirements

### Requirement: 長期ビルドルーチンのレシピが固定見出し規約に従って存在する

`plugins/loops/recipes/routine-long-build.md` が存在しなければならない (MUST)。レシピは change-1 のレシピ形式規約の固定見出し 7 節（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）をすべて含み、ループ型はプロアクティブと明記すること。前提節には `{longrun-dir}/feature-list.json` と `claude-progress.md` の存在を記載し、起動コマンド節はネイティブプリミティブ（/schedule または手動再起動 + /goal）のみで構成すること。独自の常駐スクリプト・カスタム driver を参照してはならない (MUST NOT)。

#### Scenario: レシピファイルが固定見出しを全て持つ

- **WHEN** `plugins/loops/recipes/routine-long-build.md` に対して固定見出し 7 節を grep する
- **THEN** 7 節すべてがヒットし、ループ型節にプロアクティブの記載がある

#### Scenario: 前提節が外部状態ファイルを宣言している

- **WHEN** レシピの前提節を検査する
- **THEN** feature-list.json と claude-progress.md（progress notes）の 2 つの外部状態ファイルへの言及がある

#### Scenario: 起動コマンドがネイティブプリミティブのみである

- **WHEN** レシピの起動コマンド節を検査する
- **THEN** /schedule または手動再起動 + /goal によるコピペ可能なコマンド文字列が存在し、独自 driver スクリプトへの参照は現れない

### Requirement: 1 サイクルは 1 項目のみ実装する

レシピの 1 サイクル手順は「smoke check（直近 passing 項目の verification 再実行）→ `passes:false` の先頭 1 項目のみ実装 → evidence 確認後の `passes:true` 更新 → 説明的 commit → progress 追記」の順序で定義しなければならない (MUST)。1 サイクルで複数項目を実装する手順を含めてはならない (MUST NOT)。

#### Scenario: 1 サイクル 1 項目が明記されている

- **WHEN** レシピの 1 サイクル手順を検査する
- **THEN** `passes:false` の先頭 1 項目のみを実装対象とする旨が明記され、複数項目の同時実装を認める記載がない

#### Scenario: サイクルは smoke check から始まる

- **WHEN** レシピの 1 サイクル手順の先頭ステップを検査する
- **THEN** 直近 passing 項目の verification コマンド再実行（smoke check）が実装ステップより前に置かれている

#### Scenario: サイクルは commit と progress 追記で終わる

- **WHEN** レシピの 1 サイクル手順の末尾を検査する
- **THEN** 説明的 commit と claude-progress.md への追記が passes 更新の後に置かれている

### Requirement: passes:true への更新は verification コマンドの exit 0 evidence がある場合のみ許可する

レシピは、feature-list の項目を `passes:true` に更新できる条件を「当該項目の verification コマンドを実行し exit 0 の evidence（実行ログ）がある場合のみ」と明記しなければならない (MUST)。evidence なしの自己申告更新の禁止をルーチンプロンプト（発火時に投入するプロンプト本文）に含めること (MUST)。

#### Scenario: evidence 必須の passes 更新条件が記載されている

- **WHEN** レシピの passes 更新手順を検査する
- **THEN** verification コマンドの exit 0 evidence がある場合のみ `passes:true` に更新できる旨の記載がある

#### Scenario: 自己申告更新の禁止がルーチンプロンプトに含まれる

- **WHEN** レシピの発火時プロンプト本文を検査する
- **THEN** evidence なしで `passes:true` にしてはならない旨の指示が含まれている

### Requirement: 同一項目の 2 連続 FAIL は凍結して人間へエスカレーションする

レシピの停止基準は /goal による「全項目 `passes:true`、ただし同一項目 2 連続 FAIL で凍結して人間へ」を含まなければならない (MUST)。凍結した項目を feature-list から削除してはならず (MUST NOT)、凍結の事実と理由を progress notes に記録すること。

#### Scenario: 停止基準に凍結条件が含まれる

- **WHEN** レシピの停止基準節を検査する
- **THEN** 「全項目 passes:true」の定量ゴールと「同一項目 2 連続 FAIL で凍結 + 人間へエスカレーション」の両方が記載されている

#### Scenario: 凍結項目は削除ではなく記録される

- **WHEN** レシピの凍結手順を検査する
- **THEN** 凍結項目を feature-list から削除せず、凍結の事実と理由を progress notes に記録する旨が記載されている

### Requirement: feature-list の形式はリファレンスドキュメントに記載する

`plugins/loops/references/feature-list-format.md` が存在し、feature-list の形式として各項目が `{id, description, verification, passes}` のキーを持つ JSON であること、`passes` の初期値は `false` であること、項目とその verification の削除禁止を記載しなければならない (MUST)。JSON Schema ファイルによる機械的強制を導入してはならない (MUST NOT)（形式は references の記載のみとする）。

#### Scenario: リファレンスが形式を定義している

- **WHEN** `plugins/loops/references/feature-list-format.md` を検査する
- **THEN** `id` / `description` / `verification` / `passes` の 4 キーの説明、`passes:false` 初期値、項目・verification の削除禁止の記載がある

#### Scenario: schema による強制が存在しない

- **WHEN** `plugins/loops/` 配下で feature-list 用の JSON Schema ファイルを探索する
- **THEN** feature-list を機械検証する schema ファイルは存在しない

### Requirement: 複数サイクルに分けた完走デモの evidence が残る

3 項目以上の feature-list を用意し、長期ビルドルーチンを 2 サイクル以上に分けて完走させたデモの実行ログを `{longrun-dir}` に保存しなければならない (MUST)。ログには各サイクルの smoke check 結果・実装した 1 項目・verification の exit code・passes 更新・progress 追記の記録を含めること。デモのレシピ規約検査は `/loops:design` の起動に依存せず、`plugins/loops/references/` の検査手順（停止基準必須・Bad Loop 検査）を手動実行して evidence に含めること (MUST)。

#### Scenario: 2 サイクル以上の完走デモログが存在する

- **WHEN** `{longrun-dir}` 配下を検査する
- **THEN** 3 項目以上の feature-list に対する 2 サイクル以上のデモ実行ログが存在し、各サイクルの smoke check・実装項目・verification exit code・passes 更新・progress 追記が確認できる

#### Scenario: 故意の失敗で凍結とエスカレーションが機能する

- **WHEN** デモ中に 1 項目を故意に 2 連続 FAIL させる
- **THEN** 当該項目が凍結され（`passes:false` のまま削除されない）、人間へのエスカレーションが progress notes に記録されたことがログで確認できる

#### Scenario: 規約検査はスキル起動に依存せず手動実行される

- **WHEN** デモの evidence を検査する
- **THEN** references の検査手順（停止基準必須・Bad Loop 検査）を手動実行した結果（各検査項目の PASS/FAIL）が記録されている
