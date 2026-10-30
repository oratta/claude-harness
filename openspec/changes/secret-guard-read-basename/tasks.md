## 1. 判定の変更

- [x] 1.1 `check_read` の `SECRET_FILE` / `SAFE_FILE` の入力を、パスの最後の要素に変える。パスの末尾の `/` を取り除いてから最後の要素を取り出し、空（`/` と空文字列だけ）なら何もしない。拒否の理由に引用するのは従来どおりパス全体。触る範囲: plugins/capability-registry/scripts/secret-guard.py:175-181（`check_read`）。モジュール docstring（同:1-18）と `SECRET_FILE` のコメント（同:30）に Read はファイル名で判定すると一言足す

## 2. テスト

- [x] 2.1 bats に追加・変更: `/x/credentials-service/src/index.ts` と `/x/.env/lib/site.py` は通る（今 `assert_denied` になっている 180 行目は `assert_passed` に移す）。`/x/.env`・`/x/credentials.json`・`/x/a.token`・`/x/docs/credential-guide.md`・`/x/process.env.ts`・`/x/credentials.ts`・`/x/foo.template/.env` は止まる。`/x/.env/`・`/x/credentials.json/` は止まる。守備範囲の外として `/x/config/credentials/production.key`・`/x/service-account/prod.json` は通る。触る範囲: plugins/capability-registry/tests/secret-guard.bats:132-135、175-181、247-255

## 3. 仕様と記録

- [x] 3.1 archive で `openspec/specs/capability-registry-secret-guard/spec.md` に反映し、`openspec validate capability-registry-secret-guard --type spec --strict` が exit 0 になることを確かめる。触る範囲: openspec/specs/capability-registry-secret-guard/spec.md（archive が書く）
- [x] 3.2 変更の記録 `plugins/capability-registry/changes/1488.md` を書く: Read がファイル名判定になったこと、止まり続けるもの（`credential-guide.md`、`process.env.ts`、`credentials.ts`）とその理由、パスの途中に `template` 等を含む機密の形のファイル（`.env`、`credentials.json` など）が止まるようになったこと、機密らしい語がディレクトリ名にだけあるファイル（`/x/config/credentials/production.key`、`legacy_credentials/<account>/adc.json`、`~/.credentials/calendar.json`、`/x/service-account/prod.json`、`/x/.env/prod`）の Read が通るようになり抜け道が増えること、`credential-guide.md` / `process.env.ts` の誤検知の逃げ道は無効化の環境変数のままであること、`~/.claude/settings.json` に手配線の旧 hook が残る環境では旧 hook がパス全体で判定するので効果が出ず、確認は `plugins/capability-registry/changes/1233.md` の手順 2 と同じ `claude -p --setting-sources project --plugin-dir <パス>` で行うこと、Bash 側は変えていないこと。触る範囲: plugins/capability-registry/changes/1488.md（新規）
