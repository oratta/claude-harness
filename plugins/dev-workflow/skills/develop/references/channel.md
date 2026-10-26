# channel モードの本体の手順（develop）

develop の SKILL.md「実行モード」の節から移した 3 つの小節。読むのは、本体が SKILL.md「モードの決め方」で実行モードを channel に決めたとき（決めた直後に読む。リスク許容の確かめはモードを決めた時点で行うため）と、引き継ぎから `実行モード: channel` で再開するとき。interactive と unmanned の本体は読まない。パスの書き方は SKILL.md と同じ。

## channel の聞き方

channel の本体は AskUserQuestion を呼ばない。主に聞くときは、依頼の届いたチャンネル（依頼の発言の開きタグの `chat_id`）に、チャンネルの返信ツールで質問を送り、そのターンを終える。返事は次のチャンネルのメッセージとして同じセッションに届く。

- 依頼がチャンネルから届いていない（印だけで channel になった）ときは、そのセッションの運用（憲法・CLAUDE.md）が決める主への連絡先に送る。連絡先が分からなければ、記録先に質問をコメントして `needs-approval` を付け、止まる
- 記録に残す問い（保留の依頼・2 周キャップ超え・PR トークン上限）は、先に PR か記録先のコメントに書き、チャンネルの質問にはそのコメントのフル URL を添える
- 質問の文面は `~/.claude/output-styles/readable.md` の節 3（サブエージェントには `rules/communication-style.md` の 3 番目）の型に従う。100 行を超える中身は記録先のコメントに置いて URL で渡す（チャンネルのメッセージには長さの上限がある）

**読み替えの規則**: develop と、develop から読む次の文書に書かれた「interactive は AskUserQuestion で聞く」（候補を提示して選ばせる・承認を得る・判断を仰ぐを含む）は、channel ではこの聞き方に読む。各文書には書き足さない（同じ規則を複数の文書に書くと、直すときに片方が漏れる）。例外は `commands/develop.md` の 5 か所だけ（冒頭の実行モードの段落・引数の分岐 ②⑤・issueify のヒアリング・issueify の承認ゲート）。入口の分岐で主に聞く場面なので、その場に「channel ではチャンネルに送ってターンを終え、AskUserQuestion を呼ばない」と短く書いてよい。書くのは何をするかだけで、宛先・URL の添え方・文面は書かず、この節の聞き方に従う。対象は `plugins/dev-workflow/` からの相対パスで次の 10 個で、`plugins/dev-workflow/` 配下（`tests/` と `changes/` を除く）で AskUserQuestion に触れるファイルの全部（develop の SKILL.md とこのファイルを除く。漏れは `tests/develop-channel-mode.bats` が見つける）。

- `skills/develop/references/decision-criteria.md`
- `skills/develop/references/epic-child-stop.md`
- `skills/develop/references/fix-check.md`
- `skills/develop/references/roles/spec-reviewer.md`
- `skills/develop/references/roles/worker/common.md`
- `skills/develop/references/roles/worker/spec.md`
- `templates/escalation-tripwires.md`
- `commands/develop.md`
- `commands/work-issue.md`
- `skills/issueify/SKILL.md`

## channel のリスク許容

`owner-reply-check.sh` がチャンネルの返事を主の発言として数えるのは、セッションの環境に `OWNER_REPLY_CHANNEL_SENDERS` があるときだけ。channel の本体はモードを決めた時点で、この値が空でないかだけを値を出さずに確かめ（例: `[ -n "${OWNER_REPLY_CHANNEL_SENDERS-}" ] && echo 可 || echo 不可`）、develop 開始コメントに `チャンネルの返事の確認: 可` か `チャンネルの返事の確認: 不可（OWNER_REPLY_CHANNEL_SENDERS が無い）` の 1 行を残す。G の起動指示には、実行モードの行と並べて同じ値の `チャンネルの返事の確認: 可` / `チャンネルの返事の確認: 不可` の行を書く（SKILL.md の 1 ループの (4)）。

- 可のセッションでは、リスク許容のチャンネルの返事を pr-review-gate 手順 5 の「会話で受領」として扱い、`owner-reply-check.sh` で確かめてから保留の解除の G に渡す（書式と確かめ方は pr-review-gate 手順 5 が正本。PR へのコメントは求めない）
- 不可のセッションでは、リスク許容の依頼に限り「末尾の PR にコメントで `許容する` と書く」と案内し、PR のフル URL を添える（チャンネルで返されても確かめられず、受け直しを頼むことになるため）
- 確かめられなかったとき（終了コード 1・2）の受け直しの案内はチャンネルに送り、「ゲートと同じ PC での `/develop <記録先> 許容する`」の代わりに PR のコメントを案内する
- リスク許容以外の返事（動作確認の結果・切り出しの確認・方針の選び直し）は、可・不可によらずチャンネルの返事で進めてよい

## channel の主への発言

channel の本体は、主へのすべての発言を「channel の聞き方」と同じ宛先のチャンネルに送る。質問ではない報告（再開で HEAD が動いていた・前任 W の手渡し不可・`epic-dispatch.sh` などのスクリプトの失敗・レビューの周の打ち切り・完了報告・エピックの親の報告）も含め、端末に出すだけで済ませない（住人の画面は誰も見ていないので、端末に出しただけの報告は読まれず、主の指示を待ったまま止まる）。

1 行目と最後の行は `~/.claude/output-styles/readable.md` の節 3 の書き分けに従う（主の操作も判断も要らない報告は 1 行目を `主がすること: なし` にする（主の質問への答えは正本のとおり 1 行目に答えを書く））。判断・確認・操作を求める発言の最後の答え方の行には、channel に固有の次のことを書く。

- このチャンネルで何を返すか（例: 「#1126 許容する」か「#1126 許容しない」と返す）
- リスク許容でチャンネルの返事を確かめられないときは、末尾の PR に何を書くか。PR のフル URL を添える

答え方の行に画面・タブ・入力欄（`子のタブで`・`入力欄で ! を付けて` など）を書かない。オーナーが見ているのはチャンネルだけである。
