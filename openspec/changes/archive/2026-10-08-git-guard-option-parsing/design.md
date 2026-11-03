## Context

`plugins/dev-workflow/scripts/git-destructive-guard.sh` は Bash の command を字句に分け、単純コマンドごとに `judge_simple`（先頭の環境変数代入と wrapper を読み飛ばしてコマンド名を決める）→ `judge_git`（大域オプションを読み飛ばしてサブコマンドを決める）→ `parse_opts`（サブコマンドの引数を長いオプション名の集合・短いオプションの文字の集合・位置引数に分ける）と進む。dry-run の除外は `judge_push` と `clean` の分岐が「集合に `--dry-run` か `n` があるか」で決めている。

この読み方は git と 4 か所でずれていて、issue #821 に列挙された入力を素通りさせる（proposal の Why）。#820（シェル構文の読み）と #822（Unicode エスケープのテスト）が同じ 2 ファイルを並行して直しているので、差分は列挙 4 種を直すのに要る範囲に留め、関数の分け方や戻り値の形は変えない。

spec の守備範囲は「穴を見つかるたびに塞ぎ切ることは完了条件にしない」で、受け入れ条件は「列挙された入力が止まり、既存の止めてはいけない入力（本当の dry-run など）を止めない」である。

## Goals / Non-Goals

**Goals:**

- issue #821 の列挙入力（`env -u FOO git reset --hard`、`--no-dry-run` で打ち消す 3 形、`--push-opt -n` と `--excl -n`、`--end-of-options -n`）が止まる
- 本当の dry-run（`git push -n origin main`、`git push --dry-run --force origin feature-x`、`git clean -n`、`git push --no-dry-run -n origin main` のように打ち消しの後ろで dry-run に戻したもの）と、`env` を挟んだ無害なコマンドは従来どおり何も出さない

**Non-Goals:**

- `env` 以外の wrapper（`sudo -u root git ...` など）の値を取るオプション。同じ種類の穴だが issue の列挙外で、並行作業との衝突を増やす
- 1 字句にクォートした `env -S 'git reset --hard'` を判定すること。現状どおり素通しになる（`-S` を値を取るオプションとして読まないので、クォートしない `env -S git reset --hard` は `-S` を wrapper のオプションとして飛ばした後ろの `git` から判定され、現状どおり止まる）
- 値を取らないオプションの省略形（`git reset --har`、`git clean --forc` など）。git では効くので穴は残るが、列挙外。dry-run 側の省略形（`--dry`）を dry-run と読まないのも従来どおりで、こちらは止めすぎる向きにしか起きない
- `--no-force`・`--verify` など、`--no-dry-run` 以外の打ち消し
- `git checkout` の `--` の判定（`rest` を直接見ている箇所）に `--end-of-options` を足すこと

## Decisions

### dry-run は `parse_opts` の中で左から読んだ最後の状態で決める

`parse_opts` が `--no-dry-run`（とその省略形）を読んだら、それまでに集めた `--dry-run` を長いオプションの集合から外し、`push` / `clean`（短い `-n` が `--dry-run` を意味するサブコマンド）では `n` も短いオプションの集合から外す。後ろに `-n` / `--dry-run` が来ればまた集合に入る。`judge_push` と `clean` の分岐の判定式は変えない。

- 採らなかった案: `parse_opts` の戻り値に「dry-run か」を足す、またはオプションの出現順の列を返す。判定としては素直だが、戻り値の形が変わると `judge_git` の呼び出しと #820・#822 の差分にも触れる。集合から外すだけなら差分は `parse_opts` の長いオプションの分岐の数行に収まる
- `commit` の `-n` は `--no-verify` なので、`--no-dry-run` で `n` を外してはならない。外す対象のサブコマンドを `push` / `clean` に限る小さな表を置く

### `--no-dry-run` の省略形は打ち消し側に倒す

`--no-d` 以上の長さで `--no-dry-run` の先頭と一致する長いオプション（`--no-dry`、`--no-dry-r` など）を打ち消しとして扱う。git で `--no-d` が別のオプションとの曖昧さでエラーになる場合も打ち消しとして扱うが、そのとき git は何も実行しないので、止めすぎる向きにしか起きない。手元の git 2.40.1 で `git push -n --no-dry origin main` が実際に push することを確かめた。

- 採らなかった案: 完全一致の `--no-dry-run` だけを打ち消しにする。`--no-dry` で同じ穴が残る

### 値を取る長いオプションは、既存の一覧の中で一意に決まる省略形も同じものとして読む

`ARG_OPTS` の長いオプション（`push` の `--push-option` など、`clean` の `--exclude`、`commit` の一覧）について、`=` を含まない長いオプションが一覧のどれとも完全一致せず、一覧の中のちょうど 1 つの先頭と一致するときは、そのオプションとして次の字句を値として読み飛ばす。一覧の中で複数に一致するときは従来どおり値を取らないものとして読む（git では曖昧さのエラーで何も実行しない）。

- 採らなかった案: サブコマンドごとに全オプションの一覧を持ち、git と同じ曖昧さ判定をする。一覧が長くなり git の版で変わる。一覧の中で一意でも git では値を取らないオプションとも一致して曖昧になる場合はあるが、そのとき git はエラーで何もしないので、読み飛ばしすぎても実害は無い。完全一致は git でも省略形より優先されるので、完全一致を先に見る
- 範囲: `commit` にも同じ規則が効く（`git commit --mess -n` の `-n` はメッセージの値になる）。git の読み方に揃える変更で、止めすぎていたものを止めなくなる向き。サブコマンドで分けると規則が 2 通りになるので分けない

### `--end-of-options` は `--` と同じに扱う

`parse_opts` で `--end-of-options` を読んだら、それより後ろの字句をすべて位置引数にする。`git push --end-of-options -n origin main` は位置引数が `-n origin main` になり、`judge_push` が 2 つ目以降を refspec として見るので `main` が送り先として当たる。git でも `-n` がリモート名、`origin` と `main` が refspec になる（手元で `failed to push some refs to '-n'` を確かめた）。

### `env` の値を取るオプションは wrapper の読み飛ばしの中で値ごと飛ばす

`judge_simple` の wrapper の読み飛ばしで、`env` のときだけ、値を取る短いオプション（`u` `C` `P` `a`）と長いオプション（`--unset` `--chdir` `--argv0`。`=` 付きは 1 字句）の値を次の字句ごと飛ばす。短いオプションは `parse_opts` と同じく、まとめた形（`-iu FOO`）の最後の文字なら次の字句が値、途中なら同じ字句の残り（`-uFOO`）が値。GNU と BSD（macOS）の `env` の和集合を取る。

- `-S` / `--split-string` は値を取るオプションとして扱わない。`-S` は後ろの字句を分割してコマンドとして実行する（macOS と GNU のどちらでも `env -S echo hello world` が `hello world` を出す）。値として読み飛ばすと、現在 ask で止まっている `env -S git reset --hard` が素通りになる
- 採らなかった案: wrapper の後ろの最初の非オプション字句が `git` を含むかで探す（`env -u FOO git` の `FOO` を飛ばして `git` を見つける）。値が `git` という名前の変数（`env -u git ls`）で誤検知し、読み方の規則としても説明しにくい

## Risks / Trade-offs

- [並行作業との衝突] #820・#822 が同じ関数を触る → 戻り値や関数の分け方を変えず、`parse_opts` と `judge_simple` の分岐に数行足す形にする。bats は既存の `@test` を書き換えず、新しい `@test` を足す
- [省略形の展開で読み飛ばしすぎる] 一覧の中で一意でも git では曖昧なとき、値でない字句を値として飛ばす → git がエラーで何も実行しない場合に限られる
