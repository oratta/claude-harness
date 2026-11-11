## MODIFIED Requirements

### Requirement: 格の語と対応表を 1 か所に置く

格は低い順に `最安`・`中位`・`上位`・`最上位` の 4 つとしなければならない（MUST）。格からモデル名への対応は `plugins/dev-workflow/references/model-tier-map.json` の 1 か所に置き、executor ごとに 4 格すべてを持たなければならない（MUST）。同じファイルは役ごとの上限の格 `role_caps` を持たなければならない（MUST）。`role_caps` のキーは canonical role（`spec-write`・`spec-review`・`implement`・`impl-review`・`review`・`decider`・`explore`・`summarize`）のどれかで、値は 4 格のどれかとし、`spec-write` と `implement` を必ず含まなければならない（MUST）。`role_caps` に載っていない役は上限を持たない。ファイルが読めない、または格・executor・`role_caps` が欠けているとき、resolver は既定値に倒さず止まらなければならない（MUST）。

**守備範囲（対応表と格の列挙の検証）**: ①入力の出どころは、リポジトリ同梱の `model-tier-map.json` だけである（環境変数や引数で別の表を渡す口を作らない）。②拾いたい誤りは、格・executor・`role_caps` の欠けと未知のキー（未知の役・未定義の格を含む）で、既定値に倒れて無言で別のモデルが選ばれる、または上限が無言で消えることである。③通してよい入力は、4 格ちょうど・2 executor・`spec-write` と `implement` を含む `role_caps` の表である。値の実在は検証しない（Claude はエイリアスで、Codex は worker が解決時に止める）。④この検査は入力の穴が見つかるたびに塞ぎ切ることを完了条件にしない。`tier-model` の引数と `--pre-class`・`--failure` の列挙の検証もこの段落に従う。

#### Scenario: 対応表の値

- **WHEN** `model-tier-map.json` を読む
- **THEN** claude は 最安=`haiku`、中位=`sonnet`、上位=`opus`、最上位=`fable`、codex は 最安=`luna`、中位=`sol`、上位=`sol`、最上位=`astra` である
- **AND** `role_caps` は `spec-write`=上位、`implement`=上位 の 2 件だけである

#### Scenario: 対応表が壊れている

- **WHEN** `model-tier-map.json` の codex に `上位` が無い状態で `request` を実行する
- **THEN** `status: blocked` を出して終了コード 2 で終わり、依頼ファイルを作らない

#### Scenario: 上限が欠けた表

- **WHEN** `role_caps` から `implement` を除いた表、または `role_caps` に未定義の格 `特上` を書いた表で `request` を実行する
- **THEN** `status: blocked` を出して終了コード 2 で終わり、依頼ファイルを作らない

### Requirement: 旧形式は格の規則を通らない

旧形式 `--account --model` の `request` は、格の規則・残量モードを通さず、指定された model をそのまま返さなければならない（MUST）。`requested_tier`・`tier`・`tier_reason`・`tier_cap`・`executed_tier`・`budget_modes` は null とし、`requested_model` は指定された model としなければならない（MUST）。格の入力の引数は受けて無視しなければならない（MUST）。

例外として、phase の役が `role_caps` に載っているときは、対応表を読み、指定された model を codex の列で格に戻し（照合の規則は要件「上限の判定を Claude と Codex で共有する」）、その格が役の上限を超えるなら拒否しなければならない（MUST。終了コード 2・依頼ファイルなし）。この場合に対応表が読めなければ止まらなければならない（MUST）。格に戻せない model は上限を確かめずに通す（SHALL）。`role_caps` に載っていない役では対応表を読んではならない（MUST NOT。表が壊れていても通る）。

**守備範囲（旧形式の上限）**: ①入力は旧形式の `--model` の文字列と phase である。②拾いたい誤りは、上限を持つ役（spec-write・implement）に、表の上限を超える格のモデル名（`astra`・`gpt-6-astra` など）を指定することである。③表のどの名前にも当たらない model（綴り違い・未知の版名）は、版を固定する旧形式の目的を保つため通してよい。④この検査は入力の穴が見つかるたびに塞ぎ切ることを完了条件にしない。

#### Scenario: 旧形式に事前分類を渡す

- **WHEN** `request --account spare --model gpt-6-sol --pre-class merge --phase review` を実行する
- **THEN** `role` は `impl-review`、`model` は `gpt-6-sol`、`tier` は null である

#### Scenario: 旧形式で実装役に最上位のモデルを指定する

- **WHEN** `request --account spare --model gpt-6-astra --phase implement` を実行する
- **THEN** `status: blocked` を出して終了コード 2 で終わり、依頼ファイルを作らず、メッセージに `implement`・`最上位`・`上位` を含む

#### Scenario: 旧形式で実装役に中位のモデルを指定する

- **WHEN** `request --account spare --model gpt-6-sol --phase implement` を実行する
- **THEN** 依頼ファイルが作られ、`model` は `gpt-6-sol`、`tier` は null である

#### Scenario: 上限の無い役の旧形式は壊れた表でも通る

- **WHEN** 対応表が読めない状態で `request --account spare --model astra --phase decider` を実行する
- **THEN** 依頼ファイルが作られ、`model` は `astra` である

## ADDED Requirements

### Requirement: 役の上限を超える格の依頼を拒否する

profile 形式と自動選択の `request` は、`executed_tier`（残量モードと profile の `tier_cap` を適用したあとの格）を、実際に動く entry の役（review が decider に切り替わったときは decider）の `role_caps` の上限と比べ、上限を超えるなら `status: blocked` と終了コード 2 で拒否し、依頼ファイルを作ってはならない（MUST NOT）。上限まで下げて通してはならない（MUST NOT）。拒否のメッセージは役・`executed_tier`・上限の格を含まなければならない（MUST）。`role_caps` に載っていない役は判定しない。

#### Scenario: 同梱の表では書く役は通る

- **WHEN** 同梱の表で `request --profile claude-default --phase implement --pre-class contract` を実行する
- **THEN** `status: agent-required` で、`executed_tier` は上位、`model` は `opus` である

#### Scenario: 上限を下げた表では同じ依頼を拒否する

- **WHEN** `role_caps` の `implement` を `中位` にした表で `request --profile claude-default --phase implement --pre-class contract` を実行する
- **THEN** `status: blocked` を出して終了コード 2 で終わり、メッセージに `implement`・`上位`・`中位` を含む

#### Scenario: 上限以下の依頼は通る

- **WHEN** `role_caps` の `implement` を `中位` にした表で `request --profile claude-default --phase implement` を入力なしで実行する
- **THEN** `executed_tier` は中位で、拒否されない

### Requirement: 上限の判定を Claude と Codex で共有する

`codex-develop.py` と `scripts/agent-model-guard.sh` は、model 名から格を引く規則と、拒否のメッセージの前半を、同じ 1 つの実装から使わなければならない（MUST）。model 名から格を引く規則は、model を小文字にして前後の空白を除いたもの、またはそれを `-` で区切った断片のどれかが、その executor の列のモデル名と完全に一致する格のうち、いちばん低い格とする（MUST）。一致が無ければ格なしとする。拒否のメッセージの前半は、役・要求された格・その役の上限の格を含まなければならない（MUST）。

#### Scenario: 名前の照合

- **WHEN** claude の列で `fable`・`Claude-Fable-5-1`・`opus`・`fabel` を、codex の列で `gpt-6-astra`・`gpt-5.6-sol` を格に戻す
- **THEN** 順に 最上位・最上位・上位・格なし・最上位・中位 になる

### Requirement: 表を 1 か所変えると両方の判定が変わることをテストで固定する

`plugins/dev-workflow/tests/agent-model-guard.bats` は、`plugins/dev-workflow/scripts` と `plugins/dev-workflow/references` の一時コピーの表で spec-write・implement の上限を `中位` に下げ、同じテストの中で、コピーの guard が `dev-workflow:worker`・`model: opus` を拒否し、コピーの `codex-develop.py` が `request --profile claude-default --phase implement --pre-class contract` を拒否し、同梱の表ではどちらも通ることを確かめなければならない（MUST）。

#### Scenario: 表を 1 か所変えると両方の判定が変わる

- **WHEN** `bats plugins/dev-workflow/tests/agent-model-guard.bats` を実行する
- **THEN** 終了コード 0 で、上限を下げた一時コピーで guard と `codex-develop.py` の両方の判定が許可から拒否に変わるケースを含む
