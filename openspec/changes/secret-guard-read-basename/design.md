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
3. **SAFE_FILE もファイル名に当てる。** 副作用として、パスの途中に `example`/`template` を含む `.env`（例: `/x/foo.template/.env`）が、今まではパス全体に SAFE が当たって通っていたのが、止まるようになる。止める向きの変化で、機密を通すよりは安全側。仕様のシナリオで固定する。
4. **末尾が `/` のパスなど、ファイル名が空になる入力は通す。** Read の対象はファイルなので、ファイル名が空なら判定する物がない（fail-open の方針と同じ向き）。

## Risks / Trade-offs

- `~/.aws/credentials`（ファイル名が `credentials`）や `~/.ssh/id_rsa` は止まり続けるが、機密ディレクトリ配下の別名ファイル（`~/.aws/config` など）はもとから止まらず、変わらない
- パスの途中のディレクトリ名が機密を示すことに頼っていた判定（`/x/.env/` の下に実際に機密を置いている場合など）は外れる。検査はセキュリティ境界ではなく（要件「検査の守備範囲」）、機密はファイル名で表すのが通例なので許容する
