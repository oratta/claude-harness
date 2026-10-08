## 1. 準備

- [ ] 1.1 origin/main を取り込み、#821・#822 が先に main に入っていれば差分を確かめる（`git fetch origin && git log --oneline HEAD..origin/main -- plugins/dev-workflow/scripts/git-destructive-guard.sh plugins/dev-workflow/tests/git-destructive-guard.bats`）。書き換え前の結果と比べるため、書き換え前のスクリプトを scratchpad に控える。触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:1-373

## 2. テスト（先に書き、F1・F4〜F10 の「止まる」側が落ちることを確かめる）

- [ ] 2.1 bats に見出し `# --- シェル構文の読み（#820 F1・F4〜F10） ---` のまとまりを足し、spec の各 Scenario（改行を含む引数・複数行のメッセージ・置換の中の閉じ括弧・コメント・リダイレクト・行継続・単一引用符の中の行継続・引用された演算子と引用されていない演算子・区切り語と here-string・引用された／引用されていないヒアドキュメント本文の置換）を 1 つずつ @test にする。改行・タブは `$'...'` で書く。置き場所は `out of scope: message bodies are not read as commands` の直後、`# --- 引数を取るオプションの値` の見出しの前。既存の @test は変えない。触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:156-165（`expect_stopped` / `expect_silent` は 49-63）

## 3. 字句読みの書き換え

- [ ] 3.1 `substitutions` / `normalize` / `tokenize` / `simple_commands` を、design.md「字句の読みを、引用状態と種別を保つ 1 回の走査に置き換える」の規則（演算子・行継続・コメント・リダイレクト・ヒアドキュメント・here-string・置換・改行を含む語・閉じていない引用符の扱い）で 1 つの字句読みに置き換える。不要になる `HEREDOC` 正規表現と `OP_CHARS` は消すか字句読みの中に移す。触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:66-190（定数 66-74 のうち `ASSIGN` `SHORT` `WRAPPERS` `SHELLS` `GIT_OPTS_WITH_ARG` `MAIN_REFS` は残す）
- [ ] 3.2 `judge` を字句読みの出力（単純コマンドの並びと置換の中身の並び）を使う形に直す。`judge_simple` の wrapper の読み飛ばし（214-226）と `bash -c` / `eval` の再帰（227-238）の振る舞いは変えない。触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:201-211
- [ ] 3.3 スクリプト先頭のコメントに、字句読みが扱う構文と扱わない構文（design.md の Non-Goals）を 1〜2 行で足す。触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:1-27

## 4. 確認

- [ ] 4.1 `bats plugins/dev-workflow/tests/git-destructive-guard.bats` が全件 ok（既存の @test を含む）
- [ ] 4.2 1.1 で控えた書き換え前のスクリプトと書き換え後のスクリプトに、既存 bats の全入力と #820 の入力を同じ payload で流し、結果（ask / deny / 無出力）が変わったのが #820 の入力だけであることを一覧にして確かめる（使い捨ての比較で、リポジトリには置かない）
- [ ] 4.3 `shellcheck plugins/dev-workflow/scripts/git-destructive-guard.sh` と `scripts/test.sh` が exit 0

## 5. 記録

- [ ] 5.1 変更の記録 `plugins/dev-workflow/changes/820.md` を書く（何を直したか、字句読みに置き換えた理由、ADDED で要件を足した理由、扱わない構文）。触る範囲: plugins/dev-workflow/changes/820.md（新規）
