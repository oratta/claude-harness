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

### Decision 2: ローカルに既に値があれば、`.githooks` 以外でも上書きしない

kg-recruit#127 の SessionStart hook は `.githooks` 以外の値を上書きする。これはリポジトリ自身が自分の構成を知っているから成り立つ。harness の wt-setup は全リポジトリに効くので、husky の `.husky/_` や、push-guard-setup の副作用回避として利用者が意図して入れた `.git/hooks` を壊しうる。値があるときは何もせず、何も出力しない。

読めない（`git config` が 0 でも 1 でもない終了コードを返す）ときも触らない側に倒す。

### Decision 3: 対象は「`.githooks/` を git で追跡している」リポジトリに限る

ディスク上に未追跡の `.githooks/` があるだけのリポジトリは、個人の試作である可能性がある。リポジトリの規約として共有されているフック（`git ls-files .githooks` が空でない）だけを有効にする。追跡の判定はワークツリー側のインデックスで行う（ワークツリーのチェックアウトに `.githooks/` があることが、`.githooks` という相対パスが解決できる前提になるため）。

### Decision 4: 値は相対パス `.githooks`

相対パスの `core.hooksPath` はフックを実行する作業ツリーのルートから解決される。各ワークツリーは自分のチェックアウトの `.githooks/` を使うので、ブランチごとにフックが違っても食い違わない。kg-recruit#127 と push-guard-setup の手順も同じ値を使う。

### Decision 5: 設定に失敗しても wt-setup.sh を止めない

wt-setup.sh は `set -euo pipefail` で動いており、`git config` の失敗（設定ファイルのロック等）で後続の依存チェックまで止まるのを避ける。失敗したら WARNING 行を 1 行出して続ける。WorktreeCreate hook は wt-setup.sh の失敗でワークツリー作成を巻き添えにしない設計なので、ここでも同じ方向に倒す。

## Risks / Trade-offs

- **これまで `.githooks/` があっても有効化していなかったリポジトリで、ワークツリー作成を境にフックが走り始める** → 設定したときに 1 行出力して知らせる。止めたい場合は、そのリポジトリでローカルに別の値を入れれば wt-setup は上書きしない（例: `git config --local core.hooksPath .git/hooks`）
- **ローカルを有効にした clone では、グローバルのフック（マージ済み PR のブランチへの push 拒否）が走らなくなる** → wt-setup.sh が設定したときの出力に、以後グローバルのフックが走らないことと、マージ済みブランチの拒否も要るならローカルの pre-push からグローバルを呼ぶこと（push-guard-setup 参照）を 1 行添える。push-guard-setup の手順に「ローカルの pre-push からグローバルのフックを呼ぶか、同じチェックを内包する」を書き、呼ぶ例（kg-recruit#127 の書き方）を示す。フックの中身の検査はしない（Non-Goals）
- **ワークツリーを作らない clone では自動設定されない** → push-guard-setup の手順（clone ごとに 1 回 `git config --local core.hooksPath .githooks`、確認は `git config --local --get core.hooksPath`）で補う
- **`extensions.worktreeConfig` を有効にしてワークツリー単位の設定（`config.worktree`）に `core.hooksPath` を入れている clone** → `--local` の読み取りでは見えないため、`$GIT_COMMON_DIR/config` にも値を入れる。ワークツリー単位の設定の方が優先されるので実際の挙動は変わらない
