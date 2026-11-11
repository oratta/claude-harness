# Design

## Context

動機は proposal.md の Why。今の仕組みの要点は次のとおり。

- git ガード（`scripts/git-destructive-guard.sh`、PreToolUse・matcher `Bash`）は、子（`agent_id` が空でない文字列）の破壊的 git 操作を `deny` し、拒否の記録を `<base>/denied/<key>.json` に書く。親が許可を書くスクリプトでその記録から `<base>/permits/<key>.json` を作ると、子の同じ呼び出しを 1 回だけ `allow` する。`<base>` は `${TMPDIR:-/tmp}/dev-workflow-git-guard`
- 子が許可を書くスクリプトの名前をコマンドに書くと、書き方を読み分けずに止める（要件「子は許可を書くスクリプトを呼べない」。種類 `permit-self`）。`permits/` に直接書く形は、守備範囲で通ることを許している
- Write / Edit / NotebookEdit に掛かっている PreToolUse は `context-tripwire.sh`（コンテキストの計測）だけで、書き先は見ていない。`context-tripwire.sh` が子の判定に `agent_id` を使えているので、これらのツールの payload にも子なら `agent_id` が入る
- 子・hook・親（develop の本体）・許可を書くスクリプトは、どれも同じ uid で、同じ環境変数を持って動く

## Goals / Non-Goals

**Goals:**

- 子が許可を偽造する分かりやすい 2 つの書き方（Write / Edit / NotebookEdit で `<base>` に書く・Bash のコマンドに置き場所の名前を 2 つとも書く）を、実行の前に止める
- 止めても子を打ち切らない（ルールを読み飛ばした子が 1 回当たっただけで作業を失わない）
- 正当なコマンドを止める頻度を、今の記録で測った値として残す

**Non-Goals:**

- 偽造を塞ぎ切ること（ガード全体と同じく、セキュリティ境界にしない）
- 許可を書くスクリプト・rm ガード・親の手順（`skills/develop/SKILL.md`）を変えること
- エピック #1476 の他の子の範囲。とくに #1166（許可を書くスクリプトの名前が入るだけで打ち切られる件）の `permit-self` の数え方、#1159・#1173 の範囲、Draft PR #1463 が触る字句解析部（`join_words`〜`judge` のあたり）には手を出さない

## Decisions

### 決定 1: 秘密の印（HMAC）は使わない

自動セキュリティレビューは、子が読めない秘密で許可に HMAC を付ける案を出した。使えない。hook・許可を書くスクリプト・子の Bash はどれも同じ uid で動き、hook に渡る環境変数は子の Bash にも渡る。hook が読める秘密（ファイル・環境変数・キーチェーン）は、子も同じ権限で読める。秘密を読めない場所に置けない以上、印は「子が自分で付けられる印」にしかならず、止める力は名前の判定と変わらない。止められるのは、子が書き込みを分かりやすく書いた形だけである（主の決定、https://github.com/oratta/claude-harness/issues/1155#issuecomment-6759579861 ）。

### 決定 2: Bash で名指しとみなすのは `dev-workflow-git-guard` と `permits` の 2 つ

子の Bash の `tool_input.command` の文字列のどこかに、`dev-workflow-git-guard` と `permits` の両方が含まれていたら止める（部分文字列で、大文字小文字は区別する。`permit-self` の名前の判定と同じく、シェルの書き方を読み分けない）。

選んだ理由:

- `dev-workflow-git-guard` は `<base>` の名前そのもので、この名前を書かずに `<base>` へ届くには、変数で組み立てるかグロブを使うしかない（それは通すと守備範囲に書く）
- `permits` は許可の置き場所のディレクトリ名。`<base>` の名前だけでは止めない。子は拒否の理由文で拒否の記録のパス（`<base>/denied/<key>.json`）を受け取り、報告に書くために読むことがある。`<base>` の名前だけで止めると、その読み取りまで止める
- 1 つの続いた文字列（`dev-workflow-git-guard/permits`）でなく 2 つに分けるのは、`cd "$TMPDIR/dev-workflow-git-guard" && printf ... > permits/k.json` のように、移ってから相対パスで書く形も拾うため

比べた案:

- `permits` だけ: 英語の一般語なので、無関係なコマンド（メッセージの本文など）にも出る
- `dev-workflow-git-guard` だけ: 上の拒否の記録の読み取りを止める
- `git-guard` と `permits`: 許可を書くスクリプトのテストや spec を触るコマンドにも当たりやすく、広すぎる

#### 止めすぎの頻度

この Mac の会話ログ（`~/.claude/projects/` の下の全 jsonl、2026-11-10 時点）にある Bash の呼び出し 109,484 件のうち、`dev-workflow-git-guard` を含むものは 29 件、両方を含むものは 8 件（約 0.007%）だった。8 件はすべてサブエージェントのログで、どれも issue #1155 の作業そのもの（この spec を python のヒアドキュメントで書き換える・共通ファイルを grep する・偽造を確かめる実験）だった。止めすぎが起きるのは、このガードの置き場所そのものを扱う開発の子だけで、それ以外の作業では今の記録の上では起きていない。止まった子は親に返り、親（主の呼び出しなので止まらない）が代わりに打てる。テストは bats のファイルの中に書くので、`bats <ファイル>` の呼び出しには当たらない。

#### 理由文に 2 つの名前を書かない

子への理由文には `dev-workflow-git-guard` と `permits` を並べて書かない（`permit-self` の理由文が許可を書くスクリプトの名前を書かないのと同じ）。子が理由文を報告用のコマンド（`gh issue comment` など）に写すと、そのコマンドがまた止まるため。

### 決定 3: Write / Edit / NotebookEdit は `<base>` の中への書き込みを丸ごと止める

子の Write / Edit の `tool_input.file_path`、NotebookEdit の `tool_input.notebook_path` が、パスの部品（`/` で区切った 1 つ）に `dev-workflow-git-guard` を含む場所なら止める。部品の比較は大文字小文字を区別しない（macOS の既定のファイルシステムは大文字小文字を区別せず、`Dev-Workflow-Git-Guard` でも同じフォルダに届くため）。パスは、相対なら payload の `cwd` を前に付け、`os.path.normpath` で `..` を畳んだものと、`os.path.realpath` で既にある部分の symlink を辿ったものの 2 つを見て、どちらかが当たれば止める（Bash で `ln -s` した別名のフォルダを経て書く形を拾う。`ln -s` のコマンドは `permits` を含まなければ通るので、こちらで拾う）。

`permits/` だけでなく `<base>` の中を丸ごと止めるのは、子がツールで `<base>` に書く用事が無いため。回数のファイルを書き換えれば打ち切りを外せ、拒否の記録を書き換えれば親に違うコマンドの記録を渡せる。hook とスクリプトは自分で書くので、ツールの判定は効かない。

NotebookEdit を含める。ファイルを書けるツールで、含めない理由が無い（`context-tripwire.sh` も Edit / Write / NotebookEdit を同じ組で扱っている）。

### 決定 4: Write / Edit / NotebookEdit は新しい hook のスクリプトで止める

`scripts/git-guard-base-write-guard.sh` を新しく作り、hooks.json の PreToolUse に `matcher: "Write|Edit|NotebookEdit"` で配線する。git ガードの Bash のエントリが PreToolUse の末尾である決まり（要件「破壊的 git 操作を Bash の実行前に検出する」の Scenario「hooks.json に登録されている」）は保ち、新しいエントリはその前に置く。

比べた案: git ガードの matcher を `Bash|Write|Edit|NotebookEdit` に広げる。採らない理由は 3 つ。(1) git ガードは `tool_name` が `Bash` でなければ何もしないと spec（要件「逃げ道と fail-open」の Scenario「読めない入力は素通り」）が定めており、それを変えることになる。(2) git ガードの早期 exit（payload に `git` が無ければ python3 を起動しない）は、Write の本文に `git` を含む呼び出しの大多数で効かず、Write のたびに字句解析を持つ大きな本体を起動することになる。(3) Draft PR #1463 などが触る git ガードの本体との重なりを小さくする。

新しいスクリプトの早期 exit: payload に `dev-workflow-git-guard`（大文字小文字を問わない）も `\u00` も無く、さらに子の判定に要る `agent_id` も無ければ python3 を起動しない。主の呼び出しと、置き場所に無関係な書き込みの大多数で起動しない。symlink を経た書き込み（パスに名前が出ない形）は realpath で見る必要があるので、子の呼び出しでは名前が無くても起動する（子の Write の回数は少なく、負荷は小さい）。具体的な必要条件は実装で決め、外から見える判定は spec の Scenario で縛る。

`<base>` の名前（`dev-workflow-git-guard`）は、新しいスクリプトにも書く。git ガードの本体（`guard_base` の行）と共通ファイル（`git-guard-scratchpad.py` の `BASE_NAME`）にも既に書かれており、共通ファイルを読み込んで名前を取る形にはしない（共通ファイルを読めないと止められなくなるため。名前が食い違わないことはテストで確かめる）。

`DEV_WORKFLOW_GIT_GUARD=off` のときは、新しいスクリプトも何も出さずに通す（git ガードと同じ逃げ道）。python3 が無い・payload が読めない・パスが文字列でないときは何も出さずに通す（fail-open）。

### 決定 5: 2 つの拒否は数えず、記録を書かず、許可も使わない

主の決定どおり、この 2 つの拒否は子への拒否の回数に数えない。加えて次のとおり扱う。

- Write / Edit / NotebookEdit の拒否は git ガードの外なので、回数のファイル・拒否の記録・`<base>` の確かめに触らない。`deny` を返すだけ
- Bash の拒否（種類 `permit-store`）は、拒否の記録を書かない。記録があると親が許可を書くスクリプトに渡せてしまい、許可の置き場所に書くコマンドを親が許可する道ができるため。同じ理由で、置かれた許可も探さない（`permit-self` と同じ）。理由文には、このコマンドには拒否の記録を作らず、親も許可を書けないことを書く
- 同じコマンドに破壊的 git 操作（判定しきれなかったものを含む）か `permit-self` も当たったときは、その分として今までどおり回数を数える。`permit-store` が当たったことで数えなくなると、破壊的 git 操作に 2 つの名前を書き足すだけで打ち切りを外せるため。記録は書かず、許可も使わない（`permit-store` が当たったコマンドは、親の許可で通さない）
- 子への理由文は、今の子向けの文（打ち直さない・別の書き方も試さない・報告に 4 項目を書いて親に返す）を保つ

## Risks / Trade-offs

- [変数で組み立てたパス・グロブ・スクリプトファイルの中・`cd` で移ってから `permits` の名前を書かずに書く形（`cd "$TMPDIR/dev-workflow-git-guard/p"*` など）・python の文字列連結では止まらない] → 主の決定どおり止めない。spec の守備範囲に書く。通っても許可が効くのは、使う時点の一時領域の判定を満たす scratchpad の中だけ
- [このガードの開発をする子が、spec の書き換えや偽造の確かめで止まる] → 頻度は上の測定値（約 0.007%、すべて #1155 の作業）。子は親に返り、親が打つ。打ち切らないので作業は失われない
- [Write / Edit で、無関係なパスに `dev-workflow-git-guard` という部品を持つものを止める] → この名前のフォルダは git ガードの置き場所以外に無い。リポジトリの中のテストの書き先は bats が作る一時フォルダで、子がツールで書く先ではない
- [新しい hook のスクリプトは hook が実行するので聖域] → エピックの注意書きどおり、Ready にする前に PR に human-merge を付けて主のマージ待ちにする

## Migration Plan

hook の追加と hooks.json の配線だけで、データの移行は無い。マージ後に marketplace dir 側の `sync.sh` で反映する。戻すときは、この PR を revert すれば今の挙動（直接書いた許可を通す）に戻る。
