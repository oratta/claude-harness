## ADDED Requirements

### Requirement: issue と子 issue 込みの経路でも、未知モデルの名前と行数を示す
システムは、`cost_ledger.py issue <番号>` と子 issue を持つ issue の集計（`cost_ledger.py cost <番号>` の epic 経路）の通常出力にも、合計に入った行の中の未知モデルの名前と行数を、ブランチ・PR の経路と同じ文言で示 MUST す。未知モデルが無いときはその行を出してはなら MUST NOT ない。1 行目の書式と他の行は変えてはなら MUST NOT ない。`--json` には同じ内容を `unknown_models`（`{モデル名: 行数}`）として足 SHALL す。

数える範囲は、issue 経路では issue に帰属した区間の行、epic 経路では合計に入れた行とする。リポジトリ不明として別立てにした行と、`--closing-pr` で足す閉じた PR の行は含めない。行数は応答の 2 行目以降の事実を数えない（ブランチ・PR の経路と同じ）。

#### Scenario: issue 経路に未知モデルの名前と行数が出る
- **WHEN** issue に帰属する区間に、料金表のどの鍵にも前方一致しないモデル名 `claude-nope-9` の行が 1 行ある状態で `cost_ledger.py issue <番号>` を実行する
- **THEN** 出力に `  未知モデル: claude-nope-9 1 行（料金表に単価が無いため 0 円として扱っている）` の行（未知モデルごとに 1 行、モデル名の順）があり、1 行目の書式は変わらない

#### Scenario: epic 経路に未知モデルの名前と行数が出る
- **WHEN** 子 issue の区間に未知モデルの行がある状態で、エピックの番号を `cost_ledger.py cost` に渡す
- **THEN** 出力に ブランチ・PR の経路と同じ文言の `未知モデル:` の行があり、行数は合計に入った行のぶんである

#### Scenario: 未知モデルが無ければ行を出さない
- **WHEN** 区間の行がすべて料金表に単価のあるモデルである
- **THEN** issue 経路・epic 経路の出力に `未知モデル:` の行は無い

#### Scenario: --json に unknown_models が足される
- **WHEN** 未知モデルの行がある状態で `cost_ledger.py issue <番号> --json` を実行する
- **THEN** 標準出力は JSON だけで、`unknown_models` に `{"claude-nope-9": 1}` が入っている
