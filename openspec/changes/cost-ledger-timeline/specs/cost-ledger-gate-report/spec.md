## MODIFIED Requirements

### Requirement: ゲート通過を PostToolUse の hook で捕まえる
システムは `plugins/cost-ledger/hooks/hooks.json` に `PostToolUse`・matcher `Bash` の hook を 1 つ持ち、`plugins/cost-ledger/scripts/gate-report.sh` を呼 MUST ぶ。ゲート通過は合格ラベル `agent-review:passed` を付けるコマンドとして Bash の呼び出しに現れ、そのコマンド文字列から対象の PR が分かるため。`Stop` のように PR と結びつかない event を使ってはなら MUST NOT ない。同じ hook が、`cost-ledger-timeline` の定めるきっかけ（PR / issue へのコメントと状態の変更）も捕まえる。

hook は全 Bash 呼び出しで起動するので、スクリプトは stdin に次のどの文字列も含まれなければ、JSON のパースも jq・python3 の起動もせずに即 `exit 0` MUST する: `agent-review:passed`・`gh pr comment`・`gh pr ready`・`gh pr close`・`gh pr merge`・`gh issue comment`・`gh issue close`・`gh issue reopen`。

#### Scenario: 対象外の Bash では何も起動しない
- **WHEN** 上の文字列をどれも含まない Bash 呼び出し（`gh pr view 300` を含む）の hook JSON を stdin に流す
- **THEN** `gh` と `python3` は一度も呼ばれず、stdout は空で、終了コードは 0

#### Scenario: 対象外の Bash での実行時間
- **WHEN** 対象外の Bash 呼び出しの hook JSON を stdin に流して実行時間を `time` で測る
- **THEN** 実行時間は 50 ms 未満

#### Scenario: hook の登録
- **WHEN** `plugins/cost-ledger/hooks/hooks.json` を読む
- **THEN** `PostToolUse` に matcher `Bash`・`timeout: 60` の hook があり、`async` は指定されていない

### Requirement: 有効・無効の設定を持たず、緊急停止だけを持つ
システムは有効・無効を切り替える設定項目を持ってはなら MUST NOT ない。緊急停止用に、環境変数 `COST_LEDGER_GATE_REPORT=off` のときは何もせず `exit 0` MUST する。この停止は、ゲート通過の行だけでなく、`cost-ledger-timeline` の定めるすべてのきっかけに効 MUST く。

#### Scenario: 緊急停止
- **WHEN** `COST_LEDGER_GATE_REPORT=off` を付けて付与コマンドの hook JSON を流す
- **THEN** `gh` は一度も呼ばれず、stdout は空で、終了コードは 0

#### Scenario: 緊急停止はコメントのきっかけにも効く
- **WHEN** `COST_LEDGER_GATE_REPORT=off` を付けて `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** `gh` と `python3` は一度も呼ばれず、stdout は空で、終了コードは 0

### Requirement: どの失敗でも無出力で抜ける
システムは次のどれに当たっても、stdout と stderr に何も出さず終了コード 0 で終わ MUST る: コマンドが対象外 / `gh` か `python3` が無い / `cost_ledger.py` が失敗する / GitHub に届かない・`gh` が失敗する。終了コード 2 を返してはなら MUST NOT ない。hook の失敗でゲートを止めず、文脈にも何も入れないため。

#### Scenario: `gh` が失敗する
- **WHEN** `gh` がすべて失敗する環境で付与コマンドの hook JSON を流す
- **THEN** stdout は空で、終了コードは 0

#### Scenario: 集計が失敗する
- **WHEN** `cost_ledger.py timeline` が 0 以外で終わる状況で付与コマンドの hook JSON を流す
- **THEN** コメントの作成も書き換えも行われず、stdout は空で、終了コードは 0

## REMOVED Requirements

### Requirement: 貼る数字は `/cost` と同じ入口から取る
**Reason**: 貼るものが合計の 1 行から、行を積んだ本文に変わった。数字と書式は `cost_ledger.py timeline` が持つ。
**Migration**: `cost-ledger-timeline` の「数字と書式は `timeline` サブコマンドから取る」に置き換える。コメントの 1 行目が `/cost` の 1 行目と一致する性質、`transcript_path` を使わないこと、サブエージェントの中で付与しても動くことは、そちらで保つ。

### Requirement: 貼る形はマーカー付きのコメント 1 本
**Reason**: 最新の合計で書き換える形では途中経過が残らない。主の決定（#303）で、1 本のコメントに節目ごとに行を積む形にした。
**Migration**: `cost-ledger-timeline` の「1 本のコメントに行を積む」に置き換える。ゲート通過は同じコメントに `ゲート通過` の行として積まれる。目印は `<!-- cost-ledger:timeline` に変わり、古い目印 `<!-- cost-ledger:gate-report -->` のコメントは残したまま触らない。

### Requirement: 投稿するのはゲート通過のときだけ
**Reason**: きっかけを PR / issue へのコメントと状態の変更に広げた（#303）。
**Migration**: きっかけの集合は `cost-ledger-timeline` の「行を積むきっかけ」が定める。台帳への焼き付け（Stop hook）と役割を混ぜない点は変わらない（この hook は台帳を読む前の差分追記を除いて台帳に書かない）。
