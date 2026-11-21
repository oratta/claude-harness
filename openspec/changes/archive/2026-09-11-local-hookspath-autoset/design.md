# design — local-hookspath-autoset

## Context

git の `core.hooksPath` は設定の優先順位（ローカル > グローバル）で 1 つだけ決まり、git はその 1 か所のフックしか実行しない。push-guard-setup を導入した PC ではグローバルに `~/.githooks` が入るので、ローカル設定の無い clone ではリポジトリが追跡している `.githooks/` のフックは無視される。

ローカル設定は `$GIT_COMMON_DIR/config` に書かれる。`git clone` では入らず、同じ clone のワークツリーとメインチェックアウトは同じファイルを共有する。したがって「clone ごとに 1 回」入れれば、その clone のどの作業ツリーでも効く。

wt-setup.sh は、WorktreeCreate hook（`wt-create-hook.sh`）と SessionStart hook（`wt-setup-guard.sh`、手で作ったワークツリーの初回セッションだけ）の両方から呼ばれる。ワークツリーを作れば必ず 1 回走る。

## Goals / Non-Goals

**Goals:**

- `.githooks/` を追跡しているリポジトリで、ワークツリーを作った時点でローカルの `core.hooksPath` が入っている状態にする
- 他のツールが入れたローカル設定（husky の `.husky/_`、push-guard-setup の副作用回避で入れた `.git/hooks` など）を壊さない
- push-guard-setup の文書から「ローカル設定があればローカル層が使われる」の成立条件が読み取れるようにし、手で有効にする手順と、グローバルのフックを失わないための引き継ぎ方を示す

**Non-Goals:**

- ワークツリーを一度も作らない clone（メインチェックアウトだけで作業する clone）での自動設定。文書の手動手順で補う
- `.githooks/pre-push` がグローバルのフックを呼んでいるかどうかの検査や書き換え。フックの中身はリポジトリの持ち物で、harness が書き換えない
- グローバルのフック本体（`~/.githooks/pre-push` のテンプレート）の変更

## Decisions

### Decision 1: 自動設定は wt-setup.sh に置く（SessionStart hook を新設しない）

wt-setup.sh はワークツリー作成時に確実に 1 回走り、ローカル設定は clone で共有されるので、ワークツリーを 1 つ作ればメインチェックアウトにも効く。既存の呼び出し経路（WorktreeCreate / SessionStart の初回）に乗るだけで、新しい hook も新しい呼び出しコストも増えない。

**代替案**: (a) 各リポジトリに SessionStart hook を置く（kg-recruit#127 の方式）→ リポジトリごとに配らないと効かず、配り忘れが同じ事故になる。(b) worktree プラグインの SessionStart で毎セッション確認する → wt-setup-guard は「メインリポ・git 外・セットアップ済みでは完全に無出力で即終了」を方針にしており、全リポジトリの全セッションに git の呼び出しを足すことになる。(a)(b) ともワークツリーを作らない clone でも効く利点はあるが、この変更ではワークツリー運用で起きた事故を塞ぐことを優先する。

### Decision 2: 実効値のスコープで判定し、ローカル側に値があれば `.githooks` 以外でも上書きしない

kg-recruit#127 の SessionStart hook は `.githooks` 以外の値を上書きする。これはリポジトリ自身が自分の構成を知っているから成り立つ。harness の wt-setup は全リポジトリに効くので、husky の `.husky/_` や、push-guard-setup の副作用回避として利用者が意図して入れた `.git/hooks` を壊しうる。

判定は `git config --show-scope --get core.hooksPath`（git 2.26 以上）で実効値とそのスコープを見る。動くのは未設定（終了コード 1）か、スコープが `global` / `system` のときだけで、`local` / `worktree` / `command` のときは何もせず、何も出力しない。当初は `git config --local --get` で判定していたが、`extensions.worktreeConfig` の `config.worktree` にある値と、`include.path` で読み込まれた値を見落とし、共通設定に `.githooks` を書いたうえで「設定した」と誤って出力していた（PR #298 のコードレビューで git 2.40.1 で再現）。`--show-scope` は include 経由の値を読み込み元のスコープ（`local`）として返すので、どちらも「ローカル側に値がある」と判定できる。

読めない（0 でも 1 でもない終了コードを返す）ときも触らない側に倒す。

### Decision 3: 対象は「`.githooks/` を git で追跡している」リポジトリに限る

ディスク上に未追跡の `.githooks/` があるだけのリポジトリは、個人の試作である可能性がある。リポジトリの規約として共有されているフック（`git ls-files .githooks` が空でない）だけを有効にする。追跡の判定はワークツリー側のインデックスで行う（ワークツリーのチェックアウトに `.githooks/` があることが、`.githooks` という相対パスが解決できる前提になるため）。

### Decision 4: 値は相対パス `.githooks`

相対パスの `core.hooksPath` はフックを実行する作業ツリーのルートから解決される。各ワークツリーは自分のチェックアウトの `.githooks/` を使うので、ブランチごとにフックが違っても食い違わない。kg-recruit#127 と push-guard-setup の手順も同じ値を使う。

### Decision 5: `.git/hooks/` に既存のフックがある clone では自動で切り替えない

`core.hooksPath` を `.githooks` にすると、その clone の `.git/hooks/` 直置きのフック（Git LFS の pre-push など）は走らなくなる。clone の共通フックディレクトリ（`git rev-parse --git-common-dir` の `hooks/`）に `.sample` 以外のファイルが 1 つでもあれば設定せず、「`.githooks` を追跡しているが `.git/hooks/` に既存のフックがあるため自動では有効化しなかった」旨を `=== git フック:` の見出しで 1 行出す。有効にするかは利用者が決める（push-guard-setup の手動手順）。グローバル `core.hooksPath` がある PC では `.git/hooks/` のフックは元々走っていないが、判定を単純に保つため区別しない。

### Decision 6: 注意は「=== git フック:」の見出しで出し、SessionStart 経路では残タスクに載せる

設定したとき・見送ったときの出力は `=== git フック:` で始める。wt-setup-guard.sh（SessionStart 経路）はこの見出しを拾って残タスクとして Claude に渡し、「残タスクなし。報告不要」にしない。注意文はそれまでの実効値（スコープが `global` / `system` ならその値、未設定なら `.git/hooks/`）を示し、`~/.githooks` のような固定の場所を書かない。グローバル側の値だったときだけ、push-guard-setup のグローバルを呼ぶ手順への案内を足す。

### Decision 7: 設定に失敗しても wt-setup.sh を止めない

wt-setup.sh は `set -euo pipefail` で動いており、`git config` の失敗（設定ファイルのロック等）で後続の依存チェックまで止まるのを避ける。失敗したら WARNING 行を 1 行出して続ける。WorktreeCreate hook は wt-setup.sh の失敗でワークツリー作成を巻き添えにしない設計なので、ここでも同じ方向に倒す。

## Risks / Trade-offs

- **これまで `.githooks/` があっても有効化していなかったリポジトリで、ワークツリー作成を境にフックが走り始める** → 設定したときに 1 行出力して知らせる。止めたい場合は、そのリポジトリでローカルに別の値を入れれば wt-setup は上書きしない（例: `git config --local core.hooksPath .git/hooks`）
- **ローカルを有効にした clone では、グローバルのフック（マージ済み PR のブランチへの push 拒否）が走らなくなる** → wt-setup.sh が設定したときの出力に、それまで実行されていたフック（グローバルの値）が以後走らないことと、マージ済みブランチの拒否も要るならローカルの pre-push からグローバルを呼ぶこと（push-guard-setup 参照）を添える。push-guard-setup の手順に「ローカルの pre-push からグローバルのフックを呼ぶか、同じチェックを内包する」を書き、呼ぶ例（kg-recruit#127 の書き方）を示す。フックの中身の検査はしない（Non-Goals）
- **ワークツリーを作らない clone では自動設定されない** → push-guard-setup の手順（clone ごとに 1 回 `git config --local core.hooksPath .githooks`、確認は `git config --local --get core.hooksPath`）で補う
- **`extensions.worktreeConfig` を有効にしてワークツリー単位の設定（`config.worktree`）に `core.hooksPath` を入れている clone** → wt-setup.sh を走らせたワークツリーで実効値のスコープが `worktree` になるので触らない（Decision 2）。ただし判定はそのワークツリーの実効値だけを見るので、別のワークツリーで走ったとき（そこには `config.worktree` の値が無い）は共通設定に `.githooks` を入れ、`config.worktree` を持たない他のワークツリーとメインチェックアウトにも効く
- **`.githooks/` を含まない古いブランチのワークツリー（と、`.githooks/` を初めて足すブランチのワークツリーで設定したあとの、`.githooks/` がまだ無いメインチェックアウト）** → 相対パス `.githooks` が存在しないディレクトリを指すので、グローバルも含めてどのフックも走らない。git はこのとき警告を出さない。そのブランチに `.githooks/` を取り込むまで続く
- **WorktreeCreate 経路では注意が利用者に届かない** → `wt-create-hook.sh` は stdout に worktree のパスだけを出す契約で、wt-setup.sh の出力を全部 stderr に回す。この stderr は Claude の文脈に渡らず、利用者の目にも通常は触れないので、この経路で設定されたときの注意（それまでのフックが走らなくなること）は誰にも見えない。SessionStart 経路（wt-setup-guard.sh）だけが残タスクとして載せる。この変更では WorktreeCreate 経路に通知を届ける仕組みは足さない
- **この PC で影響を受ける clone（PR #298 のコードレビューで実測）** → 次の 3 つは、main への push だけを拒否しグローバルを呼ばない `.githooks/pre-push` を追跡し、ローカルの `core.hooksPath` が無い。マージ後にそれぞれで最初にワークツリーを作った時点で、その clone のマージ済みブランチ拒否（グローバル層）が走らなくなる。WorktreeCreate 経路なら注意も出ない
  - flatmate 本体の clone
  - flatmate の住人 uranai-dev の repo
  - flatmate の住人 shukan-dev の repo
