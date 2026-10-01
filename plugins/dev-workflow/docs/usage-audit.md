# サブエージェントのコンテキスト量の監査手順（正本）

セッションとサブエージェントの起動直後に必ず載る固定分（rules・CLAUDE.md・MEMORY.md・
skill 一覧・接続コネクタ名など）が増えていないかを、実測で確かめるための手順。
2026-08-31 の約 42,000 トークンから 09-08 の約 58,678 トークンへ 8 日で約 4 割増えたのに
誰も気づかなかったのは、増加の大半が PR の diff に現れない要素で起きていて、
事後にトランスクリプトを手集計するまで観測手段が無かったためである。

集計スクリプトは `../scripts/subagent-context-audit.sh`。**この監査は観測専用**で、
閾値でセッションやツールを止めることはしない。1 体分の実測（再開前の上限判定）は
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

権限などで**読めないディレクトリが 1 つでもあった**ときも同じ扱いで、集計値は出すが
`note: "scan incomplete (unreadable directories)"` を付けてキャッシュに書かない
（走査できた分だけの結果を「全部」として TTL のあいだ配らないため。権限が戻れば
次の実行で普通に走査してキャッシュし直す）。`usage` の値が数値として扱えない行
（`1e999` や `NaN`）は、その行だけを `usage` 無しとして飛ばす。

## 2. 出力キーの意味

出力は 1 行 JSON。コンテキスト量の定義は `subagent-context.sh` と同じ
`input_tokens + cache_creation_input_tokens + cache_read_input_tokens` で、
「そのリクエストがモデルに読ませた全量」を指す。

| キー | 意味 |
|---|---|
| `count` | 窓の中にあったサブエージェントの件数（母集団の大きさ） |
| `first_median` / `first_max` | 初回コンテキスト（最初の応答時点）の中央値・最大。**起動時固定分の指標** |
| `last_median` / `last_max` | 最終コンテキスト（最後の応答時点）の中央値・最大。**1 体が膨らむ度合いの指標** |
| `over_cap_pct` | 最終コンテキストが `cap` を超えた割合（0〜100）。前任をそのまま再開できない状態になる頻度 |
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

`over_cap_pct` は前任をそのまま再開できなくなった件の割合で、上がっていれば
1 サイクルあたりのコンテキスト消費が増えている。`last_median` と合わせて見る。
上限を超えたあとに何をしてよいかは
`../skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本。

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

## 6. `--by-role`（担当別の内訳）

隔離の有無（`sources`）は役割と相関するが役割そのものではない（隔離ありの中に W も
decider も混在する）。担当（W / R1 / G / Reviewer / decider）ごとの傾向を見たいときは
`--by-role` を付ける。

```bash
# 直近 14 日を担当別に集計する
plugins/dev-workflow/scripts/subagent-context-audit.sh --by-role --refresh
```

`--by-role` は既定呼び出しの出力・走査コストに一切影響しない。付けたときだけ、全文を
前方から順に走査してトップレベルに `by_role` キーを追加する（既定呼び出しは先頭/末尾の
部分読みで済むが、`--by-role` は担当分類・`docs_median`・`reread_pct` の計上のために
全文が要る分だけ重い）。**この 2 経路は走査範囲が違うため、`--by-role` の実行と
`--by-role` を付けない実行とで、同じ瞬間に測っても `last_median` 等がわずかにずれうる**
（部分読みで見つかる末尾レコードと全文走査で見つかる末尾レコードが一致しない場合がある）。
固定分の比較には既定呼び出し同士、担当別の内訳には `--by-role` 同士を比べること。

`by_role` は次の 6 個の担当名を常にキーとして持つ（該当 0 件でもキー自体は省略しない）。

| 担当 | 分類規則 |
|---|---|
| `decider` | `agent-<id>.meta.json` の `agentType` が `dev-workflow:decider`（`description` の見た目より優先） |
| `W` / `R1` / `G` / `Reviewer` | `agentType` が decider でないとき、`description` の先頭コロン区切りトークンがこれらに完全一致 |
| `unknown` | どちらにも当たらない（`description` 無し・コロン無し・未知のトークン・meta.json 欠損/壊れ） |

`Reviewer:` の接頭辞は develop の紐付け規約（`skills/develop/SKILL.md` の「紐付けの規約」）に未規定のため、
G のレビュアーは `unknown` に落ちうる（`Reviewer` の件数が少ない・`unknown` に偏るのは想定内の挙動）。

各値は `count` / `first_median` / `docs_median` / `last_median` / `over_cap_pct` を持ち、
`W` のみ追加で `reread_pct` を持つ。`count` が 0 の担当は `first_median` / `docs_median` /
`last_median` が `null`、`over_cap_pct` が `0.0` になる。

- `docs_median`: 指示書（harness の `plugins/cache/oratta-claude-harness/.../*.md`）の
  `Read`、または `Skill` 呼び出しを含むホップの `usage` 差分を、まず個体（1
  トランスクリプト）ごとに合計し、その合計値を担当内で中央値に取ったもの。1 ホップ
  ずつ担当内で中央値を取るのではない点に注意する
- `reread_pct`: `W` にだけ付く。`description` の `#N`（記録先番号。複数出現時は最も左を
  使う）で同じ記録先の `W` を時系列でグループ化し、各グループの 2 番目以降について
  「先行する全 `W` が読んだファイルのうち自分が読み直した割合」を担当内の中央値として
  出す。**ファイル一致はベースネーム一致**（フルパス一致ではない。worktree ごとに
  絶対パスの先頭が変わるため）。「読んだファイル」は `Read` の `file_path` に加え、`Bash` の `sed -n` / `cat` /
  `head` / `tail` の引数のファイル（近似: スクリプト・オプション値・リダイレクト先は数えず、
  変数・グロブ・`sed -ne`・`xargs cat`・`grep` / `awk` / `less` は数え漏れる）。各グループの最初の `W`（先行がいない個体）と `#N` が
  取れない `W` はこの中央値の母数から除く。対象が 1 件も無ければ `null`

過去の計測を測り直すときは、キャッシュ（TTL 内）が古い算出を返すので `--refresh` を付ける。

`--cache` を省略した場合、`--by-role` は既定のキャッシュパスに `.by-role` サフィックスを
足した別ファイルを使う（既定呼び出しと結果が混ざらないようにするため）。`--cache` を
明示した場合はそのパスをそのまま使う（サフィックスを足さない）。
