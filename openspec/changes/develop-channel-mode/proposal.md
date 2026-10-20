## Why

flatmate の住人（tmux に常駐する Claude Code。オーナーはコンソールを見ず、Discord などのチャンネルだけで会話する）がオーナーから開発を頼まれて develop を使うと、今の実行モードのどちらにも合わない。interactive は主に聞くときに AskUserQuestion を使い、保留からの再開を「新しいセッションで `/develop <番号> 許容する` と打つ」と案内するが、住人の画面は誰も見ておらず、オーナーは新しいセッションを開けない。住人は AskUserQuestion を禁止されている（flatmate CLAUDE.md。2026-08-07 に住人 gene が AskUserQuestion の回答待ちで約 12 時間止まった）。unmanned（`--unmanned`）は loop-dev-agent の憲法が外枠を持つ 1 サイクル 1 仕事の形で、主に聞けず G も回さないので、オーナーの依頼に応える使い方ではない。

前提だった 2 つの変更は main に入った。#1124 で、起動する側が付ける印 `DEV_WORKFLOW_UNATTENDED` のあるセッションでは git ガードが確認画面を出さずに拒否し、チャンネルで主に承認を求めるよう案内する。#1125 で、`OWNER_REPLY_CHANNEL_SENDERS` に許可した送信者のチャンネルの発言を `owner-reply-check.sh` が主の発言として数える。この 2 つを使って、住人が develop を使うときの決まりを develop に書く。

## What Changes

- 実行モードに 3 つ目の `channel` を足す。工程は interactive と同じ (0)〜(4) を回し、主に聞く先・保留からの再開・エピックの回し方・主への発言の 1 行目だけを変える
- モードの決め方を書く: `--unmanned` があれば unmanned。無ければ、セッションに印 `DEV_WORKFLOW_UNATTENDED`（git ガードと同じ読み方。未設定・空・`0` は印なし）があるか、develop の依頼がチャンネルのメッセージで届いたなら `channel`。どちらでもなければ interactive。本体は開始時に 1 回決め、develop 開始コメントに `実行モード:` の行で残す
- channel モードでは本体は AskUserQuestion を呼ばない。develop と、develop から読む文書（`references/decision-criteria.md`・`references/roles/spec-reviewer.md`・`templates/escalation-tripwires.md`・`commands/develop.md` の引数の分岐と issueify フォールバック・`skills/issueify/SKILL.md`）の「interactive は AskUserQuestion で聞く」は、channel モードでは「依頼の届いたチャンネルに質問を送ってターンを終える」と読む
- channel モードの保留: 引き継ぎのコメントは今までどおり残し（`実行モード: channel`）、主への案内は「このチャンネルで記録先の番号を添えて返事をすれば続ける」にする。新しいセッションを開く案内と `/develop <記録先> 許容する` の案内は出さない。住人のセッションが入れ替わっていても、チャンネルの返事を受けたセッションが引き継ぎから再開する
- channel モードのリスク許容: チャンネルの返事は `owner-reply-check.sh` の「会話で受領」で確かめる。`OWNER_REPLY_CHANNEL_SENDERS` が設定されていないセッションでは、チャンネルの返事を確かめられないので、リスク許容だけは PR のコメントで返すよう案内する
- channel モードのエピック: `route` を呼ばずサブエージェント方式で回す（Orca や tmux で起こした別のセッションには印が渡らず、その画面も誰も見ていないため）
- channel モードの主への発言（質問・保留の依頼・完了報告・エピックの親の報告）は 1 行目を `主がすること: なし` か `主がすること: このチャンネルで <何を返す>`（PR のコメントが要るときは `主がすること: PR #<N> に <何を書く>` と URL）にする。画面・タブ・入力欄を指さない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 要件「実行モードと unmanned の責務分割」の実行モード表に `channel` を足す。要件「保留で止まるときは記録先に引き継ぎのコメントを 1 種類の書式で残す」の `実行モード` の値と主への案内を channel モードに合わせる。channel モードの決め方・聞き方・保留からの再開・リスク許容・エピックの回し方・主への発言の 1 行目を新しい要件として足す

## Impact

- `plugins/dev-workflow/skills/develop/SKILL.md`（実行モードの節・保留で止まるときの引き継ぎの節・新しいセッションでの再開・エピックの回し方の経路の決め方・レビューの周の「主に聞くとき」）
- `plugins/dev-workflow/commands/develop.md`（interactive で実行するという文と、引数の分岐 ②⑤ と issueify フォールバックの聞き方）
- `plugins/dev-workflow/tests/develop-channel-mode.bats`（新規。SKILL.md と commands/develop.md の文面を確かめる）
- `plugins/dev-workflow/changes/1126.md`（新規。変更の記録）
- `references/decision-criteria.md`・`references/roles/spec-reviewer.md`・`templates/escalation-tripwires.md`・`skills/issueify/SKILL.md` は直さない（SKILL.md の読み替えの規則 1 か所で扱う）
- flatmate 側（別リポジトリ）: 住人の起動で印 `DEV_WORKFLOW_UNATTENDED` を付けること（genetta-inc/flatmate#1663）と、住人のセッションの環境に `OWNER_REPLY_CHANNEL_SENDERS` を置くこと。住人が別に起こすセッションへ印を渡すことは #1123（起動部品の差し替え）の範囲
