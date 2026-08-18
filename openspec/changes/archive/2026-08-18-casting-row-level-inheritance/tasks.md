## 1. テスト先行（Red）

- [x] 1.1 `tests/casting-resolve.bats` を新設: ①カタログのみ（全行がカタログ既定由来）②project で1行上書き③local でさらに別の1行上書き、の3フィクスチャで合成結果と由来列を検証（Red 確認）
- [x] 1.2 `tests/casting-set.bats` を新設: ①owner の行単位書き換え＋変更記録追記②存在しない観点名エラー③--why 欠落エラー④replace-catalog の version 非増加拒否⑤registry の継承中／上書き中一覧⑥台帳内の存在しないパスのスキップ警告、を一時カタログ（--catalog）と `CASTING_REGISTRY` 差し替えで検証（Red 確認）
- [x] 1.3 `tests/casting-init.bats` に registry 冪等追記のケースを追加、既存の「project.md が雛形と一致」検証を差分方式テンプレ前提に更新（Red 確認）

## 2. 実装（Green）

- [x] 2.1 `templates/project.md` を差分方式に書き換え: catalog_version front matter＋「変えたい観点の行だけ書く。書いていない観点はカタログを踏襲する」の説明＋5列ヘッダのみの空表＋記入例コメント
- [x] 2.2 `scripts/casting-check.sh` に `resolve` サブコマンドを実装（catalog/project/local の行単位合成＋由来列。パース部品は既存関数を共用）
- [x] 2.3 `scripts/casting-set.sh` を新設（owner / replace-catalog、変更記録自動追記、`CASTING_REGISTRY`（既定 `~/.claude/casting/registry.txt`）走査の影響一覧。LC_ALL=C grep -F 照合・awk 文字列比較禁止）
- [x] 2.4 `commands/init.md` の生成スクリプトに registry 冪等追記を追加
- [x] 2.5 `skills/casting/SKILL.md` を更新: 行単位解決規則（強い順・行を書くなら5列）・casting-set.sh 経由の変更手続き・resolve の使い方・フィードバック動線（主のチャンネル発言→そのターンで該当行更新＋判例記録）
- [x] 2.6 `rules/perspective-casting.md` にフィードバック規則を追記（30行以内維持）
- [x] 2.7 `catalog/catalog.md` の変更手続き節に「書き込みは casting-set.sh 経由・継承中の全プロジェクトに自動で効く」を追記
- [x] 2.8 bats を実行して Green を確認する（exit code を表示）

## 3. 整合

- [x] 3.1 既存フィクスチャ（ok / tight-pipes 等の project.md）が差分方式でも意味が通るか確認し、必要なら調整する
- [x] 3.2 `openspec validate casting-row-level-inheritance` を通す
- [x] 3.3 `bats plugins/casting/tests/` 全体を実行して全 green（exit code 表示）

## 4. 検証（親セッションが実施）

- [x] 4.1 issue #114 の受け入れ条件を1件ずつ突き合わせて確認する
