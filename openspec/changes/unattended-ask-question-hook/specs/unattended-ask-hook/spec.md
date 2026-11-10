## ADDED Requirements

### Requirement: AskUserQuestion の PreToolUse に hook を登録する

`plugins/dev-workflow/hooks/hooks.json` は `PreToolUse`（matcher `AskUserQuestion`）に `plugins/dev-workflow/scripts/unattended-ask-guard.sh` を登録しなければならない（MUST）。登録はこの 1 項目だけで、hooks.json の `if` で絞ってはならない（MUST NOT。判定はスクリプトに一本化し、bats から確かめられるようにする）。

#### Scenario: hooks.json に登録されている

- **WHEN** `plugins/dev-workflow/hooks/hooks.json` の `PreToolUse` の項目を読む
- **THEN** matcher が `AskUserQuestion` の項目がちょうど 1 つあり、その command が `"${CLAUDE_PLUGIN_ROOT}/scripts/unattended-ask-guard.sh"` である

### Requirement: 無人の印のあるセッションで AskUserQuestion を拒否する

hook は、環境変数 `DEV_WORKFLOW_UNATTENDED` に印があるとき、`hookSpecificOutput.hookEventName` が `PreToolUse`、`permissionDecision` が `deny` の JSON を標準出力に出し、exit 0 で終わらなければならない（MUST）。どのスキル・コマンドから呼ばれた AskUserQuestion でも同じに扱い、`permission_mode` と payload の中身（`agent_id` の有無を含む）で判定を変えてはならない（MUST NOT）。

守備範囲: 入力はこの環境変数だけ。拾う誤りは、画面を見る人のいないセッションで選択肢の画面が出て止まること。印が無くチャンネルの依頼だけで channel になったセッションは止めない（hook は本文を見られず、オーナーが画面の前にいる場合も含む）。穴が見つかるたびに塞ぎ切ることを完了条件にしない（MUST NOT）。

#### Scenario: 印のあるセッションでは拒否する

- **WHEN** `DEV_WORKFLOW_UNATTENDED=1` を付けて、`tool_name` が `AskUserQuestion` の payload を、`permission_mode` が `default` のものと `bypassPermissions` のもの、`agent_id` の無いものと `agent_id` が `a1` のものでそれぞれ hook に渡す
- **THEN** どれも exit 0 で、標準出力が JSON として読め、`hookSpecificOutput.hookEventName` が `PreToolUse`、`hookSpecificOutput.permissionDecision` が `deny` である

### Requirement: 印は git ガードと同じに読み、印が無ければ何もしない

印の読み方は spec `destructive-git-hook` の `DEV_WORKFLOW_UNATTENDED` と同じでなければならない（MUST）。値の前後の空白を除いたものが空（未設定を含む）か `0` なら印なし、それ以外はすべて印ありとする。印が無いときは何も出力せず exit 0 で終わらなければならない（MUST。印の無いセッションの振る舞いを変えない）。

#### Scenario: 印の値は git ガードと同じに読む

- **WHEN** `DEV_WORKFLOW_UNATTENDED` を未設定・空・空白だけ・`0`・` 0 `・`1`・` true `・`yes` のそれぞれにして、AskUserQuestion の payload を渡す
- **THEN** 未設定・空・空白だけ・`0`・` 0 ` では何も出力せず exit 0、`1`・` true `・`yes` では `permissionDecision` が `deny` である

### Requirement: git ガードの印と逃げ道で判定を変えない

hook は `DEV_WORKFLOW_GIT_GUARD_NO_ASK` と `DEV_WORKFLOW_GIT_GUARD` の値で判定を変えてはならない（MUST NOT。NO_ASK は git ガードだけに効く印で、`DEV_WORKFLOW_GIT_GUARD=off` は git ガードの逃げ道である）。

#### Scenario: git ガードの印と逃げ道によらない

- **WHEN** `DEV_WORKFLOW_UNATTENDED` を付けずに `DEV_WORKFLOW_GIT_GUARD_NO_ASK=1` だけを付けて渡す。さらに `DEV_WORKFLOW_UNATTENDED=1` と `DEV_WORKFLOW_GIT_GUARD=off` を付けて渡す
- **THEN** 前者は何も出力せず exit 0、後者は `permissionDecision` が `deny` である

### Requirement: 拒否理由はチャンネルで聞いてターンを終える手順を案内する

`permissionDecisionReason` は、呼んだスキルが develop でなくてもそれだけで次の行動が決まるよう、次を含まなければならない（MUST）: 先頭の `[dev-workflow unattended-ask-guard]`／無人の印 `DEV_WORKFLOW_UNATTENDED` があり画面を見ている人がいないこと／打ち直さないこと／依頼がチャンネルから届いたなら開きタグの `chat_id` に返信ツールで質問を送りターンを終えること／届いていなければセッションの運用が決める連絡先に送り、分からなければ記録先にコメントして `needs-approval` を付けて止まること／選択肢は本文に番号付きで書き `rules/communication-style.md` の 3 番目の型に従うこと／サブエージェントなら本体への return に書くこと。中身は develop の `references/channel.md`「channel の聞き方」と食い違ってはならない（MUST NOT）。

#### Scenario: 理由文が聞き方の要素を含む

- **WHEN** `DEV_WORKFLOW_UNATTENDED=1` で AskUserQuestion の payload を渡し、`permissionDecisionReason` を読む
- **THEN** `[dev-workflow unattended-ask-guard]`・`DEV_WORKFLOW_UNATTENDED`・`打ち直さず`・`chat_id`・`返信ツール`・`ターンを終える`・`needs-approval`・`番号`・`communication-style`・`return` をすべて含む
