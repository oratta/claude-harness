## Context

`plugins/dev-workflow/scripts/subagent-context.sh` は「名前で指定した 1 体が今いくら読んでいるか」を測る。母集団の傾向（起動直後の固定分が増えていないか、上限 150,000 を超えて手渡しになる割合が増えていないか）は測る手段が無く、2026-09-09 のレビューセッションでは使い捨ての Python スクリプト（`analyze_agents.py`）で 44 体を手集計した。この change はその集計を常設化する。

現状の関係する部品は 3 つ:

- `scripts/usage-probe.sh` — OAuth usage API を叩き、`~/.claude/.usage-snapshot`（`fable_weekly_pct` / `weekly_all_pct` / `weekly_resets_epoch`）を 5 分キャッシュで書く。
- `scripts/session-tripwires.sh` — SessionStart hook。usage-probe を best-effort 実行し、snapshot から残量モードを導出して `additionalContext` にブロックを注入する。既に「サブエージェントのコンテキスト上限」の 1 行がここに載っている。
- `scripts/subagent-context.sh` — 1 体の実測。

トランスクリプトの置き場は実測で 2 系統ある:

| 系統 | パス | 名前 |
|---|---|---|
| 名前付きサブエージェント | `~/.claude/projects/<encoded-cwd>/<session-uuid>/subagents/agent-*.jsonl` | ファイル名に agent 名が入る |
| `isolation: "worktree"` のサブエージェント | `~/.claude/projects/<encoded-worktree-path>/<session-uuid>.jsonl` | agent 名も agentId も残らない |

後者の project ディレクトリ名は worktree のパスをエンコードしたもので、Agent ツールが作る worktree のパス規約（`<repo>/.claude/worktrees/agent-<hash>`）から必ず `--claude-worktrees-agent-<hash>` で終わる。実機（2026-09-09 時点）で 51 ディレクトリを確認した。これが #257 で「glob や agentId では直らない」とされた経路を、集計目的に限って拾える唯一の安価な手掛かりになる。

## Goals / Non-Goals

**Goals:**

- 直近 N 日（既定 14 日）のサブエージェントについて、件数 / 初回コンテキストの中央値・最大 / 最終コンテキストの中央値・最大 / 上限超の割合を 1 行 JSON で出す。
- `isolation: "worktree"` のサブエージェントを集計対象に含める。
- その値を既存の usage 監査の出力（SessionStart の注入ブロック）に載せ、固定分の増加に気づけるようにする。
- どの失敗経路でもセッション開始を妨げない（fail-open）。

**Non-Goals:**

- 閾値による強制停止・警告以上の介入（#261 が扱う）。この change は通知・記録だけで、判定に基づく分岐を一切足さない。
- 固定分そのものの削減（#260）、編集時の予算ゲート（#258）。
- `subagent-context.sh` が worktree 隔離の W を名前で見つけられない問題（#243）の解決。集計は母集団を数えるだけで、名前解決はしない。
- 履歴の保存・時系列グラフ。出すのはその時点のスナップショット 1 行で、時系列は将来必要になってから足す。

## Decisions

### 1. usage-probe.sh を拡張せず、独立したスクリプトにする

`plugins/dev-workflow/scripts/subagent-context-audit.sh` を新設する。

- **理由**: usage-probe.sh はネットワーク（OAuth usage API）が入力で、`~/.claude/.usage-snapshot` を atomic に書く 5 分キャッシュの部品である。14 日分のローカルファイル走査は入力・コスト・失敗の仕方がまったく違う（ネットワーク断ではなくファイル数と I/O で遅くなる）。同居させると、遅い走査が snapshot の鮮度を巻き込み、片方の失敗がもう片方を止める。
- **却下案**: usage-probe.sh に `subagent_context` キーを足して `.usage-snapshot` に同居させる。snapshot の読み手（session-tripwires の残量導出、agent-model-guard の共有枠判定）が増えたキーで壊れることはない（いずれも `.get()`）が、5 分 TTL が 14 日窓の走査を毎回誘発する。

### 2. 出力先は session-tripwires.sh の注入ブロック。機械可読な記録はスクリプト自身のキャッシュファイル

session-tripwires.sh が `subagent-context-audit.sh` を best-effort で実行し、既存の「サブエージェントのコンテキスト上限」の行の隣に実測を並べる。

- **理由**: 上限の説明が既にそこにあり、実測を同じ場所に置くと「上限 150,000 に対して実際どうなっているか」が 1 か所で読める。別レポートを新設すると誰も見ない。
- 機械可読な記録は `${SUBAGENT_CONTEXT_AUDIT_CACHE:-~/.claude/.subagent-context-audit}`（1 行 JSON）。集計結果はここに残るので、後から `cat` で読める＝受け入れ条件の「監査の出力に載る」を snapshot 側でも満たす。
- **却下案**: 定期レポート（daily-report）に載せる。日次レポートは人が読む文書で、開発中のセッションが即座に参照できない。

### 3. キャッシュ TTL は既定 6 時間

`SUBAGENT_CONTEXT_AUDIT_TTL`（秒、既定 21600）。キャッシュファイルの mtime が TTL 以内なら再走査せず中身をそのまま返す。`--refresh` で強制再走査。

- **理由**: 14 日窓の中央値は数時間では意味のある動きをしない。一方 SessionStart は 1 日に何十回も走る。usage-probe の 5 分より長く取るのは、走査コストがネットワーク 1 往復より大きいため。

### 4. トランスクリプトの全文を読まない

- 初回コンテキスト: 先頭から順に読み、**最初に現れた `usage` 付き assistant レコード**で読むのをやめる。
- 最終コンテキスト: ファイル末尾から固定サイズ（既定 256 KiB）の窓を読み、後ろから最初に見つかる `usage` 付き assistant レコードを使う。見つからなければ窓を倍にして最大 4 MiB まで広げ、それでも無ければその 1 件を「最終不明」として件数から外す（初回だけ数える）。
- **理由**: 1 体のトランスクリプトが数百 MB になる実績がある。全文読みは SessionStart hook に載せられない。
- **却下案**: `tac`／逆順読みライブラリ。python3 標準だけで書く方針（`subagent-context.sh` と同じ依存）を崩さない。

### 5. 対象期間はファイルの mtime で切る

`--days N`（既定 14）は各トランスクリプトファイルの mtime で判定する。レコード内のタイムスタンプは見ない。

- **理由**: mtime は `stat` 1 回で取れ、走査対象を開く前に絞れる。レコードの時刻で切るとファイルを開かないと判定できず、絞り込みの意味が消える。
- **トレードオフ**: 長時間走り続けた 1 体は最終書き込み時刻で分類されるため、窓の境界付近で数日ずれる。観測目的では許容する。

### 6. worktree 隔離の判別はディレクトリ名の規約に依る

project ディレクトリ名が `*--claude-worktrees-agent-*` に一致すれば、その直下の `*.jsonl` を「worktree 隔離のサブエージェント」として集計に含める。

- **理由**: 名前も agentId もレコードに残らない以上、パス規約が唯一の手掛かり。実機で 51 ディレクトリを確認済み。
- **既知の誤差**: その worktree で人間が手動で `claude` を起動した対話セッションも同じ場所に落ちるため、母集団に混ざる。**過大計上に倒れる**（サブエージェントでないものを数える）方向で、観測専用の指標としては安全側。出力に `sources` の内訳（`named` / `worktree`）を含め、誤差の大きさを見えるようにする。
- **却下案**: レコードの内容（system prompt に含まれる agent 指示など）で分類する。全ファイルの先頭を開く必要があり、絞り込みの利点を失う。

### 7. コンテキスト量の定義は `subagent-context.sh` と揃える

`input_tokens + cache_creation_input_tokens + cache_read_input_tokens`。中央値は偶数件のとき中央 2 値の平均を四捨五入した整数。

- **理由**: 2 つの指標が別定義だと、1 体の実測と母集団の実測を突き合わせられない。

### 8. 失敗はすべて exit 0 の空結果

引数エラーだけ exit 1。トランスクリプト 0 件・`~/.claude/projects` が無い・`python3` が無い・JSON が壊れているは、いずれも `{"count":0,...}`（と `note` フィールド）を出して exit 0。session-tripwires 側は `count` が 0 なら実測の行を注入しない。

- **理由**: SessionStart hook から呼ばれる。ここで非 0 を返して hook を落とすと、同じ hook が注入している昇格トリップワイヤーごと消える。
- **`subagent-context.sh` との違い**: あちらは「上限超か」の判定に使われるので exit 2 / 1 に意味がある。こちらは観測専用で、呼び出し側に判定させない（Decision 1 の Non-Goal と同じ理由）。

## Risks / Trade-offs

- **[SessionStart が重くなる]** → キャッシュ TTL 6 時間＋ mtime による事前絞り込み＋部分読み。TTL 内はファイルを 1 個も開かない。加えて session-tripwires からの呼び出しは best-effort（失敗・タイムアウトを無視）。
- **[worktree 経路に人間の対話セッションが混ざる]** → 過大計上側に倒れることを spec に明記し、`sources` の内訳を出力に含める。指標の用途は「増えているかどうか」の傾向把握で、絶対値の精度を要求しない。
- **[Claude Code 側のディレクトリ構造・usage フィールドが変わると壊れる]** → 壊れ方は「対象 0 件」になるだけで、fail-open で無出力になる。`subagent-context.sh` が既に同じ依存を持っており、依存の総量は増えない。テストは実機の `~/.claude` を読まず、fixture ディレクトリ（`--projects`）に対して回す。
- **[観測を足しただけでは固定分は減らない]** → この change は #260（削減）と #258（編集時ゲート）の前提を作るだけ、と proposal で明示する。効果の確認はエピック #257 の完了条件が担う。
- **[過大な情報でセッション文脈が太る]** → 注入は 1〜2 行に収める（この change 自体が固定分を増やす側に回らないよう、注入本文の行数を spec で縛る）。
