## 1. テスト先行（Red）

- [x] 1.1 スタブ `op` を argv ログと stdin ログの 2 本に分け、「値が argv に現れず stdin の JSON にのみ現れる」
  「特殊文字（`"` `\` 改行 `$` `'` タブ）入りの値が完全一致で通る」「category / credential フィールドが現行互換」の
  3 ケースを追加。現行実装で Red を確認する
- [x] 1.2 既存のアイテム名アサート（argv ログの grep）を stdin の JSON から `title` を読む形へ置き換える

## 2. 実装（Green）

- [x] 2.1 `fmtoken.sh` の `op item create` を JSON テンプレートの stdin 渡しに置換する
  （`printf` → `python3` → `op item create --vault agents -` の 3 段パイプ。フォールバックは書かない）
- [x] 2.2 `--register` 系 bats 全件 green を確認する（exit 43/46/47 の既存経路を含む）

## 3. 追随

- [x] 3.1 `fmtoken.sh` のヘッダコメントに「`op` へも JSON を stdin で渡す」を追記する
  （将来の改修者が assignment statement に戻さないように）
- [x] 3.2 `1password.md` の登録経路の記述を実装に一致させる
- [x] 3.3 `plugin.json` / `marketplace.json` の version を 1.7.1 に上げる
- [x] 3.4 `openspec validate fmtoken-register-argv-leak --strict` と `scripts/lint.sh` を通し、archive して PR に含める
