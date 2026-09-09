## ADDED Requirements

### Requirement: サブエージェントのコンテキスト量の母集団集計

`plugins/dev-workflow/scripts/subagent-context-audit.sh` は、直近 N 日（`--days`、既定 14）のサブエージェントのトランスクリプトを走査し、母集団の統計を 1 行 JSON で標準出力に出さなければならない（SHALL）。JSON は次のキーを含む（SHALL）: `count`（対象件数）/ `first_median` / `first_max`（初回コンテキストの中央値・最大）/ `last_median` / `last_max`（最終コンテキストの中央値・最大）/ `over_cap_pct`（最終コンテキストが上限を超えた件数の割合、0〜100）/ `cap` / `days` / `sources` / `generated_at`。

`sources` は隔離の有無で分けた統計であり、`isolated`（`isolation: "worktree"` で起こしたもの）と `non_isolated` のそれぞれが `count` / `first_median` / `last_median` / `over_cap_pct` を持たなければならない（MUST）。件数だけの内訳にしてはならない（MUST NOT。隔離の有無は役割と相関して母集団の性質が異なるため、構成比が動いただけの変化と固定分そのものの増加を読み手が後から切り分けられる必要がある）。傾向判断の主系列は全体の `first_median` とし、`sources` はその切り分けに使う。

1 体のコンテキスト量の定義は `subagent-context.sh` と同一で、assistant レコードの `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` でなければならない（MUST）。初回はファイル先頭から最初に現れた `usage` 付き assistant レコード、最終は末尾から遡って最初に見つかる同レコードとする（SHALL）。上限は `--cap` または `DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）を用いる（SHALL）。中央値は偶数件のとき中央 2 値の平均を四捨五入した整数とする（SHALL）。

走査対象は `${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/*/*/subagents/agent-*.jsonl` の 1 経路に限らなければならない（MUST）。`isolation: "worktree"` で起こしたサブエージェントも同じ場所に置かれ、隔離によって変わるのはファイル名だけである（隔離ありは名前が載らず `agent-<agentId>.jsonl`、隔離なしは `agent-a<name>-<hash>.jsonl`）。したがってこの 1 経路で隔離エージェントも自然に含まれる。`subagents/` の外にあるトランスクリプト（メインセッション、および worktree の中から起動された入れ子の `claude` セッション。project ディレクトリ名が `*--claude-worktrees-agent-*` に一致するものを含む）は、サブエージェントではないので集計に含めてはならない（MUST NOT）。

隔離の有無の分類は、同じディレクトリの `agent-<id>.meta.json` の `spawnedWithWorktree` が `true` かどうかで行う（SHALL）。meta.json が無い・読めない場合はファイル名のパターンで分類し、それも判定できなければ `non_isolated` に数える（SHALL）。分類できないことを理由にその 1 件を全体の `count` から落としてはならない（MUST NOT）。

対象期間の判定はファイルの mtime で行う（SHALL。レコード内のタイムスタンプは見ない）。

トランスクリプトの全文を読んではならない（MUST NOT）。初回は最初の `usage` 付きレコードで読み取りを打ち切り、最終は末尾から固定サイズの窓（既定 256 KiB）を読んで見つからなければ上限（4 MiB）まで窓を倍加し、それでも見つからない 1 件は最終側の集計から除く（SHALL）。

集計結果は `${SUBAGENT_CONTEXT_AUDIT_CACHE:-~/.claude/.subagent-context-audit}` に 1 行 JSON で保存しなければならない（MUST）。キャッシュの mtime が `SUBAGENT_CONTEXT_AUDIT_TTL`（秒、既定 21600）以内なら、トランスクリプトを走査せずキャッシュの内容をそのまま出力する（SHALL）。`--refresh` は TTL を無視して再走査する（SHALL）。

この集計は観測専用であり、閾値に基づいてセッション・ツール・エージェントの実行を止めてはならない（MUST NOT。強制停止は別の仕組みが担う）。引数エラー以外はすべて exit 0 とし、トランスクリプトが 1 件も無い・projects ディレクトリが無い・`python3` が無い場合は `count` が 0 の結果を出して exit 0 で終わらなければならない（MUST。fail-open）。個々のレコードの JSON が壊れていても、その行を飛ばして他の件の集計を続けなければならない（MUST）。

#### Scenario: 直近 14 日の集計が 1 行 JSON で出る

- **WHEN** 対象期間内に名前付きサブエージェントのトランスクリプトが複数存在する状態で `subagent-context-audit.sh` を実行する
- **THEN** `count` / `first_median` / `first_max` / `last_median` / `last_max` / `over_cap_pct` / `cap` / `days` / `sources` / `generated_at` を含む 1 行 JSON が出力され、exit 0 になる

#### Scenario: worktree 隔離のエージェントが集計に含まれる

- **WHEN** `subagents/` に、隔離ありのトランスクリプト（`agent-<agentId>.jsonl` と `spawnedWithWorktree: true` を持つ meta.json）と隔離なしのトランスクリプト（`agent-a<name>-<hash>.jsonl`）が混在している
- **THEN** 両方とも `count` に含まれ、前者は `sources.isolated`、後者は `sources.non_isolated` の `count` / `first_median` / `last_median` / `over_cap_pct` に反映される

#### Scenario: サブエージェント以外のトランスクリプトは数えない

- **WHEN** project ディレクトリ名が `--claude-worktrees-agent-<hash>` で終わるディレクトリの直下に `<uuid>.jsonl`（worktree の中から起動された入れ子の `claude` セッション）がある
- **THEN** そのファイルは `count` にも `sources` のどちらにも含まれない

#### Scenario: meta.json が無くても集計は落ちない

- **WHEN** 対象トランスクリプトの隣に meta.json が無い、またはその中身が壊れている
- **THEN** そのファイルは全体の `count` に含まれたまま、ファイル名のパターンで分類され、判定できなければ `sources.non_isolated` に数えられる

#### Scenario: 対象期間外のトランスクリプトは数えない

- **WHEN** mtime が `--days` の窓より古いトランスクリプトが projects ディレクトリにある
- **THEN** そのファイルは `count` にも `sources` のどちらの経路にも含まれない

#### Scenario: トランスクリプトが 1 件も無い環境

- **WHEN** projects ディレクトリが空、または存在しない状態で実行する
- **THEN** `count` が 0 の結果を出力して exit 0 で終わる（エラー終了しない）

#### Scenario: 一部のレコードが壊れていても集計が続く

- **WHEN** 対象トランスクリプトの一部に JSON として解釈できない行が混ざっている
- **THEN** その行は無視され、残りのレコードと他のファイルから統計が算出され、exit 0 になる

#### Scenario: 上限超の割合が出る

- **WHEN** 対象のうち最終コンテキストが `cap` を超えるものがある
- **THEN** `over_cap_pct` がその割合（0〜100）として出力される

#### Scenario: TTL 内はキャッシュを返す

- **WHEN** キャッシュファイルの mtime が `SUBAGENT_CONTEXT_AUDIT_TTL` 以内の状態で集計を実行する
- **THEN** トランスクリプトを走査せずキャッシュの内容をそのまま出力する。`--refresh` を付けた場合は TTL を無視して再走査し、キャッシュを更新する

### Requirement: 集計結果の永続化と監査手順の文書

サブエージェントのコンテキスト量の監査手順は `plugins/dev-workflow/docs/usage-audit.md` を正本としなければならない（SHALL）。この文書は次を含む（SHALL）: ① 集計スクリプト `subagent-context-audit.sh` の実行コマンド（`--days` / `--cap` / `--refresh` の使い方を含む）② 出力キーの意味（`first_median` / `last_median` / `over_cap_pct` / `sources` の隔離別統計）③ 何を見たら固定分が増えたと判断するか（全体の `first_median` の推移を主系列とし、動いたときは `sources` で母集団の構成変化と切り分ける）④ 集計結果が残るキャッシュファイルの場所。

この監査の出力先を SessionStart hook（`scripts/session-tripwires.sh`）の注入内容に足してはならない（MUST NOT）。SessionStart への注入は全セッション・全サブエージェントの起動時固定分を増やす側の変更であり、固定分の増加を止めるという目的に反するため、観測の経路はキャッシュファイルと文書にとどめる。既存の残量モード導出・共有枠モード導出・`subagent-context.sh` の要件は変更しない（MUST NOT）。

#### Scenario: 監査手順が文書からたどれる

- **WHEN** 固定分が増えていないかを確認したい人が `plugins/dev-workflow/docs/usage-audit.md` を読む
- **THEN** 実行コマンド・出力キーの意味・増加と判断する基準・キャッシュファイルの場所が揃っており、他のファイルを見ずに監査を 1 回回せる

#### Scenario: 集計結果が機械可読な形で残る

- **WHEN** 集計を 1 回実行したあとにキャッシュファイルを読む
- **THEN** 直近の集計結果が 1 行 JSON として残っており、そのまま別のツールに渡せる

#### Scenario: SessionStart の注入内容は増えない

- **WHEN** この change の実装後にセッションを開始する
- **THEN** `session-tripwires.sh` が注入する内容は従来どおりで、集計に由来する行は 1 行も増えていない
