# Proposal: capability-registry-plugin

## Why

エージェントが外部サービスを操作するとき、CLI を使う意思があっても「(1) その CLI の存在・認証状態が分からない」「(2) トークンの在処が分からない」の 2 つのハードルで諦め、ブラウザを開いて「ログインしてください」と人間に依頼してしまう。これがトークン浪費と手間の元凶になっている。(2) は flatmate 側で 1Password vault `agents` + read-only Service Account + `fmtoken.sh` により解決済み（flatmate コミット 29ceb6a）。残る (1) の発見層を担うプラグインを新設する（issue #43）。

## What Changes

- 新プラグイン `plugins/capability-registry/` を新設する
  - **発見層（ソフトトリガー）**: `skills/capability-registry/SKILL.md` にサービス索引（1 サービス 1 行: CLI 名 / 認証確認コマンド / トークン取得 / ブラウザ必須の例外操作）を置き、詳細はサービス別ファイル（`<service>.md`）に遅延ロードする。トリガー文言は「外部サービスを操作する前に」とし、description 自体をトリガー文にする（スキルの name+description は全セッションに自動注入されるため、CLAUDE.md への追記が不要になる）
  - **「CLI が無い」ネガティブエントリ**も索引に記載する（無いものを探し回るコストが最も高いため）
  - **トークン取得ラッパー**: `scripts/fmtoken.sh` を flatmate から移設する（全プロジェクト共通の道具のため）。`${CLAUDE_PLUGIN_ROOT}` 参照で動作し、Keychain `op-sa-claude-agents-ro` または 600 権限ファイルから SA トークンを取得する
  - **強制層（ハードトリガー）**: PreToolUse hook で `mcp__claude-in-chrome__*` 等のブラウザツール呼び出しをマッチし、「CLI で不可能な理由」の明示を促す（deny ではなく注意喚起から始める）。プラグイン同梱 hooks はインストールだけで有効になる
- `.claude-plugin/marketplace.json` に capability-registry を登録する
- レジストリ初期エントリは実際に使った実績のあるサービスのみ: 1Password(op) / GitHub(gh) / Supabase / Vercel / Stripe

## Capabilities

### New Capabilities

- `capability-registry-skill`: 発見層。外部サービス操作前に発火するスキル索引（description トリガー、1 画面以内の索引、サービス別詳細への遅延ロード、ネガティブエントリ、CLAUDE.md 無編集で発火）
- `capability-registry-fmtoken`: トークン取得ラッパー。fmtoken.sh がプラグイン内から動く（プロジェクト名の機械導出・正規化、SA トークンの env → Keychain → 600 ファイルのフォールバック、未登録時 exit 44 で登録依頼を返す）
- `capability-registry-browser-guard`: 強制層。ブラウザツールの PreToolUse hook が CLI 代替の検討を促す（注意喚起モード、インストールだけで有効）

### Modified Capabilities

（なし — 既存 capability の要件変更はない）

## Impact

- 追加: `plugins/capability-registry/`（plugin.json / skills / scripts / hooks / tests）
- 変更: `.claude-plugin/marketplace.json`（プラグイン登録、version bump）
- リポ外の後続作業: flatmate 側 `scripts/fmtoken.sh` の扱い（削除 or プラグインへの参照置換）を決めて flatmate リポに反映する。本 change では方針決定と記録まで
- 前提: 1Password の SA トークンが Keychain `op-sa-claude-agents-ro` か `~/.config/op-sa/claude-agents-ro.token` に配布済みのマシンで動作する
