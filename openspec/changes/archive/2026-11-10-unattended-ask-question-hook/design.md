# Design

## Context

動機は proposal.md の Why。現状の関係する部品は次のとおり。

- 無人の印 `DEV_WORKFLOW_UNATTENDED` は #1124 で決めた「このセッションの画面を見ている人がいない」印で、起動する側（flatmate の住人の `boot.sh` など。flatmate#1663・#1123）が claude の環境に入れる。hook のプロセスにもその環境が引き継がれる。読み方は spec `destructive-git-hook` の要件「確認画面が出るモードでだけ ask を返す」にあり、`scripts/git-destructive-guard.sh` は埋め込みの Python で `(os.environ.get("DEV_WORKFLOW_UNATTENDED") or "").strip()` が `""` か `"0"` なら印なしとしている。develop の SKILL.md「モードの決め方」も同じ読み方を Bash で行う
- develop の channel モードは「印があるか、依頼がチャンネルのメッセージ（本文が `<channel source=` で始まる発言）なら channel」と決める（spec `dev-workflow-develop`）。2 つ目の信号はプロンプト本文で、hook の PreToolUse の payload には載らない
- `tests/develop-channel-mode.bats` の「reading rule」の検査は、`plugins/dev-workflow/` 配下（`tests/` と `changes/` を除く）で `AskUserQuestion` を含むファイルが、`channel.md` の読み替えの対象の列挙にすべて載っていることを求める。hook の登録（matcher）と hook の本体はこの語を含む

## Goals / Non-Goals

**Goals:**

- 印のあるセッションの AskUserQuestion を、呼んだスキル（develop・wt-clean・その他のプラグイン）によらず hook で拒否し、理由文でチャンネルに聞く手順へ誘導する
- 印の無いセッションの振る舞いを一切変えない

**Non-Goals:**

- 印が無く、依頼がチャンネルから届いただけで channel になったセッションの AskUserQuestion を止めること（下の Decisions の 2 つ目）
- `DEV_WORKFLOW_GIT_GUARD_NO_ASK` の印で AskUserQuestion を止めること。NO_ASK は spec `destructive-git-hook` で「git ガードだけに効く印」と決めてあり、主の承認の範囲も `DEV_WORKFLOW_UNATTENDED` だけである
- `ExitPlanMode` など、AskUserQuestion 以外の対話で止まりうるツールを止めること
- hook を無効にする逃げ道の環境変数を足すこと。止めたくないセッションは印を付けなければよく、印は起動する側が決めるものなので、別の逃げ道は要らない

## Decisions

### 印の読み方は写し、git ガードと共有部品にしない

hook の本体は bash だけで書き、`DEV_WORKFLOW_UNATTENDED` の値の前後の空白（`[[:space:]]`）を除いて、空か `0` なら印なし、それ以外は印ありとする。git ガードの読み方は `git-destructive-guard.sh` の中の埋め込み Python の 2 行で、関数としても別ファイルとしても切り出されていない。

- 採る: 同じ規則を bash で書き、同じ値の表（未設定・空・空白だけ・`0`・` 0 `・`1`・` true `・`yes`）を新しい bats で確かめて、2 つの実装の読み方が揃っていることをテストで保つ
- 棄却: 共通ファイル（例: `scripts/lib/unattended-mark.sh`）に切り出して両方から読む。`git-destructive-guard.sh` を書き換えることになり、親エピックの方針（このスクリプトは触らない。Draft PR #1463 と重なりうる）に反する。読み方は 1 行の規則で、spec に正本があるので、写しても食い違いはテストで見つかる
- 棄却: Python で書く。payload を読む必要が無く（matcher で AskUserQuestion だけが来る）、環境変数 1 つを見るだけなので python3 の起動は要らない。python3 が無い環境で fail-open になる経路も生まれない

### hook は印だけで判定し、チャンネルの依頼だけで channel になったセッションは範囲外にする

hook が受け取るのは PreToolUse の payload（`tool_name`・`tool_input`・`session_id`・`permission_mode` など）とプロセスの環境変数で、develop の依頼の発言の本文は見えない。

- 採る: 印だけで判定する。理由は 3 つ。1) 主の承認の範囲が「印があるセッション」であり、範囲を広げるには承認を取り直す必要がある。2) develop の SKILL.md は「オーナーが自分の画面の前にいて Discord から頼んだセッションが channel になるのは許す」としていて、印の無いチャンネルの依頼には画面の前に人がいる場合が含まれる。そこで AskUserQuestion を拒否すると、答えられる人がいるのに止めることになる。3) 印の無いチャンネルの依頼で develop が AskUserQuestion を呼ばないことは、develop の文面（`channel.md` の読み替えの規則）が既に担っている
- 棄却: UserPromptSubmit の hook で `<channel source=` で始まる発言を見つけたらセッションごとの状態ファイルに書き、PreToolUse の hook がそれを読んで拒否する。上の 2) の理由で止めすぎるうえ、状態ファイルの寿命（いつ消すか・別の依頼に切り替わったら）の設計が増え、聖域（hooks）への変更が承認の範囲を超える
- 残る穴: 印が付かず、依頼もチャンネル以外から届いた住人は、hook にも develop の文面にも止められない。これは #1126 の Risks と issue の本文のとおり、印が付く経路（#1123・flatmate#1663）で塞ぐ

### hook は payload を見ず、呼び出し元（主・サブエージェント）で分けない

- 印があれば必ず deny を返す。payload は読み捨てる（標準入力は最後まで読んでから終わる。書き手が途中で詰まらないため）。matcher が `AskUserQuestion` なので、他のツールでは起動されない
- サブエージェントは通常 AskUserQuestion を持たないが、持っていた場合に備え、理由文の最後に「サブエージェントなら質問を本体への return に書いて返る」を 1 文入れる。`agent_id` で文面を分けると payload の読み取り（JSON の解析）が要り、上の「bash だけ」の判断と合わないので分けない
- `permission_mode` によらない。bypassPermissions でも PreToolUse の deny は効く

### 拒否理由は develop の「channel の聞き方」に沿い、develop に限らず読める形にする

理由文は固定の 1 段落で、次を含める: このセッションに無人の印 `DEV_WORKFLOW_UNATTENDED` があり画面を見ている人がいないこと／AskUserQuestion を打ち直さないこと／依頼がチャンネルから届いたなら、その発言の開きタグの `chat_id` にチャンネルの返信ツールで質問を送り、ターンを終えること／チャンネルから届いていなければ、セッションの運用（憲法・CLAUDE.md）が決める主への連絡先に送り、分からなければ記録先に質問をコメントして `needs-approval` を付けて止まること／選択肢は本文に番号付きで書き、文面は `rules/communication-style.md` の 3 番目の型に従うこと／サブエージェントなら本体への return に書くこと。先頭に `[dev-workflow unattended-ask-guard]` を付け、どの hook が止めたかを分かるようにする（git ガードの理由文と同じ形）。

- 採る: 宛先・URL の添え方・needs-approval まで理由文に書く。develop 以外のスキル（wt-clean など）から呼ばれたときは `channel.md` を読んでいないので、理由文だけで次の行動が決まる必要がある
- 棄却: 「develop の references/channel.md を読む」とだけ書く。develop 以外では読む理由が無く、プラグインのパスの解決も要る

### AskUserQuestion に触れるファイルの列挙から hook の 2 ファイルを除く

- 採る: `channel.md` の除外（現在は「develop の SKILL.md とこのファイルを除く」）に `hooks/hooks.json` と `scripts/unattended-ask-guard.sh` を足し、`tests/develop-channel-mode.bats` の「reading rule」の検査でも同じ 2 つのパスを名指しで飛ばす。この列挙は「interactive は AskUserQuestion で聞く」を channel で読み替える手順の文書の一覧で、hook の 2 ファイルは手順として読まれない
- 棄却: 2 ファイルを列挙に載せる。読み替える文が無いファイルを読み替えの対象に挙げることになり、列挙の意味が崩れる
- 棄却: `hooks/` ディレクトリごと除く。将来 `hooks/` に手順の文書が置かれることは無いが、除外を名指しにしておけば、別の hook が AskUserQuestion に触れたときに検査が落ちて、除くか列挙するかを考える機会になる

## Risks / Trade-offs

- [Claude Code の版によって、AskUserQuestion への PreToolUse の deny の効き方が変わる（拒否が無視される・理由が Claude に渡らない）] → bats では hook の出力だけを確かめる。実機で 1 回、印を付けたセッションで AskUserQuestion が拒否され、理由文が Claude に渡ることを確かめる（(3a) の return の `画面確認:` 行で本体に要否を伝える）
- [印のある住人が、hook の無い環境（dev-workflow を入れていない・古い版の cache）で動く] → hook は入っていなければ効かない。develop の文面の規則がそのまま残るので、develop の経路では従来どおり
- [印の読み方の規則が git ガード側だけ変わり、2 つが食い違う] → 両方の bats が同じ値の表を持つ。spec `unattended-ask-hook` は読み方を spec `destructive-git-hook` と同じと書き、片方を変える PR はもう片方の spec に当たる
- [オーナーが画面の前にいるのに印を付けて起動したセッションで、AskUserQuestion が使えない] → 印は「画面を見ている人がいない」ときに起動する側が付けるもので、付けた側の誤り。理由文に従えばチャンネルで聞けるので止まりはしない

## Migration Plan

- マージ後、marketplace の自動更新で hook が入る。印を付けていないセッションには何も起きないので、移行の手順は要らない
- 戻すときは hooks.json の 1 項目とスクリプトを消す PR を出す
