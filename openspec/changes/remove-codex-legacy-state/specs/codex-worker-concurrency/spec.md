## REMOVED Requirements

### Requirement: アカウント単位の同時実行数は設定で決まる
**Reason**: account slot は SQLite ownership と lifecycle job の占有状態に依存し、前景実行ではどちらも存在しないため capability ごと廃止する。

**Migration**: canonical coordinator が 1 worktree に 1 件ずつ割り当てる。account 単位の共通上限が将来必要なら、Codex 専用の registry を戻さず Claude 側と共通の仕組みとして設計する。

#### Scenario: 前景実行を同じ account へ複数起動する
- **WHEN** 呼び出し側が同じ account の前景実行を複数起動する
- **THEN** worker は永続 slot を数えず、呼び出し側が並行数を管理する

### Requirement: 作業ディレクトリ単位の排他は変わらない
**Reason**: cwd 排他は未受領 job と共有 ownership store に依存し、Claude サブエージェントにも対応する worker lock がないため廃止する。

**Migration**: canonical coordinator が専用 worktree を割り当て、同じ worktree に書く role を同時起動しない。

#### Scenario: 同じ作業ディレクトリへ 2 件起動する
- **WHEN** 呼び出し側が同じ cwd を指す前景実行を 2 件起動する
- **THEN** worker は lock 状態を作らず、どちらも cwd 排他を理由には拒否しない

### Requirement: 残枠の判定は同時実行本数ぶんの余裕を要求する
**Reason**: 占有 slot 数を掛ける計算は削除する ownership store に依存するため廃止する。

**Migration**: `codex-worker` の foreground quota preflight が、依頼 1 件と `quota_margin_pct` に対して利用枠を検査する。

#### Scenario: 前景実行の利用枠を確認する
- **WHEN** 1 件の前景実行がターン開始前に利用枠を確認する
- **THEN** 同時実行数を 1 として余裕率を検査し、他の job や slot を参照しない

### Requirement: サーバーが開始を拒否したら理由を残して停止する
**Reason**: failed/unknown の job 状態と ownership 保持は永続 job transport 専用なので廃止する。サーバー拒否そのものの処理は `codex-worker` の 1 行 JSON 契約に統合済みである。

**Migration**: app-server の拒否コードを `error_kind` に含めて非ゼロで終了し、自動再試行も別 account への振替もしない。

#### Scenario: サーバーが開始を拒否する
- **WHEN** thread/start または turn/start がエラー応答を返す
- **THEN** worker は理由を含む 1 行 JSON を返して非ゼロで終了し、永続 job 状態を作らない

### Requirement: 放置されたアカウント側の占有を外す手段がある
**Reason**: 前景実行は account slot を取得せず、解放対象となる永続占有がないため reap 操作を廃止する。

**Migration**: 停止は起動した foreground command を止める。過去の state directory は利用者が安全確認後に手動削除する。

#### Scenario: reap を呼び出す
- **WHEN** 利用者が廃止済みの reap subcommand を指定する
- **THEN** 引数解析で拒否し、過去の state directory を変更しない
