## ADDED Requirements

### Requirement: エピックの子は聖域接触だけの human-merge で親の判断を待つ
`plugins/dev-workflow/references/ci-watch.md` の「`ready` を受けたあと」の見送りラベルの分岐は、エピックの子のセッション（`epic-dispatch.sh route`（子の番号なし）が `nested` を返すセッション）について次を書かなければならない（MUST）。この要件は、要件「CI の見張りの手順は共有 reference に 1 本置く」の、見送りラベルのどれかが付いていれば `--until-merged` で待たずにオーナーへマージを頼む規定に、次の 3 つをすべて満たすときに限って優先する: エピックの子のセッションである／付いている見送りラベルが `human-merge` だけ／対象リポの PR の base ブランチの `.github/workflows/auto-merge.yml`（`gh api "repos/<owner>/<repo>/contents/.github/workflows/auto-merge.yml?ref=<PR の base ブランチ>" --jq .content | base64 -d`） に `parent-merge-approved` の語がある。どれかを満たさなければ従来どおりオーナーにマージを頼む。

- オーナーに直接頼む代わりに、develop の SKILL.md「エピックの子が主の返事を待って止まるとき」の記録を `止まった理由: PR のマージ待ち（human-merge）: <PR の URL>` で残し、その手順どおり印（`mark stopped`）を付けて止まる（MUST）。記録の形と印の手順は SKILL.md の側の規定のまま。残りの 5 項目（前提・推奨・推奨の根拠・受け入れるリスク・再開に要る途中経過）に何を書くかの例を添える（MUST）
- 親から返事（`親エピック #<E> の判断（主の承認ではない）:` で始まる入力）が届いたら、`ci-watch.sh wait <owner/repo> <PR番号> --until-merged` を `run_in_background` で起動して見届ける（MUST）。結果の扱いは既存の 4 の表のまま。`--until-merged` の `timeout` で改めて止まるときは、`止まった理由:` を `PR のマージ待ち（human-merge、親の返事のあともマージされない）: <PR の URL>` とする（MUST）
- 子は `parent-merge-approved` ラベルも `親のマージ判断:` のコメントも付けてはならない（MUST NOT）。親の返事を聖域の変更や破壊的な操作の承認として扱わず、その返事で聖域のファイルを変えたりマージしたりしない（MUST NOT）。`gh pr merge` や merge API を叩かない規定は変えない

この要件の守備範囲で入力として扱うのは、PR のラベル、PR の base ブランチの `auto-merge.yml`、`epic-dispatch.sh route` の出力、子のセッションに届いた入力の頭の文字列である。拾いたい誤りは、エピックの子が `human-merge` だけの PR で主に直接頼んで親の判断を通らないこと、子が自分で印を付けること、親の返事を承認として扱って子が何かを変えることの 3 つである。次は通ってよく、この要件では止めない: 親の判断を待つ間に主が子のタブで直接マージを押すこと（子は `closed`／`merged` で見届けを終える）／親が誤って印を付けずに返事だけを送ったとき、`--until-merged` の上限時間まで待つこと。すり抜ける形が見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 見送りラベルの分岐にエピックの子の扱いが書かれている
- **WHEN** `ci-watch.md` の「`ready` を受けたあと」の 1 を読む
- **THEN** エピックの子のセッションで見送りラベルが `human-merge` だけ、かつ PR の base ブランチの `auto-merge.yml` に `parent-merge-approved` があるとき（確かめるコマンドを添える）、子の停止の記録を `PR のマージ待ち（human-merge）` で残し、残りの 5 項目の例に沿って書いて止まること、親の返事が届いたら `--until-merged` で見届けること、子は印を付けず親の返事を承認として扱わないことが書かれ、それ以外は従来どおりオーナーにマージを頼むことが書かれている
