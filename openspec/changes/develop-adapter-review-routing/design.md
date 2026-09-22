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
- レビュー結果を G に渡す方法を変えること。Claude の G は SendMessage で再開する（`gate-runner.md`・`SKILL.md` の (4) の既存規則）、Codex の G は新しい phase で渡す（`codex-develop.md` の既存規則）。今回は渡す中身に executor / model と dispatch 記録の URL を足すだけ

## Decisions

### G への経路の伝え方: 本体が起動指示に `レビュー経路:` の 1 行を書く

develop の本体は、(4) で G を起動する指示（spawn 時）・再開する指示（SendMessage）・手渡しで後任を起こす指示のすべてに、**常に** `レビュー経路: adapter` の 1 行を書く。現行の develop は 3 つの起動形すべてを adapter で解決するので、本体が「今は adapter 経路か」を毎回評価する条件は置かない（評価を飛ばした瞬間に今回と同じ不具合へ落ちるため）。Codex の G では request の instructions（`--input` の指示ファイル）が起動指示に当たるので、そこにも書く。G はこの行だけで判別し、環境変数・記録先のコメント・自分の起動方法から推測しない。

`レビュー経路: 従来` は develop の本体が書かない値と定義する。使うのは、develop の本体以外の呼び出し元が `gate-runner.md` で G を起こす場合だけである。

用語: `レビュー経路: adapter` は新 Codex モードを含む adapter 解決の全構成（`claude-default` も含む）を指し、新 Codex モードとは同義ではない。gate-runner.md の従来モードのレビュー実行者の表は、`レビュー経路: 従来` または行が無いときだけ適用する。

- 採用理由: G は起動指示を必ず読む。記録先の develop 開始コメントから推測させる案は、G に照合の手間を増やし、明示 profile の経路では自動選択の記録が無いので判別材料にならない。環境変数案は Claude の Agent 起動で渡す仕組みが無い
- 行が無いとき: 従来経路として扱う。issue の受け入れ条件が「従来経路の既定を変えない」を求めており、この行を書かない古い本体や、develop 外から pr-review-gate を回す呼び出し元で振る舞いを変えないため
- 書き忘れへの対策: 主な対策は条件を外すこと（本体の指示が「常に書く」なので、判断を誤る余地が無い）。bats は `SKILL.md` の (4) と Role profile の選択節にある「常に書く」の文言を固定する
- 再開のたびに書く理由: G のコンテキストが手渡しで入れ替わると、前の起動指示を後任が読めないため

### adapter 経路の G は full / light のどちらでも `needs-reviewer` を返す

G は手順 1（前提を揃える・HEAD SHA の固定）と手順 2-0（light / full の判定と `レビュー重量:` コメント）まで済ませてから返す。payload の `判定` に `full（adapter 経路）` を足す。`選んだ経路`・`実行コマンド`・`終了コード`・`出力の要点`・`実待ち時間` はすべて `未実行（adapter 経路）` と書き、Codex の証拠を作らない（既存の bats がこれらの欄名を固定しているので、欄は残して値だけを決める）。Codex 不可の実測（バイナリ探索・起動）は行わない（投げ先を決めるのは本体の選び直しなので、G が Codex を試す意味が無い）。`推奨モデル` は adapter 経路では参考値で、実際の投げ先は本体の選び直しが決める。

「レビュー実行者:」の PR コメントは、要約を受け取った G が今までどおり投稿する。adapter 経路では `レビュー実行者: <executor>/<model>（adapter 経路・dispatch 記録: <URL>）` とし、本体から渡された executor / model と dispatch 記録のコメント URL を写す。gate-runner.md は `pr-review-gate/SKILL.md` を正本と宣言しており、正本の「レビュー実行者:」の書き分け（Task サブエージェントの 2 形）と PR コメント雛形は形を限定しているので、この 1 形を正本側にも足して食い違いを作らない。

### 本体の手順（(4) の needs-reviewer）

adapter 経路で `needs-reviewer` を受けたら、本体は次の順で進む。

1. `codex-develop.py request --phase review`（実行先オプションはこの develop 開始時と同じもの。自動選択なら無指定のまま）で投げ先を選び直す
2. 返った選択（構成・reason・Claude と最良 Codex の margin・各 `fetched_at`・代表 Codex account。欠測は `missing`）と、解決した executor / model を記録先に dispatch 記録として投稿する。投稿に成功するまでレビュアーを起動しない
3. executor が `claude` なら Agent ツールでレビュアーを起動する（model は adapter が返した値に残量上限を適用したもの。事前分類に当たれば profile の `decider` entry で `dev-workflow:decider`。既存の規則のまま）。`codex` なら request を実行する
4. レビュー要約と、選ばれた executor / model・dispatch 記録のコメント URL を G に渡す。渡し方は G の起動形で分かれる: Claude の G は SendMessage で再開して渡す（`gate-runner.md`「needs-reviewer の return」節と `SKILL.md` の (4) の既存規則）。Codex の G は新しい phase `gate` を開始してその入力に渡す（`codex-develop.md`「品質と transport 差分」の G の項）

従来経路（`レビュー経路: 従来` または行が無い G）が `needs-reviewer` を返したときに呼び出し元が Agent ツールで既定 `opus` のレビュアーを起こす手順（`gate-runner.md` の既存記述）は変えない。

### Codex の phase `review` が `gate-runner.md` を読むことへの対処

`codex-develop.py` の `prompt()` は phase `review`（レビュアー役）にも `gate-runner.md` を渡している。新しい「adapter 経路では `needs-reviewer` を返す」の節を、レビュアー役がそのまま読むと自分でレビューせず返してしまうおそれがある。そこで節の冒頭で、この規則は「G（phase `gate`）として起動されたとき」の規則であり、phase `review` のレビュアーとして起動されたときは適用しない、と限定する。コードは変えない。

## Risks / Trade-offs

- [本体が `レビュー経路: adapter` の行を書き忘れる] → G が Codex を直接呼び、余裕の無い Codex を消費し得る。本体の指示を「常に書く」に無条件化して判断の余地を無くし、bats でその文言を固定する。完全な機械的強制（hook での検査）は今回の範囲外
- [将来 develop に adapter を通さない起動形が戻る] → 「常に `adapter` を書く」が誤りになる。そのときは起動形ごとに書く値を決め直す変更として扱う（今の SKILL.md にはその起動形が無い）
- [dispatch 記録の投稿が 1 回増える] → phase `review` の選び直しは他の phase と同じ扱いで、記録の形式も既存の dispatch 記録と同じ。追加の固定費は小さい
