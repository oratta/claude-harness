# Design: capability-registry-plugin

## Context

エージェントは外部サービス操作時に CLI の存在・認証状態・トークンの在処が分からず、ブラウザ操作と人間へのログイン依頼に流れてしまう。トークンの在処問題は flatmate の `fmtoken.sh`（1Password vault `agents` + read-only SA）で解決済み。本プラグインは残る「発見層」を担い、あわせて fmtoken.sh を全プロジェクト共通の道具としてプラグインに移設する。

このリポの既存プラグイン規約: plugin.json は `plugins/<name>/.claude-plugin/plugin.json`、hooks は `plugins/<name>/hooks/hooks.json`、テストは `plugins/<name>/tests/*.bats`（bats）、hook スクリプトは fail-soft（欠損時は無出力 exit 0）。

## Goals / Non-Goals

**Goals:**
- インストールだけで発火する（CLAUDE.md・settings.json の追加編集ゼロ）
- ソフトトリガー（スキル description）とハードトリガー（PreToolUse hook）の 2 層
- fmtoken.sh をプラグイン内で完結して動かす（`${CLAUDE_PLUGIN_ROOT}` 参照）
- 「CLI が無い」ネガティブエントリを一級情報として持つ

**Non-Goals:**
- ブラウザツールの deny（拒否）はしない。注意喚起（コンテキスト注入)まで
- 全サービスの網羅。実績のあるサービスのみ登録し、育てる運用
- flatmate リポ側の変更（方針決定と記録のみ。実作業は flatmate 側の後続 issue）
- SA トークンの配布・登録の自動化（登録は人間が 1Password アプリで行う）

## Decisions

### D1: hook は PreToolUse + `permissionDecision: "allow"` + `additionalContext` で注意喚起する
- 採用: hook スクリプトは JSON `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "additionalContext": "<注意喚起>"}}` を返す。ツール実行は止めず、Claude のコンテキストに「CLI 代替を検討したか」を注入する。
- 代替案と不採用理由:
  - exit 2（ブロック + stderr を Claude に返す）: 実質 deny。正当なブラウザ操作（レジストリの例外操作）まで止まり、リトライの往復でかえってトークンを浪費する。issue の「deny ではなく注意喚起から始める」に反する。
  - `permissionDecision: "ask"`: 人間の応答待ちが発生し、無人ループで詰まる。
- 昇格パス: 注意喚起で破られ続ける実績が溜まったら、matcher 単位で deny に強化する余地を hooks.json の構造として残す（スクリプトの出力を変えるだけで済む設計）。

### D2: 注意喚起はセッションごとに初回のみ注入する
- 採用: hook 入力 JSON の `session_id` をキーに `${TMPDIR:-/tmp}/capability-registry-warned-<session_id>` マーカーを置き、同一セッション 2 回目以降は無出力 exit 0。
- 理由: 正当なブラウザ作業は 1 タスクで数十回ツールを呼ぶ。毎回注入するとノイズとトークン浪費で本末転倒。判断が必要なのは「ブラウザに行くと決めた最初の瞬間」だけ。
- マーカーが書けない環境でも fail-soft（注入を諦めて exit 0）とし、ツール実行を絶対にブロックしない。

### D3: matcher はブラウザ系 MCP ツールに限定する
- 採用: `mcp__claude-in-chrome__.*|mcp__playwright__.*` を hooks.json の matcher に置く（正規表現マッチ）。
- 理由: Bash 内の `open <url>` 等まで追うのは誤検知が多く、強制層の信頼を損なう。ハードトリガーは「機械的に確実に分かる範囲」に絞り、残りはソフトトリガー（スキル）が拾う。

### D4: fmtoken.sh は flatmate 版（fb21df1）をそのまま移設し、flatmate 側は削除する方針
- 採用: スクリプトは cwd 基準で動く自己完結設計（`git rev-parse --show-toplevel`）のため、無改変で移設できる。issue 記載の 29ceb6a 以後に fb21df1（600 権限ファイルのフォールバック）が入っており、これを含む最新版を正とする。
- 実装時の逸脱（記録）: exit 43 メッセージ内の `$TOKEN_FILE` を `${TOKEN_FILE}` にブレース化する 1 行のみ修正した。全角括弧が直後に続くと bash が変数名を誤パースして `set -u` で落ちる潜在バグで、テストで顕在化した。挙動は同等。flatmate 側の扱いは genetta-inc/flatmate#126 に起票済み。
- flatmate 側の扱い: プラグイン版を single source of truth とし、flatmate の `scripts/fmtoken.sh` は削除して flatmate 側ドキュメントからプラグインパス（`~/.claude/plugins/cache/oratta-claude-harness/capability-registry/<ver>/scripts/fmtoken.sh` またはインストール済みスキル経由）を参照する。実作業は flatmate リポの後続 issue として起票する（本リポの change には含めない）。

### D5: 索引 SKILL.md + サービス別ファイルの遅延ロード
- 採用: SKILL.md は frontmatter（description = トリガー文）+ 1 サービス 1 行の索引表 + ネガティブエントリ節のみで約 50 行以内。詳細（セットアップ、例外操作の具体例、運用知見）は `skills/capability-registry/<service>.md` に置き、索引から名前参照する。
- 理由: name+description は全セッション常駐のため索引本体はロードされない。スキル発火時も 1 画面で判断できるサイズを守り、深掘りが要る時だけサービス別ファイルを読ませる。

### D6: テストは bats で決定的に書く（op 非依存）
- 採用: dev-workflow の tests/*.bats に倣う。fmtoken.sh のテストは `op` をスタブ（PATH 先頭に偽 op を置く）して正規化・フォールバック順・exit 43/44 を検証。hook テストは JSON を stdin 投入して出力形状とセッション重複抑止を検証。スキルテストは frontmatter のトリガー文言・索引行数・ネガティブエントリ・初期エントリの存在を検証。marketplace.json への登録もテストする。
- 理由: 1Password 実環境に依存するテストは CI で回らない。受け入れ条件のうち機械検証可能な部分をすべて bats に落とす。

## Risks / Trade-offs

- [PreToolUse の `additionalContext` が古い Claude Code で未対応] → JSON 全体が無視されてもツール実行は通る（fail-open）。注意喚起が出ないだけで害はない
- [`<project>--<service>` 命名: issue 本文の「ENV変数名」と実装の service 名が揺れる] → 実装（fb21df1）の `<project>--<service>` を正とし、SKILL.md の索引に各サービスの正しい引き方（例: `fmtoken.sh github`）を明記して揺れを吸収する
- [プラグイン更新でキャッシュパスが変わり fmtoken.sh の絶対パスが陳腐化] → ドキュメントでは `${CLAUDE_PLUGIN_ROOT}` 経由の参照を正とし、絶対パスを書かない
- [注意喚起が常態化して無視される（お願いベース回帰）] → マーカー方式で希少性を保つ + 将来 deny への昇格余地を D1 に残す

## Open Questions

（なし — flatmate 側の実作業は後続 issue として切り出すことで本 change から除外済み）
