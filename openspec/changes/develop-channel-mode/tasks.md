## 1. テストを先に書く

- [ ] 1.1 `plugins/dev-workflow/tests/develop-channel-mode.bats` を新しく作り、`tests/develop-skill.bats` と同じ形（`LC_ALL=C.UTF-8`・節の切り出し関数）で、次を文面の確かめとして書く（この時点では落ちることを確かめる）。実行モードの節に `channel` の行があり回す工程が (0)〜(4)・決める順（`--unmanned` → 印 `DEV_WORKFLOW_UNATTENDED` かチャンネルの依頼 → interactive）・印の読み方（未設定・空・`0` は印なし）・開始コメントの `実行モード:` の行・読み替えの規則と対象の 5 文書の名前・`チャンネルの返事の確認:` の行・channel のエピックは `route` を呼ばず `回し方: サブエージェント（channel モード）`・channel の主への発言の 1 行目の 3 形と画面・タブを書かないこと。保留の節の引き継ぎの表の `実行モード` が `interactive / channel / unmanned`・channel の主への案内（チャンネルで記録先の番号を添えて返事）・番号の無い返事の扱い。再開の節に、channel ではチャンネルの返事を手順 2 の回答として扱うこと。`commands/develop.md` の分岐 ②⑤ と issueify フォールバックに channel ではチャンネルで聞くこと。SKILL.md と `commands/develop.md` の `AskUserQuestion` を含む各行が、その行の中か実行モードの節の読み替えで channel を除いていること（行ごとの許可リストにせず、読み替えの規則の存在と、各行が interactive の文脈であることを確かめる） 触る範囲: plugins/dev-workflow/tests/develop-channel-mode.bats（新規）、plugins/dev-workflow/tests/develop-skill.bats:1-40（書き方の手本として読むだけ）

## 2. SKILL.md の実行モード

- [ ] 2.1 「実行モード」の表に `channel` の行を足し（起動: 印かチャンネルの依頼・本体: そのセッション・対話: チャンネルで聞く（AskUserQuestion は使わない）・回す工程: (0)〜(4)）、表の下にモードの決め方（決める順・印の読み方・Bash で読む・開始コメントの `実行モード: <モード>（<理由>）`・途中で変えない・再開では引き継ぎの値を使う）と、channel の 4 つの違いの要約を書く。interactive の行の対話の欄は今のまま 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:390-399（「実行モード」）
- [ ] 2.2 同じ節に channel の聞き方（依頼の届いたチャンネルの `chat_id` に返信ツールで送りターンを終える・チャンネル以外から始まったときの連絡先と、分からないときの記録先コメント＋`needs-approval`・記録に残す問いは先にコメントしてフル URL を添える・100 行を超える中身は記録先に置く）と、読み替えの規則（develop と、develop から読む `references/decision-criteria.md`・`references/roles/spec-reviewer.md`・`templates/escalation-tripwires.md`・`commands/develop.md`・`skills/issueify/SKILL.md` の「interactive は AskUserQuestion」を channel ではこの聞き方に読む）を書く 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:390-399（「実行モード」）
- [ ] 2.3 同じ節に channel のリスク許容（開始時に `OWNER_REPLY_CHANNEL_SENDERS` の有無を値を出さずに確かめ、開始コメントに `チャンネルの返事の確認: 可 / 不可（OWNER_REPLY_CHANNEL_SENDERS が無い）`・不可ならリスク許容だけ PR のコメントを案内・受け直しの案内は PR のコメント）と、channel の主への発言の 1 行目の 3 形（画面・タブ・入力欄を書かない）を書く 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:390-399（「実行モード」）
- [ ] 2.4 「Role profile の選択」の develop 開始コメントに残すものの列挙に、`実行モード:` の行と（channel のとき）`チャンネルの返事の確認:` の行を足す 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:22（「Role profile の選択」の 1 段落目）

## 3. SKILL.md の保留・再開・聞く箇所・エピック

- [ ] 3.1 「保留で止まるときの引き継ぎ」の表の `実行モード` を `interactive / channel / unmanned` にし、「主への案内」の段落を interactive の案内として残したうえで、channel の案内（このチャンネルで記録先の番号を添えて返事をすれば続ける。新しいセッションと `/develop <記録先> 許容する` の案内は出さない。同じセッションに届けばそのまま続ける・キャッシュの代金は受け入れる）を足す 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:298-328（「保留で止まるときの引き継ぎ」）
- [ ] 3.2 「新しいセッションでの再開」の手順 2 に、channel（引き継ぎの `実行モード: channel`）ではチャンネルの返事を「`/develop` の引数の残り」の代わりの回答として扱うこと、返事に添えた番号で記録先を決めること、番号の無い返事は開いている引き継ぎが 1 件ならそれ・2 件以上ならチャンネルで聞き直すことを足す 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:330-341（「新しいセッションでの再開」）
- [ ] 3.3 「レビューの周を主に聞かずに続ける」の「主に聞くとき」の `interactive は AskUserQuestion で判断を仰ぎ` に `channel はチャンネルで聞き`（実行モードの節の聞き方）を足す 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:294
- [ ] 3.4 1 ループの (4) の「保留 →」の「主に新しいセッションでの再開を案内する」に、channel では実行モードの節の案内にすることを足す 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:183
- [ ] 3.5 「エピックの扱い」→「回し方」の経路の決め方の unmanned の文の隣に、channel も `route` を呼ばずサブエージェント方式で回し、エピックに `回し方: サブエージェント（channel モード）` を残すこと・develop の手順のために別の Claude Code セッションを起こさないことと、その理由（別のセッションには印が届かず、その画面を誰も見ていない）を足す 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:421（「回し方」の経路の決め方の段落）
- [ ] 3.6 SKILL.md の frontmatter の `description` は変えない（常時注入の予算 `tests/injection-budget.bats` を動かさないため） 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:1-5（読むだけ）

## 4. commands/develop.md

- [ ] 4.1 「interactive モード（デフォルト）で実行する」の文を、実行モードは SKILL.md「実行モード」の決め方で決める（`--unmanned` はこのコマンドから使わない、は残す）に直す 触る範囲: plugins/dev-workflow/commands/develop.md:35
- [ ] 4.2 引数の分岐 ② と ⑤ の候補の提示、issueify フォールバックの手順 2 のヒアリングと手順 4 の承認ゲートに、channel ではチャンネルに送ってターンを終え、AskUserQuestion を呼ばないことを 1 文ずつ足す 触る範囲: plugins/dev-workflow/commands/develop.md:37-47（「引数の解釈」）、plugins/dev-workflow/commands/develop.md:51-75（「issueify フォールバック」）

## 5. 記録と確かめ

- [ ] 5.1 変更の記録 `plugins/dev-workflow/changes/1126.md` を、既存の記録（例: `changes/1125.md`）の形で書く。住人の環境で使うために flatmate 側で要る設定（印 `DEV_WORKFLOW_UNATTENDED` と `OWNER_REPLY_CHANNEL_SENDERS`）と、受け入れ条件 3 つ目をマージ後に flatmate #1638 のリハーサルで確かめることを書く 触る範囲: plugins/dev-workflow/changes/1126.md（新規）、plugins/dev-workflow/changes/1125.md（手本として読むだけ）
- [ ] 5.2 `bats plugins/dev-workflow/tests/develop-channel-mode.bats` と、文面を確かめる既存のテスト（`develop-skill.bats`・`develop-command.bats`・`develop-handover.bats`・`develop-roles.bats`・`spec-decision-and-review.bats`・`epic-dispatch.bats`）と `tests/injection-budget.bats` を通す 触る範囲: plugins/dev-workflow/tests/（実行のみ）、tests/injection-budget.bats（実行のみ）
- [ ] 5.3 `openspec validate develop-channel-mode --type change --strict` を通す 触る範囲: openspec/changes/develop-channel-mode/（実行のみ）
