## Why

secret-guard の Read の判定は、パス全体に機密らしい語（`.env`、`credential(s)`、`.token` など）があるかを見る。そのため `credentials-service/` や `.env/`（Python の仮想環境などのディレクトリ名）の下にあるふつうのソースファイルまで Read できず、抜ける手段は hook 全体を止める環境変数しかない。Read で中身が transcript に載る危険があるのは、そのファイル自体が機密のときであって、親ディレクトリの名前ではない。

## What Changes

- Read の判定対象を、パス全体から最後の要素（ファイル名）に絞る。ファイル名に当てる語の一覧と、テンプレート類（`.env.example` など）を通す規則は変えない
- `/x/credentials-service/src/index.ts` と `/x/.env/lib/site.py` は止まらなくなる
- `.env`、`credentials.json`、`*.token` の Read は止まり続ける
- ファイル名自体に機密らしい語を含むもの（`/x/docs/credential-guide.md`、`/x/process.env.ts`、`/x/credentials.ts`）は止まり続ける。ファイル名だけでは値を含むかどうかを区別できず、既知の止めすぎとして残す。誤検知の逃げ道は従来どおり無効化の環境変数
- パスの末尾の `/` は取り除いてから判定する（`/x/.env/` も止まる）
- 機密らしい語がディレクトリ名にだけあるファイル（`/x/config/credentials/production.key`、`/x/service-account/prod.json`、`/x/.env/prod`）の Read は通るようになる。抜け道が増えることは受け入れる
- Bash の機密ファイル表示（`cat <path>` など）の判定は変えない。Read だけを絞る

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `capability-registry-secret-guard`: 要件「検査の守備範囲」（通すことを許す一覧に、機密らしい語がディレクトリ名にだけあるファイルの Read を足す。値が出る抜け道が増えることを受け入れる）、要件「値が画面に出ない使い方は止めない」（「判定は移す前の hook と同じ」の例外に Read の判定対象の絞り込みを加える）と、要件「止めすぎる向きの既知の挙動を変えない」（パス全体の判定による止めすぎを外し、ファイル名による止めすぎを残す）

## Impact

- `plugins/capability-registry/scripts/secret-guard.py`（`check_read`）
- `plugins/capability-registry/tests/secret-guard.bats`
- `openspec/specs/capability-registry-secret-guard/spec.md`（archive 時に反映）
- `plugins/capability-registry/changes/1488.md`（変更の記録）
- `~/.claude/settings.json` に手配線の旧 secret-guard が残る環境では、旧 hook がパス全体で判定するので効果が出ない（片方でも拒否すれば止まる）。動作確認は `claude -p --setting-sources project --plugin-dir <パス>` で行う
