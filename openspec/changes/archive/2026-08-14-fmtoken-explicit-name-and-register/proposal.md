# Proposal: fmtoken-explicit-name-and-register

## Why

`1password.md` は「アイテム登録は人間が 1Password アプリで行う（ブラウザ・CLI とも不可の運用）」
を前提に書かれていたが、実運用は既に CLI 代行に移っている（#49 / #58 の `claude-agents-rw` SA に
よる登録、2026-07-30 の moko `moko--TRELLO_TOKEN` 登録）。主の判断（2026-07-30）も
「CLI 登録は可能なままにする — 人間の手作業登録こそ命名規約違反のリスク源」で確定している。

さらに fmtoken.sh は git remote からプロジェクト名を導出する設計のため、エージェント名接頭辞の
アイテム（`<agent>--<SERVICE>`、例: `moko--TRELLO_TOKEN`）はプロジェクト導出では引けない
（flatmate 住人は全員 `flatmate` に解決される）。明示名で参照・登録できる経路が無く、
各所（flatmate `scripts/trello.sh` のトークン解決ブロック等）が生の `op read` を手書きしていた。

oratta/claude-harness#63 の受け入れ条件（agent-proposed triage 済み）に対応する。
issue の「発展」セクション（human tier への投函専用チャネル・create-only SA の検証/発行）は
人間側の意思決定を要するためスコープ外。

## What Changes

- `scripts/fmtoken.sh` に 2 経路を追加:
  - `--name <item>`: 明示名参照（プロジェクト導出をスキップ。origin remote 不要。`--check` 併用可）
  - `--register <item>`: 登録。値は stdin 渡し（transcript / ps への露出防止）、
    書き込み用 SA（env `OP_SERVICE_ACCOUNT_TOKEN_RW` → 600 ファイル `claude-agents-rw.token` →
    Keychain `op-sa-claude-agents-rw` の順。環境の ro トークンは流用しない）、
    命名規約 `<prefix>--<service>` の機械検証（exit 46）、既存アイテムの上書き拒否（exit 47）
- `1password.md` の「アイテム登録」節を改訂: read = `op-sa-claude-agents-ro` /
  register = `op-sa-claude-agents-rw` の役割分担を正規手順として明記し、
  「人間セッション代行のみ」を正規手順とする記述を撤去
- `SKILL.md` の原則・索引表（1Password 行）・資格情報の階層表を同期（exit 44 時の第一選択を
  「値が手元にあれば自己登録」に変更）
- `tests/fmtoken.bats` に `<project>--<service>` / `<agent>--<SERVICE>` 両命名規約の
  参照・登録テストを追加（op スタブに `item create` を追加）
- plugin.json 1.6.0 → 1.7.0 / SKILL.md frontmatter / marketplace.json を同時 bump

## Capabilities

capability-registry-fmtoken
