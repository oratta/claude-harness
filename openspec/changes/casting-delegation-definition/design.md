## Context

casting は「観点」側のホワイトリスト（配役表 3 層＋返信前チェック）だけを持ち、「ツール」側のホワイトリスト（Claude Code の permission）とは別々に見えている。#207 は両者を「委任」という 1 つの定義に束ね、観点の判断基準を主と対話で作る入口を足す。

## 判断1: 定義の正本は `catalog/delegation.md`（rules ではなく catalog 配下）

`rules/` は常時ロード層で、`tests/casting-structure.bats` が `perspective-casting.md` を 30 行以内に縛っている。定義文（プリミティブ・ロールの位置づけ・宣言書式・正本の優先順）は数十行になるので常時ロードに入れず、`catalog.md`（観点の語彙）・`injection.md`（注入の配線）と並ぶ第 3 の正本として `plugins/casting/catalog/delegation.md` に置く。rule には 1 文と正本へのポインタだけ足す。

## 判断2: 宣言ファイルは project.md に同居させず `delegation.md` を別に切る

`scripts/casting-check.sh` は project.md / local.md の `^|` で始まる**全行**を 5 列検査と観点語彙 lint にかける。許可ツール表（列構成が違う）を project.md に同居させると malformed-row になるか、check 側の走査範囲を「配役の見出し配下だけ」に変える大改修が要る。宣言は別ファイル `.claude/casting/delegation.md` にし、check の検査対象には入れない（列構成が異なるファイルを 5 列検査に巻き込まない）。「2 表を 1 か所で宣言できる」は、このファイル 1 枚（またはセッション宣言の `## 委任` 見出し 1 つ）の中に 2 表が並ぶことで満たす。

## 判断3: 宣言ファイルは「要約」であり正本ではない（二重管理の扱い）

ツールの正本は Claude Code の permission（settings.json の allow/deny、`/permissions`）、観点の正本は配役表 3 層（`casting-check.sh resolve` の出力）。delegation.md はその両方の要約を 1 か所に見せる宣言で、食い違ったら正本が勝つと定義文に書く。要約に落とすのは「主と新住人が立ち上げ時に 1 枚で読める」ためで、機械的な整合検査は本 change では持たない（将来 resolve から生成する余地は残すが、今回は手書き）。観点表は `| 観点 | 担い手 | 根拠 |` の 3 列で、5 列の上書き行（project.md の領分）は書かせない。

## 判断4: ロールは組み合わせ名

「委任レベル 0/1/2」「開発担当」「マーケ担当」のようなプリセットは、許可ツール集合と任された観点集合の特定の組み合わせに付けた名前と位置づける。定義文に例を 2 つ置くが、ロールの一覧表や正本は作らない（flatmate 側の住人定義に委ねる）。

## 判断5: policy-interview はメインセッションが policies を書く唯一の例外

`injection.md` の大原則は「注入文書はメインセッションに読み込まない」。policy-interview はその文書を**作る**工程なので、コマンド実行中に限りメインセッションが対象 slug の policy を読み書きしてよい例外とし、生成後は判断に使わず参照しないことをコマンド本文に明記する。質問は 1 問ずつ自由回答（communication-style の規則に従い AskUserQuestion のような選択肢 UI を使わない）で、順序は判断基準 → 閾値・数値 → 前提とする外部規約 → 人格（名前は起案して主が差し替え可）。既存 policy がある場合は現在の判断基準を読み上げてから差分を聞く（上書きではなく更新）。

## 判断6: 「全文を把握していない規約」の書式

`templates/policy.md` に「## 前提とする外部規約（全文未把握でよい）」節を足す。表の列は `| 規約 | 参照先 | 主の把握度 | スペシャリストへの指示 |` とし、把握度は「全文把握／概要のみ／名前のみ」の 3 語に固定する。スペシャリストは「名前のみ」「概要のみ」の規約を判断の前に参照先で読んでから意見を返す、と指示列に書く。これで「X の規約を守る」を主が全文を読んでいなくても宣言できる。

## 判断7: init.md の生成スクリプトに delegation.md を足す

既存の非上書き・冪等の型（project.md / precedents.md と同じ `if [ ! -f ]`）で `templates/delegation.md` をコピーする。`casting-init.bats` の「first run」テストは diff で雛形同一性を見ているので、同型のテストを delegation.md にも足す。テンプレのパス表記 lint（`template-path-lint.awk`）は `templates/*.md` 全体に効くため、新雛形もプラグイン内相対パスをコードスパンに書かない。

## Risks / Trade-offs

- 宣言ファイルと正本の乖離を機械検査しない → 立ち上げ時の 1 枚として使い、迷ったら正本（permission / resolve）を見る、と定義文で明示して受け入れる
- rule の追記で 30 行制限に近づく → 現在 22 行。1 文追記＋正本 1 行で 24 行に収める
