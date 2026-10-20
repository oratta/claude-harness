## MODIFIED Requirements
### Requirement: 許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する

`plugins/dev-workflow/scripts/git-guard-permit.sh` は、引数に拒否の記録のパスと理由（空でない文字列）を受け取り、次をすべて確かめたときだけ許可を書かなければならない（MUST）。どれかを確かめられなければ、許可を書かず、理由を stderr に書いて 0 以外で終わらなければならない（MUST）。

- 記録が `<base>/denied/<key>.json` の形の場所にあり、`basename(<base>)` が `dev-workflow-git-guard` で、中身から計算し直した `<key>` がファイル名と一致する。`<base>` は記録のパスの 2 つ上とし、環境変数 `TMPDIR` を見てはならない（MUST NOT。hook と親の Bash で `TMPDIR` が違いうるため）
- 記録の `session_id`・`cwd`・`command` が、一時領域の判定を満たす。`command` の単純コマンド（`&&`・`;`・改行で区切ったもの）のどれかの先頭の語が `rm` なら、次の git 用の判定の代わりに要件「rm の一時領域の判定」（spec rm-permission-hook）を使い、それ以外は次の判定を使う（どちらを使うかは記録の `command` だけで決め、記録の他の項目は見ない）

git 用の一時領域の判定は、`session_id`・`cwd`・`command` の 3 つを入力とし、次をすべて満たすときに満たすとする。git 用の判定と rm の判定は `plugins/dev-workflow/scripts/` の 1 つのファイルに置き、許可を書くスクリプトと hook（要件「子への拒否を記録し、親が 1 回だけ通せるようにする」と spec rm-permission-hook）がそれを読んで使わなければならない（MUST）。

- 判定する側（許可を書くスクリプト・hook）の環境変数に、`cd` や `git` の行き先・設定を変えるもの（`CDPATH`・`GIT_DIR`・`GIT_WORK_TREE`・`GIT_COMMON_DIR`・`GIT_INDEX_FILE`・`GIT_OBJECT_DIRECTORY`・`GIT_ALTERNATE_OBJECT_DIRECTORIES`・`GIT_NAMESPACE`・`GIT_CEILING_DIRECTORIES`・`GIT_DISCOVERY_ACROSS_FILESYSTEM`、および `GIT_CONFIG` で始まるもの）が 1 つも設定されていない（値が空でも設定されているものとして扱う。子の Bash は Claude Code の環境を受け継ぐので、hook の環境にあるものは子のコマンドにも効く）。ただし、一部の起動環境で Claude Code のセッションの Bash に渡される `GIT_CONFIG_COUNT`・`GIT_CONFIG_KEY_<n>`・`GIT_CONFIG_VALUE_<n>` の組は、次をすべて満たすときに限り、設定されていないものとして扱う（MUST）: `GIT_CONFIG_COUNT` が 10 進の非負整数（先頭の `0` の連続や符号を含まない）で、`GIT_CONFIG_KEY_0` から `GIT_CONFIG_KEY_<COUNT-1>` と `GIT_CONFIG_VALUE_0` から `GIT_CONFIG_VALUE_<COUNT-1>` がすべて設定され、すべての `GIT_CONFIG_KEY_<n>` の値が無害なキーの一覧（`credential.interactive`・`credential.guiPrompt`。大文字小文字まで完全一致）のどれかで、`GIT_CONFIG_COUNT` の範囲の外の番号の `GIT_CONFIG_KEY_*` / `GIT_CONFIG_VALUE_*` が 1 つも無い。`GIT_CONFIG_VALUE_<n>` の値は見ない。この組のどれか 1 つでも満たさなければ、`GIT_CONFIG` で始まる変数をすべて、今までどおり設定されているものとして扱う。`GIT_CONFIG`・`GIT_CONFIG_GLOBAL`・`GIT_CONFIG_SYSTEM`・`GIT_CONFIG_NOSYSTEM`・`GIT_CONFIG_PARAMETERS` など、この組以外の `GIT_CONFIG` で始まる変数は、組が揃っていても設定されているものとして扱う。無害なキーは「`cd` と `git` の行き先を変えず、判定が確かめた作業ツリー・git ディレクトリ以外へ git を向けない」と確かめたものだけを一覧に足し、足すときはこの要件を直す
- コマンドが英数字・空白・タブ・改行（LF だけ。CR は拒む）・`/ . _ , : = @ + % -`・`;`・`&&` だけでできている（変数・置換・引用符・リダイレクト・パイプ・グロブ・`~`・コメント・行継続を含まない）
- `&&`・`;`・改行で区切った単純コマンドがすべて、引数 1 つの `cd`（実在するディレクトリで、引数が `/`・`./`・`../` で始まるか `.`・`..` そのもの。シェルはそれ以外の引数を、オプション（`-P`・`--`）・ディレクトリスタックの番号（`+1`・`-1`）・zsh の `=` 展開・`CDPATH` や zsh の `cdpath` の探索として読みうるため）か、サブコマンドの前に `-C <パス>` だけを置いた `git`（`-C` は複数置けて、左から順に適用する）で、サブコマンドが `checkout`・`restore`・`reset`・`clean`・`branch`・`switch`・`status`・`add`・`commit`・`rev-parse` のどれかであり、`git` が 1 つ以上ある
- 各 `git` の作業ディレクトリ（`cwd` から `cd` と `-C` を順に適用し `realpath` で解決したもの）から親へ辿って見つかる `.git` について、作業ツリーの最上位・git ディレクトリ（`.git` がファイルなら `gitdir:` の先）・共通の git ディレクトリ（`commondir` があればその先）の `realpath` が、すべて `session_id` のセッションの scratchpad の中（scratchpad そのものを含む。scratchpad の直下に `.git` があれば scratchpad 全体を作業ツリーとする repo として中に数える）にある。scratchpad とは、`basename` が `scratchpad`、その親の `basename` が `session_id`、さらに 2 つ上の `basename` が `claude-<判定を動かすユーザーの uid>` のディレクトリで、かつその `claude-<uid>` の親の `realpath` が一時フォルダの置き場所（`/tmp`・`/private/tmp` と、hook では自分の環境変数 `TMPDIR` と Python の `tempfile.gettempdir()`、許可を書くスクリプトでは `<base>` の親（hook が `<base>` を置いた `TMPDIR`）の、`realpath` のどれか。hook と親の Bash で `TMPDIR` が違いうるので、スクリプトは自分の `TMPDIR` を数えず、hook と同じ候補で判定する）で、`claude-<uid>` がディレクトリで、所有者が判定を動かすユーザーの uid で、グループと他者に書き込み権が無いものである（作業ツリーの中などに同じ形のフォルダを作っても scratchpad に数えない）。`session_id` は英数字と `-` だけの空でない文字列でなければならない。scratchpad の中で `.git` が見つからないものは拒む
- 判定は単純コマンドを左から順に、実行前のファイルの配置で解く。前の単純コマンドが失敗したりファイルの配置を書き換えたりすると、判定が見た行き先と実際の行き先が割れるので、次をすべて満たす。これは判定から実行までの短い窓（判定のあとで別のものが配置を差し替える）とは別物で、コマンド自身の結果（`cd` の失敗、前の `git` による作業ツリーの書き換え）で起きる
  - `cd` を 1 つでも含むコマンドは、区切りが `&&` だけである（`;` と改行を 1 つも含まない。実行権限の無いディレクトリへの `cd` などが失敗すると、`;` や改行の後ろの `git` は元の `cwd` で走るため）
  - `cd` は最初の `git` より前にだけある（前の `git` が移り先を消したり、外への symlink に置き換えたりしうるため）
  - `git` が 2 つ以上あるコマンドでは、どの `git` にも `-C` が無い（前の `git` が `-C` の辿る道筋を書き換えうるため）
  - `git` が 2 つ以上あるコマンドでは、作業ディレクトリ（`cwd` から `cd` を辿った物理パス。`cd` が無ければ `cwd`）の `realpath` が、見つかった作業ツリーの最上位の `realpath` と一致する（作業ツリーの中のサブディレクトリは前の `git` に消されたり置き換えられたりしうるため）
- 見つかった `.git` を git が git ディレクトリとして受け入れる形である（git ディレクトリと共通の git ディレクトリと、共通の git ディレクトリの `objects` と `refs` がディレクトリで、どれにも判定を動かすユーザーが入れる（実行権限がある）。git ディレクトリの `HEAD` が `ref: refs/` で始まるか 40 桁か 64 桁の 16 進）。`.git` ファイルと `commondir` は、git と同じくファイル全体を読んで末尾の CR と LF だけを落とし、そのあとに CR・LF・NUL が残るもの（2 行以上ある・行の途中に改行文字がある）は拒む（git は受け入れない `.git` を飛ばして上の階層の repo を使い、改行を含んだままのパスを使うため）
- 作業ツリーの最上位より上のどの階層（scratchpad とその外を含め `/` まで）にも、`.git` も、git ディレクトリそのものの形（`HEAD` と、`objects` か `refs`）も無い（判定と git の受け入れ方がずれたときに、git が確かめていない repo や scratchpad の外に置かれた `.git` を使う余地を残さないため）
- git ディレクトリと共通の git ディレクトリの中に symlink が 1 つも無く、サブモジュールの git ディレクトリ（`modules`）も無く、作業ツリーの最上位に `.gitmodules` も無い（`refs`・`index`・`objects` などが外を指すと、中の repo への操作が外の repo を書き換え、サブモジュールへの再帰は `.git/modules/<name>` の先の repo を触るため）
- 共通の git ディレクトリの `config` と git ディレクトリの `config.worktree` に、`worktree` のキーも `[include` / `[includeIf` の節も `submodule` の文字列も無い（節名とキーは大文字小文字を区別せずに見る。git が区別しないため）

判定のために git を実行してはならない（MUST NOT。子が作った repo の設定でコマンドが動きうるため）。許可は `<base>/permits/<key>.json` に、`session_id`・`agent_id`・`cwd`・`command`・`scratchpad`・確かめた repo・理由・`created_at`・`expires_at`（書いた時刻の 15 分後の UNIX 秒）を入れて、一時ファイルからの `rename` で置かなければならない（MUST）。許可を書いたら、その子の回数のファイル（`<base>/<sha256(session_id + NUL + agent_id)>`）を消さなければならない（MUST。要件「同じ子への拒否の繰り返しを打ち切る」）。消せなかったときは stderr に書き、exit 0 で終わってよい。成功したときは、許可したコマンド・cwd・scratchpad・確かめた repo・期限を stdout に書かなければならない（MUST）。

守備範囲: 受け取る入力は、引数・拒否の記録・ファイルシステム上の scratchpad と repo の置き場所に加え、判定を動かすプロセスの環境変数（`CDPATH`・`GIT_DIR` など行き先を変えるものと、`GIT_CONFIG_COUNT`・`GIT_CONFIG_KEY_<n>`・`GIT_CONFIG_VALUE_<n>`。値は Claude Code が入れたものを含め呼び出し側が決める）である。拾いたい誤りは、親が「子が自分の一時領域を戻すだけ」と判断を誤って、一時領域の外のワークツリー・ホーム・他のリポジトリへの破壊的な操作を許可することである。次の入力は通す（許可を書く）ことを許す: 子が自分の Bash の中だけで `GIT_DIR` / `GIT_WORK_TREE` などを設定し、判定する側の環境には無いまま git が別の場所を触るもの（スクリプトと hook は子のシェルの中の環境を見られない。同じ呼び出しの中で代入する形は文字の制限と単純コマンドの制限で拒む）／scratchpad の中の、親の判断と違うファイルや repo を触るもの（守らないもの）。止めすぎる向きでは、引用符やグロブを使ったコマンド・許した以外の git のサブコマンドは scratchpad の中でも許可できないが、これは許す。`git -C X reset --hard && git -C X clean -fdx` のように `git` が 2 つ以上で `-C` を使うもの（`cd X && git reset --hard && git clean -fdx` に書き直す）・作業ツリーの中のサブディレクトリで `git` を 2 つ以上走らせるもの・末尾に改行や `;` がある `cd` 入りのコマンドも許可できないが、これも許す。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 一時領域の中の repo への操作は許可を書く

- **WHEN** `<tmp>/claude-<uid>/<slug>/<session_id>/scratchpad/repo` に repo を作り、`cwd` がそこで `git checkout -- .` の拒否の記録を作って、記録のパスと理由を渡す
- **THEN** exit 0 で終わり、`permits/` に許可が 1 つ作られ、stdout に scratchpad のパスが含まれる

#### Scenario: 一時領域の外を触る許可は書けない

- **WHEN** 拒否の記録の `cwd` が scratchpad の外の repo のもの、`cd` で scratchpad の外の repo に移ってから `git reset --hard` するもの、`git -C <外の repo> clean -fd` のもの、`.git` が外の git ディレクトリを指す repo のもの、`session_id` が別のセッションの scratchpad の中の repo のもの、共通の git ディレクトリの `config` に `[Core]` の節と `WorkTree = <外のパス>` のキーを大文字混じりで書いた repo のもの、をそれぞれ渡す
- **THEN** どれも 0 以外で終わり、`permits/` に許可が作られない

#### Scenario: git が受け入れない .git・git ディレクトリの中の symlink・サブモジュールがある repo には許可を書かない

- **WHEN** scratchpad の中の、`.git` が中身の無いディレクトリの repo・`commondir` が CR 付きの `..` の repo・`.git` ファイルが 2 行ある repo・`.git` ファイルの行の途中に CR がある repo・`commondir` が 2 行ある repo・`.git/objects` か `.git/refs` の実行権限を落とした repo・別の repo の作業ツリーの中に作った repo・scratchpad の親に `.git` ファイルを置いた scratchpad の中の repo・`.git` の `refs`・`index`・`packed-refs`・`HEAD`・`objects`・`refs/heads`・`logs` のどれかを外の repo の同じものへの symlink にした repo・`.git/modules/sub` を外の repo の `.git` への symlink にした repo・作業ツリーの最上位に `.gitmodules` がある repo・`config` に `[Submodule "sub"]` の節がある repo への操作の拒否の記録をそれぞれ渡す
- **THEN** どれも 0 以外で終わり、`permits/` に許可が作られず、外の repo の branch は残る

#### Scenario: 一時フォルダの外に作った同じ形のフォルダは scratchpad に数えない

- **WHEN** 一時フォルダの置き場所でないディレクトリ（作業ツリーの中など）の下に `claude-<uid>/<slug>/<session_id>/scratchpad/repo` を作り、`cwd` がそこで `git checkout -- .` の拒否の記録を渡す。また、同じ `cwd` とコマンドで 4 つの値が一致し期限内の許可を `permits/<key>.json` に直接書いてから、その payload を hook に渡す
- **THEN** スクリプトは 0 以外で終わって `permits/` に許可が作られず、hook は `permissionDecision` が `deny` で `permissionDecisionReason` に「許可はあるが行き先を確かめられない」を含む

#### Scenario: Claude Code が入れる無害な GIT_CONFIG の組なら許可を書き、使う

- **WHEN** `GIT_CONFIG_COUNT=2`・`GIT_CONFIG_KEY_0=credential.interactive`・`GIT_CONFIG_VALUE_0=false`・`GIT_CONFIG_KEY_1=credential.guiPrompt`・`GIT_CONFIG_VALUE_1=false` を設定した環境で、一時領域の中の repo への `git checkout -- .` の拒否の記録をスクリプトに渡し、そのあと同じ環境で hook に元の payload を渡す
- **THEN** スクリプトは 0 で終わって `permits/` に許可が作られ、hook は `permissionDecision` が `allow` になる

#### Scenario: 無害でないキーや組の崩れがあれば許可を書かない

- **WHEN** 上の組の `GIT_CONFIG_KEY_1` を `core.worktree` に替えた環境、`GIT_CONFIG_COUNT=2` なのに `GIT_CONFIG_KEY_1` が無い環境、`GIT_CONFIG_COUNT=1` なのに `GIT_CONFIG_KEY_1` がある環境、上の組に `GIT_CONFIG_GLOBAL` か `GIT_CONFIG_PARAMETERS` を足した環境、`GIT_CONFIG_COUNT` が `abc` の環境で、それぞれ同じ拒否の記録をスクリプトに渡す
- **THEN** どれも 0 以外で終わり、理由に環境変数の名前が含まれ、`permits/` に許可が作られない

#### Scenario: 行き先を変える環境変数があれば許可を書かず、使わない

- **WHEN** 一時領域の中の repo への `git checkout -- .` の拒否の記録を、`GIT_DIR` を scratchpad の外の repo の git ディレクトリに向けた環境でスクリプトに渡す。また、その環境変数の無い環境で許可を書いたあと、`GIT_DIR` を外に向けた環境で hook に元の payload を渡す
- **THEN** スクリプトは 0 以外で終わって `permits/` に許可が作られず、hook は `permissionDecision` が `deny` で `permissionDecisionReason` に「許可はあるが行き先を確かめられない」を含む

#### Scenario: 行き先を確定できないコマンドは許可を書かない

- **WHEN** コマンドが `cd "$D" && git checkout -- .`・`git reset --hard && rm -rf x`・`git push --force origin main`・`GIT_DIR=x git reset --hard`・`git checkout -- . > out`・`git init /x/outside`・CR を含む `git checkout -- .` の拒否の記録をそれぞれ渡す
- **THEN** どれも 0 以外で終わり、`permits/` に許可が作られない

#### Scenario: cd の移り先がパスの形で始まらないものは許可を書かず、使わない

- **WHEN** scratchpad の外の `cwd` に、scratchpad の中の repo を指す `-Z`・`-P`・`--`・`+1`・`=git`・`repo` という名前のリンクを置き、`cd -Z; git reset --hard`・`cd -P && git status`・`cd -- && git reset --hard`・`cd +1; git reset --hard`・`cd =git; git reset --hard`・`cd repo && git reset --hard` の拒否の記録をそれぞれ渡す。また、`cd -Z; git reset --hard` について 4 つの値が一致し期限内の許可を `permits/<key>.json` に直接書いてから、その payload を hook に渡す
- **THEN** スクリプトはどれも 0 以外で終わって `permits/` に許可が作られず、hook は `permissionDecision` が `deny` で `permissionDecisionReason` に「許可はあるが行き先を確かめられない」を含む

#### Scenario: cd の失敗や前の git の書き換えで行き先が変わるコマンドは許可を書かず、使わない

- **WHEN** `cwd` が scratchpad の外の作業ツリーで、scratchpad の中の repo（`main` で `sub/f` を追跡し、ブランチ `evil` では `sub` が外への symlink。未追跡のディレクトリ `build` がある）と実行権限を落としたディレクトリ `locked` について、`cd <repo>/locked ; git reset --hard`・`;` を改行にした同じもの・`git -C <repo> clean -fdx ; cd <repo>/build ; git reset --hard`・`cd <repo> && git checkout evil && cd ./sub && git reset --hard`・`git -C <repo> checkout evil && git -C <repo>/sub reset --hard`・`cd <repo>/sub && git checkout evil && git reset --hard` の拒否の記録をそれぞれ渡す。また、`cwd` が repo で `cd <repo>; git reset --hard`・`git status && cd <repo> && git reset --hard` の記録を渡す。また、`cd <repo>/locked ; git reset --hard` について 4 つの値が一致し期限内の許可を `permits/<key>.json` に直接書いてから、その payload を hook に渡す
- **THEN** スクリプトはどれも 0 以外で終わって `permits/` に許可が作られず、hook は `permissionDecision` が `deny` で `permissionDecisionReason` に「許可はあるが行き先を確かめられない」を含む。`cd ./repo && git reset --hard && git clean -fdx`（`cwd` が scratchpad）は今までどおり許可を書く

#### Scenario: 置き場所や中身が合わない記録には許可を書かない

- **WHEN** 拒否の記録を `denied/` の外に写したもの、`dev-workflow-git-guard` でない名前のディレクトリの下の `denied/` に写したもの、中身のコマンドを書き換えたもの、理由を空にしたもの、をそれぞれ渡す
- **THEN** どれも 0 以外で終わり、`permits/` に許可が作られない

#### Scenario: スクリプトは TMPDIR ではなく記録の場所に許可を書く

- **WHEN** hook を `TMPDIR=A` で動かして `A` の下の scratchpad の repo への拒否の記録を作り、スクリプトを `TMPDIR=B` で動かしてから、同じ payload を `TMPDIR=A` の hook に渡す
- **THEN** 許可が `A` の下の `dev-workflow-git-guard/permits/` に作られ、`B` の下には何も作られず、hook は `permissionDecision` を `allow` にする

#### Scenario: スクリプトは自分の TMPDIR を一時フォルダの候補に数えない

- **WHEN** hook を `TMPDIR=A` で動かして、`B` の下にだけある scratchpad の repo への拒否の記録を作り、スクリプトを `TMPDIR=B` で動かす
- **THEN** 0 以外で終わり、`permits/` に許可が作られない（hook はこの scratchpad を数えないので、書いても使えない）

#### Scenario: rm のコマンドの記録には rm 用の判定で許可を書く

- **WHEN** `cwd` が scratchpad の中で、コマンドが `cd ./tbl; rm -rf x/*` の拒否の記録（`kinds` は `rm`）を渡す
- **THEN** exit 0 で終わり、`permits/` に許可が 1 つ作られる。同じ記録の `kinds` を `git` に書き換えても、判定は `command` だけで決まるので結果は変わらない

### Requirement: 拒否理由は承認の取り方を案内する

対話のセッションの主の呼び出し（`agent_id` が無い・空・文字列でない）への `permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（9 種のどれか。複数当たればすべて）／規範の正本が `rules/destructive-git-guard.md` であること／実行せず主に承認を求めること／承認されたら主が自分で実行すること（Claude Code の入力欄で `!` を付けるか、自分の端末で。`ask` のときは、確認画面が出ないセッション（`claude -p` など）ではそうすること）／`ask` のときは、確認画面を出していること／言い換えたコマンドで再実行して hook を避けないこと。`!` の入力は PreToolUse hook を通らない（対話セッションで `! git reset --hard` が止められずに実行されることを確かめた）ので、`!` の案内を残す。コマンドに付けて hook を通す目印（環境変数の前置など）を案内してはならない（MUST NOT）。

無人のセッションの主の呼び出しへの `permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（判定しきれなかった入れ子のときはその旨）／規範の正本が `rules/destructive-git-guard.md` であること／このコマンドは実行していないこと／何を・なぜ・いつ実行するかをチャンネル（Discord など）でオーナーに伝えて承認を求めること（文字列「チャンネル」と「オーナー」を含む）／承認されたらオーナーが自分で実行すること／言い換えたコマンドで再実行して hook を避けないこと。無人のセッションへの理由に、確認画面の話（文字列「確認画面」）を書いてはならない（MUST NOT。出していない確認画面の操作を待って止まる余地を残さないため）。コマンドに付けて hook を通す目印を案内してはならない（MUST NOT）。

子の呼び出し（`agent_id` が空でない文字列）への `deny` の `permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（判定しきれなかった入れ子のときはその旨）／規範の正本が `rules/destructive-git-guard.md` であること／このコマンドは実行されないこと／打ち直さず、別の書き方も試さないこと（文字列「打ち直さず」を含む）／scratchpad の検証用 repo なら git で戻さず作り直すこと／それ以外は作業を止め、報告に次の 4 項目を書いて親に返すこと（打ちたかったコマンドの全文、対象のパス、その対象を自分で作ったか（作ったなら、作ったコマンド）、なぜ要るか。文字列「コマンドの全文」「対象のパス」「自分で作った」を含む）／親の許可を受けられる打ち方の例は、変数を使わず実パスで単独のコマンドとして打つこと（変数や置換を含む形は親が許可を書けない。ほかの形が許可を受けられないとは書かない）（1 文で書く。文字列「実パスで単独のコマンド」を含む。この文は打ち方を教えるもので、打ち直しを許すものではなく、「打ち直さず」の指示は変えない）／拒否の記録を書けたときは、そのパスと、親に返す報告にそのパスを書くこと。子への理由に、確認画面を出していること、`!` を付けて打つこと、許可を書くスクリプトの名前と使い方を書いてはならない（MUST NOT。主に上げるのも許可を書くのも親の役目で、子が自分で主に聞こうとしたり自分で許可を書こうとしたりする余地を残さないため）。コマンドに付けて hook を通す目印を案内してはならない（MUST NOT）。

#### Scenario: deny の理由に承認の取り方が書かれている

- **WHEN** `agent_id` の無い、`permission_mode` が `auto` の payload で `git push origin main` を渡す
- **THEN** `permissionDecisionReason` に、main / master への push に当たったこと、`rules/destructive-git-guard.md`、主に承認を求めること、主が自分で実行することが含まれ、`DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

#### Scenario: ask の理由に確認画面と、画面が出ないときの取り方が書かれている

- **WHEN** `agent_id` の無い、`permission_mode` が `bypassPermissions` の payload で `git push origin main` を渡す
- **THEN** `permissionDecision` が `ask` で、`permissionDecisionReason` に、main / master への push に当たったこと、`rules/destructive-git-guard.md`、確認画面を出していること、主に承認を求めること、主が自分で実行することが含まれ、`DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

#### Scenario: 無人のセッションの理由はチャンネルでオーナーに依頼するよう案内する

- **WHEN** `DEV_WORKFLOW_UNATTENDED=1` を付けて、`agent_id` の無い、`permission_mode` が `bypassPermissions` の payload で `git push origin main` を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` に、main / master への push に当たったこと、`rules/destructive-git-guard.md`、実行していないこと、「チャンネル」と「オーナー」、オーナーが自分で実行すること、言い換えて再実行しないことが含まれ、「確認画面」と `DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

#### Scenario: 子への理由は親に返すよう案内する

- **WHEN** `agent_id` が空でない文字列で `permission_mode` が `default` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecisionReason` に、許可を受けられる打ち方の 1 文（「実パスで単独のコマンド」と「変数」）、作業の破棄に当たったこと、`rules/destructive-git-guard.md`、「打ち直さず」、scratchpad の検証用 repo なら作り直すこと、報告に書く 4 項目（「コマンドの全文」「対象のパス」「自分で作った」「なぜ」）を書いて親に返すこと、拒否の記録のパスが含まれ、「確認画面」と `!` を付けて打つ案内と `git-guard-permit.sh` と `DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない
