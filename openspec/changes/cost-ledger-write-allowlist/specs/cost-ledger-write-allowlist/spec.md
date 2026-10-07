## ADDED Requirements

### Requirement: GitHub に書き込むのは許可の一覧に載っているリポジトリだけ
システムは、GitHub へのコストの書き込み（コメントの作成と書き換え）を、許可の一覧に載っているリポジトリ（github.com の `owner/repo`）に対してだけ行 MUST う。一覧が空のとき（既定）、システムはどのリポジトリにも書き込んではなら MUST NOT ない。対象は GitHub への書き込みのすべてで、ゲート通過の行、節目ごとの行、issue を閉じたときの合計の行、後から足される書き込み経路（auto-merge と自動クローズの後追いなど）を含む。`/cost` の表示と台帳への追記は GitHub に何も書かないので、この要件の対象外である。

`cost-ledger-gate-report` と `cost-ledger-timeline` のシナリオで「積む」「投稿の対象になる」「コメントが作成される」とあるものは、対象のリポジトリと hook の `cwd` の origin のリポジトリが一覧に載っていることを前提とする。この要件は行の書式を変えない。

#### Scenario: 一覧に載っているリポジトリ
- **WHEN** 一覧に `oratta/claude-harness` があり、origin が `https://github.com/oratta/claude-harness.git` の `cwd` で `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** oratta/claude-harness の #300 に行が積まれる

#### Scenario: 一覧に載っていないリポジトリ
- **WHEN** 一覧に `oratta/claude-harness` だけがあり、origin が `https://github.com/example-org/other-repo.git` の `cwd` で `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われず、`gh` は一度も呼ばれない

#### Scenario: 一覧が無い
- **WHEN** 一覧のファイルが無い状態で、きっかけの表のコマンド（`gh pr comment`・`gh pr ready`・`gh pr close`・`gh pr merge`・`gh issue comment`・`gh issue close`・`gh issue reopen`・合格ラベルの付与）の hook JSON をそれぞれ流す
- **THEN** どのコマンドでもコメントの作成も書き換えも行われず、`gh` は一度も呼ばれない

### Requirement: 一覧はリポジトリの外のテキストファイルから読む
システムは許可の一覧を、環境変数 `COST_LEDGER_WRITE_REPOS_FILE` が空でなければその値のパス、空か未設定なら `$HOME/.config/cost-ledger/write-repos` のテキストファイルから読 MUST む。環境変数の値そのもの（プラグインの userConfig が渡す `CLAUDE_PLUGIN_OPTION_*` を含む）をリポジトリの一覧として読んではなら MUST NOT ない。作業中のリポジトリの設定ファイルの `env` から設定できるため。

ファイルは 1 行に `owner/repo` を 1 つ書く。システムは各行の前後の空白を除き、空行と `#` で始まる行を読み飛ば SHALL す。`[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+` に全体が一致しない行（`github.com/owner/repo` のようなホスト付き、`owner/*` のようなワイルドカード、URL）は、その行だけを無視 MUST する。照合は大文字と小文字を区別せずに SHALL 行う。

ファイルが無い・空・読めない・通常のファイルでない・持ち主が実行ユーザーでない・実行ユーザー以外が書ける、のどれかに当たるとき、システムは一覧を空として扱 MUST う。

#### Scenario: コメントと空行
- **WHEN** 一覧のファイルが `# 自分のリポジトリ`・空行・`oratta/claude-harness` の 3 行で、`oratta/claude-harness` に書いてよいかを判定する
- **THEN** 書いてよいと判定される

#### Scenario: 大文字と小文字
- **WHEN** 一覧に `Oratta/Claude-Harness` があり、`oratta/claude-harness` に書いてよいかを判定する
- **THEN** 書いてよいと判定される

#### Scenario: 書式に合わない行
- **WHEN** 一覧のファイルが `github.com/oratta/claude-harness`・`example-org/*`・`example-org/sample` の 3 行である
- **THEN** `example-org/sample` だけが書いてよいと判定され、`oratta/claude-harness` と `example-org/other-repo` は書いてはいけないと判定される

#### Scenario: 環境変数に一覧を書いても効かない
- **WHEN** 一覧のファイルが無く、環境変数 `COST_LEDGER_WRITE_REPOS=oratta/claude-harness` と `CLAUDE_PLUGIN_OPTION_WRITE_REPOS=oratta/claude-harness` を付けて、origin が oratta/claude-harness の `cwd` で `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われず、`gh` は一度も呼ばれない

#### Scenario: 自分以外が書けるファイル
- **WHEN** 一覧のファイルの権限が 666 で、中に `oratta/claude-harness` がある
- **THEN** `oratta/claude-harness` は書いてはいけないと判定される

### Requirement: 作業中のリポジトリの中のファイルだけでは有効にならない
システムは、一覧のファイルの実体（シンボリックリンクを解決したパス）が次のどちらかの配下にあるとき、一覧を空として扱 MUST う: hook の `cwd` から親へたどって最初に `.git`（ディレクトリでもファイルでも）を持つディレクトリ（見つからなければ `cwd` そのもの）／環境変数 `CLAUDE_PROJECT_DIR` が設定されていれば、そこから同じようにたどったディレクトリ。clone しただけのリポジトリが、自分の中の設定ファイルで一覧の場所を自分の中へ向けて、自分を許可することを防ぐため。この検査のために `git` や `gh` を起動してはなら MUST NOT ない。

守備範囲: 防ぐのは、作業中のリポジトリの中にあるファイル（`.claude/settings.json` の `env` を含む）だけを使って書き込みを有効にすること。次は防がない: 作業中のリポジトリの設定が、リポジトリの外に既にあるファイルを一覧として指すこと／リポジトリの hook やスクリプトが実行されてリポジトリの外にファイルを作ること。これらを塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 一覧の場所をリポジトリの中へ向ける
- **WHEN** origin が example-org/other-repo の `cwd` の中に `example-org/other-repo` と書いたファイルを置き、`COST_LEDGER_WRITE_REPOS_FILE` をそのファイルに向けて `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われず、`gh` は一度も呼ばれない

#### Scenario: HOME をリポジトリの中へ向ける
- **WHEN** `cwd` のリポジトリの中に `.config/cost-ledger/write-repos` を置いて `cwd` の origin のリポジトリを書き、`HOME` をそのリポジトリの最上位に向け、`COST_LEDGER_WRITE_REPOS_FILE` を付けずにきっかけの hook JSON を流す
- **THEN** コメントの作成も書き換えも行われず、`gh` は一度も呼ばれない

#### Scenario: リポジトリの中のファイルへのシンボリックリンク
- **WHEN** リポジトリの外に置いた一覧のファイルが、`cwd` のリポジトリの中のファイルへのシンボリックリンクである
- **THEN** 一覧は空として扱われ、コメントの作成も書き換えも行われない

#### Scenario: リポジトリの設定ファイルだけがある
- **WHEN** 一覧のファイルが無く、`cwd` のリポジトリに `.claude/settings.json` があって `env` に `COST_LEDGER_WRITE_REPOS_FILE`（リポジトリの中のファイルを指す）が書かれており、その `env` の値を環境変数として付けてきっかけの hook JSON を流す
- **THEN** コメントの作成も書き換えも行われず、`gh` は一度も呼ばれない

### Requirement: 判定は 1 つの関数が行い、書き込む経路はすべてそれを通す
システムは「このリポジトリに書いてよいか」の判定（一覧の読み込み、ファイルの検査、照合）を `plugins/cost-ledger/scripts/write_allow.py` の 1 つの関数にまとめ MUST る。GitHub に書き込む経路は、書き込みの前にこの関数を通 MUST す。一覧の読み方や照合を別の場所に書き写してはなら MUST NOT ない。`plugins/cost-ledger/scripts/` の Python のスクリプトで `gh` を起動するものは、`write_allow` を読み込んでいなければなら MUST ない（後から足される後追いのスクリプトにも適用する）。例外は、GitHub から読むだけで書き込まないスクリプトで、テストの中に名前と理由を並べた一覧に載っているものに限る（この change の時点では、番号が PR か issue かを判別するだけの `cost_ledger.py` の 1 つ）。

`gate-report.sh` が一覧のファイルの有無と大きさだけを見て抜ける近道は、この要件の対象外とする（中身を読まず、判定の代わりにならないため）。

#### Scenario: gh を起動するスクリプトは判定を読み込んでいる
- **WHEN** `plugins/cost-ledger/scripts/*.py` のうち `gh` を起動するものを調べる（`write_allow.py` 自身と、読むだけの例外の一覧に載っている `cost_ledger.py` を除く）
- **THEN** そのすべてが `write_allow` を読み込んでいる

#### Scenario: 例外の一覧に無いスクリプトが gh を起動する
- **WHEN** `gh` を起動し、`write_allow` を読み込まず、例外の一覧にも無いスクリプトを `plugins/cost-ledger/scripts/` に置いた状態で同じ検査を行う
- **THEN** 検査は失敗し、そのスクリプトの名前を示す

#### Scenario: origin の読み方が集計と一致する
- **WHEN** origin の URL が `https://github.com/o/r.git`・`git@github.com:o/r.git`・`ssh://git@github.com/o/r.git` のリポジトリと、ホストが github.com でないリポジトリについて、`write_allow.py` と `cost_ledger.py` の両方で origin のリポジトリを求める
- **THEN** どの URL でも両者の答えが一致し、github.com でないホストではどちらも github.com のリポジトリとして扱わない

### Requirement: 一覧に無いリポジトリでは `gh` を呼ばない
システムは、一覧が空のとき、hook の標準入力を読まず、`python3` も `gh` も起動せずに終了コード 0 で終わ MUST る。

一覧が空でないとき、システムは最初の `gh` を呼ぶ前に次の 2 つを確かめ MUST る。どちらかを満たさない対象については `gh` を 1 回も呼んではなら MUST NOT ない。

- hook の `cwd` の origin のリポジトリ（ホストが github.com のもの）が一覧にある。無い・読めないときは、そのコマンドのすべての対象を捨てる
- コマンドがリポジトリを名指ししている（`-R` / `--repo`、前置きの `GH_REPO=値`、PR / issue の URL、`gh api` のパス）ときは、そのリポジトリが一覧にある

さらに、対象の確認で GitHub が返したリポジトリ名が一覧に無いとき、システムはその対象について、それ以降の `gh`（既存コメントの取得、閉じた PR の問い合わせ、書き込み）を呼んではなら MUST NOT ない。改名や移管で、一覧にある名前への問い合わせが別の名前のリポジトリへ転送されることがあるため。

どの経路でも、stdout と stderr には何も出さず、終了コードは 0 で MUST ある（LLM のトークンを使わず、会話の文脈に何も入れない）。

守備範囲: 拾いたい誤りは、一覧に無いリポジトリへコストを書き込むことと、一覧に無いリポジトリへ `gh` の問い合わせを送ること。次の入力は誤ったまま通ることを許す: `cwd` の origin が一覧にあり、`gh repo set-default` や hook が引き継いだ環境変数 `GH_REPO` によって `gh` の既定のリポジトリが origin 以外を指しているとき、対象の確認の読み取りが 1 回、一覧に無いリポジトリへ送られることがある（書き込みは行われない）。これを塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 一覧が空なら python3 も起動しない
- **WHEN** 一覧のファイルが無い状態で `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** `gh` と `python3` は一度も呼ばれず、stdout と stderr は空で、終了コードは 0

#### Scenario: 名指ししたリポジトリが一覧に無い
- **WHEN** 一覧に `oratta/claude-harness` だけがあり、origin が oratta/claude-harness の `cwd` で `gh pr comment 300 -R example-org/other-repo --body x` の hook JSON を流す
- **THEN** `gh` は一度も呼ばれない

#### Scenario: 対象のうち一覧にあるものだけを進める
- **WHEN** 一覧に `oratta/claude-harness` だけがあり、origin が oratta/claude-harness の `cwd` で `gh pr comment 300 --body x; gh issue comment 12 -R example-org/other-repo --body y` の hook JSON を流す
- **THEN** oratta/claude-harness の #300 にだけ行が積まれ、`gh` の引数に `example-org/other-repo` は一度も現れない

#### Scenario: GitHub が返した名前が一覧に無い
- **WHEN** 一覧に `oratta/claude-harness` だけがあり、対象の確認の応答のリポジトリ名が `example-org/other-repo` である
- **THEN** `gh` が呼ばれた回数は対象の確認の 1 回だけで、コメントの作成も書き換えも行われない

#### Scenario: origin が無い
- **WHEN** 一覧に `oratta/claude-harness` があり、git リポジトリでない `cwd` で `gh api -X POST repos/oratta/claude-harness/issues/300/labels -f 'labels[]=agent-review:passed'` の hook JSON を流す
- **THEN** `gh` は一度も呼ばれない

### Requirement: 全体停止は一覧より先に効く
システムは、環境変数 `COST_LEDGER_GATE_REPORT=off` のとき、一覧の内容にかかわらず何も書き込んではなら MUST NOT ない。このとき一覧のファイルを読んではなら MUST NOT ない。評価の順は、全体停止、一覧のファイルが空かどうか、きっかけの文字列の有無、の順と SHALL する。

#### Scenario: 一覧に載っていても off なら書かない
- **WHEN** 一覧に `oratta/claude-harness` があり、`COST_LEDGER_GATE_REPORT=off` を付けて、origin が oratta/claude-harness の `cwd` で `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** `gh` と `python3` は一度も呼ばれず、stdout は空で、終了コードは 0

### Requirement: 一覧の作り方と、既に付いた行の消し方を README に書く
システムは `plugins/cost-ledger/README.md` に次を書 MUST く: 既定では GitHub に何も書き込まないこと／一覧のファイルの場所と書式、作り方／全体停止 `COST_LEDGER_GATE_REPORT=off` が一覧より先に効くこと／行が付かないときに確かめること（ファイルの場所・書式・権限、`cwd` の origin、全体停止）／既に付いた行を一覧して消す手順。

消す手順は、対象のリポジトリで、目印 `<!-- cost-ledger:timeline`（と、以前の目印 `<!-- cost-ledger:gate-report -->`）を持つ自分のコメントを一覧するコマンドと、id を指定して消すコマンドの 2 段で SHALL 書く。一覧を見てから消すこと、削除は取り消せないこと、通知メールで届いた分は消えないこと、リポジトリを公開する前に使うことを添える。README の例に書くリポジトリ名は、このリポジトリ自身か架空の名前（`example-org/other-repo` など）に限 MUST る。

#### Scenario: README に手順がある
- **WHEN** `plugins/cost-ledger/README.md` を読む
- **THEN** `write-repos`、`COST_LEDGER_WRITE_REPOS_FILE`、目印 `<!-- cost-ledger:timeline` を持つコメントを一覧するコマンド、`-X DELETE` で消すコマンドの記述がある
