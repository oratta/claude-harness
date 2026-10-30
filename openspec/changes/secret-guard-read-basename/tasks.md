## 1. 判定の変更

- [ ] 1.1 `check_read` の `SECRET_FILE` / `SAFE_FILE` の入力を、パスの最後の要素に変える。ファイル名が空なら何もしない。拒否の理由に引用するのは従来どおりパス全体。触る範囲: plugins/capability-registry/scripts/secret-guard.py:175-181（`check_read`）。モジュール docstring（同:1-18）と `SECRET_FILE` のコメント（同:30）に Read はファイル名で判定すると一言足す

## 2. テスト

- [ ] 2.1 bats に追加・変更: `/x/credentials-service/src/index.ts` と `/x/.env/lib/site.py` は通る（今 `assert_denied` になっている 180 行目は `assert_passed` に移す）。`/x/.env`・`/x/credentials.json`・`/x/a.token`・`/x/docs/credential-guide.md`・`/x/process.env.ts`・`/x/credentials.ts`・`/x/foo.template/.env` は止まる。`/x/credentials-service/` は通る。触る範囲: plugins/capability-registry/tests/secret-guard.bats:132-135、175-181、247-255

## 3. 仕様と記録

- [ ] 3.1 archive で `openspec/specs/capability-registry-secret-guard/spec.md` に反映し、`openspec validate capability-registry-secret-guard --type spec --strict` が exit 0 になることを確かめる。触る範囲: openspec/specs/capability-registry-secret-guard/spec.md（archive が書く）
- [ ] 3.2 変更の記録 `plugins/capability-registry/changes/1488.md` を書く: Read がファイル名判定になったこと、止まり続けるもの（`credential-guide.md`、`process.env.ts`、`credentials.ts`）とその理由、パスの途中に `template` 等を含む `.env` が止まるようになったこと、Bash 側は変えていないこと。触る範囲: plugins/capability-registry/changes/1488.md（新規）
