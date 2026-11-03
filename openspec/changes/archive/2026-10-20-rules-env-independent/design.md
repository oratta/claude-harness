## Context

6 ファイルを検索すると、受け入れ条件 1 の語に当たるのは `rules/communication-style.md:15` の 1 行だけで、`rules/browser-infra-env-capture.md:10` と `rules/destructive-git-guard.md` は語に当たらないがプラグインや `~/.claude/rules-archive/` を前提にしている（受け入れ条件 2）。読み手は 2 種類いる。オーナーの環境（Harness の全プラグインと hook が入っている）と、flatmate が配る客の Mac（規則のファイルだけが入る）。

## Decisions

### D1: 外した参照は「消す」でなく、オーナーの環境でだけ読む場所に移すか、条件つきに直す

- 正本のパス（`communication-style.md:15`）: 規則の本文は「Output Style `readable`（`~/.claude/output-styles/readable.md`）が全文の正本」と書く。`scripts/sync.sh` が Output Style をこのパスに symlink するので、どの cwd からも解決でき、`marketplaces/` を含まない。既存 spec `always-on-injection-scope` の「移設先を任意の cwd から辿れる形にする」は解決できる形を 2 つ（スキル名・marketplace 絶対パス）に限っているので、Output Style 用に 3 つめの形（`~/.claude/output-styles/<name>.md`）を MODIFIED で足す（Output Style 名だけで示す案は、パスが無く辿れないので採らない）。clone の絶対パスは `rules/README.md` の行に既にある（移設先の表が正本）ので、そこへ残す。`rules/README.md` は symlink されず注入もされないので、オーナーの環境でだけ読まれる
- `capability-registry:capability-registry`（`browser-infra-env-capture.md:10`）: スキルを条件つきにして残す（「入っていれば、保管庫への昇格の手順の正本」）。残す理由は、オーナーの環境での効き方を変えないため（受け入れ条件 3）。条件なしで名指しするのをやめるだけで、スキルの参照は消えない。無い環境の手順も本文に 1 文で足す
- 1Password / GitHub Actions secrets: 本文からは製品名を外し「秘密情報の保管庫」と書く。製品名の対応（オーナーの環境ではどれか）は `rules/README.md` の行が持つ
- `rules-archive`（`destructive-git-guard.md:3`）: 経緯を置く場所の話は規則の守らせる原則ではないので、パスを外し「経緯はこの repo に含めない」だけにする。パスは `rules/README.md:5` に既にある
- `dev-workflow` の hook（`destructive-git-guard.md` の「hook との分担」）: 節の冒頭に条件（dev-workflow プラグインの hook が入っていれば）を足し、節の最後に「hook が入っていない環境では、一覧の操作もこのルールだけが止める」を足す

### D2: 「入っていれば」の書き方は、前提を節や文の先頭に 1 回置く

文ごとに「hook があれば」を繰り返すと短い版が長くなる（常時注入のバイト数が増える）。節の冒頭に 1 回条件を置き、節の中の文は事実（hook が何を止めるか）のまま残す。`plugins/dev-workflow/tests/git-destructive-guard.bats` の節を読むテストは、節の中の語（サブエージェント・確認画面を出さず・打ち直さず・親に返る・画面を見ている人のいないセッション・チャンネル・主に承認を求める）を行単位で探すので、それらを同じ行に残す。

### D3: 選ばなかった案

- 規則の本文から hook の分担の節を全部外して `rules/README.md` に移す: 節の内容（hook で止まらないもの）は hook が無い環境にも意味があり（このルールだけが止める）、`openspec/specs/destructive-git-hook/spec.md` と `always-on-injection-scope` が本文に残すことを求めているので採らない
- 6 ファイルを flatmate 用に書き写して別ファイルにする（版を分ける）: 配るたびの手作業をなくす目的（原本のまま配る）に反するので採らない
- `rules/README.md` の他の固有記述（flatmate の boot.sh など）も直す: 固有記述の一覧で「担い手なし」の行で、この issue の受け入れ条件の対象（6 ファイル）の外。親エピックの注意書きで範囲外

### D4: 受け入れ条件 4（symlink）の確かめ方

`scripts/sync.sh` は `rules/*.md` と `output-styles/*.md` のファイル名で symlink を張る。この変更はファイルの改名・新規・削除をしない（`git diff --name-status` に `R`/`A`/`D` が無い）ので、張り方は変わらない。開発用 worktree の `sync.sh` は実行せず、`tests/rules-sync.bats`（偽の `CLAUDE_DIR` に対して張る既存の検査）と `git diff --name-status` で確かめる。

## Risks

- 条件つきに直した文の読み違い: 規則の守らせる内容は変えないので、オーナーの環境の挙動は変わらない。テストの語が行単位で残ることは `git-destructive-guard.bats` と `always-on-injection-scope.bats` が見る
