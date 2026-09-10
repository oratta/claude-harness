# prototypes — 計測用の使い捨てスクリプト（実装ではない）

2026-09-09〜10 のセッションで「issue / PR ごとの API 換算コストを出せるか」を確かめるために書いたもの。
**プラグインの実装ではない。** 設計の根拠になった数字がどう出たかを再現できるように残している。
実装（`scripts/` 配下に置く本番のもの）ができたら、このディレクトリは削除してよい。

料金表は各スクリプトの `P` に手で書いてある（$/MTok の (入力, 出力, キャッシュ書込5m, キャッシュ書込1h, キャッシュ読出)）。
本番ではここを 1 か所に寄せる。

| スクリプト | 何を出すか | 実行例 |
|---|---|---|
| `branch-cost.py` | 1 ブランチのコストをモデル別に内訳付きで | `python3 branch-cost.py oratta/token-optimize` |
| `all-branch-cost.py` | 全ブランチのコスト（全履歴を 1 パス） | `python3 all-branch-cost.py` |
| `per-post-cost.py` | 1 ブランチを「投稿から投稿まで」の区間に割る | `python3 per-post-cost.py oratta/token-optimize` |
| `repo-main-share.py` | リポジトリごとの main / ブランチの内訳 | `python3 repo-main-share.py` |
| `issue-rescue.py` | main 上のコストのうち issue 番号を触ったセッションの割合（flatmate 固定） | `python3 issue-rescue.py` |

## 読んでいるデータ

`~/.claude/projects/**/*.jsonl`。アシスタントの 1 メッセージが 1 行で、次のフィールドを使っている。

- `gitBranch` — **サブエージェント（`isSidechain: true`）の行にも入る**。これが帰属の第 1 の鍵
- `cwd` — リポジトリの特定に使う。`git -C <cwd> rev-parse --git-common-dir` で worktree を親リポに畳める
- `message.model` / `message.usage` — 単価の選択とトークン内訳
- `requestId` — 重複排除の鍵（同じ行が複数ファイルに現れることがある）
- `message.content[].input.command` — `gh issue view/comment/edit <N>` から issue 番号を拾う（第 2 の鍵）
