# Spec Delta

## Purpose

シークレットの値が画面（transcript）に出る形の Bash と Read を、capability-registry 同梱の PreToolUse hook が実行前に止める。PostToolUse では値がもう transcript に載っているので、防げる場所は実行前だけである。トークンを使うこと自体は止めない。

## ADDED Requirements

### Requirement: プラグインを入れるだけで Bash と Read の実行前に検査する

capability-registry は `hooks/hooks.json` の PreToolUse に、`Bash` と `Read` だけにマッチする secret-guard の hook を定義しなければならない（MUST）。`settings.json` や `~/.claude/hooks/` の編集なしに、プラグインを入れるだけで有効にならなければならない（MUST）。hooks.json の既存の browser-guard の配線は変えてはならない（MUST NOT）。

#### Scenario: settings.json に配線が無い環境で止まる

- **WHEN** ユーザーの `settings.json` を読まず、capability-registry だけを読み込んだ Claude Code で、`GH_TOKEN` に偽の値を入れて `echo "$GH_TOKEN"` を Bash ツールで実行させる
- **THEN** コマンドは実行されず、secret-guard の拒否の理由がエージェントに返る

#### Scenario: Bash と Read 以外では発火しない

- **WHEN** hooks.json の secret-guard の matcher を `Bash`、`Read`、`Grep`、`mcp__claude-in-chrome__navigate` に当てる
- **THEN** `Bash` と `Read` にだけ一致する

#### Scenario: 手で配線した hook と同時に走っても壊れない

- **WHEN** 同じ入力に、手で配線した旧 hook とプラグインの hook が両方走る
- **THEN** 片方でも拒否すれば実行は止まり、拒否しない入力はどちらも何も出力しない

### Requirement: 値が画面に出る形を止める

hook は次のいずれかに当たる呼び出しに対し、`hookSpecificOutput` の `permissionDecision` が `deny` で、理由に `[secret-guard]` を含む JSON を stdout に出して exit 0 としなければならない（MUST）: 値を標準出力に出すコマンドへのシークレットらしい名前の環境変数の参照／`printenv`／コマンドを伴わない `env`／ファイルを読むコマンドによる機密ファイルの表示／Keychain の値の取り出し（`security find-generic-password` などの `-w` `-g`）／コマンド置換の外での `op read` と `op item get` の `--fields` `--reveal`／機密ファイルの Read。

#### Scenario: Bash の露出が止まる

- **WHEN** `echo "$GH_TOKEN"`、`printf %s ${MY_API_KEY}`、`printenv`、`printenv | wc -l`、`env`、`cat .env`、`cat ~/.npmrc`、`op read op://v/i/f`、`op item get x --fields password`、`security find-generic-password -s x -w` をそれぞれ Bash の payload で渡す
- **THEN** どれも exit 0 で `permissionDecision` が `deny` の JSON が出る

#### Scenario: 機密ファイルの Read が止まる

- **WHEN** `file_path` が `/x/.env`、`/x/.env.local` の Read の payload を渡す
- **THEN** どれも exit 0 で `permissionDecision` が `deny` の JSON が出る

### Requirement: 値が画面に出ない使い方は止めない

hook は、シークレットをコマンド置換で変数に入れて使う形と、値を出さない確かめ方を止めてはならない（MUST NOT）。判定は移す前の hook と同じでなければならない（MUST）。止めないときは何も出力せず exit 0 とする。

#### Scenario: コマンド置換での利用は止まらない

- **WHEN** `GH_TOKEN="$(get-token github)" gh api /user`、`GH_TOKEN="$(op read op://v/i/f)" gh api /user` を Bash の payload で渡す
- **THEN** どれも exit 0 で何も出力しない

#### Scenario: 値を出さない確かめ方とテンプレートは止まらない

- **WHEN** `echo "${GH_TOKEN:+SET}"`、`echo "${#GH_TOKEN}"`、`cat .env.example`、`env FOO=1 ls`、`echo "--- .env:"`、`echo hi > .env`、`ls` を Bash の payload で渡し、`file_path` が `/x/.env.example`、`/x/README.md` の Read の payload を渡す
- **THEN** どれも exit 0 で何も出力しない

### Requirement: 壊れたときと無効化のときは素通りする

hook は fail-open でなければならない（MUST）。python3 が無い・stdin が JSON として読めない・検査が例外で落ちるときは、呼び出しを止めてはならない（MUST NOT）。環境変数 `CAPABILITY_REGISTRY_SECRET_GUARD` が `off` のときは、検査せずに通さなければならない（MUST）。ガードのバグで全作業が止まるほうが害が大きいため。

#### Scenario: 読めない入力は通す

- **WHEN** 空の stdin、または JSON でない stdin を渡す
- **THEN** exit 0 で stdout に何も出力しない

#### Scenario: python3 が無ければ通す

- **WHEN** `PATH` に python3 が無い状態で、`echo "$GH_TOKEN"` の Bash の payload を渡す
- **THEN** exit 0 で stdout に何も出力しない

#### Scenario: 無効化のスイッチで止まらなくなる

- **WHEN** `CAPABILITY_REGISTRY_SECRET_GUARD=off` のとき、`echo "$GH_TOKEN"` の Bash の payload を渡す
- **THEN** exit 0 で stdout に何も出力しない

### Requirement: 配布物に個人の固有記述を含めない

secret-guard のスクリプトと hook の出力は、個人の道具の名前（`fmtoken`）・個人のパス（`op-sa` など）・個人の経緯を含んではならない（MUST NOT）。拒否の理由に添える案内は、特定の取得ツールを名指しせず、コマンド置換で変数に入れる形と `:+` で存在を確かめる形を示さなければならない（MUST）。hook の python3 は `-I` で起動しなければならない（MUST。作業ディレクトリや `PYTHONPATH` の偽のモジュールを読まないため）。

#### Scenario: 個人の道具を名指ししない

- **WHEN** secret-guard のスクリプトの本文と、拒否の JSON の出力を検査する
- **THEN** `fmtoken` と `op-sa` の文字列は含まれない

#### Scenario: 拒否の理由が代わりの書き方を示す

- **WHEN** `echo "$GH_TOKEN"` の拒否の理由を読む
- **THEN** コマンド置換で変数に入れる形と `${VAR:+SET}` の形が書かれている

#### Scenario: 偽のモジュールを読まない

- **WHEN** 偽の `json.py` と `re.py` を置いたディレクトリをカレントと `PYTHONPATH` にして hook を実行する
- **THEN** 偽のモジュールは読まれず、出力は通常の環境と同じである

### Requirement: 配線場所の文書がプラグイン側を指す

`plugins/casting/catalog/injection.md` の secret-guard の配線の記述は、capability-registry プラグインの hook を指さなければならない（MUST）。`~/.claude/settings.json` と `~/.claude/hooks/secret-guard.py` を配線場所として書いてはならない（MUST NOT）。README は secret-guard が capability-registry を入れると入ることを案内しなければならない（MUST）。手で配線した環境から外す手順は、`plugins/capability-registry/changes/1233.md` に書かなければならない（MUST）。

#### Scenario: 注入マップの配線先

- **WHEN** `plugins/casting/catalog/injection.md` の secret-guard の行を読む
- **THEN** `plugins/capability-registry/` の hook を指し、`~/.claude/hooks/secret-guard.py` の記述が無い

#### Scenario: 手の配線を外す手順

- **WHEN** `plugins/capability-registry/changes/1233.md` を読む
- **THEN** `settings.json` の PreToolUse から secret-guard のエントリを外す手順と、外す時期が書かれている
