# Tasks

## 1. 共通ファイルに確かめと安全な開き方を置く

- [x] 1.1 `<base>`・`denied/`・`permits/` を lstat の 4 条件（symlink でない・ディレクトリ・自分の uid・グループと他者に書き込み権なし）で確かめ、無ければ 0700 で作る関数を足す。`<base>` の親が無ければ作らずに失敗とし、満たさなかった条件とパスを返す。既にあるフォルダのモードは変えない（spec destructive-git-hook「拒否の記録・回数・許可の置き場所（`<base>`）を確かめてから使う」） 触る範囲: plugins/dev-workflow/scripts/git-guard-scratchpad.py:22-74（`BASE_NAME` の近く、`append_log`・`write_json_atomic` の前）、plugins/dev-workflow/scripts/git-guard-scratchpad.py:137-156（`_is_scratchpad` の lstat の確かめ方を手本にする）
- [x] 1.2 `write_json_atomic` を、予測できない名前・`O_CREAT|O_EXCL|O_NOFOLLOW`・0600 で一時ファイルを作ってから `rename` で置く形にする。`append_log` を `O_APPEND|O_CREAT|O_NOFOLLOW`・0600 で開く形にする。symlink を辿らずに JSON と整数を読む関数（回数のファイル・許可・拒否の記録用）を足す 触る範囲: plugins/dev-workflow/scripts/git-guard-scratchpad.py:50-73（`append_log`・`write_json_atomic`）

## 2. git ガードの子の経路を確かめに通す

- [x] 2.1 子の経路で、判定のファイルを読んだあと、許可を使う前に 1.1 の確かめを呼ぶ。満たさなければ許可を探さず・記録を書かず・回数を数えずに `deny` を返し、理由文に「拒否の記録を作れなかった」・`<base>` のパス・満たさなかった条件・報告にコマンドの全文を書くことを入れる（`"continue"` のキーを出さない）。判定のファイルを読めないときも回数を数えない 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:884-917（`guard_base` と子の経路）、plugins/dev-workflow/scripts/git-destructive-guard.sh:935-950（子向けの理由文）
- [x] 2.2 `count_child_deny` を 1.2 の関数で読み書きする形にし（symlink を辿らずに読む・一時ファイルからの `rename` で置く）、`<base>` を自分で `makedirs` しない。置き場所の決め方（`os.environ.get("TMPDIR") or "/tmp"`）と、`tempfile.gettempdir()` を使わないことは保つ 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:776-801（`count_child_deny`）
- [x] 2.3 `use_permit` で、`rename` で取った許可を 1.2 の関数で symlink を辿らずに読む（symlink なら読めないものとして消す）。`load_common` で 1.1・1.2 の関数が揃っているかも見る 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:809-869（`load_common`・`use_permit`）
- [x] 2.4 主の呼び出しの経路が `<base>` を作りも確かめもしないことを確かめる（コードを変えずに済むならテストだけ） 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:918-926（`elif is_no_ask or is_unattended:` 以降）

## 3. rm ガードを確かめに通す

- [x] 3.1 key を出したあと、許可を使う前に 1.1 の確かめを呼ぶ。満たさなければ許可を探さず・記録も `permit-log.jsonl` の行も書かずに `deny` を返し、message を「拒否の記録を作れなかった」の文に揃えて `<base>` のパスと満たさなかった条件を足す。`use_permit` の取った許可の読み方を 1.2 の関数にする（spec rm-permission-hook「rm の hook も `<base>` を確かめてから使う」と、MODIFIED にした「子の rm の確認画面に、親の許可に従って答える」の、確かめを満たしたときだけ許可を取り記録を書く順序） 触る範囲: plugins/dev-workflow/scripts/rm-permission-guard.sh:72-157（`base`・`use_permit`・記録と message）

## 4. 許可を書くスクリプトを確かめに通す

- [x] 4.1 記録の場所から求めた `<base>` を 1.1 で確かめ、満たさなければ許可も `permit-log.jsonl` の行も書かず、回数のファイルも消さずに、条件と場所を stderr に書いて 0 以外で終わる。拒否の記録を 1.2 の関数で symlink を辿らずに読む 触る範囲: plugins/dev-workflow/scripts/git-guard-permit.sh:48-96

## 5. テスト

- [x] 5.1 git ガードのテストを足す: 新しく作る `<base>` と `denied/` が 0700・記録と回数が 0600／`<base>` が symlink なら 2 回とも deny・「拒否の記録を作れなかった」あり・「直ちに作業を終えて親に返す」なし・`"continue"` なし・先に何も作らず置いた許可が残る／0777 の `<base>` の下に何も作らない／`denied/`・`permits/` が symlink なら先に何も作らない／回数のファイルと `permit-log.jsonl` を symlink にしても先が変わらない／主の呼び出しは symlink の `<base>` でも `ask` で理由文が変わらない／判定のファイルが無いとき 2 回目も打ち切らず回数のファイルを作らない／既にある 0755 の `<base>` はそのまま使えモードが変わらない／`permits/<key>.json` を、内容が一致し期限内で一時領域の判定を満たす許可を書いた `<base>` の外のファイルへの symlink にすると allow せず、リンク先の中身が変わらない 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:807-870（「child count」の並び）、plugins/dev-workflow/tests/git-destructive-guard.bats:1834-1860（「without the shared file」）
- [x] 5.2 許可を書くスクリプトのテストを足す: 記録を書かせたあと `<base>` を 0777 にすると 0 以外で終わり、stderr に `<base>` のパスがあり、許可と `permit` の行が無い／拒否の記録が symlink なら読まずに 0 以外で終わる 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:1711-1760（「the script refuses records in the wrong place」の近く）
- [x] 5.3 rm ガードのテストを足す: `<base>` が symlink なら deny・message に「拒否の記録を作れなかった」と `<base>` のパス・先に `denied/` も `permit-log.jsonl` も作らない／symlink の先に置いた一致する許可を使わず残す。／`permits/<key>.json` を、内容が一致し期限内で rm の一時領域の判定を満たす許可を書いた `<base>` の外のファイルへの symlink にすると allow せず、リンク先の中身が変わらない。既存の「記録を書けなくても deny を返す」が通り続けることを確かめる 触る範囲: plugins/dev-workflow/tests/rm-permission-guard.bats:222-250（「without the common file」「when the record cannot be written」の近く）
- [x] 5.4 `bats plugins/dev-workflow/tests/git-destructive-guard.bats plugins/dev-workflow/tests/rm-permission-guard.bats` を全件通し、既存のテスト（とくに「child count: still denies when the count cannot be written」と「permit:」の並び）が落ちないことを確かめる 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats、plugins/dev-workflow/tests/rm-permission-guard.bats

## 6. 変更の記録

- [x] 6.1 変更の記録を書く 触る範囲: plugins/dev-workflow/changes/1155.md（新規）
