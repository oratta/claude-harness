# Design

## Context

動機は proposal.md の Why。制約は次のとおり。

- PermissionRequest の入力に、なぜ確認画面が出たか（確認の種類・文言）は入っていない。実機（Claude Code 2.1.321、`claude -p` で入力を書き出す hook を置いた）で見た項目は `session_id`・`transcript_path`・`cwd`・`prompt_id`・`permission_mode`・`effort`・`hook_event_name`・`tool_name`・`tool_input`（`command`・`description`）・`permission_suggestions`（子なら `agent_id`）。#1132 の 2.1.304 の結果と同じ
- 同じ実機確認で、bypassPermissions の主の Dangerous rm（`cd <dir>; rm -f tbl/*`）では `permission_suggestions` が空の配列、default の主の普通の確認（作業ディレクトリへの `touch`）では `addDirectories`・`setMode` の 2 件だった
- bypassPermissions では、確認画面は規則で自動許可できない安全確認（Dangerous rm・critical path など）のときだけ出る（#1132 が引いた公式の記述と実機の表）。default では普通の Bash の確認でも同じ hook が呼ばれる
- 「Dangerous rm operation not ruled out」は、`$(printf ...)` と逆引用符・改行・行継続・`$'...'`・ノーブレークスペース・約 3.9KB の長い本文の 6 形を bypassPermissions で試しても再現しなかった。また 2.1.321 では bypassPermissions の子が `cd <dir>; rm -f tbl/*` を打っても PermissionRequest が呼ばれずに実行された（主では呼ばれて拒否された。#1132 の 2.1.304 では子でも拒否された）。子の bypassPermissions での PermissionRequest の入力（`permission_mode` の値）はまだ実機で見ていない

## Goals / Non-Goals

**Goals:**

- 子が bypassPermissions で動いているときに、rm でないコマンドで出る確認画面で止まり続けず、拒否と打ち直し方を受け取って、自分で打ち直すか親に返れる

**Non-Goals:**

- 確認画面が出る書き方そのものを本体側で減らすこと（本体の構文解析は変えられない）
- 子が default など確認を求めるモードで動くときの、rm でない確認への応答（画面を見ている人がいる前提のモードで、普通の権限確認と見分けられない）
- 無人の印（`DEV_WORKFLOW_UNATTENDED`。git の破壊的操作の hook が使うもの）での応答の切り替え（印は git の破壊的操作のための仕組みで、エピック #1476 の別の子の範囲に近い）
- rm でない確認への deny に、親の 1 回だけの許可や拒否の記録を付けること（書き方を変えれば通る問題で、親が許可して同じコマンドを通す道は要らない）

## Decisions

### 子の rm でない確認のうち、bypassPermissions のときだけ deny する

選んだ形: `agent_id` が空でない文字列で、コマンドが rm の入口の形（単純コマンドのどれかの先頭の語が `rm`）に当たらず、`permission_mode` がちょうど `bypassPermissions` のときに deny する。それ以外の rm でない確認には何も返さない。

検討した案:

- **子の rm でない確認をすべて deny する**: 子が default で動くと、作業ディレクトリへの書き込みのような普通の権限確認まで拒否され、画面で主が承認する今までの流れが壊れる。入力から確認の種類を読めないので、普通の確認と Dangerous rm を見分けられない。採らない
- **`permission_suggestions` が空のときだけ deny する**: 規則で自動許可できない確認では空になる、という観察は主の Dangerous rm 1 件だけで、公式に約束された性質ではない。版の変更で黙って外れても気づけない。採らない（bypassPermissions と組み合わせる案も、bypassPermissions の条件だけで足りるので採らない）
- **bypassPermissions のときだけ deny する（採用）**: bypassPermissions で確認画面が出るのは規則で許可できない安全確認だけなので、普通の権限確認を巻き込まない。dev-workflow の子（エピックの別セッションの作業者など）は `--dangerously-skip-permissions` で動くので、今回の事故の形に当たる。`permission_mode` は公式に入力の項目として載っている値で、判定に使える

### deny の理由は打ち直し方と親に返る条件を書き、記録は書かない

rm の deny と違い、親の許可で同じコマンドを通す道は作らない。今回の事故は書き方（`$(...)`・逆引用符・置換を本文に含む形）で確認が出た形なので、子に別の書き方で打ち直させるほうが早い。ただし hook は確認の原因を知らず、`is_rm_command` は `/bin/rm` などを入口の外とするので、「rm ではない」「書き方が原因」とは断定しない。理由には、既存の rm の判定に当たらないコマンドで確認が求められたので実行していないこと・確認の原因が本文の引用や置換なら本文をファイルに書いて `--body-file` で渡すなどの形で打ち直せること・打ち直せなければ何をしたかったか（コマンドの全文）を報告に書いて親に返ることを入れる。文頭は rm の deny と同じ `[dev-workflow rm-permission-guard]` とし、続けて「rm の判定に当たらない」と書いて rm の deny と見分けられるようにする。拒否の記録（`denied/<key>.json`）は書かない（親の許可を書くスクリプトが、rm でも git でもない記録に許可を書く道を作らないため）。

### 判定の置き場所は hook の入口

rm の入口の判定（共通ファイル `git-guard-scratchpad.py` の `is_rm_command`、読めないときは同じ形の簡易判定）で rm でないと分かった直後に、`permission_mode` を見て deny するか何も返さないかを決める。共通ファイルを読めないときも同じに振る舞う（この deny は key も記録も使わない）。`is_rm_command` は変えない。`hooks/hooks.json` は既に matcher `Bash` で登録済みなので変えない。

## Risks / Trade-offs

- [子の PermissionRequest の `permission_mode` が、親が bypassPermissions でも `bypassPermissions` にならない版がある] → 実装の最初に実機で子の入力の `permission_mode` を確かめる。`bypassPermissions` でなければ実装を止めて仕様に戻す（判定の条件が変わるため）
- [子の入力の `permission_mode` を実機で取れない（子に確認画面を出せない）] → 実装に進まず、未検証として本体に返す（判定の前提を確かめられないため）
- [「not ruled out」の確認を実機で再現できず、受け入れ条件の実機確認ができない] → 再現形を探すのは実装の段で行う。再現できなければ、実機確認は未検証として本体に返す（試した形・版・hook を直接呼んだ結果を添える）。受け入れ条件を変えるときは、主の判断結果を記録先に記録してから変える
- [bypassPermissions の子が、rm でないのに本当に主の判断が要る安全確認（critical path への書き込みなど）に当たっても、主の画面に上がらず拒否される] → 今でも誰も見ていない子はその画面で止まり続けるので、拒否して親に返るほうが早く主に届く。理由に「打ち直せなければ親に返る」を書く
- [主の対話セッションで画面を見ている人がいるのに、bypassPermissions の子の確認が拒否される] → 主は子の報告から同じ操作を自分で行える。止まったまま気づかれない被害のほうが大きい
- [子がコマンドを言い換えて確認を避け、本来止めるべき操作を通す] → 対象は rm でないコマンドで、git の破壊的操作は PreToolUse の git の破壊的操作の hook が先に止める（PreToolUse の deny は PermissionRequest より先に効く。#1132）

## 守備範囲

拾いたい誤りは、権限確認を省いて動く誰も見ていない子が、rm を含まないコマンドで出た確認画面で止まり続け、親の見張りも気づかないことである。bypassPermissions の子が、rm でないコマンドで主の判断が要る別の安全確認に当たっても、主の画面に上げずに拒否することは許す（子が親に返り、主には報告で届く）。確認を求めるモードで動く子の、rm でない安全確認は拾わない。各要件の守備範囲の正本は spec の各要件の段落で、ここはその要約。

## Migration Plan

hook のスクリプトの差し替えだけで、`hooks/hooks.json` は変えない。戻すときはこの PR の差分を戻す。
