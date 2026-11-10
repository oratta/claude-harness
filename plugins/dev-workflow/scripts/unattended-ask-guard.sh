#!/usr/bin/env bash
# PreToolUse hook（matcher: AskUserQuestion）: 画面を見ている人のいないセッションで AskUserQuestion を拒否し、
# 質問はチャンネルに送ってターンを終えるよう理由文で案内する（issue #1153。spec unattended-ask-hook）。
#
# 選択肢の画面は誰にも答えられず、セッションが無期限に止まる。develop の channel モードは文面で
# AskUserQuestion を呼ばないと決めているが（references/channel.md「channel の聞き方」）、develop 以外の
# スキル（wt-clean など）からの呼び出しと、文面に反した呼び出しは文面では止まらないので、ここで止める。
#
# 判定に使うのは環境変数 DEV_WORKFLOW_UNATTENDED（起動する側が claude の環境に入れる無人の印）だけ。
# 読み方は git ガード（scripts/git-destructive-guard.sh、spec destructive-git-hook）と同じ: 前後の空白を除いて
# 空（未設定を含む）か 0 なら印なし、それ以外はすべて印あり。git ガードの読み方は埋め込み Python の中にあり
# 切り出されていないので、ここでは bash で同じ規則を書く（揃っていることは tests/unattended-ask-guard.bats の
# 値の表で保つ）。
#
# payload は判定に使わない（呼んだスキル・permission_mode・agent_id によらない）。DEV_WORKFLOW_GIT_GUARD_NO_ASK
# （git ガードだけに効く印）と DEV_WORKFLOW_GIT_GUARD（git ガードの逃げ道）も見ない。
# 印の無いチャンネルの依頼で channel になったセッションは止めない（hook はプロンプトの本文を見られない）。
#
# 印が無ければ何も出さず exit 0。python3 は使わない。
set -u

# 標準入力は最後まで読み捨てる（書き手が途中で詰まらないため）
cat >/dev/null 2>&1 || true

mark="${DEV_WORKFLOW_UNATTENDED-}"
# 前後の空白を除く
mark="${mark#"${mark%%[![:space:]]*}"}"
mark="${mark%"${mark##*[![:space:]]}"}"
case "$mark" in
  ''|0) exit 0 ;;
esac

# 理由文は固定。JSON の文字列に入れるので " と \ を含めない
reason='[dev-workflow unattended-ask-guard] このセッションには無人の印 DEV_WORKFLOW_UNATTENDED がある（画面を見ている人がいない）ので、AskUserQuestion を拒否した。選択肢の画面は誰にも答えられず、セッションが止まる。AskUserQuestion は打ち直さず、質問はチャンネルに送ってターンを終える。依頼がチャンネルから届いたなら、その発言の開きタグの chat_id に、チャンネルの返信ツールで質問を送り、そのターンを終える。チャンネルから届いていなければ、そのセッションの運用（憲法・CLAUDE.md）が決める主への連絡先に送る。連絡先が分からなければ、記録先に質問をコメントして needs-approval を付けて止まる。選択肢は本文に番号付きで書き、文面は rules/communication-style.md の 3 番目の型（質問から書き、推奨まで出す）に従う。サブエージェントなら、質問を本体への return に書いて返る。'

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
exit 0
