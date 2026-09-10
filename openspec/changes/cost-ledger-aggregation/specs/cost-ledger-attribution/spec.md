## ADDED Requirements

### Requirement: 会話ログの読み取りと重複排除
システムは Claude Code の会話ログ（`~/.claude/projects/**/*.jsonl`）を読み、アシスタントメッセージの行からトークン内訳を集計 SHALL する。同一の行が複数のファイルに現れることがあるため、`requestId` を鍵として重複を排除 MUST する。

#### Scenario: 同じ requestId が複数ファイルに現れる
- **WHEN** 同一の `requestId` を持つ行が 2 つ以上のログファイルに存在する
- **THEN** その行のトークンは 1 回だけ集計される

#### Scenario: ログのルートが環境で異なる
- **WHEN** 会話ログの置き場所が既定（`~/.claude/projects`）と異なる
- **THEN** 置き場所は環境変数で解決され、リポジトリ内のファイルに固定パスが書かれていない

### Requirement: ブランチによる帰属（第 1 の鍵）
システムは各行の `gitBranch` を第 1 の帰属の鍵と SHALL する。サブエージェントの行（`isSidechain: true`）にも `gitBranch` が入るため、サブエージェントの消費も同じブランチへ帰属 MUST する。

#### Scenario: サブエージェントの行を含めて集計する
- **WHEN** あるブランチのコストを求め、そのブランチに `isSidechain: true` の行が含まれている
- **THEN** サブエージェントの行のトークンも合計に含まれる

#### Scenario: gitBranch を持たない行
- **WHEN** 行に `gitBranch` が無い、または空文字である
- **THEN** その行はブランチへ帰属せず、集計から静かに落ちずに未帰属として扱われる

### Requirement: worktree の親リポジトリへの畳み込み
システムは各行の `cwd` から `git -C <cwd> rev-parse --git-common-dir` を用いてリポジトリを特定し、worktree のコストを親リポジトリへ畳み込 MUST む。

#### Scenario: worktree 上の作業を親リポジトリに寄せる
- **WHEN** `cwd` が親リポジトリの worktree を指している
- **THEN** そのコストは worktree ごとではなく親リポジトリの集計に含まれる

#### Scenario: cwd が既に存在しない
- **WHEN** `cwd` のディレクトリが削除済みで `git rev-parse` が失敗する
- **THEN** 集計は中断せず、その行は `cwd` の文字列そのものをリポジトリの識別子として扱う

### Requirement: issue 番号による帰属（第 2 の鍵）
システムは各行の `message.content[].input.command` を走査し、`gh issue view`・`gh issue comment`・`gh issue edit` に渡された issue 番号を第 2 の帰属の鍵と SHALL する。ブランチだけでは main 上の作業が帰属先を持たないため、この鍵が必要である。

#### Scenario: main 上の作業が issue に帰属する
- **WHEN** main ブランチ上のセッションで `gh issue comment 148` が実行されている
- **THEN** そのセッションの該当区間のコストは issue 148 へ帰属する

#### Scenario: issue 番号を一度も触っていないセッション
- **WHEN** セッション中に `gh issue view/comment/edit` が一度も実行されていない
- **THEN** そのセッションのコストはどの issue にも帰属せず、未帰属として扱われる

### Requirement: 投稿から投稿までの区間分割
1 セッションが複数の issue を触るため、システムはセッションを投稿（`gh pr comment` / `gh issue comment` / `gh pr create`）から投稿までの区間に分割し、区間ごとに直近に触った issue へコストを寄せ MUST る。

#### Scenario: 1 セッションが複数 issue を触る
- **WHEN** 1 セッションで issue 148 に投稿したあと issue 213 に投稿している
- **THEN** 最初の投稿までの区間は issue 148 へ、そのあとの区間は issue 213 へ帰属する

#### Scenario: 区間の合計がセッションの合計と一致する
- **WHEN** あるブランチの区間ごとのコストをすべて足す
- **THEN** その合計はそのブランチの総額と一致する（丸め誤差を除く）
