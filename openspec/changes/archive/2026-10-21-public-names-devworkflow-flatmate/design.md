## Context

dev-workflow の「担い手なし」の行は約 50 行で、約 30 行が Orca 経路、約 20 行が flatmate の名指しとオーナーの開発環境の前提と検査の入力のプロジェクト名。Orca 経路の行は #1123 の結果で書き方が決まる。#1123 では、PR #1174 が orca の呼び出しを `scripts/epic-launch-orca.sh` に切り出し、spec `dev-workflow-epic-state` に「起動部品は epic-launch-<名前>.sh の 1 本ずつ」を置いたので、Orca は差し替え可能な起動部品の 1 つになった。ただし #1123 の change 3b（tmux の部品・`route` の `tmux`・develop SKILL.md「エピックの扱い」の書き直し）が作業中で、同じ節を書き直す。

## Decisions

### D1: 直し方の選び方

- flatmate を正本・配布元・設置元と名指しする行: 名を外して一般の言い方にする。例: 「loop-dev-agent の憲法の正本は flatmate 側」→「憲法の正本はそれを配布するリポジトリ側」、「issue テンプレートは flatmate の `new-resident` が配る」→「issue テンプレートは各リポジトリが持つ」。意味の変わる行（誰が配るかを手順が使っている行）は、手順が使う事実だけを残す。flatmate を指す例の表（`memory-refresh/SKILL.md:76,94`）は `example` の名前に置き換える
- `CLAUDE_HARNESS_DEV_DIR`（`ci-watch.md:95`・`memory-refresh/SKILL.md:82`）: Harness 自体を開発するときの規則は個人版の `rules/plugin-editing.md` が持つので、公開版の文は「開発用の clone から worktree を切る」と一般に書き、環境変数名は外す
- daily-report と Obsidian の vault（`self-verification.md:41`）・agents 保管庫（`auto-merge.md:273`）: 個人版へ移す部品を指す行は、「記録の置き場があれば」「秘密情報の保管庫」のように個人版の有無に依らない書き方に直す
- 検査の入力のプロジェクト名（moko）: `example` に置き換える。検査は入力の文字列が結果を変えないことを確かめている行なので、置き換えても結果は同じになる（テストを走らせて確かめる）
- 選ばなかった案: 行を「載せない行の基準」に足して外す。flatmate の名指しは出典ではなく手順の前提なので、基準の「出典や経緯としてだけ名前を挙げる行」には当たらない

### D2: Orca 経路の行はこの change では本文を触らず、担い手だけを #1177 に付け替える

#1123 の結果から、Orca は差し替え可能な起動部品の 1 つなので、個人版へ移さず「Orca を使う場合」の書き方に直すと決めた（issue #1168 本文の方針）。ただし書き直しの対象の節を 3b が同時に書き直しており、3b の後に route の名前など語彙が決まる。先にこの PR で書き直すと衝突し、3b の語彙とずれる。そのため本文は #1177 に回し、この change は一覧の「直す issue」の欄を #1177 に付け替える。付け替える行は、既存の一覧の Orca 経路の行を内容で照合し直したもの（Orca の語を含まない起動説明の関連段落、例えば `cld` を前提にした段落を含む）と、Orca の語を含む行（README.md:15・develop SKILL.md の 46・207・350・353・375・481〜525、reply-after-idle.md、owner-reply-check.sh、declarations.md、stages/pass.md:95）。一覧の行番号は #1174 などでずれているので、付け替え前に Orca の語で `git grep` し直す。#1177 の受け入れ条件は、本文を直した行を一覧から消すこと。

### D3: 候補語の判定

change A の design D3 と同じ。dev-workflow の公開版の部品について、一覧に無い当たりを判定する。Orca の語の当たりで一覧に無いもの（例: `plugins/worktree/references/session-devserver-cleanup.md` の Orca への言及は dev-workflow でないので change A 側）は、dev-workflow のものを #1177 の担当として一覧に足し、それ以外は載せない行の基準で判定する。

### D4: テスト

固有記述の取りこぼしは検査で全部は拾えない。直した語が戻るのを落とす検索だけを `tests/public-private-split.bats` に足す。対象は spec のとおり。

### #1164 の行

一覧には #1164 を担い手とする行が残っているが、#1164 は PR #1175 でマージ済み。実ファイルから既に消えていることを確かめた行はこの PR で一覧から消し、消えていない行は担い手を #1164 のまま残して記録する（本体の決定。tasks 4.4）。
