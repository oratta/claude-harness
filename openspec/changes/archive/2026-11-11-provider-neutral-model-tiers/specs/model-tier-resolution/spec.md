# model-tier-resolution

## Purpose

develop の各役のモデルを、提供元・構成・自動選択かどうかによらない 1 つの規則で格として決め、呼び出し先ごとの対応表でモデル名に置き換える。

## ADDED Requirements

### Requirement: 格の語と対応表を 1 か所に置く

格は低い順に `最安`・`中位`・`上位`・`最上位` の 4 つとしなければならない（MUST）。格からモデル名への対応は `plugins/dev-workflow/references/model-tier-map.json` の 1 か所に置き、executor ごとに 4 格すべてを持たなければならない（MUST）。ファイルが読めない、または格か executor が欠けているとき、resolver は既定値に倒さず止まらなければならない（MUST）。

**守備範囲（対応表と格の列挙の検証）**: ①入力の出どころは、リポジトリ同梱の `model-tier-map.json` だけである。②拾いたい誤りは、格・executor の欠けと未知のキーで、既定値に倒れて無言で別のモデルが選ばれることである。③通してよい入力は、4 格ちょうど・2 executor の表である。値の実在は検証しない（Claude はエイリアスで、Codex は worker が解決時に止める）。④この検査は入力の穴が見つかるたびに塞ぎ切ることを完了条件にしない。`tier-model` の引数と `--pre-class`・`--failure` の列挙の検証もこの段落に従う。

#### Scenario: 対応表の値

- **WHEN** `model-tier-map.json` を読む
- **THEN** claude は 最安=`haiku`、中位=`sonnet`、上位=`opus`、最上位=`fable`、codex は 最安=`luna`、中位=`sol`、上位=`sol`、最上位=`astra` である

#### Scenario: 対応表が壊れている

- **WHEN** `model-tier-map.json` の codex に `上位` が無い状態で `request` を実行する
- **THEN** `status: blocked` を出して終了コード 2 で終わり、依頼ファイルを作らない

### Requirement: tier-model で対応表を引ける

`codex-develop.py tier-model --executor <executor> --tier <格>` は、対応表の 1 件を JSON で返さなければならない（MUST）。未定義の executor または格は `status: blocked` と終了コード 2 で拒否しなければならない（MUST）。検証の守備範囲は要件「格の語と対応表を 1 か所に置く」の段落に従う。

#### Scenario: 全格を引ける

- **WHEN** claude と codex の 4 格それぞれで `tier-model` を実行する
- **THEN** どれも終了コード 0 で、executor・tier・model を返す

#### Scenario: 未定義の格を拒否する

- **WHEN** `tier-model --executor codex --tier 特上` を実行する
- **THEN** `status: blocked` を出して終了コード 2 で終わる

### Requirement: request は格の入力を受ける

`request` は `--pre-class sacred|merge|contract|billing`（繰り返し可）、`--design-judgment`、`--failure first|executor|judgment`、`--unmanned` を受けなければならない（MUST）。4 分類の語は順に聖域パス・マージ権限・層間契約・課金/法務を指す。列挙の外の値は拒否し、依頼ファイルを作ってはならない（MUST NOT）。検証の守備範囲は要件「格の語と対応表を 1 か所に置く」の段落に従う。

#### Scenario: 未定義の事前分類を拒否する

- **WHEN** `request --pre-class other` を実行する
- **THEN** 非 0 で終わり、依頼ファイルを作らない

### Requirement: 格は役と入力だけから決める

要求の格は phase と `request` の入力だけから決めなければならない（MUST）。構成・executor・自動選択かどうかを入力にしてはならない（MUST NOT）。基準は W（phase `spec`・`implement`・`finish`）が中位、G（phase `gate`）が中位、R1（phase `spec-review`）とレビュアー（phase `review`）が上位、decider が最上位、explore と summarize が最安とする。下の scenario に無い入力と phase の組み合わせは格を動かしてはならない（MUST NOT）。

#### Scenario: W を上げる条件

- **WHEN** W の phase で、`--pre-class` のどれか、`--design-judgment`、`--failure executor` のいずれかを渡す
- **THEN** 要求の格は上位で、最上位にはならない

#### Scenario: W は失敗で下がらない

- **WHEN** 事前分類に当たる W の phase で `--failure first` または `--failure judgment` を渡す
- **THEN** 要求の格は上位のままである

#### Scenario: G は上げない

- **WHEN** phase `gate` に `--pre-class merge`、`--design-judgment`、`--failure executor` を渡す
- **THEN** 要求の格は中位である

#### Scenario: decider の失敗の段

- **WHEN** phase `decider` に `--failure first` または `--failure executor` を渡す
- **THEN** 要求の格は上位である。`--failure judgment` または `--failure` なしなら最上位である

### Requirement: 読んで判断する役は事前分類で decider に切り替える

phase `spec-review` と `review` に `--pre-class merge`、`contract`、`billing` のどれかを渡したとき、`request` は対象 role の entry ではなく構成の `decider` entry を使い、返す `role` を `decider`、要求の格を最上位にしなければならない（MUST）。読む指示書は phase のものを保たなければならない（MUST）。依頼ファイルの `role` は phase の role（`impl-review` または `spec-review`）を保ち、結果 JSON の `role` だけを `decider` にしなければならない（MUST）。`codex-worker.py` の `NETWORK_ROLES` で decider だけが gh とネットワークを持たず、phase `review` の指示書は gh を使うので、sandbox を変えないためである。`--pre-class sacred` だけでは切り替えてはならない（MUST NOT）。

#### Scenario: 層間契約のレビュー

- **WHEN** `claude-write-codex-review` の構成で `request --phase review --pre-class contract` を実行する
- **THEN** 結果の executor は codex、model は `astra`、`role` は `decider`、`phase` は `review` で、依頼ファイルの `role` は `impl-review`、sandbox は phase `review` と同じで、prompt には phase `review` の指示書が入る

#### Scenario: 聖域パスだけのレビュー

- **WHEN** `request --phase spec-review --pre-class sacred` を実行する
- **THEN** `role` は `spec-review` のままで、要求の格は上位である

### Requirement: 残量モードを格に適用する

`request` は要求の格に `SHARED_BUDGET_MODE` と `FABLE_BUDGET_MODE` を適用した格を返さなければならない（MUST）。適用は構成の上限より先に行い、executor によって変えてはならない（MUST NOT）。適用の結果は `decision-criteria.md` の残量モードと共有枠モードの表と一致しなければならない（MUST）。

#### Scenario: depleted は全役を中位までにする

- **WHEN** `SHARED_BUDGET_MODE=depleted` で全 phase を解決する
- **THEN** 適用後の格は explore と summarize が最安のままで、それ以外は中位である。Codex でも同じである

#### Scenario: throttled は上げていない役を中位まで下げる

- **WHEN** `SHARED_BUDGET_MODE=throttled` で、入力なしの R1、事前分類に当たる W、`--pre-class contract` の R1、decider、explore を解決する
- **THEN** 適用後の格は順に中位、上位、上位、上位、最安である

#### Scenario: exhausted は全経路で上位までにする

- **WHEN** `FABLE_BUDGET_MODE=exhausted`、`SHARED_BUDGET_MODE=ok` で decider を解決する
- **THEN** 適用後の格は上位で、`--unmanned` の有無で変わらない

#### Scenario: reserve は自動実行だけ上位までにする

- **WHEN** `FABLE_BUDGET_MODE=reserve`、`SHARED_BUDGET_MODE=ok` で decider を解決する
- **THEN** `--unmanned` ありなら適用後の格は上位、なしなら最上位である

#### Scenario: abundant は上げない

- **WHEN** `FABLE_BUDGET_MODE=abundant`、`SHARED_BUDGET_MODE=ok` で全 phase を解決する
- **THEN** 適用後の格は `conserve` のときと同じである

### Requirement: 残量モードの導出

`request` は明示 env を最優先に、無ければ起動 account の実効値から残量モードを導出しなければならない（MUST）。閾値は `session-tripwires.sh` の式と同じにする。値が読めないときは止まらず `conserve`・`ok` として進めなければならない（MUST）。明示 env が未知の値なら、`FABLE_BUDGET_MODE` は `conserve`、`SHARED_BUDGET_MODE` は `throttled` として扱わなければならない（MUST）。

#### Scenario: 明示 env が勝つ

- **WHEN** `SHARED_BUDGET_MODE=ok` を明示し、実効値の `weekly_all_pct` が 95 である
- **THEN** 共有枠モードは `ok` である

#### Scenario: 実効値から導出する

- **WHEN** env が無く、`now` を固定し、実効値の `fable_weekly_pct` が 95、`weekly_all_pct` が 60、`weekly_resets_epoch` が `now` の 6 日後である
- **THEN** `budget_modes` は `exhausted` と `throttled` になる

#### Scenario: usage データが無い

- **WHEN** env が無く、実効値が読めない
- **THEN** `budget_modes` は `conserve` と `ok` で、`request` は止まらない

#### Scenario: 未知の明示値

- **WHEN** `FABLE_BUDGET_MODE=foo`、`SHARED_BUDGET_MODE=bar` で解決する
- **THEN** 格は `conserve` と `throttled` のときと同じである

### Requirement: 構成の上限は格の決定のあとに効く

profile の entry の `tier_cap` は適用後の格をその格まで下げた `executed_tier` を作らなければならない（MUST）。`tier_cap` は適用後の格の `tier` を変えてはならず（MUST NOT）、格を上げてはならない（MUST NOT）。`model` は `executed_tier` を対応表で引いた値としなければならない（MUST）。

#### Scenario: codex-economy の書く役

- **WHEN** `codex-economy` で phase `implement` を入力なしで解決する
- **THEN** `tier` は中位、`tier_cap` は最安、`executed_tier` は最安、`model` は `luna` である

#### Scenario: 事前分類に当たる書く役でも上限が効く

- **WHEN** `codex-economy` で `request --phase implement --pre-class merge` を実行する
- **THEN** `tier` は上位、`executed_tier` は最安、`model` は `luna` である

### Requirement: 格の出力

`request` の標準出力の結果は `requested_tier`・`tier`・`tier_reason`・`tier_cap`・`executed_tier`・`requested_model`・`model`・`budget_modes` を持たなければならない（MUST）。`tier` は残量モード適用後の格で、構成によらず同じ値でなければならない（MUST）。`tier_reason` は `tier` が `requested_tier` と違うときに原因のモード（`SHARED_BUDGET_MODE=depleted` など）を、同じときに `unchanged` を持つ。依頼ファイルに格の欄を足してはならない（MUST NOT）。

#### Scenario: Claude の適用値

- **WHEN** `FABLE_BUDGET_MODE=exhausted`、`SHARED_BUDGET_MODE=ok` で `claude-default` の decider を解決する
- **THEN** `requested_tier` は最上位、`tier` は上位、`tier_reason` は `FABLE_BUDGET_MODE=exhausted`、`requested_model` は `fable`、`model` は `opus` である

#### Scenario: 両方のモードが同じ格に下げる

- **WHEN** `FABLE_BUDGET_MODE=exhausted`、`SHARED_BUDGET_MODE=throttled` で decider を解決する
- **THEN** `tier` は上位で、`tier_reason` は `SHARED_BUDGET_MODE=throttled` である

#### Scenario: 依頼ファイルの欄は増えない

- **WHEN** executor=codex の role で依頼ファイルを作る
- **THEN** 依頼ファイルの `model` は結果の `model` と同じで、格の欄を持たず、`codex-worker.py run` が受け付ける

### Requirement: 旧形式は格の規則を通らない

旧形式 `--account --model` の `request` は、格の規則・残量モード・対応表を通さず、指定された model をそのまま返さなければならない（MUST）。`requested_tier`・`tier`・`tier_reason`・`tier_cap`・`executed_tier`・`budget_modes` は null とし、`requested_model` は指定された model としなければならない（MUST）。格の入力の引数は受けて無視しなければならない（MUST）。

#### Scenario: 旧形式に事前分類を渡す

- **WHEN** `request --account spare --model gpt-6-sol --pre-class merge --phase review` を実行する
- **THEN** `role` は `impl-review`、`model` は `gpt-6-sol`、`tier` は null である

### Requirement: 構成で格が変わらないことをテストで固定する

`plugins/dev-workflow/tests/test_model_resolution_current.py` は、全役・全構成・12 の残量モードの組・格の入力の組み合わせについて、`tier` が同じ値になることをリテラルの期待値で確かめなければならない（MUST）。期待値を対応表や profile の JSON から導いてはならない（MUST NOT）。

#### Scenario: 構成を変えても格が変わらない

- **WHEN** `python3 -m pytest plugins/dev-workflow/tests/test_model_resolution_current.py` を実行する
- **THEN** 終了コード 0 で、`claude-write-codex-review` の構成でも事前分類に当たる W の `tier` が上位である

#### Scenario: 入力なしの通常時は今の値を保つ

- **WHEN** `FABLE_BUDGET_MODE=conserve`、`SHARED_BUDGET_MODE=ok` で、全構成の全役を入力なしで解決する
- **THEN** 8 役 × 7 分岐（`codex-standard`・`codex-economy`・`hybrid-standard`・`claude-write-codex-review`・`auto:claude-write-codex-review`・`auto:codex-standard`・`auto:claude-default`）の executor と model は #613 で固定した値と同じである

#### Scenario: model-tiers.md の Claude の値と一致する

- **WHEN** テストが対応表の claude と `model-tiers.md` のティア表を突き合わせる
- **THEN** `haiku`・`sonnet`・`fable` の 3 行と、重めの役に渡す `'opus'` の記述が対応表の値と一致する
