## Why

PR #759（#690: 子 issue を持つ issue の `/cost` に子 issue ごとの内訳と合計を出す）のレビューで、spec・README・docstring・変更の記録の文面が実装とずれている箇所が見つかった（issue #765）。blocking の指摘ではなく、挙動の不一致も無い。読む人が誤った前提で判断しないよう、実装に合わせて直す。

## What Changes

- `cost-ledger-timeline`: 「1 本のコメントに行を積む」の 1 行目の定めを、`--child-issue` の有無で場合分けする
- `cost-ledger-attribution`: 「issue の合計は、閉じた PR の分と…」の「issue の合計は `/cost <issue番号>` の値と同じ」を、`cost_ledger.py issue <番号>` の 1 行目の値（子 issue を持つ issue の `/cost` の 1 行目は子 issue 込みで一致しない）と書く
- `cost-ledger-cost-command`:
  - 「issue の経路はリポジトリで絞る」に、エピックで閉じた PR の分をブランチ名だけで引くことを書き足す
  - 「子 issue を持つ issue では…」の「子を持つ issue では続けて `（自身 …）`」を、実装（数える対象の issue の中に子がある issue）に合わせる
  - 「子の行の額の和と一致」の文（表示の項目 2 の括弧書きと一致の規則）を「小数 6 桁に丸めた値で一致。表示の 2 桁どうしは 1 セントずれうる」に直す
  - 同じ要件の `children_usd` と直下の子の `usd` の和を、「小数 6 桁に丸めた値で一致」に直す
  - Scenario「題名の制御文字は空白にして表示する」の WHEN に、#10 の子が #11 の 1 件だけだと書く
- archive 済みの 3 つの change（`cost-ledger-epic-breakdown`・`cost-ledger-deleted-cwd-repo`・`cost-ledger-epic-timeline-rows`）の delta spec にも、上のうち同じ文言の直しを入れる
- archive 済みの `cost-ledger-epic-breakdown/design.md` の「### 13.」の見出しの前に空行を入れる
- `plugins/cost-ledger/README.md`: 出力例を Scenario の出力に揃える／「帰属の鍵」の番号付きリストを「2 本立て」の段落の直後に戻す／エピックのコメントに積む行の記述を `cost-ledger-timeline` の定め（子 issue 込み）に合わせる
- `plugins/cost-ledger/changes/690.md`: 題名とリポジトリ名の制御文字を空白にする変更を 1 行足す
- `cost_ledger.py`: `assign_epic_rows()` の docstring に、`children_usd` と直下の子の `usd` の和は 6 桁に丸めた値で一致すると書く（docstring のみ。挙動は変えない）

`cost-ledger-timeline` の「1 本のコメントに行を積む」の1 行目の文は、`--child-issue` を渡した回と子 issue を持たない issue では `/cost` の 1 行目と同じだが、渡さない回の子 issue を持つ issue（子孫の問い合わせの失敗など）では `cost_ledger.py issue` の 1 行目と同じ（`区間`）で、合計の行の種別も `--child-issue` があれば `子 issue 込み` なので、条件つきの文言に直す（`cmd_timeline` の docstring も同じ）。

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `cost-ledger-timeline`: 1 行目の定めの場合分け
- `cost-ledger-attribution`: issue の合計と `/cost` の関係の文言（Scenario の WHEN に「子 issue を持たない」を足す）
- `cost-ledger-cost-command`: リポジトリで絞る要件への書き足し、エピックの要件の文言 3 か所

## Impact

- 文書・spec・docstring・archive 済みの文書だけ。実行される行は変わらない（`cost_ledger.py` は docstring のみの差分）
