## Why

`fmtoken.sh --register` は値を stdin で受けるところまでは正しいが、登録本体
（`plugins/capability-registry/scripts/fmtoken.sh:120`）で `op item create ... "credential[password]=${value}"`
と assignment statement に展開しており、**内部で起動する `op` プロセスの実行中は `ps` から値が見える**。
一方 `1password.md` と spec は「ps への露出を防ぐため stdin で受ける」と主張しており、文書の主張が実装で
担保されていない（oratta/claude-harness#130、PR #106 レビューの follow-up）。

実害の上積みはほぼゼロ（`ps` を読める同一ユーザーのローカル攻撃者は 600 権限の SA トークンファイルも読める）。
塞ぐ理由は、**主張が実装で担保されていない状態が将来の誤った安心につながる**ことと、
`op item create --help` 自身が assignment statement による秘密の受け渡しを警告し JSON テンプレートを
推奨していることの 2 点。ベンダー警告に反した形を仕様として固定する（＝文書を実装に合わせて書き下げる）
選択肢は採らない。

## What Changes

- **`op` への値の受け渡しを JSON テンプレートの stdin 渡しに変える**: `op item create --vault agents -`
  が stdin から読む JSON に値を入れ、どのプロセスの argv にも値を載せない。argv に渡すのはアイテム名
  （秘密でない）だけ
- **JSON の組み立ては `/usr/bin/python3`**（`--list` が既に使っている既存依存）。手組みの `printf` は
  値に含まれる `"` `\` 改行でクレデンシャルを黙って壊す
- **値を環境変数で渡さない**: 同一ユーザーからは argv と同程度に見えるため、塞いだことにならない
- **fail-closed を維持**: JSON を組めない・`op` が失敗した場合は非 0 で終了する。assignment statement への
  フォールバックは書かない（例外時にだけ argv 経路が開き、しかも例外時こそ気づかれない）
- **spec の Scenario を argv まで検証範囲に広げる**: 現行 Scenario の THEN は「値は標準出力に現れない」
  までしか見ておらず、argv は検証範囲外だった
- **アイテムの形は現行互換**: category は API Credential（JSON では `API_CREDENTIAL`）、フィールドは
  `credential`。`op://agents/<item>/credential` の参照は変わらない

## Capabilities

### Modified Capabilities

- `capability-registry-fmtoken`: Requirement「登録（--register）は書き込み用 SA 経由で命名規約を機械検証して行う」に
  「値を `op` の argv に載せてはならない」を追加し、Scenario の検証範囲を argv まで広げる

## Impact

- `plugins/capability-registry/scripts/fmtoken.sh` — `--register` の `op item create` 呼び出し 1 行を置換（+ヘッダコメント）
- `plugins/capability-registry/tests/fmtoken.bats` — スタブ `op` が argv と stdin を別ログに記録するよう拡張。
  「値が argv に現れず stdin の JSON にのみ現れる」「特殊文字入りの値が完全一致で通る」「アイテムの形が現行互換」の
  3 ケースを追加。既存のアイテム名アサートは stdin の JSON から `title` を読む形へ変更
- `plugins/capability-registry/skills/capability-registry/1password.md` — 登録経路の記述を実装に一致させる
- `plugins/capability-registry/.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json` — version 1.7.0 → 1.7.1
