# Tasks: loops-integration

## 1. 統合検証テストの作成（RED）

- [x] 1.1 `plugins/loops/tests/integration.bats` を新設し、marketplace 同期テストを書く: (a) `plugins[]` に `name == "loops"` かつ `source == "./plugins/loops"` のエントリが存在、(b) `plugins[]` 全エントリで plugin.json の version と完全一致、(c) marketplace.json と全 plugin.json が `jq .` で parse PASS
- [x] 1.2 README 検証テストを書く: 4 ループタイプの語（ターンベース / ゴールベース / タイムベース / プロアクティブ）・公式記事 URL（https://claude.com/blog/getting-started-with-loops）・`/plugin install loops@oratta-claude-harness`・`plugins/loops/` への参照が README.md に存在し、レシピ固定見出しが README に現れないこと
- [x] 1.3 cost-guardrails 検証テストを書く: `plugins/loops/references/cost-guardrails.md` が存在し、トークン管理項目がちょうど 6 項目数えられ、「頻度」「スクリプト化」「パイロット」「4倍」「15倍」「/usage」「/workflows」がヒットし、`claude-` で始まるモデル ID が 0 件であること
- [x] 1.4 レシピ規約・ランタイム不在の横断検証テストを書く: (a) `plugins/loops/recipes/*.md` 全件が 7 固定見出し（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）を持つ、(b) `grep -L '停止基準'` の出力が空、(c) plugins/loops/ 配下に反復実行を自前実装する常駐スクリプトが 0 件、(d) 全レシピの起動コマンドが /goal・/loop・/schedule・スラッシュコマンドのいずれかで始まる
- [x] 1.5 この時点で `bats plugins/loops/tests/integration.bats` を実行し、未実装項目（cost-guardrails.md 不在・loops 未登録・README 未追記）のテストが FAIL することを確認する（RED 確認）

## 2. cost-guardrails.md の新設

- [x] 2.1 `research/loop-engineering.md` 冒頭の公式記事セクションからトークン管理 6 項目の文言を転記・確定する（頻度最小化・決定論部分のスクリプト化・パイロット実行を含む）
- [x] 2.2 `plugins/loops/references/cost-guardrails.md` を作成する: 6 項目（番号付きで数えられる形式）+ コスト定量事実（ループ≒チャットの約 4 倍・マルチエージェント≒約 15 倍）+ `/usage`・`/workflows` によるコストレビュー手順（確認タイミング付き）。モデル ID は書かない（必要なら `plugins/longrun/references/model-tiers.md` を参照）
- [x] 2.3 タスク 1.3 のテストが PASS することを確認する（GREEN）

## 3. README への位置づけ追記

- [x] 3.1 ルート README.md のプラグイン一覧に loops セクションを追記する: 位置づけ（ネイティブプリミティブの合成レシピ集。独自ランタイムではない）・公式 4 ループタイプの一覧・公式記事リンク・インストールコマンド・詳細への導線（plugins/loops/ と research/）。既存プラグイン紹介の体裁に合わせ、要約に留める
- [x] 3.2 タスク 1.2 のテストが PASS することを確認する（GREEN）

## 4. marketplace 登録と version 同期

- [x] 4.1 `git diff origin/main --name-only` で change-1〜4 の実変更プラグインを列挙し、bump 対象リストを確定する（変更なしプラグインは bump しない）
- [x] 4.2 `.claude-plugin/marketplace.json` の `plugins[]` に loops エントリ（name / description / source: ./plugins/loops / category / version / author / keywords）を追加する。version は `plugins/loops/.claude-plugin/plugin.json` と完全一致させる
- [x] 4.3 bump 対象の各プラグインで plugin.json の version を上げ、marketplace.json の対応エントリに同期する（機能追加は minor・検証節追記のみは patch を目安）
- [x] 4.4 marketplace.json の top-level version を bump する
- [x] 4.5 タスク 1.1 のテストが PASS することを確認する（GREEN）

## 5. 統合検証の実行とエビデンス記録

- [x] 5.1 `find plugins -name '*.bats' -print0 | xargs -0 bats` を実行し、リポジトリ全体の bats スイートが全 PASS することを確認する
- [x] 5.2 全 *.json の `jq .` parse 検証を実行する（スクリプトを追加した場合は `bash -n` も実行する）
- [x] 5.3 統合検証の実行出力（bats の PASS 件数と exit code・version 一致/レシピ規約/ランタイム不在の各検証結果）を `{longrun-dir}` 配下にエビデンスログとして保存する
- [x] 5.4 FAIL があった場合は該当 change の成果物側を最小修正して再実行する（仕様・テスト基準は緩めない）。修正不能な構造問題は凍結して人間へエスカレーションする
