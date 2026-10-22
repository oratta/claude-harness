## 1. テストを先に書く

- [ ] 1.1 `plugins/dev-workflow/tests/forbidden-words-check.bats` を新しく作り、spec `dev-workflow-forbidden-words-check` の Scenario をテストにする（実行権限と先頭行・plugin の外のコピーから呼べること・exit 0/1/2 と `--count-file`・辞書の語の追加で落ちること・大文字小文字・パス名の当たり・コメントと空行・辞書が無い・複数の `--dict`・期限付き allow がファイル全体を許すこと・恒久 allow が固定の文字列を含む行だけを許しパス名の当たりを許さないこと・恒久は gh を引かないこと・flatmate の既存の書式の行と書式違反の文面・未使用の allow・CLOSED の gh スタブ・gh 失敗時の通知・違反の順序・flatmate の fixture と同じ文面と順序・複数の辞書に同じ語があるときの件数と綴りと順序・読めないファイル）。gh は PATH 先頭のスタブで差し替える。fixture の語はテスト内で作る架空の語にし、実在の固有名を書かない。テスト名は ASCII のみ。触る範囲: plugins/dev-workflow/tests/forbidden-words-check.bats（新規）。書き方の手本: plugins/dev-workflow/tests/unclear-reply-rephrase.bats、flatmate の scripts/test-ship-check.sh（読み取りのみ）の gh スタブ（mkstub、30-60 行目あたり）

## 2. スクリプトを足す

- [ ] 2.1 `plugins/dev-workflow/scripts/forbidden-words-check.sh` を新しく作り、実行権限を付ける。flatmate の `scripts/ship-check.sh` の「禁止語」「allow の読み込みと書式の検査」「出荷ファイルの中身とパスの照合」「allow の放置と issue の状態」の各節（読み取りのみ。flatmate の親ワークツリーの該当節を手本に、文面と順序を変えずに移す）に、恒久の種類（`=` の第 3 欄・行内の固定の文字列による許可）・複数の `--dict`/`--allow`・`--name`・`--count-file`・`FORBIDDEN_WORDS_NO_GH` を足す。冒頭のコメントに契約を書く。触る範囲: plugins/dev-workflow/scripts/forbidden-words-check.sh（新規）

## 3. 文書と記録

- [ ] 3.1 `plugins/dev-workflow/docs/forbidden-words-check.md` を書く（spec の「辞書の書式と allow の期限の規則を文書にする」の項目）。触る範囲: plugins/dev-workflow/docs/forbidden-words-check.md（新規）
- [ ] 3.2 変更の記録 `plugins/dev-workflow/changes/1207.md` を書く（何を足したか・なぜ・後続の change と flatmate#1732 への引き継ぎ）。触る範囲: plugins/dev-workflow/changes/1207.md（新規）。書き方の手本: plugins/dev-workflow/changes/1168.md

## 4. 確かめる

- [ ] 4.1 `bats plugins/dev-workflow/tests/forbidden-words-check.bats tests/public-private-split.bats tests/injection-budget.bats tests/lint-plugin-validate.bats` が通り、続けて全テスト（`scripts/test.sh`）と `scripts/lint.sh`（shellcheck）が通る。予算ファイル `tests/injection-budget.txt` と `.github/workflows/` は動かさない。触る範囲: なし（実行だけ）
- [ ] 4.2 比較は 2 段で行う（読み取りのみ。flatmate は編集しない）。(a) 正常系: flatmate の親ワークツリーの `ship/forbidden.txt`・`ship/allow.txt` と `bash scripts/ship-check.sh --list` の一覧を共有スクリプトに渡し、現行の `bash scripts/ship-check.sh` と同じく違反 0 件・exit 0 になることを確かめる（実リポジトリは違反が無いので、ここで見るのは正常系だけ）。(b) 違反系: 禁止語・パス名の当たり・期限付き allow・書式違反・未使用・CLOSED の gh スタブを入れた fixture を作り、同じ辞書・allow・一覧を現行の `ship-check.sh` と共有スクリプトの両方に渡して、標準エラーの違反の行が同じ文面・同じ順序で一致することを確かめる。移植元の集計行 `ship-check: 違反 N 件` と末尾の `ship-check: OK（…）` は呼び出し側（flatmate）の責務なので比較から除き、N は `--count-file` の値と照らす。結果を記録先にコメントする。触る範囲: なし（実行だけ）
- [ ] 4.3 `openspec validate forbidden-words-check --type change --strict` が通る。触る範囲: なし（実行だけ）
