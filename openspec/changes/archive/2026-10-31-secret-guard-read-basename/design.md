## Context

`check_read` は `SECRET_FILE.search(path)` と `SAFE_FILE.search(path)` をパス全体に当てている。#1233 で移したときは移す前の hook と同じ判定に固定したため、親ディレクトリ名でも止まる。

## Goals / Non-Goals

**Goals**
- 親ディレクトリの名前だけで Read が止まらないようにする
- ファイル名が機密の形のものは今までどおり止める

**Non-Goals**
- Bash の機密ファイル表示（`cat <path>`）の判定。`cat /x/credentials-service/a.ts` のようなものは止まり続ける。Read だけの変更に閉じる
- ファイル名に語を含む非機密ファイル（`credential-guide.md`、`process.env.ts`）を通すこと。区別には中身か拡張子の許可リストが要り、規模が合わない

## Decisions

1. **判定対象はパスの最後の要素（`os.path.basename` 相当）にする。** 当てる正規表現（`SECRET_FILE`）と通す正規表現（`SAFE_FILE`）は変えない。変えるのは入力だけなので、`.env`・`.env.local`・`credentials.json`・`a.token`・`.npmrc`・`id_rsa` などファイル名が機密の形のものは同じ結果になる。
   - 代案: 正規表現をファイル名向けに書き直し、`credential-guide.md` なども通す。却下: 設計判断が増え、止めすぎの縮小が目的の範囲を超える。
2. **ファイル名に機密らしい語を含むものは止め続ける。** `/x/docs/credential-guide.md`（`credential` で止まる）、`/x/process.env.ts`（`.env` で止まる）、`/x/credentials.ts`（現行の既知の挙動）。受け入れ条件に載っていないため、この change では通さないと決める。誤検知は、拒否の理由が案内する無効化の環境変数で逃げる。
3. **SAFE_FILE もファイル名に当てる。** 副作用として、パスの途中に `example`/`template`/`dist` を含む機密の形のファイル（`/x/foo.template/.env`、`/x/foo.template/credentials.json`、`/x/app.dist/.env.production` など）が、今まではパス全体に SAFE が当たって通っていたのが、止まるようになる。止める向きの変化で、機密を通すよりは安全側。仕様のシナリオで固定する。
4. **パスを字句として正規化（`os.path.normpath`）してからファイル名を取り出す。** Read は `.env/`・`.env/.`・`.env/foo/..` のようなパスでもファイルを読み、hook にも付いたまま渡る（レビューと本体の実測）。末尾の `/` を取り除くだけでは最後の要素が `.` や `..` になって判定を通ってしまう。正規化の結果のファイル名が空・`.`・`..`（`/`、空文字列など）のときは判定する物が無いので通す。`/x/.env/../site.py` は `site.py` になって通り、`/x/ok/../.env` は `.env` になって止まる。`/x/credentials-service/` は止まるが、今も止まっている入力で、Read はディレクトリを読めないので失うものは無い。シンボリックリンクは解かない（字句の正規化だけ）。

## Risks / Trade-offs

- `~/.aws/credentials`（ファイル名が `credentials`）や `~/.ssh/id_rsa` は止まり続けるが、機密ディレクトリ配下の別名ファイル（`~/.aws/config` など）はもとから止まらず、変わらない
- パスの途中のディレクトリ名だけに頼っていた判定は外れ、値が画面に出る抜け道が増える。実例: `/x/config/credentials/production.key`、`legacy_credentials/<account>/adc.json`、`~/.credentials/calendar.json`、`/x/service-account/prod.json`（`service[-_]account[^\s]*\.json` の `[^\s]*` が `/` をまたいで当たっていた）、`/x/.env/prod`、`/x/.env.d/db`。検査はセキュリティ境界ではなく（要件「検査の守備範囲」）、issue の目的は親ディレクトリ名による止めすぎをなくすことなので受け入れ、要件「検査の守備範囲」の通すことを許す一覧に足した。特定のディレクトリ名を判定に足して塞ぐことはしない（穴を塞ぎ切らない方針）
- Read より Bash が緩い場合もあれば、厳しい場合もある。Bash 側は変えないので、`cat /x/config/credentials/production.key` は Bash で止まり Read では通る（Bash で拒否されたエージェントが Read に切り替えると値が出る。上の抜け道に含まれる）。逆に `cat /x/foo.template/.env` は Bash で通り Read では止まる
