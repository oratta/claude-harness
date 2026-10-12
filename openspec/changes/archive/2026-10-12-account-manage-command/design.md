## Context

登録簿（`accounts.json`）を書く手段は `accounts-init.sh` だけで、これは「いま居るシェルの `CLAUDE_SECURESTORAGE_CONFIG_DIR` の実値を、`--id` のスロットとして登録する」もの。同じ id なら上書き、無ければ追加し、既存の `enabled` は残す（#976）。オン・オフを書く手段は無く、手で編集している。

## Goals / Non-Goals

**Goals:**

- 一覧・追加・オフ・オンがそれぞれコマンド 1 つで済む
- 書き換えは登録簿の控えを取ってから行い、壊れた JSON を黙って上書きしない
- 他の欄（`label`・`securestorage`・スロットの順序・未知のキー）は変えない

**Non-Goals:**

- Codex 側のオフ（#978）、`codex-develop.py` の変更
- アカウントの削除（認証情報の置き場所の削除を伴うので別の判断）
- ログインそのものの自動化（`add` は実行すべきコマンドを表示するだけ）
- `accounts-init.sh` の挙動変更

## Decisions

**D1. 別スクリプト `accounts.sh` にし、`accounts-init.sh` は拡張しない。**
`accounts-init.sh` の意味は「居るシェルの環境から登録する。同じ id は上書きする」で、`add`（置き場所を作る。同じ id は拒否する）とは正反対の既存 id の扱いになる。同じスクリプトに入れると、引数の有無でこの 2 つの意味が切り替わる。`accounts-init.sh` は既存の README・bats（`usage-probe-multi-account.bats`）・利用者の手順が呼んでいるので、壊さずに残す。却下した案: `accounts-init.sh` にサブコマンドを足す（既存の `--id` だけの呼び出しとの互換を保つ分岐が要り、2 つの意味が 1 本に同居する）。

**D2. サブコマンド形式 `accounts.sh <list|add|on|off> ...`。**
名前は `accounts.sh`（`cld` / `cld-account` / `accounts-init.sh` と同じ「accounts」の語で揃える）。引数の形式は `accounts-init.sh` の `--id` ではなく位置引数の id にする。`on` / `off` / `add` は対象 id が必須の 1 操作で、`--id` を毎回書かせる利点が無い。`--label` だけがオプション。

**D3. 認証情報の置き場所の基点は `CLAUDE_ACCOUNTS_HOME`（既定 `$HOME/.claude-accounts`）。**
置き場所は `<基点>/<id>`。テストが実ホームを触らないようにするための上書き口でもある。絶対パスでなければ exit 2。ディレクトリが既にあっても id が登録簿に無ければ使う（作り直さない）。`securestorage` には作ったディレクトリの絶対パスを文字列のまま書く（`accounts-init.sh` が実値をそのまま書くのと同じ理由。Keychain のサービス名がパスの表記で変わるため、ここで末尾スラッシュや `~` を持ち込まない）。

**D4. `on` は `enabled: true` を書く（キーを消さない）。`off` は `enabled: false` を書く。**
受け入れ条件が false → true の遷移を求めている。キーを消す案は「省略時はオン」で同じ意味になるが、`list` や diff で変化が見えにくい。もともと `enabled` が無いスロットに `on` を実行しても `true` が書かれる（意味は変わらない）。

**D5. 控えは `<登録簿>.bak` の 1 世代。書き込みは一時ファイル＋`os.replace`。**
書き換えのたびに上書きする。履歴を溜めない（1 つ前に戻せれば足りる）。登録簿が無いとき（`add` が新規作成するとき）は控えを作らない。書き込みの一時ファイルは `accounts-init.sh` と同じく `mkstemp`（同時実行で奪い合わない）。登録簿が JSON として読めない・トップレベルがオブジェクトでない・`accounts` が配列でないときは、何も書かず exit 1。これは `accounts-init.sh` と同じではない: `accounts-init.sh` は JSON として読めないときだけ exit 1 で、読めても `accounts` が配列でなければ空の登録簿として扱い、そのまま上書きする（`accounts-init.sh:81-93`）。`accounts.sh` は既存のスロットを黙って失わないよう、より厳しくする（`accounts-init.sh` は変えない）。

**D6. `add` の出力。**
stdout にログインするコマンドを 1 行、`CLAUDE_SECURESTORAGE_CONFIG_DIR=<絶対パス> claude`（起動後に `/login`）の形で出す。パスはシェルの単一引用符で囲み、パス中の `'` は `'\''` にする（基点に空白があっても、1 行をそのまま貼って実行できる。`securestorage` に書く値は引用符なしの素のパス）。stderr に登録した旨の 1 行。`list` の出力は 1 行 1 スロットで `<id>\t<label>\t<on|off>\t<securestorage>`（既定アカウントは `securestorage` を `-` と出す）。

**既知の性質（リスクではない）:** 登録簿が無いところへ最初に `add` すると、既定アカウントのスロットが無い登録簿ができる。既定アカウントも並べたいときは、従来どおり `accounts-init.sh --id <id>` をそのシェルで実行する。README に書く。

## Risks / Trade-offs

- 登録簿を JSON として書き直すため、手で書いていたインデントや並びの整形は `indent=2` に揃う。値と順序は変わらない（`accounts-init.sh` も同じ）。
- README の `accounts.json` を手で編集する案内は、`accounts.sh` で足りる操作（追加・オン・オフ・一覧）については全部コマンドの手順に置き換える。手編集が要る操作（`label` や `securestorage` の変更）は `accounts-init.sh` の再実行で足りるので、手編集の案内は残さない。フィールドの形を示す参照表（`enabled` の行）は操作の案内ではないので残す。
- `.bak` は 1 世代なので、2 回続けて実行すると最初の状態の控えは残らない。起こる場面は、続けて 2 回間違えたときだけ。
