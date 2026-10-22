## 1. 置き換え前の基準を取る（読み取りだけ・編集しない）

- [ ] 1.1 比較用の作業場を scratchpad に作る（`git clone` で origin/main の写しを 2 つ: 旧 bats 用と、実装後に新 bats を載せる用。破壊的な git 操作で戻さず、壊れたら作り直す）。旧 bats（origin/main の `tests/public-private-split.bats`）で、検索の 4 つの振る舞いを範囲ごと（nondev・devwf-moko・devwf-flatmate・devwf-dev-dir）に記録する: ①今の main で 0 件（`bats` が通る）②辞書の語を含む行を公開版の部品に 1 行足すと落ちる③許可された行は通る（許可の行を含むファイルの許可どおりの行）④同じファイルの別の行に同じ語を足すと落ちる。記録は表（範囲 × 振る舞い × 旧の結果）にして 4.2 で使う。触る範囲: なし（実行だけ）

## 2. 辞書・allow・bats を置き換える

- [ ] 2.1 テストを先に書く: `tests/public-private-split.bats` の 455-537 行（dev-workflow 以外の検索）と 539-609 行（dev-workflow の検索）の手前に、共有スクリプトを呼ぶ補助関数（検索範囲の一覧を作る、nondev は一時ディレクトリへ段階化して個人版の節を空行にする、辞書と allow を渡して呼ぶ）と、次のテストを足す。固有名の語は辞書の先頭の語を読んで使い、bats に直書きしない。テスト名は ASCII のみ。(a) 5 つの呼び出し（nondev・nondev-pc-path・devwf-moko・devwf-flatmate・devwf-dev-dir）が今の main で exit 0 (b) 段階化したコピーの対象ファイルに辞書の語の行を 1 行足すと exit 1 で `<パス>:<行番号>:<語>` が出る（範囲ごと）(c) allow に載った行は通り、同じファイルの別の行に同じ語を足すと exit 1 (d) 辞書の語の大文字始まりの綴りの行を足すと exit 1 (e) 語を名前に含むファイルを範囲に足すと `<パス>:path:<語>` で exit 1 (f) allow の写しに何も打ち消さない行を足すと「何も打ち消していない」で exit 1 (g) 個人版の節（capability-registry の `SKILL.md` の「表記規約」「資格情報の階層」）に語の行を足しても exit 0 (h) 辞書のファイルが `tests/public-names/dict/` に 6 本あり、語が 9 語だけで重複しない (i) `tests/public-private-split.bats` に辞書の語の正規表現と `NONDEV_ALLOW`・`DEVWF_ALLOW` が残らない。辞書・allow を作る前なので、この時点で (a)(h) は落ちる。触る範囲: tests/public-private-split.bats:455-609（置き換える節。新しいテストは同じ節に足す）、書き方の手本: tests/public-private-split.bats:292-300（`check_split` を呼ぶテスト）、plugins/dev-workflow/tests/forbidden-words-check.bats
- [ ] 2.2 辞書を置く: `tests/public-names/dict/` に `moko.txt`・`other-projects.txt`・`flatmate.txt`・`owner-pc-path.txt`・`new-resident.txt`・`dev-dir-env.txt` を design の表のとおりに作る（1 行 1 語。先頭に `#` のコメント行で「公開済みの語だけ。新しい固有名は書かない」と書く）。触る範囲: tests/public-names/dict/（新規 6 本）
- [ ] 2.3 allow を移す: `tests/public-names/allow/nondev.txt` を作り、`tests/public-private-split.bats:463-484`（`NONDEV_ALLOW` の 21 行）を `<path>:<語>:=<固定の文字列>` に移す（語は各行の固定の文字列が当たる辞書の語。固定の文字列は変えない。基準「出典」「互換」を行の直前の `#` のコメントに書く）。あわせて、大文字小文字を区別しなくなって新しく当たる 2 行（`plugins/worktree/scripts/wt-setup.sh` と `plugins/worktree/skills/wt-setup/SKILL.md` の `Uranai で実証` を含む行。語は `uranai`、基準は出典）を足す。1 行が 2 語に当たる行があれば語ごとに 1 行にする。実際の当たりは `bash plugins/dev-workflow/scripts/forbidden-words-check.sh --root <段階化した一時ディレクトリ> --dict ... < 一覧` の出力から起こし、行の過不足（過は「何も打ち消していない」、不足は当たりの違反）が 0 になるまで合わせる。触る範囲: tests/public-names/allow/nondev.txt（新規）、移し元は tests/public-private-split.bats:463-484
- [ ] 2.4 bats を置き換える: `tests/public-private-split.bats` の 455-609 行から、検索語の正規表現（`nondev_hits` に渡していた語・`devwf_unlisted` の第 1 引数）、`NONDEV_ALLOW`・`DEVWF_ALLOW`、`nondev_unlisted`・`devwf_unlisted`、許可リストの鮮度の 2 本のテスト（`every allow-list entry still matches a line`・`every dev-workflow allow-list entry still matches a line`）を消し、範囲の決定（`NONDEV_SCOPE`・`nondev_files`・`DEVWF_FLATMATE_FILES`・`DEVWF_DEVDIR_FILES`・`devwf_public_files`）と 2.1 の呼び出しだけにする。語の検索 5 本（`non-dev-workflow public parts carry no owner-specific names...`・`the worktree plugin carries no owner PC path`・dev-workflow の 3 本）は、2.1 の呼び出しを使う形に直す。表と一覧の形・網羅の検査と配る候補の 6 ファイルの検査（1-454 行と 610 行以降）は触らない。触る範囲: tests/public-private-split.bats:455-609
- [ ] 2.5 `docs/public-private-split.md` の許可リストの置き場の記述（162 行目の「`tests/public-private-split.bats` の許可リストに 1 件ずつ載せる」ほか、`grep -n "許可リスト" docs/public-private-split.md` と `grep -n "public-private-split.bats" docs/public-private-split.md` で当たる、許可の置き場を指す記述）を `tests/public-names/allow/nondev.txt` に直す。表と一覧の中身は直さない。触る範囲: docs/public-private-split.md:162（ほか grep で当たる行）

## 3. 実機で確かめる

- [ ] 3.1 `bats tests/public-private-split.bats` が通る。通ったあと `scripts/test.sh public-private-split`（CI と同じ経路）が exit 0 になる。触る範囲: なし（実行だけ）
- [ ] 3.2 固有名を 1 つ足すと落ちることを、CI と同じ経路で確かめる: 作業場の写しで公開版のファイルに辞書の語を含む行を足して `scripts/test.sh public-private-split` が exit 0 以外になる。後始末は写しごと作り直す（破壊的な git 操作で戻さない）。触る範囲: なし（実行だけ）

## 4. 置き換えの前後で検出結果が変わらないことを確かめる

- [ ] 4.1 1.1 と同じ 4 つの振る舞い（①今の main で 0 件 ②語を 1 つ足すと落ちる ③許可された行は通る ④同じファイルの別の行に書くと落ちる）を、範囲ごと（nondev・devwf-moko・devwf-flatmate・devwf-dev-dir）に新しい bats で記録する。同じ入力（同じファイル・同じ足す行）を使う。触る範囲: なし（実行だけ）
- [ ] 4.2 1.1 の旧の表と 4.1 の新の表を並べて、4 つの振る舞いがすべて一致することを確かめ、記録先の issue にコメントする。一致しない欄があれば原因を書く。唯一の差として、旧が拾わなかった大文字始まりの綴りの当たり 2 行（2.3）を新が拾い、許可に載せたことを書く（パス名の当たりは 0 件）。触る範囲: なし（実行だけ。コメントの投稿）
- [ ] 4.3 全テスト（`scripts/test.sh`）と `scripts/lint.sh` が通る。予算ファイル `tests/injection-budget.txt` と `.github/workflows/` は動かさない。触る範囲: なし（実行だけ）
- [ ] 4.4 `openspec validate public-names-ci-check --type change --strict` が通る。触る範囲: なし（実行だけ）
