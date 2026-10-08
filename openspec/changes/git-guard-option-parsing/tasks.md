## 1. 失敗するテストを先に足す

- [ ] 1.1 bats に新しい `@test` を足し、issue #821 の列挙入力が止まること（`env -u FOO git reset --hard`、`git push -n --no-dry-run origin main`、`git clean -n --no-dry-run -f`、`git push --dry-run --no-dry-run --force origin main`、`git push -n --no-dry origin main`、`git push --push-opt -n origin main`、`git clean --excl -n -f`、`git push --end-of-options -n origin main`）を書く。加えて `env -uFOO git reset --hard`、`env --unset=FOO git reset --hard`、`env -iu FOO git reset --hard`、`env -S git reset --hard`（現状どおり止まる）、`git commit -n --no-dry-run -m x`（commit の `-n` は `--no-verify` で打ち消されない）も止まることを書く。既存の `@test` は書き換えない。触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:165-203（「引数を取るオプションの値」の節の後ろに足す）
- [ ] 1.2 同じく新しい `@test` で、止めてはいけない入力が何も出さないことを書く: `git push --no-dry-run -n origin main`、`git clean -f --no-dry-run -n`、`git push --dry-run --no-dry-run --dry-run --force origin main`、`git push --push-option=x -n origin main`、`env -u FOO git status`、`env -i -u FOO git push origin feature-x`。触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:165-203
- [ ] 1.3 `bats plugins/dev-workflow/tests/git-destructive-guard.bats` で 1.1 の入力が落ち、既存のテストが通ることを確かめる

## 2. スクリプトを直す

- [ ] 2.1 `judge_simple` の wrapper の読み飛ばしで、`env` のときだけ値を取るオプション（短い `u` `C` `P` `a`、長い `--unset` `--chdir` `--argv0`。`=` 付きは 1 字句。`-S` / `--split-string` は後ろの字句がコマンドとして実行されるので値を取るものとして扱わない）の値を飛ばす。短いオプションはまとめた形の最後の文字なら次の字句、途中なら同じ字句の残りが値。表は `WRAPPERS` の近くに置く。触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:66-72（定数）、plugins/dev-workflow/scripts/git-destructive-guard.sh:214-226（`judge_simple` の wrapper ループ）
- [ ] 2.2 `parse_opts` で `--end-of-options` を `--` と同じに扱う。触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:255-283（`parse_opts`）
- [ ] 2.3 `parse_opts` の長いオプションの分岐で、`=` を含まず `long_arg` のどれとも完全一致しない名前が `long_arg` のちょうど 1 つの先頭と一致するとき、そのオプションとして次の字句を値として飛ばす。触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:244-283（`ARG_OPTS` と `parse_opts`）
- [ ] 2.4 `parse_opts` の長いオプションの分岐で、`--no-d` 以上の長さで `--no-dry-run` の先頭と一致する名前を読んだら `longs` から `--dry-run` を外し、`push` / `clean` のときだけ `short_set` から `n` も外す（サブコマンドの小さな表を置く）。`judge_push` と `clean` の分岐の判定式は変えない。触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:244-283、確認のみ plugins/dev-workflow/scripts/git-destructive-guard.sh:313-317・331-344
- [ ] 2.5 スクリプト冒頭のコメント（対象の説明）のうち dry-run の記述を「dry-run（後ろの --no-dry-run で打ち消されていないもの）」に直す。触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:13-15

## 3. 確認

- [ ] 3.1 `bats plugins/dev-workflow/tests/git-destructive-guard.bats` が全件通る
- [ ] 3.2 `openspec validate git-guard-option-parsing --strict` が通る
- [ ] 3.3 `bats tests/` の中で hook・注入予算に関わるもの（`tests/injection-budget.bats` を含む）が変更前と同じ結果になる
