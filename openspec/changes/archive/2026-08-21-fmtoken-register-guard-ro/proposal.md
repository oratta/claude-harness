## Why

`fmtoken.sh --register` の二重登録ガード（`plugins/capability-registry/scripts/fmtoken.sh:115-118`）は、
**rw トークンに差し替えた後に `op read` を試す**ことで「既に登録済みか」を判定している。
`claude-agents-rw` SA に read 権が無い構成では、この判定が常に「未登録」側に倒れ（fail-open）、
1Password は同名アイテムの作成を許すため `--register` を 2 回叩くと重複アイテムができ、
以後の title 参照の解決が曖昧になる（oratta/claude-harness#131、PR #106 レビューの follow-up）。

issue 本文は「rw SA の read 権を実機で一度確認する」を先頭に置くが、ガードを
**read 権の有無に依存しない形**に直せば確認の答えがどちらでも同じ実装が正解になるため、
実機確認（Keychain の生体認証を要する＝人間の手が要る）を前提から外す。

## What Changes

- **二重登録の判定を読み取り用 SA（claude-agents-ro）に寄せる**: ro SA はこのスクリプトの
  読み取り経路全体が依存している＝定義上 read 可能。判定に rw SA の read 権を使わない
- **判定は title 完全一致**（`op item list --vault agents --format json`）: `credential` フィールドの
  有無に依存しない（フィールド欠落アイテムを「未登録」と誤判定して同名重複を作らないため）
- **判定不能時は fail-closed**: ro トークンが解決できない・`op item list` が失敗した場合は
  `op item create` を呼ばずに exit 48 で終了し、stderr に「ro トークンをこのマシンに配布する」か
  「rw SA に read 権を付ける」かの選択肢を出す（1Password 側の権限変更は人間の GUI 作業）
- **スコープ外**: 実機での「rw SA が agents 保管庫に read 権を持つか」の確認（上の設計で答えが不要になる）と、
  1Password 側の SA 権限変更（Individual プランでは CLI/API から不可）

## Capabilities

### Modified Capabilities

- `capability-registry-fmtoken`: Requirement「登録（--register）は書き込み用 SA 経由で命名規約を機械検証して行う」に
  二重登録判定の SA（ro）・判定方法（title 完全一致）・判定不能時の fail-closed（exit 48）を追加する

## Impact

- `plugins/capability-registry/scripts/fmtoken.sh` — `--register` の存在判定ブロックを ro SA + `op item list` 化。
  `resolve_ro_token` に `--optional`（exit せず非 0 を返す）を追加
- `plugins/capability-registry/tests/fmtoken.bats` — スタブ `op` の `item list` が `FMTOKEN_TEST_REGISTERED` の
  title を返すよう拡張し、`item create` の SA 照合を `FMTOKEN_TEST_EXPECT_SA_CREATE` で経路別化。
  「rw が read できなくても同名 title で exit 47」「同名なしなら create」「ro 未解決で exit 48」
  「item list 失敗で exit 48」の 4 ケースを追加
- `plugins/capability-registry/skills/capability-registry/1password.md` — 二重登録ガードの判定 SA を前提として明記
- `plugins/capability-registry/.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json` — version bump
