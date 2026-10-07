## ADDED Requirements

### Requirement: GitHub に書き込むのは許可の一覧に載っているリポジトリだけ
システムは、GitHub へのコストの書き込み（コメントの作成と書き換え）を、許可の一覧に載っているリポジトリ（github.com の `owner/repo`）に対してだけ行 MUST う。一覧が空のとき（既定）、システムはどのリポジトリにも書き込んではなら MUST NOT ない。対象は GitHub への書き込みのすべてで、ゲート通過の行、節目ごとの行、issue を閉じたときの合計の行、後から足される書き込み経路（auto-merge と自動クローズの後追いなど）を含む。`/cost` の表示と台帳への追記は GitHub に何も書かないので、この要件の対象外である。

`cost-ledger-gate-report` と `cost-ledger-timeline` のシナリオと本文で「積む」「投稿の対象になる」「コメントが作成される」とあるもの、および「対象の確認までは行う」「対象として確かめる」「問い合わせる」とあるものは、対象のリポジトリ（コマンドが名指ししたリポジトリを含む）と hook の `cwd` の origin のリポジトリが一覧に載っていることを前提とする。どちらかが一覧に無いときは、対象の確認も行わない（`cost-ledger-timeline`「対象の解決」の「対象のリポジトリが作業中のリポジトリと違うときは、対象の確認までは行い、書き込まない」は、両方が一覧に載っているときの動きである）。この要件は行の書式を変えない。

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

ファイルが無い・空・読めない・通常のファイルでない・持ち主が実行ユーザーでない・実行ユーザー以外が書ける、のどれかに当たるとき、システムは一覧を空として扱 MUST う。通常のファイルか・持ち主・権限は、シンボリックリンクを解決した実体について SHALL 見る（リンクそのものの持ち主や権限は見ない。一覧のファイルを別の場所の実体へのリンクにして管理する使い方を妨げないため）。

守備範囲: この読み込みが受け取る入力は、利用者が手で書く `write-repos`（と、`COST_LEDGER_WRITE_REPOS_FILE` が指す同じ書式のファイル）に限る。拾いたい誤りは、ホスト付きの行・ワイルドカードの行・URL の行を `owner/repo` と誤って読み、利用者が意図していないリポジトリを許可すること。次の入力は誤ったまま通ることを許す: 存在しないリポジトリ名や綴り違いの行（どのリポジトリにも一致せず、書かれないだけ）／`owner/repo.git` のように書式には合うが GitHub の名前と一致しない行（一致せず、書かれない）／`owner/repo # メモ` のように末尾にコメントを付けた行（行ごと無視される）／1 行に複数の名前を空白で区切って書いた行（行ごと無視される）。これらを塞ぎ切ることはこの要件の完了条件にしない。

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

#### Scenario: リポジトリの外の実体へのシンボリックリンク
- **WHEN** 一覧のファイルが、`cwd` のリポジトリの外にある通常のファイル（持ち主は実行ユーザー、権限 600、中に `oratta/claude-harness`）へのシンボリックリンクである
- **THEN** `oratta/claude-harness` は書いてよいと判定される

#### Scenario: 実体を自分以外が書ける
- **WHEN** 一覧のファイルが、権限 666 の通常のファイル（中に `oratta/claude-harness`）へのシンボリックリンクである
- **THEN** `oratta/claude-harness` は書いてはいけないと判定される

#### Scenario: 末尾にコメントを付けた行
- **WHEN** 一覧のファイルが `oratta/claude-harness # 自分の` の 1 行である
- **THEN** `oratta/claude-harness` は書いてはいけないと判定される

### Requirement: 作業中のリポジトリの中のファイルだけでは有効にならない
システムは、一覧のファイルの実体（シンボリックリンクを解決したパス）が次のどちらかの配下にあるとき、一覧を空として扱 MUST う: hook の `cwd` から親へたどって最初に `.git`（ディレクトリでもファイルでも）を持つディレクトリ（見つからなければ `cwd` そのもの）／環境変数 `CLAUDE_PROJECT_DIR` が設定されていれば、そこから同じようにたどったディレクトリ。clone しただけのリポジトリが、自分の中の設定ファイルで一覧の場所を自分の中へ向けて、自分を許可することを防ぐため。この検査のために `git` や `gh` を起動してはなら MUST NOT ない。

守備範囲: 防ぐのは、作業中のリポジトリの中にあるファイル（`.claude/settings.json` の `env` を含む）だけを使って書き込みを有効にすること。ここでの「リポジトリの中」は上のディレクトリだけでなく、起点（`cwd` と `CLAUDE_PROJECT_DIR`）から根までの親のうち `.git` を持つディレクトリのすべて（入れ子のリポジトリの中にいるときの外側のリポジトリ）と、`.git` がファイル（worktree・submodule）のときにその `gitdir:` と `commondir` が指すリポジトリ本体（とその作業ツリー）を含み、そのどれかの配下にあれば一覧を空として扱う。`.git` のファイルをたどれない・解釈できないときも空として扱う。次は防がない: 作業中のリポジトリの設定が、リポジトリの外に既にあるファイルを一覧として指すこと／リポジトリの hook やスクリプトが実行されてリポジトリの外にファイルを作ること／同じリポジトリ本体から切った兄弟の worktree の中のファイルを指すこと（ファイルを読むだけでは兄弟の worktree の場所を辿らない）。これらを塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 一覧の場所をリポジトリの中へ向ける
- **WHEN** origin が example-org/other-repo の `cwd` の中に `example-org/other-repo` と書いたファイルを置き、`COST_LEDGER_WRITE_REPOS_FILE` をそのファイルに向けて `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われず、`gh` は一度も呼ばれない

#### Scenario: HOME をリポジトリの中へ向ける
- **WHEN** `cwd` のリポジトリの中に `.config/cost-ledger/write-repos` を置いて `cwd` の origin のリポジトリを書き、`HOME` をそのリポジトリの最上位に向け、`COST_LEDGER_WRITE_REPOS_FILE` を付けずにきっかけの hook JSON を流す
- **THEN** コメントの作成も書き換えも行われず、`gh` は一度も呼ばれない

#### Scenario: リポジトリの中のファイルへのシンボリックリンク
- **WHEN** リポジトリの外に置いた一覧のファイルが、`cwd` のリポジトリの中のファイルへのシンボリックリンクである
- **THEN** 一覧は空として扱われ、コメントの作成も書き換えも行われない

#### Scenario: worktree の中から親のリポジトリ本体の中のファイルを指す
- **WHEN** `cwd` が git の worktree で、一覧のファイルがその worktree を切った元のリポジトリ本体の中にある
- **THEN** 一覧は空として扱われ、`gh` は一度も呼ばれない

#### Scenario: 入れ子のリポジトリの中から外側のリポジトリの中のファイルを指す
- **WHEN** `cwd` がリポジトリの中に置いた別の clone（または submodule）で、一覧のファイルが外側のリポジトリの中にある
- **THEN** 一覧は空として扱われ、`gh` は一度も呼ばれない

#### Scenario: リポジトリの設定ファイルだけがある
- **WHEN** 一覧のファイルが無く、`cwd` のリポジトリに `.claude/settings.json` があって `env` に `COST_LEDGER_WRITE_REPOS_FILE`（リポジトリの中のファイルを指す）が書かれており、その `env` の値を環境変数として付けてきっかけの hook JSON を流す
- **THEN** コメントの作成も書き換えも行われず、`gh` は一度も呼ばれない

### Requirement: 判定は 1 つの関数が行い、書き込む経路はすべてそれを通す
システムは「このリポジトリに書いてよいか」の判定（一覧の読み込み、ファイルの検査、照合）を `plugins/cost-ledger/scripts/write_allow.py` の 1 つの関数にまとめ MUST る。GitHub に書き込む経路は、書き込みの前にこの関数を通 MUST す。一覧の読み方や照合を別の場所に書き写してはなら MUST NOT ない。`plugins/cost-ledger/scripts/` の Python のスクリプトで `gh` を起動するものは、`write_allow` を読み込んでいなければなら MUST ない（後から足される後追いのスクリプトにも適用する）。例外は、GitHub から読むだけで書き込まないスクリプトで、テストの中に名前と理由を並べた一覧に載っているものに限る（この change の時点では、番号が PR か issue かを判別するだけの `cost_ledger.py` の 1 つ）。

`gate-report.sh` が一覧のファイルの有無と大きさだけを見て抜ける近道は、この要件の対象外とする（中身を読まず、判定の代わりにならないため）。

この検査は、調べるディレクトリを引数に取る 1 つの手続きとして SHALL 書く。本物の `plugins/cost-ledger/scripts/` に対する検査と、検査が落ちることを確かめる否定のテストが同じ手続きを使い、否定のテストは一時ディレクトリに作った複製に対して行う（本物のディレクトリにファイルを置かない）。

守備範囲: この検査が受け取る入力は、`plugins/cost-ledger/scripts/` の `*.py` のソースの文字列に限る。拾いたい誤りは、GitHub へ書き込むスクリプトが `write_allow` を通さないまま main に入ること。次の入力は誤ったまま通ることを許す: `write_allow` を読み込んでいるが、書き込みの前で `allowed()` を呼んでいないスクリプト／`gh` を変数や `shutil.which` の結果を通して起動していて、ソースの文字列の検索に掛からないスクリプト／シェルスクリプトなど `*.py` 以外のもの。これらを塞ぎ切ることはこの要件の完了条件にしない（レビューで見る）。

#### Scenario: gh を起動するスクリプトは判定を読み込んでいる
- **WHEN** `plugins/cost-ledger/scripts/` を引数にして検査を行う（`write_allow.py` 自身と、読むだけの例外の一覧に載っている `cost_ledger.py` を除く）
- **THEN** `gh` を起動する `*.py` のすべてが `write_allow` を読み込んでおり、検査は通る

#### Scenario: 例外の一覧に無いスクリプトが gh を起動する
- **WHEN** 一時ディレクトリに `plugins/cost-ledger/scripts/` を複製し、`gh` を起動し、`write_allow` を読み込まず、例外の一覧にも無いスクリプトをその複製に足して、複製を引数にして同じ検査を行う
- **THEN** 検査は失敗し、そのスクリプトの名前を示す。本物の `plugins/cost-ledger/scripts/` にはファイルが増えていない

#### Scenario: origin の読み方が集計と一致する
- **WHEN** origin の URL が `https://github.com/o/r.git`・`git@github.com:o/r.git`・`ssh://git@github.com/o/r.git` のリポジトリと、ホストが github.com でないリポジトリについて、`write_allow.py` と `cost_ledger.py` の両方で origin のリポジトリを求める
- **THEN** どの URL でも両者の答えが一致し、github.com でないホストではどちらも github.com のリポジトリとして扱わない

### Requirement: 一覧に無いリポジトリでは `gh` を呼ばない
システムは、一覧のファイルが無いか、大きさが 0 のとき、hook の標準入力を読まず、`python3` も `gh` も起動せずに終了コード 0 で終わ MUST る。それ以外の理由で一覧を空として扱うとき（コメントと空行だけ、書式に合う行が無い、読めない、通常のファイルでない、持ち主や権限が合わない、作業中のリポジトリの中にある）は、`python3` は起動してよいが、`gh` を 1 回も呼んではなら MUST NOT ない。

一覧に 1 つ以上のリポジトリがあるとき、システムは最初の `gh` を呼ぶ前に次の 2 つを確かめ MUST る。どちらかを満たさない対象については `gh` を 1 回も呼んではなら MUST NOT ない。

- hook の `cwd` の origin のリポジトリ（ホストが github.com のもの）が一覧にある。無い・読めないときは、そのコマンドのすべての対象を捨てる
- コマンドがリポジトリを名指ししている（`-R` / `--repo`、前置きの `GH_REPO=値`、PR / issue の URL、`gh api` のパス）ときは、そのリポジトリが一覧にある

さらに、対象の確認で GitHub が返したリポジトリ名が一覧に無いとき、システムはその対象について、それ以降の `gh`（既存コメントの取得、閉じた PR の問い合わせ、書き込み）を呼んではなら MUST NOT ない。改名や移管で、一覧にある名前への問い合わせが別の名前のリポジトリへ転送されることがあるため。

どの経路でも、stdout と stderr には何も出さず、終了コードは 0 で MUST ある（LLM のトークンを使わず、会話の文脈に何も入れない）。

守備範囲: 拾いたい誤りは、一覧に無いリポジトリへコストを書き込むことと、一覧に無いリポジトリへ `gh` の問い合わせを送ること。次の入力は誤ったまま通ることを許す: `cwd` の origin が一覧にあり、`gh repo set-default` や hook が引き継いだ環境変数 `GH_REPO` によって `gh` の既定のリポジトリが origin 以外を指しているとき、対象の確認の読み取りが 1 回、一覧に無いリポジトリへ送られることがある（書き込みは行われない）／そのうえで、issue 向けのコマンドに渡された番号が PR だったときは、対象の確認が issue と PR の 2 回になるので、読み取りは 2 回になる（GitHub が返した名前での判定は、対象の確認が全部終わったあとに行う）。これらを塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 一覧のファイルが無ければ python3 も起動しない
- **WHEN** 一覧のファイルが無い状態で `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** `gh` と `python3` は一度も呼ばれず、stdout と stderr は空で、終了コードは 0

#### Scenario: 一覧のファイルの大きさが 0
- **WHEN** 一覧のファイルが大きさ 0 で、`gh pr comment 300 --body x` の hook JSON を流す
- **THEN** `gh` と `python3` は一度も呼ばれず、終了コードは 0

#### Scenario: コメントだけの一覧
- **WHEN** 一覧のファイルが `# まだ何も許可していない` の 1 行だけで、origin が oratta/claude-harness の `cwd` で `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** `gh` は一度も呼ばれず、stdout と stderr は空で、終了コードは 0

#### Scenario: 名指ししたリポジトリが一覧に無い
- **WHEN** 一覧に `oratta/claude-harness` だけがあり、origin が oratta/claude-harness の `cwd` で `gh pr comment 300 -R example-org/other-repo --body x` の hook JSON を流す
- **THEN** `gh` は一度も呼ばれない

#### Scenario: 対象のうち一覧にあるものだけを進める
- **WHEN** 一覧に `oratta/claude-harness` だけがあり、origin が oratta/claude-harness の `cwd` で `gh pr comment 300 --body x; gh issue comment 12 -R example-org/other-repo --body y` の hook JSON を流す
- **THEN** oratta/claude-harness の #300 にだけ行が積まれ、`gh` の引数に `example-org/other-repo` は一度も現れない

#### Scenario: GitHub が返した名前が一覧に無い
- **WHEN** 一覧に `oratta/claude-harness` だけがあり、origin が oratta/claude-harness の `cwd` で `gh pr comment 300 --body x` の hook JSON を流し、対象の確認（`pulls/300`）の応答のリポジトリ名が `example-org/other-repo` である
- **THEN** `gh` が呼ばれた回数は対象の確認の 1 回だけで、コメントの作成も書き換えも行われない

#### Scenario: origin が無い
- **WHEN** 一覧に `oratta/claude-harness` があり、git リポジトリでない `cwd` で `gh api -X POST repos/oratta/claude-harness/issues/300/labels -f 'labels[]=agent-review:passed'` の hook JSON を流す
- **THEN** `gh` は一度も呼ばれない

### Requirement: 全体停止は一覧より先に効く
システムは、環境変数 `COST_LEDGER_GATE_REPORT=off` のとき、一覧の内容にかかわらず何も書き込んではなら MUST NOT ない。このとき一覧のファイルを読んではなら MUST NOT ない。評価の順は、全体停止、一覧のファイルが無いか大きさ 0 か、きっかけの文字列の有無、の順と SHALL する。「一覧のファイルを読まない」ことは、一覧の中身を読むのが `python3` の中だけであることから、「`python3` が起動しない」ことで確かめる。

#### Scenario: 一覧に載っていても off なら書かない
- **WHEN** 一覧に `oratta/claude-harness` があり、`COST_LEDGER_GATE_REPORT=off` を付けて、origin が oratta/claude-harness の `cwd` で `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** `python3` は一度も起動されず（一覧の中身は読まれない）、`gh` も呼ばれず、stdout は空で、終了コードは 0

### Requirement: 一覧の作り方と、既に付いた行の消し方を README に書く
システムは `plugins/cost-ledger/README.md` に次を書 MUST く: 既定では GitHub に何も書き込まないこと／一覧のファイルの場所と書式、作り方／全体停止 `COST_LEDGER_GATE_REPORT=off` が一覧より先に効くこと／行が付かないときに確かめること（ファイルの場所・書式・権限、`cwd` の origin、全体停止）／既に付いた行を一覧して消す手順。

消す手順は、対象のリポジトリで、目印 `<!-- cost-ledger:timeline`（と、以前の目印 `<!-- cost-ledger:gate-report -->`）を持つ自分のコメントを一覧するコマンドと、id を指定して消すコマンドの 2 段で SHALL 書く。一覧を見てから消すこと、削除は取り消せないこと、通知メールで届いた分は消えないこと、リポジトリを公開する前に使うことを添える。README の例に書くリポジトリ名は、このリポジトリ自身か架空の名前（`example-org/other-repo` など）に限 MUST る。

#### Scenario: README に手順がある
- **WHEN** `plugins/cost-ledger/README.md` を読む
- **THEN** `write-repos`、`COST_LEDGER_WRITE_REPOS_FILE`、目印 `<!-- cost-ledger:timeline` を持つコメントを一覧するコマンド、`-X DELETE` で消すコマンドの記述がある
