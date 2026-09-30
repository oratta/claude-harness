## MODIFIED Requirements

### Requirement: issue による帰属（第 2 の鍵）
issue 番号はリポジトリ内でしか一意でないため、システムは第 2 の帰属の鍵を **（リポジトリ識別子, issue 番号）の組** と SHALL する。issue 番号だけを鍵にしてはなら MUST NOT ない。

issue 番号は各行の `Bash` ツールの `command` から、`gh issue view`・`gh issue comment`・`gh issue edit`・`gh issue close`・`gh issue develop` に渡された番号として拾 SHALL う。拾うこの 5 つのサブコマンドは設計の根拠になった計測（測り方と数字は archive 済みの change `cost-ledger-aggregation` の design に記録。計測スクリプトは change `cost-ledger-gate-report` で削除した）と一致させるが、走査する場所は**実行されたコマンド**に限 SHALL る。その計測はツール呼び出しの入力全体を文字列にして当てていたため、サブエージェントへの指示文やファイル編集の中身に書かれた `gh issue view <番号>` という文字列にも反応した。実行していないコマンドの文字列を根拠に帰属させてはなら MUST NOT ない。

#### Scenario: 実行していないコマンドの文字列は帰属しない
- **WHEN** `Agent` の指示文や `Edit`・`Write` の本文に `gh issue view 999` という文字列が含まれるが、そのコマンドは実行されていない
- **THEN** その行は issue 999 に帰属しない

#### Scenario: 別リポジトリの同じ番号が混ざらない
- **WHEN** リポジトリ A の issue 108 とリポジトリ B の issue 108 の両方に行が存在する
- **THEN** それぞれの組は別の帰属先として扱われ、合算されない

#### Scenario: main 上の作業が issue に帰属する
- **WHEN** main ブランチ上のセッションで `gh issue comment 148` が実行されている
- **THEN** そのセッションの該当区間のコストは、そのリポジトリの issue 148 へ帰属する

#### Scenario: close と develop も鍵になる
- **WHEN** セッション中に `gh issue close 273` または `gh issue develop 273` だけが実行されている
- **THEN** その区間は issue 273 へ帰属する

#### Scenario: issue 番号を一度も触っていないセッション
- **WHEN** セッション中に上記 5 つのコマンドが一度も実行されていない
- **THEN** そのセッションのコストはどの issue にも帰属せず、未帰属として扱われる

### Requirement: セッションごとの区間分割
1 セッションが複数の issue を触るため、システムはコストを区間に分割して帰属させ MUST る。区間は **`sessionId` ごとに `timestamp` 順に並べて**切 MUST る。ブランチ全体を時刻順に並べて切ってはなら MUST NOT ない。利用者は複数セッションを並行して走らせるため、ブランチ単位で並べると別セッションの行が互いの区間に混ざる。

区間の境界は投稿とし、投稿は `gh pr comment`・`gh issue comment`・`gh pr create`・`gh pr ready` の 4 つと SHALL する。この 4 つは設計の根拠になった計測（測り方と数字は archive 済みの change `cost-ledger-aggregation` の design に記録）が境界にしていた集合と一致させる。区間ごとに、その区間で直近に触った issue へコストを寄せる。

ブランチの総額は、そのブランチに属する各セッションの区間の合計を足したものと SHALL する。

#### Scenario: 1 セッションが複数 issue を触る
- **WHEN** 1 セッションで issue 148 に投稿したあと issue 213 に投稿している
- **THEN** 最初の投稿までの区間は issue 148 へ、そのあとの区間は issue 213 へ帰属する

#### Scenario: 並行する 2 セッションの区間が混ざらない
- **WHEN** 同じブランチで 2 つのセッションが時刻の重なる区間を持つ
- **THEN** 区間は `sessionId` ごとに切られ、一方の投稿が他方の区間を区切ることはない

#### Scenario: Draft から Ready への切り替えが境界になる
- **WHEN** セッション中に `gh pr ready 271` が実行されている
- **THEN** その行は区間の境界として扱われる

#### Scenario: 区間の合計がブランチの総額と一致する
- **WHEN** あるブランチの区間ごとのコストをすべて足す
- **THEN** その合計はそのブランチの総額と一致する（丸め誤差を除く）
