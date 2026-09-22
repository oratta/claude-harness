## Context

develop の本体は、実行先を 3 通りで決める: 自動選択（profile も旧形式も無指定）、明示 profile（`--profile NAME [--profile-file PATH]`）、旧形式（`--account NAME --model MODEL`）。どれも adapter（`scripts/codex-develop.py request`）で canonical role の投げ先を解決する。この 3 通りをまとめて「adapter 経路」と呼ぶ。adapter が導入される前の、本体が Agent ツールで各役割を直接起こし G が Codex を直接呼ぶ流れを「従来経路」と呼ぶ。

PR レビューは canonical phase `review`（role `impl-review`）に対応し、adapter 経路では構成ごとに投げ先が違う（例: `claude-default` では executor `claude` / model `opus`、`claude-write-codex-review` では Codex）。しかし G の指示書 `gate-runner.md` は full レビューの実行者を「G の Bash から Codex を直接」と固定しており、adapter 経路の規則（`codex-develop.md`「品質と transport 差分」の G の項）は G の読む範囲に無い。

G の起動には 2 つの形がある。Claude の G は本体が Agent ツールで起こし、G は `gate-runner.md` を読む。Codex の G（phase `gate` の投げ先が Codex の構成）は `codex-develop.py` の `prompt()` が「Do not spawn agents, invoke Claude, codex exec, or codex-companion … return needs-reviewer」と指示しており、すでに `needs-reviewer` を返す。今回の不具合は Claude の G で起きる。

## Goals / Non-Goals

**Goals:**
- adapter 経路では、G が full でもレビュアーを自分で呼ばず `needs-reviewer` を返すことを、G の読む `gate-runner.md` に書く
- G が adapter 経路か従来経路かを、指示書に書かれた 1 つの方法で判別できるようにする
- `needs-reviewer` を受けた本体が phase `review` で投げ先を選び直し、その選択を記録してから選ばれた投げ先でレビュアーを起動する流れを、`SKILL.md` の (4) から辿れるようにする

**Non-Goals:**
- 従来経路の既定（full は G が Codex を直接呼ぶ）を変えること
- `codex-develop.py` のコード・自動選択の選択表・profile の中身を変えること
- レビュー結果を G に渡す方法（Claude の G は SendMessage で再開、Codex の G は新しい phase で渡す）を変えること。これは `codex-develop.md` の既存規則に従う

## Decisions

### G への経路の伝え方: 本体が起動指示に `レビュー経路:` の 1 行を書く

本体は G を起動する指示（spawn 時）と再開する指示（SendMessage）の両方に、`レビュー経路: adapter` か `レビュー経路: 従来` のどちらか 1 行を書く。G はこの行だけで判別し、環境変数・記録先のコメント・自分の起動方法から推測しない。

- 採用理由: G は起動指示を必ず読む。記録先の develop 開始コメントから推測させる案は、G に照合の手間を増やし、明示 profile の経路では自動選択の記録が無いので判別材料にならない。環境変数案は Claude の Agent 起動で渡す仕組みが無い
- 行が無いとき: 従来経路として扱う。issue の受け入れ条件が「従来経路の既定を変えない」を求めており、この行を書かない古い本体や、adapter を使わない呼び出し元（pr-review-gate を develop 外から回す場合など）で振る舞いを変えないため
- この既定を選ぶことで受け入れる結果: 本体が adapter 経路で行を書き忘れると、今回の不具合と同じく G が Codex を直接呼ぶ。これは `SKILL.md` の (4) と Role profile の選択節の両方に「adapter 経路では必ず書く」と明記し、bats で文言を固定して抑える
- 再開のたびに書く理由: G のコンテキストが手渡しで入れ替わると、前の起動指示を後任が読めないため

### adapter 経路の G は full / light のどちらでも `needs-reviewer` を返す

G は手順 1（前提を揃える・HEAD SHA の固定）と手順 2-0（light / full の判定と `レビュー重量:` コメント）まで済ませてから返す。payload の `判定` に `full（adapter 経路）` を足し、`選んだ経路` は `adapter 経路のため未実行` と書く。Codex 不可の実測（バイナリ探索・起動）は行わない（投げ先を決めるのは本体の選び直しなので、G が Codex を試す意味が無い）。`推奨モデル` は adapter 経路では参考値で、実際の投げ先は本体の選び直しが決める。

「レビュー実行者:」の PR コメントは、要約を受け取った G が今までどおり投稿する。adapter 経路では括弧内を `（adapter 経路・<executor>/<model>）` とし、本体から渡された選択結果を写す。

### 本体の手順（(4) の needs-reviewer）

adapter 経路で `needs-reviewer` を受けたら、本体は次の順で進む。

1. `codex-develop.py request --phase review`（実行先オプションはこの develop 開始時と同じもの。自動選択なら無指定のまま）で投げ先を選び直す
2. 返った選択（構成・reason・Claude と最良 Codex の margin・各 `fetched_at`・代表 Codex account。欠測は `missing`）と、解決した executor / model を記録先に dispatch 記録として投稿する。投稿に成功するまでレビュアーを起動しない
3. executor が `claude` なら Agent ツールでレビュアーを起動する（model は adapter が返した値に残量上限を適用したもの。事前分類に当たれば profile の `decider` entry で `dev-workflow:decider`。既存の規則のまま）。`codex` なら request を実行する
4. レビュー要約を G に渡す（渡し方は `codex-develop.md` の既存規則）

従来経路で `needs-reviewer` を受けたときの本体の手順（Agent ツールで既定 `opus` のレビュアーを起こす）は変えない。

### Codex の phase `review` が `gate-runner.md` を読むことへの対処

`codex-develop.py` の `prompt()` は phase `review`（レビュアー役）にも `gate-runner.md` を渡している。新しい「adapter 経路では `needs-reviewer` を返す」の節を、レビュアー役がそのまま読むと自分でレビューせず返してしまうおそれがある。そこで節の冒頭で、この規則は「G（phase `gate`）として起動されたとき」の規則であり、phase `review` のレビュアーとして起動されたときは適用しない、と限定する。コードは変えない。

## Risks / Trade-offs

- [本体が `レビュー経路:` の行を書き忘れる] → G が Codex を直接呼び、余裕の無い Codex を消費し得る。`SKILL.md` の 2 か所に書き、bats で文言を固定する。完全な機械的強制（hook での検査）は今回の範囲外
- [dispatch 記録の投稿が 1 回増える] → phase `review` の選び直しは他の phase と同じ扱いで、記録の形式も既存の dispatch 記録と同じ。追加の固定費は小さい
