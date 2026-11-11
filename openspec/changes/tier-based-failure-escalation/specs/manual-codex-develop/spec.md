## ADDED Requirements

### Requirement: 失敗ループの昇格で profile と実装役の設定を差し替えない
`references/codex-develop.md` は、失敗ループが起きたときの本体の手順を実行側と判断側それぞれについて格の言葉で書かなければならない（MUST）。実行側では `request` に W の phase と `--failure executor` を渡し、返った `model` だけで実行役を起こす（MUST）。判断側では `request --phase decider --failure judgment` が返す `decider` entry の投げ先・account・model で決める役を立てる（MUST）。本体は昇格の手段として、profile の作り直し・`--profile` / `--profile-file` の差し替え・model の明示・effort の変更をしてはならない（MUST NOT）。Codex の実装役の model が変わらないことは、対応表で引いた結果として書く（MUST）。

#### Scenario: Codex profile で実行側の失敗が起きる
- **WHEN** `codex-standard` の構成で、W の 2 回目の失敗が実行側と分類される
- **THEN** 本体は `request --phase implement --failure executor` を同じ profile の指定で呼び、返った model（対応表の上位）で実装役を起こし、別の profile を作らず、effort を変えない

#### Scenario: 判断側の失敗で決める役を立てる
- **WHEN** W の 2 回目の失敗が判断側と分類される
- **THEN** 本体は `request --phase decider --failure judgment` が返した投げ先・account・model で決める役を立て、実行役の格は変えない

#### Scenario: 手順が文書にある
- **WHEN** `references/codex-develop.md` を読む
- **THEN** 失敗ループの実行側と判断側の手順、`--failure` の値、profile・model・effort を差し替えないことが書かれている

### Requirement: 格が上がって model が変わる再開は新しい thread に手渡す
同じ Claude role を再開する前の `request` の呼び直しで、返った `tier` が thread の格より高く、返った `model` が thread の起動時の applied model と違うとき、本体は SendMessage してはならず（MUST NOT）、返った `model` で新しい thread を起こし、前任の return と成果物を手渡さなければならない（MUST）。返った `model` が thread の applied model と同じなら SendMessage で再開してよい。SendMessage の再開では model を変えられないため、この規則が無いと昇格が起きないまま再開される。

#### Scenario: Claude の W が実行側の失敗で上がる
- **WHEN** 中位（`sonnet`）で起動した W について、`request --phase implement --failure executor` が上位（`opus`）を返す
- **THEN** 本体は SendMessage せず、`opus` の新しい W を起こして前任の return を渡す

#### Scenario: model が変わらない昇格
- **WHEN** 呼び直しで返った `tier` は thread の格より高いが、返った `model` は thread の applied model と同じである
- **THEN** 本体は SendMessage で再開してよい

### Requirement: develop 開始時の profile の指定を工程の途中で変えない
本体は develop 開始時の profile の指定（`--profile NAME`・`--profile-file PATH`・旧形式の account/model・無指定のどれか）を、develop の終わりまで同じ値で `request` に渡さなければならない（MUST）。無指定のときに phase ごとに構成を選び直す既存の規則は変えない。指定を変える必要があるときは、主に承認を求め、記録先に `profile 変更: <変更前の指定> → <変更後の指定>` の行と主の承認の発言を引いたコメントを残してから変えなければならない（MUST）。この要件は文書の規則であり、`request` による機械的な拒否はこの要件の範囲に含めない（#615 の範囲）。

#### Scenario: 途中で外部 profile を作りたくなる
- **WHEN** develop の途中で、本体が別の `--profile-file` を作って渡そうとする
- **THEN** 文書の規則に従い、主の承認と記録先の `profile 変更:` の行が無ければ渡さない

#### Scenario: 規則が文書にある
- **WHEN** `references/codex-develop.md` を読む
- **THEN** 開始時の指定を途中で変えないこと、変えるときの承認の記録の書式が書かれている
