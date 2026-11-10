# Tasks

## 1. hook の本体と登録

- [x] 1.1 `plugins/dev-workflow/scripts/unattended-ask-guard.sh` を bash だけで書く（python3 を呼ばない）。冒頭のコメントに目的・印の読み方（spec `destructive-git-hook` と同じ。前後の `[[:space:]]` を除いて空か `0` なら印なし）・payload を判定に使わないこと・NO_ASK と `DEV_WORKFLOW_GIT_GUARD` を見ないことを書く。標準入力は最後まで読み捨て、印が無ければ何も出さず exit 0、印があれば `hookSpecificOutput`（`hookEventName: PreToolUse`・`permissionDecision: deny`・`permissionDecisionReason`）の JSON を 1 行出して exit 0。理由文は design.md「拒否理由は develop の『channel の聞き方』に沿い…」の要素を全部含む固定文で、`"` と `\` を含めない。実行権限を付ける。確かめ方: 1.3 の bats が通る。触る範囲: plugins/dev-workflow/scripts/unattended-ask-guard.sh（新規）
- [x] 1.2 `plugins/dev-workflow/hooks/hooks.json` の `PreToolUse` の Bash の git-destructive-guard の項目の直前に（`tests/git-destructive-guard.bats` が git ガードを PreToolUse の最後の項目と求めるため） matcher `AskUserQuestion`・command `"\"${CLAUDE_PLUGIN_ROOT}/scripts/unattended-ask-guard.sh\""` の項目を 1 つ足す。確かめ方: `python3 -I -m json.tool plugins/dev-workflow/hooks/hooks.json` が通り、1.3 の登録の検査と `tests/lint-plugin-validate.bats`（command の引用）と `tests/hook-python-isolation.bats`（hooks.json に載ったスクリプトの python3 の検査）が通る。触る範囲: plugins/dev-workflow/hooks/hooks.json:50-77（"PreToolUse" の配列）
- [x] 1.3 `plugins/dev-workflow/tests/unattended-ask-guard.bats` を書く。setup で `DEV_WORKFLOW_UNATTENDED`・`DEV_WORKFLOW_GIT_GUARD_NO_ASK`・`DEV_WORKFLOW_GIT_GUARD` を unset し、テスト名は ASCII。spec `unattended-ask-hook` の Scenario 5 つ（登録・印のあるセッションの拒否を `default`/`bypassPermissions` × `agent_id` 有無で・印の値の表 8 通り・git ガードの印と逃げ道・理由文の要素）をそれぞれ 1 テスト以上にする。JSON は `python3 -I -c` で読んで確かめる。確かめ方: `bats plugins/dev-workflow/tests/unattended-ask-guard.bats` が全部通る。さらにスクリプトの印の判定を一時的に外した写し（scratchpad に置く）で拒否の検査が落ちることを 1 回確かめる。触る範囲: plugins/dev-workflow/tests/unattended-ask-guard.bats（新規）

## 2. develop の channel の文面と列挙の検査

- [x] 2.1 `plugins/dev-workflow/skills/develop/references/channel.md`「channel の聞き方」に 1 項目足す: 印 `DEV_WORKFLOW_UNATTENDED` のあるセッションでは `scripts/unattended-ask-guard.sh` の hook がどのスキルからの呼び出しも拒否し、理由文でこの聞き方を案内すること、チャンネルの依頼だけで channel になった（印の無い）セッションには効かず、この節の規則だけが歯止めになること。AskUserQuestion の語を含む行は `tests/epic-child-no-ask-tool.bats` の検査（否定の形 `AskUserQuestion を呼ばない` 等か interactive の条件つきだけを許す）に合う書き方にする。あわせて読み替えの規則の段落の除外（「develop の SKILL.md とこのファイルを除く」）に `hooks/hooks.json` と `scripts/unattended-ask-guard.sh`（手順として読まれない hook の 2 ファイル）を足す。確かめ方: `bats plugins/dev-workflow/tests/epic-child-no-ask-tool.bats plugins/dev-workflow/tests/develop-channel-mode.bats` が通る（2.2 のあと）。触る範囲: plugins/dev-workflow/skills/develop/references/channel.md:5-13（## channel の聞き方）
- [x] 2.2 `plugins/dev-workflow/tests/develop-channel-mode.bats` の「reading rule: every file mentioning AskUserQuestion is listed …」で、SKILL.md と channel.md に並べて `hooks/hooks.json` と `scripts/unattended-ask-guard.sh` を名指しで飛ばす（`hooks/` ごとは除かない。design.md の最後の Decision）。確かめ方: `bats plugins/dev-workflow/tests/develop-channel-mode.bats` が通り、飛ばす 2 行を外すと 1.1・1.2 のあとの木で「読み替えの列挙に無い」で落ちることを 1 回確かめる。触る範囲: plugins/dev-workflow/tests/develop-channel-mode.bats:89-104（reading rule のテスト）

## 3. 変更の記録と全体の確認

- [x] 3.1 `plugins/dev-workflow/changes/1153.md` を書く（既存の `changes/1582.md` の形: 見出し・`## 変更`・`## 検証`）。何を足したか（hook・登録・channel.md の 1 項目と除外・bats）、範囲（全スキル・印だけで判定・チャンネルの依頼だけの channel は範囲外とその理由）、git ガードと NO_ASK は変えないこと、常時注入の rules と予算は変えないこと、版は上げないこと、実機での確認の結果（3.3）を書く。確かめ方: ファイルがあり、`bats tests/public-private-split.bats` が通る。触る範囲: plugins/dev-workflow/changes/1153.md（新規）
- [x] 3.2 関係する既存の検査を通す: `bats plugins/dev-workflow/tests/unattended-ask-guard.bats plugins/dev-workflow/tests/develop-channel-mode.bats plugins/dev-workflow/tests/epic-child-no-ask-tool.bats plugins/dev-workflow/tests/hook-python-invocation.bats tests/hook-python-isolation.bats tests/lint-plugin-validate.bats tests/injection-budget.bats tests/public-private-split.bats` が全部通る。`git diff --stat origin/main` に `scripts/git-destructive-guard.sh` と `rules/` が無いことを確かめる。触る範囲: なし（確認のみ）
- [ ] 3.3 実機の要否を (3a) の return の `画面確認:` 行で本体に伝える: 印 `DEV_WORKFLOW_UNATTENDED=1` を付けて `claude --plugin-dir <worktree>/plugins/dev-workflow` を起動し、AskUserQuestion を呼ばせて、拒否され理由文が Claude に渡ること（選択肢の画面が出ないこと）を確かめる手順を書く。W は画面で確かめない。触る範囲: なし（return に書く）

## Workflow follow-up

- hook が実行するスクリプトを変える PR なので、Ready にする前に PR に `human-merge` を付け、主のマージ待ちとして止める（本体と G が扱う）
- archive 時に `openspec/specs/unattended-ask-hook/spec.md` の Purpose を書く
