## MODIFIED Requirements

### Requirement: 検査の守備範囲

検査の目的は、エージェントが値の出る形をそのまま書いたときに止めることで、セキュリティ境界ではない。受け取る入力は、Claude Code が PreToolUse で渡す Bash と Read の payload と、hook プロセスの環境変数 `CAPABILITY_REGISTRY_SECRET_GUARD` に限る。拾う型は、要件「値が画面に出る形を止める」に挙げた形をそのまま書いたものとする。次は通ることを許す: `Grep` など Bash と Read 以外のツール／ssh 越しの実行（`ssh host cat .env`）／スクリプトファイルの中の実行（`bash show.sh`）／別の言語からの読み出し（`python3 -c ...`）／シークレットらしくない名前の変数（`echo "$MY_VALUE"`）／変数に入れたパス（`cat "$F"`）／機密らしい語がディレクトリ名にだけあるファイルの Read（`/x/config/credentials/production.key`、`/x/service-account/prod.json`、`/x/.env/prod`）。穴が見つかるたびに塞ぎ切ることは完了条件にしない（MUST NOT）。

#### Scenario: 守備範囲の外の入力は通す

- **WHEN** `ssh host cat .env`、`bash show.sh`、`echo "$MY_VALUE"`、`cat "$F"` を Bash の payload で渡し、`file_path` が `/x/config/credentials/production.key`、`/x/service-account/prod.json` の Read の payload を渡す
- **THEN** どれも exit 0 で何も出力しない

### Requirement: 止めすぎる向きの既知の挙動を変えない

止めすぎる向きの既知の挙動のうち、ヒアドキュメント本文の行をコマンドとして読むこと、およびファイル名に機密らしい語を含む Read を止めること（`credentials.ts`、`credential-guide.md`、`process.env.ts`）を変えてはならない（MUST NOT。正本は要件「値が画面に出ない使い方は止めない」）。Read の判定はファイル名だけで行い、親ディレクトリの名前に機密らしい語があるだけでは止めてはならない（MUST NOT）。

#### Scenario: 止めすぎる向きの既知の挙動も変えない

- **WHEN** ヒアドキュメントの本文の行に `echo "$GH_TOKEN"` があるコマンドを Bash の payload で渡し、`file_path` が `/x/credentials.ts`、`/x/docs/credential-guide.md`、`/x/process.env.ts` の Read の payload を渡す
- **THEN** どれも `permissionDecision` が `deny` の JSON が出る

#### Scenario: 親ディレクトリの名前だけでは止めない

- **WHEN** `file_path` が `/x/credentials-service/src/index.ts`、`/x/.env/lib/site.py` の Read の payload を渡す
- **THEN** どれも exit 0 で何も出力しない

### Requirement: 値が画面に出ない使い方は止めない

hook は、シークレットをコマンド置換で変数に入れて使う形と、値を出さない確かめ方を止めてはならない（MUST NOT）。判定は移す前の hook と同じでなければならない（MUST）。例外は 3 つだけで、個人の道具 1 本に専用だった検査（`fmtoken.sh` の裸実行）を持ち込まないこと、要件「壊れたときと無効化のときは素通りする」の無効化、Read の判定対象をパス全体からファイル名（パスの最後の要素）に絞ることである。ファイル名に当てる語とテンプレート類の規則は移す前と同じとし、判定の前に、パスの末尾の `/` を取り除く（Read は末尾に `/` を付けたパスでもファイルを読み、hook にも付いたまま渡るため）。止めないときは何も出力せず exit 0 とする。

#### Scenario: コマンド置換での利用は止まらない

- **WHEN** `GH_TOKEN="$(get-token github)" gh api /user`、`GH_TOKEN="$(op read op://v/i/f)" gh api /user` を Bash の payload で渡す
- **THEN** どれも exit 0 で何も出力しない

#### Scenario: 値を出さない確かめ方とテンプレートは止まらない

- **WHEN** `echo "${GH_TOKEN:+SET}"`、`echo "${#GH_TOKEN}"`、`cat .env.example`、`env FOO=1 ls`、`echo "--- .env:"`、`echo hi > .env`、`ls` を Bash の payload で渡し、`file_path` が `/x/.env.example`、`/x/README.md` の Read の payload を渡す
- **THEN** どれも exit 0 で何も出力しない

#### Scenario: ファイル名が機密の形の Read は止まり続ける

- **WHEN** `file_path` が `/x/.env`、`/x/credentials.json`、`/x/a.token` の Read の payload を渡す
- **THEN** どれも exit 0 で `permissionDecision` が `deny` の JSON が出る

#### Scenario: テンプレート類の判定もファイル名で行う

- **WHEN** `file_path` が `/x/foo.template/.env` の Read の payload を渡す
- **THEN** exit 0 で `permissionDecision` が `deny` の JSON が出る

#### Scenario: 末尾に `/` を付けても止まる

- **WHEN** `file_path` が `/x/.env/`、`/x/credentials.json/` の Read の payload を渡す
- **THEN** どれも exit 0 で `permissionDecision` が `deny` の JSON が出る

#### Scenario: 個人専用の検査は持ち込まない

- **WHEN** `fmtoken.sh github` を Bash の payload で渡す
- **THEN** exit 0 で何も出力しない
