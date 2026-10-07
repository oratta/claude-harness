## 設計判断: 警告の出し口

- 案 A: develop の SKILL.md に「開始時に環境変数を確認する」手順を足す。LLM が手順を守る前提で、守られない・常時注入が増える
- 案 B（採用）: SessionStart hook。develop を起動するセッションは必ず SessionStart を通るので機械的に出せ、テストで検証でき、固定の注入を増やさない。develop 以外のセッションでも出るが、チーム機能が有効なこと自体が種別の制限を無効にするので害はない
- `session-tripwires.sh` に混ぜず別スクリプトにする。あちらはテンプレート欠損時に無出力で終わる fail-soft で、警告がその条件に巻き込まれるのを避ける。matcher は既存と同じ `startup|clear|compact` の別エントリで登録する

## 有効値の判定

無効とみなすのは、未設定・空文字・`0`・`false`（大文字小文字を区別しない）。それ以外（`1`、`true` など）は有効とみなす。Claude Code 本体が真偽をどう解釈するか確証がないため、「無効と分かる値以外は有効」に倒して見逃しを避ける。

## 出力

有効なときだけ、SessionStart hook の JSON（`systemMessage` で利用者に表示、`hookSpecificOutput.additionalContext` でモデルにも伝える）を標準出力へ 1 件出す。内容は、現状（チーム機能が有効）、起きること（名前付き spawn が teammate になり subagent_type の道具制限・本文が無視される）、対処（`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` を未設定か `0` にする）。常に exit 0（セッション開始を止めない）。
