## MODIFIED Requirements

### Requirement: サブエージェントのコンテキスト量の母集団集計

`plugins/dev-workflow/scripts/subagent-context-audit.sh` は、直近 N 日（`--days`、既定 14）のサブエージェントのトランスクリプトを走査し、母集団の統計を 1 行 JSON で標準出力に出さなければならない（SHALL）。JSON は次のキーを含む（SHALL）: `count`（対象件数）/ `first_median` / `first_max`（初回コンテキストの中央値・最大）/ `last_median` / `last_max`（最終コンテキストの中央値・最大）/ `over_cap_pct`（最終コンテキストが上限を超えた件数の割合、0〜100）/ `cap` / `days` / `sources` / `generated_at`。

`sources` は隔離の有無で分けた統計であり、`isolated`（`isolation: "worktree"` で起こしたもの）と `non_isolated` のそれぞれが `count` / `first_median` / `last_median` / `over_cap_pct` を持たなければならない（MUST）。件数だけの内訳にしてはならない（MUST NOT。隔離の有無は役割と相関して母集団の性質が異なるため、構成比が動いただけの変化と固定分そのものの増加を読み手が後から切り分けられる必要がある）。傾向判断の主系列は全体の `first_median` とし、`sources` はその切り分けに使う。

集計の母数は 2 種類あり、一致しない場合がある。`sources.isolated.count` と `sources.non_isolated.count` の合計は全体の `count` と一致しなければならない（MUST。分類できない件も母集団から落とさず `non_isolated` に寄せるため）。一方で `last_median` / `last_max` / `over_cap_pct` は**最終コンテキストが見つかった件だけ**を母数とし（窓を上限まで広げても `usage` 付きレコードが見つからない件は最終側の集計から除くため）、その母数は全体の `count` 以下になる（SHALL）。

1 体のコンテキスト量の定義は `subagent-context.sh` と同一で、assistant レコードの `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` でなければならない（MUST）。初回はファイル先頭から最初に現れた `usage` 付き assistant レコード、最終は末尾から遡って最初に見つかる同レコードとする（SHALL）。上限は `--cap` または `DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）を用いる（SHALL）。中央値は偶数件のとき中央 2 値の平均を四捨五入した整数とする（SHALL）。

走査対象は projects ディレクトリ（既定 `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-~/.claude}/projects}`。`--projects DIR` で差し替えられる）配下の `*/*/subagents/agent-*.jsonl` の 1 経路に限らなければならない（MUST）。`isolation: "worktree"` で起こしたサブエージェントも同じ場所に置かれ、隔離によって変わるのはファイル名だけである（隔離ありは名前が載らず `agent-<agentId>.jsonl`、隔離なしは `agent-a<name>-<hash>.jsonl`）。したがってこの 1 経路で隔離エージェントも自然に含まれる。`subagents/` の外にあるトランスクリプト（メインセッション、および worktree の中から起動された入れ子の `claude` セッション。project ディレクトリ名が `*--claude-worktrees-agent-*` に一致するものを含む）は、サブエージェントではないので集計に含めてはならない（MUST NOT）。Workflow 経由で起こしたサブエージェント（`subagents/workflows/<wf-id>/agent-*.jsonl`）は `subagents/` の内側にあるが、固定深さのこの 1 経路に当たらないので母集団に含めない（MUST NOT）。

隔離の有無の分類は、同じディレクトリの `agent-<id>.meta.json` の `spawnedWithWorktree` が `true` かどうかで行う（SHALL）。meta.json が無い・読めない場合は `non_isolated` に数える（SHALL。ファイル名からの推定は行わない）。分類できないことを理由にその 1 件を全体の `count` から落としてはならない（MUST NOT）。

対象期間の判定はファイルの mtime で行う（SHALL。レコード内のタイムスタンプは見ない）。

トランスクリプトの全文を読んではならない（MUST NOT）。**ただし `--by-role` を指定した場合を除く**（この場合は「担当分類の優先順位」「`docs_median`」「`reread_pct`」の算出に加え、全体キー・`sources`・担当別の初回および最終コンテキストの判定にも全文走査の値を使う（SHALL）。部分読みである既定呼び出しの値とは僅かにずれうる）。`--by-role` を指定しない場合、初回は最初の `usage` 付きレコードで読み取りを打ち切り、最終は末尾から固定サイズの窓（既定 256 KiB）を読んで見つからなければ上限（4 MiB）まで窓を倍加し、それでも見つからない 1 件は最終側の集計から除く（SHALL）。

集計結果は `${SUBAGENT_CONTEXT_AUDIT_CACHE:-${CLAUDE_CONFIG_DIR:-~/.claude}/.subagent-context-audit}` に 1 行 JSON で保存しなければならない（MUST）。**ただし `--cache` を明示しない場合、`--by-role` を指定したときは既定パスに `.by-role` サフィックスを足したパス（`${SUBAGENT_CONTEXT_AUDIT_CACHE:-${CLAUDE_CONFIG_DIR:-~/.claude}/.subagent-context-audit}.by-role`）に保存する（SHALL。既定呼び出しと `--by-role` の集計内容が異なるため、同じキャッシュファイルを共有すると TTL 内でどちらかの結果が誤って返るのを避ける）。`--cache` を明示した場合はそのパスにそのまま保存する（`--by-role` の有無でサフィックスを足さない。呼び出し側が衝突を自分で管理する前提）。** キャッシュの mtime が `SUBAGENT_CONTEXT_AUDIT_TTL`（秒、既定 21600）以内なら、トランスクリプトを走査せずキャッシュの内容をそのまま出力する（SHALL）。`--refresh` は TTL を無視して再走査する（SHALL）。

この集計は観測専用であり、閾値に基づいてセッション・ツール・エージェントの実行を止めてはならない（MUST NOT。強制停止は別の仕組みが担う）。引数エラー以外はすべて exit 0 とし、トランスクリプトが 1 件も無い・projects ディレクトリが無い・`python3` が無い場合は `count` が 0 の結果を出して exit 0 で終わらなければならない（MUST。fail-open）。個々のレコードの JSON が壊れていても、その行を飛ばして他の件の集計を続けなければならない（MUST）。

この集計の守備範囲は次のとおりとする（SHALL）。①入力の出どころ: 対象は利用者の `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-~/.claude}/projects}/*/*/subagents/agent-*.jsonl` と、同じ場所の `agent-<id>.meta.json`（Claude Code が書く）で、中身は Claude Code の出力形式に従う。②拾いたい誤り: サブエージェント以外のトランスクリプトや対象期間外の個体を数えること、壊れたレコードや `meta.json` の欠落で集計全体が落ちること、分類できない個体が母集団の合計から落ちること。③通ることを許す入力の具体例: `meta.json` が無い・読めない個体は隔離なしとして `non_isolated` に数えてよく、`--by-role` の全文走査と既定の部分読みで全体キーが僅かにずれてよい。④未知の形式のトランスクリプトを見つけるたびに規則を足して塞ぎ切ることは、この要件の完了条件にしない。

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
- **THEN** そのファイルは全体の `count` に含まれたまま `sources.non_isolated` に数えられ、`sources.isolated.count` と `sources.non_isolated.count` の合計は全体の `count` と一致する

#### Scenario: `--by-role` 指定時のみ全文走査が許される

- **WHEN** `--by-role` を付けて `subagent-context-audit.sh` を実行する
- **THEN** 担当分類・`docs_median`・`reread_pct` の算出のためにトランスクリプトの全文が前方から走査され、全体キー・`sources`・担当別の初回および最終コンテキストの判定にもその値が使われる。既定呼び出しの部分読みとは値が僅かにずれうる

#### Scenario: 既定と `--by-role` でキャッシュファイルが分かれる

- **GIVEN** `--cache` と `SUBAGENT_CONTEXT_AUDIT_CACHE` を指定せずに `subagent-context-audit.sh` と `subagent-context-audit.sh --by-role` を同じ環境で実行する（キャッシュの基点 `${CLAUDE_CONFIG_DIR:-~/.claude}` を <基点> と呼ぶ）
- **WHEN** それぞれの実行後にキャッシュファイルを見る
- **THEN** 既定の実行は `<基点>/.subagent-context-audit` に、`--by-role` の実行は `<基点>/.subagent-context-audit.by-role` に、それぞれ別ファイルとして結果が保存される

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

#### Scenario: CLAUDE_CONFIG_DIR の下の会話記録を集計する
- **GIVEN** `CLAUDE_PROJECTS_DIR` が未設定で、`CLAUDE_CONFIG_DIR` が指す一時ディレクトリの `projects/<project>/<session>/subagents/agent-*.jsonl`（対象期間内）に usage 付きのトランスクリプトがあり、`HOME` の下には無い。キャッシュは `--refresh` を付けて無効化する
- **WHEN** `subagent-context-audit.sh --refresh` を `--projects` なしで実行する
- **THEN** `CLAUDE_CONFIG_DIR` の下のトランスクリプトを走査し、`count` が 1 以上になる

#### Scenario: キャッシュの既定が CLAUDE_CONFIG_DIR の下になる
- **GIVEN** `SUBAGENT_CONTEXT_AUDIT_CACHE` と `--cache` が未指定で、`CLAUDE_CONFIG_DIR` が一時ディレクトリを指す
- **WHEN** `subagent-context-audit.sh` を実行する
- **THEN** 集計結果は `<CLAUDE_CONFIG_DIR>/.subagent-context-audit` に保存され、`HOME` の下には作られない
