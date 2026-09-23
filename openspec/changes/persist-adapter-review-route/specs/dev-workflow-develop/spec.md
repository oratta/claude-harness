## MODIFIED Requirements

### Requirement: G はレビュー経路を起動指示の 1 行で判別する
develop の本体は、(4) で G を起動する指示・再開する指示・手渡しで後任の G を起動する指示のすべてに、起動形を問わず**常に** `レビュー経路: adapter` の 1 行を書かなければならない（MUST）。条件付きにしてはならない（MUST NOT）。現行の develop は実行先の 3 つの起動形（自動選択・明示 profile・旧形式の account/model 指定）すべてを adapter（`codex-develop.py request`）で解決するため、develop の本体が G を起こす場面はすべて adapter 経路である。Codex の G に対しては、request の instructions（`--input` に渡す指示ファイル）が起動指示に当たり、そこにも同じ行を書かなければならない（MUST）。

`レビュー経路: 従来` は、develop の本体以外の呼び出し元が `gate-runner.md` で G を起こす場合と、行を書かない古い本体のための値であり、develop の本体は書いてはならない（MUST NOT）。

`gate-runner.md` は、新しい G が起動指示の `レビュー経路:` 行だけで経路を判別し、環境変数・記録先のコメント・自分の起動方法から推測しないことを書かなければならない（MUST）。`レビュー経路: adapter` で起動された同一の G は、その後の再開指示に `レビュー経路:` 行が無くても adapter 経路のまま動かなければならない（MUST）。行が無いときに従来経路として扱う規則は、新しい G の起動指示（手渡しで起こされた後任 G の起動指示を含む）に行が無かった場合にだけ適用しなければならない（MUST）。あわせて、`レビュー経路: adapter` は新 Codex モードを含む adapter 解決の全構成（`claude-default` を含む）を指し、従来モードのレビュー実行者の表は `レビュー経路: 従来`、または行の無い起動指示で開始された G にだけ適用すると書かなければならない（MUST）。`SKILL.md` は、G の起動・再開指示に常に `レビュー経路: adapter` を書く本体の責任を、Role profile の選択節と (4) の両方に書かなければならない（MUST）。

#### Scenario: 自動選択での G 起動
- **WHEN** 本体が自動選択（profile も旧形式も無指定）で develop を進め、(4) で G を起動する
- **THEN** G の起動指示に `レビュー経路: adapter` の行があり、G はこの行を見て adapter 経路の規則に従う

#### Scenario: 明示 profile で Codex の G を起動
- **WHEN** 本体が明示 profile で develop を進め、phase `gate` の投げ先が Codex で request を作る
- **THEN** request の instructions に `レビュー経路: adapter` の行がある

#### Scenario: 行が無い G 起動
- **WHEN** `レビュー経路:` の行を含まない起動指示で新しい G（手渡しで起こされた後任 G を含む）が起動される
- **THEN** G は従来経路として扱い、full では今までどおり Bash から Codex を直接呼ぶ

#### Scenario: adapter 経路で起動済みの G を行無しで再開
- **WHEN** `レビュー経路: adapter` で起動された同一の G が、`レビュー経路:` の行を含まない指示で再開される
- **THEN** G は adapter 経路のまま動き、従来経路へ切り替わらない

#### Scenario: 手渡し後の G 再開
- **WHEN** 本体が G を SendMessage で再開する、または手渡しで後任の G を起動する
- **THEN** その指示にも `レビュー経路: adapter` の行がある
