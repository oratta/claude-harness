# legacy-command-removal — status/decisions 系コマンドの削除と orchestrator 解体

## ADDED Requirements

### Requirement: status / decisions 系コマンドを削除し残存参照をゼロにする
`/longrun:status` `/longrun:decisions` `/lr:s` `/lr:d` を削除しなければならない（MUST）。削除対象ファイルは `plugins/longrun/commands/status.md`、`plugins/longrun/commands/decisions.md`、`plugins/lr/commands/s.md`、`plugins/lr/commands/d.md` である。あわせて `plugins/longrun/` と `plugins/lr/` 配下の全 plugin.json / README / commands/*.md（exec.md 末尾の「実行中の進捗確認」セクション含む）、およびリポジトリ直下 `.claude-plugin/marketplace.json`（lr / longrun の description 文字列）から残存参照を全て排除しなければならない（MUST）。旧 checkpoint.md 形式の互換読み取りは提供しない。進捗確認の代替はネイティブの `/workflows` ライブビューとする。

#### Scenario: コマンドファイル 4 本が存在しない
- **WHEN** 書き換え後のリポジトリを検査する
- **THEN** `plugins/longrun/commands/status.md`、`plugins/longrun/commands/decisions.md`、`plugins/lr/commands/s.md`、`plugins/lr/commands/d.md` が存在しない

#### Scenario: grep で残存参照が 0 件である
- **WHEN** `plugins/longrun/`・`plugins/lr/` 配下の全 plugin.json / README / commands/*.md と `.claude-plugin/marketplace.json` に対して `/longrun:status` `/longrun:decisions` `/lr:s` `/lr:d`（および status.md / decisions.md / s.md / d.md へのパス参照）を grep する
- **THEN** ヒットが 0 件である（`plugins/lr/.claude-plugin/plugin.json` の commands[] エントリと description 内の `/lr:s, /lr:d` 文字列、marketplace.json の lr description 内の同文字列、`plugins/longrun/README.md` のコマンド表、exec.md 末尾の進捗確認セクションが全て除去されている）

### Requirement: longrun-orchestrator スキルを解体する
`plugins/longrun/skills/longrun-orchestrator/` を削除し、Workflow スクリプト生成ロジックは exec コマンド + 同梱スクリプトテンプレートへ移管しなければならない（MUST）。これにより backlog の Skill 命名規則リファクタリング（-er / -or 終わりの動作主体名の廃止）のうち orchestrator 分を消化する。新設するスキル・テンプレートに -er / -or 終わりの命名を導入してはならない（MUST NOT）。

#### Scenario: orchestrator スキルが存在せずロジックが移管されている
- **WHEN** 書き換え後のリポジトリを検査する
- **THEN** `plugins/longrun/skills/longrun-orchestrator/` が存在せず、`plugins/longrun/.claude-plugin/plugin.json` の skills[] からも除去されている
- **THEN** Review → Build → Verify のオーケストレーションは exec.md とスクリプトテンプレートで完結している

#### Scenario: 命名規則リファクタが backlog から消化される
- **WHEN** 解体完了後に backlog（Skill 命名規則リファクタリング）を確認する
- **THEN** orchestrator 分の項目が消し込まれている

### Requirement: バージョンを両プラグインで同期して BREAKING bump する
longrun は着手時点の現行 version を起点に 6.0.0 へ、lr は 5.1.1 → 6.0.0 に bump しなければならない（MUST）（longrun の起点は change-1 マージ済みなら 5.3.0、未マージなら現行値。最終的に 6.0.0 に揃える）。各プラグインについて plugin.json と marketplace.json plugins[] の 2 箇所でバージョンが一致していなければならない（MUST）。marketplace.json の top-level version はマーケットプレイス全体のものであり、bump 要否は別途判断とする。

#### Scenario: longrun と lr の version 同期が取れている
- **WHEN** `plugins/longrun/.claude-plugin/plugin.json`、`plugins/lr/.claude-plugin/plugin.json`、`.claude-plugin/marketplace.json` の plugins[]（longrun / lr エントリ）を比較する
- **THEN** longrun は全箇所 6.0.0、lr は全箇所 6.0.0 で一致している（lr の bump 漏れがない）
- **THEN** 全 JSON が `jq .` の構文検証を通る
