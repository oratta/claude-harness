## Why

マージ待ちの子を決める役（`dev-workflow:decider`）に渡す入力の列挙と、その前の 4 つの前提の確認は、`epic-merge-wait.md` の 1 段落（約 3,000 字）と `parent-merge-criteria.md` の「守備範囲」の両方に同じ一覧が文章で書かれ、親が `gh` を何本も手で打って集めている（#1686、エピック #1682 の子。PR #1739・#1741 のあとに残った 1 件）。決まった入力から決まった出力が出る処理なので、スクリプトに出せば、その分の文章が親のコンテキストに入らなくなる。`stop-judge.sh` が停止の入力を集める形と同じにする。

## What Changes

- 新しいスクリプト `plugins/dev-workflow/scripts/parent-merge-inputs.sh` を足す。`<エピック番号> <子> <PR の URL> --last-message <ファイル>` を受け、4 つの前提を `gh` で確かめ、全部満たせば決める役の入力文を stdout に組み立てて exit 0、前提を満たさなければ `主に上げる: <理由>` を出して exit 3、読めない・引数の誤り・信頼できない投稿者のときは stdout を空にして exit 1
- 入力文に入れるものは、今の手順書の列挙のとおり: エピックの本文、子 issue の本文と `親エピックからの注意書き:`（投稿者が OWNER・MEMBER・COLLABORATOR のものだけ）、子の最後の発言の全文（親が渡すファイル）、PR の本文・ラベル・今の HEAD の SHA、変更ファイルの一覧と差分、PR のリスク宣言・動作確認・ゲートのコメント、CI の結果、PR の base ブランチの `auto-merge.yml` の聖域とマージ条件の行、`human-merge` を付けた自動マージの処理の投稿、配役表、有効な委任の記録の本文と URL と親が渡す `委任の確認の場所:` の行
- `epic-merge-wait.md` の **マージ待ちの子** の段落から、前提の確認の `gh` の書き方と入力の列挙を消し、スクリプトの呼び方と「出力が `主に上げる:` なら主に上げる／入力文なら決める役に渡す」の分類だけにする。決める役を起こす・可のときの印の付け方・返事・記録は親の手順として残す
- `parent-merge-criteria.md` の「守備範囲」の入力の列挙を、スクリプトの出力を指す 1 文にする
- 手順書の字数を前後で記録し、予算ファイルを実測に合わせて下げる

## 出さないもの（理由）

- 子の最後の発言の全文の取得: 会話ログ（`child-log`）と停止の JSON から親が得るもので、`gh` だけでは集まらない。親がファイルで渡す
- 委任が有効かの判定（`epic-delegation.md` の ①〜⑥）と `委任の確認の場所:` の確認: 主の発言の位置を親が確かめる作業で機械的に決まらない。スクリプトは記録の本文と URL を出すだけで、有効かどうかを判定しない（親が確かめてから `--delegation-place` を渡す）
- 決める役の起動、可のときの印の付け替え・コメント・ラベル・`reply`・エピックへの記録: 判断と副作用を含むので親の手順に残す

## Capabilities

### Modified Capabilities
- `dev-workflow-develop`: マージ待ちの子の入力の収集と前提の確認をスクリプトが行う

## Impact

`plugins/dev-workflow/scripts/`（新規 1）、`plugins/dev-workflow/tests/`（新規 bats 1、`parent-merge.bats` の該当断言）、`skills/develop/references/`（`epic-merge-wait.md`、`parent-merge-criteria.md`）、`tests/` の予算ファイル、`plugins/dev-workflow/changes/1686.md`。既存スクリプトの出力語・終了コードと hook 本体は変えない。`plugins/dev-workflow/skills/pr-review-gate/` と `references/roles/gate-runner.md` は触らない。
