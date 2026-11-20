# Tasks

行番号は仕様づくりの時点（基準 HEAD `032656e4`）の値。編集前に該当範囲を読み直す。テストが先、実装があと。

## 1. スクリプトとテスト

- [x] 1.1 `plugins/dev-workflow/tests/parent-merge-inputs.bats` を新規に書く。spec の全 Scenario（入力文の節の見出し・前提 4 つそれぞれの exit 3・exit 1 の 3 種・信頼できない投稿者の PR コメントが出ない・委任の候補の最新 1 件と `--delegation-place`・既存の `stop-judge.bats` の差し替えの手本どおり `gh` を PATH の偽物で差し替える）を書き、実装前に失敗することを確かめる。触る範囲: plugins/dev-workflow/tests/parent-merge-inputs.bats（新規）、plugins/dev-workflow/tests/stop-judge.bats:1-60（`gh` の差し替えの書き方の手本）
- [x] 1.2 `plugins/dev-workflow/scripts/parent-merge-inputs.sh` を新規に書く。`read_trusted_body` と同じ投稿者の確認は `stop-judge.sh` のものを手本にし（共通化はしない）、前提 4 つは今の `epic-merge-wait.md` の文のとおりに実装する。触る範囲: plugins/dev-workflow/scripts/parent-merge-inputs.sh（新規）、plugins/dev-workflow/scripts/stop-judge.sh:60-130（`read_trusted_body` と gh の読み方）

## 2. 手順書を呼び方と分類にする

- [x] 2.1 `epic-merge-wait.md` の **マージ待ちの子** の段落から、前提の確認の `gh` の書き方と入力の列挙を消し、`parent-merge-inputs.sh` の呼び方と分類（`主に上げる:` なら主に上げる／入力文なら決める役に渡す）にする。**残す文**: 決める役を起こして `parent-merge-criteria.md` で判断させること、可のとき古い `parent-merge-approved` を外す・HEAD の取り直し・コメント → ラベルの順・`reply --as parent`・エピックへの `マージに回した` の 1 行、否・不足・迷ったときは主に上げること、印を付けるのは親だけ・`gh` の認証アカウントの条件。`parent-merge.bats` の該当断言（83・92 行目付近）、`develop-skill.bats` の「子の最後の発言の全文（更新前の版の子は停止の記録）」が手順書と判断基準にあることの検査（1901・1903 行目）、`owner-escalation-narrowing.bats` の「有効な委任の本文・URL・確認場所を決める役に渡す」の検査（225 行目付近。段落と spec の `**判断**` 行の文言を見ている）を、手順書の文言ではなく、スクリプトの出力（子の最後の発言のファイルの本文・委任の記録の候補の本文と URL・`--delegation-place` の行が入力文に出ること。`parent-merge-inputs.bats` で検査）へ移し、親が委任の有効性を確かめてから `--delegation-place` を渡す条件が手順書に残っていることの検査に付け替える。ほかの断言も、段落ではなくスクリプトの呼び方と残す文を見る形に付け替える。触る範囲: plugins/dev-workflow/skills/develop/references/epic-merge-wait.md:5、plugins/dev-workflow/tests/parent-merge.bats:75-120、plugins/dev-workflow/tests/develop-skill.bats:1895-1904、plugins/dev-workflow/tests/owner-escalation-narrowing.bats:220-232
- [x] 2.2 `parent-merge-criteria.md` の「守備範囲」の入力の列挙を、スクリプトの出力を指す 1 文にする（拾いたい誤りと止めないものの文は残す）。`develop-skill.bats:1903` の `parent-merge-criteria.md` に「子の最後の発言の全文（更新前の版の子は停止の記録）」があることの検査は、この 1 文にその語を残すか、スクリプトの出力の検査（2.1）へ移す。触る範囲: plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md:42-44
- [x] 2.3 `epic-multirepo.md` のマージ待ちの読み替え表が `gh` の読み先を書いている行は、スクリプトが PR の URL から repo を決めるので、行の文言が偽にならないか確かめて合わせる（動作は変えない）。触る範囲: plugins/dev-workflow/skills/develop/references/epic-multirepo.md（マージ待ちの読み替え表）

## 3. 予算と記録

- [x] 3.1 手順書の字数を前後で測り（`wc -m`・`wc -c`）、`tests/develop-epic-scene-budget.txt` の `parent-merge-wait`・`parent-merge-delegated` の行（と、同じファイルを含む行）を実測に合わせて下げる。`tests/injection-budget.txt` は常時注入に触れないので変えない（変わるなら理由を PR 本文に書く）。触る範囲: tests/develop-epic-scene-budget.txt:1-14
- [x] 3.2 `plugins/dev-workflow/changes/1686.md` に今回の分を足す（既存の記録があれば追記。出した 1 候補・出さなかった部分と理由・字数の前後）。触る範囲: plugins/dev-workflow/changes/1686.md
- [x] 3.3 関係する bats と `./scripts/lint.sh` を通す（検証のみ）。今回の implement 指示により、25 分超の `./scripts/test.sh` 全体は実行せず本体に委ねる。触る範囲: scripts/test.sh、scripts/lint.sh
