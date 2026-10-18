## ADDED Requirements

### Requirement: 親経由の返事の合否を、偽 2 件・本物 1 件の混在ログで機械的に固定する

`plugins/dev-workflow/tests/owner-reply-relayed-scenario.bats` は、1 本の親の会話ログ（`OWNER_REPLY_PROJECTS_DIR` で差し替えたテスト用のもの）に、偽の文 2 種と本物の文 1 件を同居させ、同じ停止の記録の作成日時と URL で `owner-reply-check.sh --relayed` を当てて、次を固定しなければならない（MUST）。`scripts/test.sh owner-reply-relayed-scenario` の 1 コマンドで、主の入力・GitHub・Orca を使わずに合否が出なければならない（MUST）。

| 入力 | 期待 |
|---|---|
| 偽 1: uuid が親の発言の行、またはツールの結果の行 | `REASON=not-owner`・`MATCHES=0`、exit 1（2 つの行それぞれ） |
| 偽 2: 停止の記録の作成日時より前の主の発言の行 | `REASON=not-after`・`MATCHES=0`、exit 1 |
| 本物: 停止の記録の URL を書いた親の報告のあとの、主の「許容」の行 | exit 0、`MATCH:` 行に「許容」、`MATCHES=1` |

偽 1 の 2 行を親の報告と本物のあいだに置き、さらに本物のあとにも置いたログで、本物は exit 0・`MATCHES=1` のままでなければならず、本物の行を含むそのログで偽 1・偽 2 は上の表どおり落ちなければならない（MUST）。

このテストの範囲（検査の守備範囲は既存要件「owner-reply-check.sh は主の発言の場所を引き、親経由の返事を場所で確かめる」のものに従う）: ①固定するのは `--relayed` の出力と終了コードまで。宣言コメントへの追記と `needs-approval` の付け外しはゲートの動作で、このテストでは守らない（ゲートが `REASON` を見て通さない側に倒す文言は pr-review-gate と develop の bats が固定する）。実機の Orca を使う確認は、親・子・ゲートの継ぎ目を変えたときに残す ②実 GitHub に試しのエピック・子 issue・PR を作る方式は採らない（外部状態が残るため）。

#### Scenario: 偽の文は落ち、本物の文は通る
- **WHEN** 偽 1・偽 2・本物の行を含む 1 本のテスト用会話ログに `--relayed` を行ごとに当てる
- **THEN** 偽 1 は `REASON=not-owner`、偽 2 は `REASON=not-after`（どちらも exit 1）、本物は exit 0 になる

#### Scenario: 偽が本物の前後にあっても判定が変わらない
- **WHEN** 偽 1 の 2 行を親の報告と本物のあいだに置き、さらに本物のあとにも置いたログに `--relayed` を当てる
- **THEN** 本物は exit 0・`MATCHES=1`、偽 1 の各行は `REASON=not-owner`、偽 2 は `REASON=not-after` のまま
