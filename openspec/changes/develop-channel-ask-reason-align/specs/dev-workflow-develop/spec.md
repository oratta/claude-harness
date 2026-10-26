## MODIFIED Requirements

### Requirement: channel モードでは主に聞くときチャンネルに送り、AskUserQuestion を呼ばない

channel の本体は AskUserQuestion を呼んではならない（MUST NOT）。主に聞くときは、依頼の届いたチャンネル（依頼の発言の開きタグの `chat_id`）にチャンネルの返信ツールで質問を送り、そのターンを終えなければならない（MUST）。依頼がチャンネルから届いていないときは、そのセッションの運用が決める主への連絡先に送り、連絡先が分からなければ記録先に質問をコメントして `needs-approval` を付けて止まる（MUST）。記録に残す問い（保留の依頼・2 周キャップ超え・PR トークン上限）は先に PR か記録先のコメントに書き、チャンネルの質問にそのコメントのフル URL を添える（MUST）。

`skills/develop/references/channel.md` の「channel の聞き方」は、develop と develop から読む文書の「interactive は AskUserQuestion で聞く」を、channel ではこの聞き方に読むと 1 か所に書き、対象の文書（`skills/develop/references/decision-criteria.md`・`skills/develop/references/epic-child-stop.md`・`skills/develop/references/fix-check.md`・`skills/develop/references/roles/spec-reviewer.md`・`skills/develop/references/roles/worker/common.md`・`skills/develop/references/roles/worker/spec.md`・`templates/escalation-tripwires.md`・`commands/develop.md`・`commands/work-issue.md`・`skills/issueify/SKILL.md`）を、`plugins/dev-workflow/` からの相対パスの 1 つの形で挙げなければならない（MUST）。`plugins/dev-workflow/` 配下（`tests/` と `changes/` を除く。`changes/` は変更の記録で、手順として読まれない）で `AskUserQuestion` を含むファイルは、SKILL.md と `skills/develop/references/channel.md` を除いてすべて、`plugins/dev-workflow/` からの相対パスがそのまま（バッククォートで囲んだ形で）この列挙に載っていなければならず（MUST）、bats で確かめる（SHALL。読み替えを 1 か所に書く方式は、列挙が漏れると漏れた文書の本体の手順が AskUserQuestion に流れるため）。`commands/develop.md` は、引数の分岐 ②⑤ の候補の提示と issueify フォールバックの承認が channel ではチャンネルでの質問になることを、その場にも書かなければならない（MUST。入口の分岐で主に聞く場面なので、channel.md の読み替えの規則の例外としてその場にも書く）。

この要件の守備範囲は、channel で本体が AskUserQuestion に流れる経路を develop の文面から無くすことである。拾いたい誤りは、develop の手順のどこかが channel の本体に AskUserQuestion を呼ばせること。develop 以外のスキル（wt-clean など）が AskUserQuestion を呼ぶことと、本体が文面に反して呼ぶことを機械的に止めることは、この要件の範囲に入れない。穴が見つかるたびに検査を足して塞ぎ切ることを、この要件の完了条件にしない（MUST NOT）。

#### Scenario: 2 周キャップ超えで選び直しが要る

- **WHEN** channel の本体で、仕様レビューの直し方の判定が「選び直しが要る」になる
- **THEN** 本体は記録先に `needs-approval` を付けて経緯をコメントし、そのコメントの URL を添えた質問を依頼の届いたチャンネルに送ってターンを終え、AskUserQuestion を呼ばない

#### Scenario: 引数なしの /develop をチャンネルで頼まれた

- **WHEN** channel の本体が `commands/develop.md` の分岐 ⑤（引数なし）を処理する
- **THEN** 開いている issue の一覧と 2 つの選択肢をチャンネルに送ってターンを終え、AskUserQuestion を呼ばない

#### Scenario: AskUserQuestion の経路が残っていない

- **WHEN** SKILL.md と `commands/develop.md` で `AskUserQuestion` を含む行を読む
- **THEN** その行か、`references/channel.md` の読み替えの規則によって、channel では AskUserQuestion を呼ばないことが読み取れる

#### Scenario: AskUserQuestion に触れるファイルが列挙から漏れていない

- **WHEN** bats が `plugins/dev-workflow/` 配下（`tests/` と `changes/` を除く）で `AskUserQuestion` を含むファイルを集める
- **THEN** SKILL.md と `skills/develop/references/channel.md` 以外のすべてのファイルの `plugins/dev-workflow/` からの相対パスが、バッククォートで囲んだ形で `references/channel.md` の読み替えの対象の列挙に載っている
