# サブエージェントのコンテキスト量の監査手順（正本）

セッションとサブエージェントの起動直後に必ず載る固定分（rules・CLAUDE.md・MEMORY.md・
skill 一覧・接続コネクタ名など）が増えていないかを、実測で確かめるための手順。
2026-08-31 の約 42,000 トークンから 09-08 の約 58,678 トークンへ 8 日で約 4 割増えたのに
誰も気づかなかったのは、増加の大半が PR の diff に現れない要素で起きていて、
事後にトランスクリプトを手集計するまで観測手段が無かったためである。

集計スクリプトは `../scripts/subagent-context-audit.sh`。**この監査は観測専用**で、
閾値でセッションやツールを止めることはしない。1 体分の実測（手渡し判定）は
`../scripts/subagent-context.sh` が別に担う。

## 1. 実行する

```bash
# 直近 14 日・上限 150000 で集計する（TTL 内ならキャッシュをそのまま返す）
plugins/dev-workflow/scripts/subagent-context-audit.sh

# 今の状態で測り直す（キャッシュの TTL を無視して再走査する）
plugins/dev-workflow/scripts/subagent-context-audit.sh --refresh

# 窓と上限を変える（例: 直近 7 日・上限 120000 で見る）
plugins/dev-workflow/scripts/subagent-context-audit.sh --days 7 --cap 120000 --refresh
```

`--projects DIR` で走査先（既定 `${CLAUDE_PROJECTS_DIR:-~/.claude/projects}`）を、
`--cache FILE` で保存先を差し替えられる。テストが実機の `~/.claude` を読まないための口でもある。

引数エラー以外は必ず exit 0 で終わる。トランスクリプトが 1 件も無い・projects
ディレクトリが無い・`python3` が無い場合は `count` が 0 の結果と `note` を出す
（走査できなかった結果はキャッシュに書かない。TTL のあいだ配られてしまうため）。

## 2. 出力キーの意味

出力は 1 行 JSON。コンテキスト量の定義は `subagent-context.sh` と同じ
`input_tokens + cache_creation_input_tokens + cache_read_input_tokens` で、
「そのリクエストがモデルに読ませた全量」を指す。

| キー | 意味 |
|---|---|
| `count` | 窓の中にあったサブエージェントの件数（母集団の大きさ） |
| `first_median` / `first_max` | 初回コンテキスト（最初の応答時点）の中央値・最大。**起動時固定分の指標** |
| `last_median` / `last_max` | 最終コンテキスト（最後の応答時点）の中央値・最大。**1 体が膨らむ度合いの指標** |
| `over_cap_pct` | 最終コンテキストが `cap` を超えた割合（0〜100）。手渡しに切り替わる頻度 |
| `cap` / `days` | 使った上限と窓（`--cap` / `--days`、既定 150000 / 14 日） |
| `sources` | 隔離の有無で分けた統計。`isolated` / `non_isolated` がそれぞれ `count` / `first_median` / `last_median` / `over_cap_pct` を持つ |
| `generated_at` | 集計時刻（UTC） |

**母数が 2 種類あることに注意する。** `sources.isolated.count` と
`sources.non_isolated.count` の合計は `count` と一致する（分類できない件も母集団から
落とさず `non_isolated` に寄せるため）。一方 `last_median` / `last_max` / `over_cap_pct` は
**最終コンテキストが見つかった件だけ**が母数で、`count` 以下になりうる（末尾の窓を
4 MiB まで広げても `usage` 付きレコードが見つからない件は最終側から除くため）。
`over_cap_pct` の分母を `count` だと思って読むと、割合を過小に見積もる。

## 3. 何を見たら固定分が増えたと判断するか

**主系列は全体の `first_median`。** 起動直後に必ず載る分がそのまま出るので、
これが上がっていたら固定分が増えている。数千トークン単位で動いたら疑う。

動いたときは `sources` で切り分ける。隔離の有無は役割と相関していて
（隔離されるのは実装を回す作業者、隔離なしにはレビュー役が多い）、渡される
プロンプトの長さが違う。`sources.isolated` と `sources.non_isolated` の
`first_median` が**両方とも上がっていれば固定分そのものの増加**、片方だけで
`count` の構成比が変わっていれば**母集団の構成が変わっただけ**と読める。

`over_cap_pct` は手渡しの発生頻度で、上がっていれば 1 サイクルあたりの
コンテキスト消費が増えている。`last_median` と合わせて見る。

## 4. キャッシュファイル

保存先は `${SUBAGENT_CONTEXT_AUDIT_CACHE:-~/.claude/.subagent-context-audit}`（1 行 JSON）。
mtime が `SUBAGENT_CONTEXT_AUDIT_TTL`（秒、既定 21600 = 6 時間）以内なら、
トランスクリプトを 1 個も開かずにこの中身をそのまま返す。14 日窓の中央値は
数時間では意味のある動きをしないので、既定を長めに取っている。今すぐ測り直したいときは
`--refresh` を使う。他のツールに渡すときはこのファイルをそのまま読めばよい。

## 5. 母集団に入っているもの・いないもの

走査するのは `<projects>/*/*/subagents/agent-*.jsonl` の **1 経路だけ**。
`isolation: "worktree"` で起こしたサブエージェントも同じ `subagents/` に置かれ、
変わるのはファイル名だけ（隔離ありは名前が載らず `agent-<agentId>.jsonl`、
隔離なしは `agent-a<name>-<hash>.jsonl`）なので、この 1 経路で隔離ありも入る。

入らないものが 3 種類ある:

- **メインセッション**（`<projects>/<slug>/<uuid>.jsonl`）— サブエージェントではない
- **worktree の中から起動された入れ子の `claude` セッション**
  （`<projects>/<slug>--claude-worktrees-agent-<hash>/<uuid>.jsonl`）— 同じく
  サブエージェントではない。ここを母集団に入れると集計が汚れる
- **Workflow 経由のサブエージェント**（`<projects>/<slug>/<uuid>/subagents/workflows/<wf-id>/agent-*.jsonl`）
  — `subagents/` の内側にあるが階層が 1 段深く、固定深さのこの経路に当たらない。
  2026-09-09 時点の実機では 2 件で、フラットな 2,022 件に対して集計値を動かさないため
  経路を足していない。dev-workflow は `../references/workflow-execution.md` で
  Workflow 経路を持つので、**この母数は将来増えうる**。Workflow の利用が増えたら
  走査経路を足すか、別系列として出すかを決め直すこと

隔離の有無は隣の `agent-<id>.meta.json` の `spawnedWithWorktree` で分類する。
meta.json が無い・壊れている件は `non_isolated` に寄せ、全体の `count` からは落とさない
（分類の失敗で母集団が痩せないようにするため）。ファイル名からの推定はしていない。
