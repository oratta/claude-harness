# Tasks: loops-plugin

## 1. テスト先行（規約検証 bats の作成 — RED）

- [ ] 1.1 `plugins/loops/tests/plugin-structure.bats` を作成: plugin.json の JSON parse（`name: loops`・semver version）、必須ファイル一式（skills 2 本 / references 2 本 / templates 2 本）の存在、独自ランタイム不在（`*.bats` を除く `*.sh`/`*.js`/`*.py` が 0 件・`*.schema.json` が 0 件）、モデル ID 直書き 0 件（`claude-` grep）を検証するテストを書き、この時点で FAIL することを確認する
- [ ] 1.2 `plugins/loops/tests/recipe-format.bats` を作成: `references/recipe-format.md` に固定見出し 7 項目（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）の規約定義・停止基準必須の明記・実行インターフェース宣言範囲 4 項目（発火時プロンプト / 推奨頻度 / 停止基準 / 実行環境の制約）とスケジューラ登録が呼び出し側責務である旨、`templates/recipe-template.md` に 7 見出しとネイティブプリミティブ注記、があることを検証するテストを書く（RED）
- [ ] 1.3 `plugins/loops/tests/state-convention.bats` を作成: State 規約（`loops/state/<name>.state.md` 配置・4 節・永続化原則）の記載と、`templates/state-template.md` の 4 見出し + silent drop 禁止注記を検証するテストを書く（RED）
- [ ] 1.4 `plugins/loops/tests/design-skill.bats` を作成: `skills/loops-design/SKILL.md` に選択フレームワーク（手放す対象 4 つと 4 タイプの対応）・停止基準必須の出力ゲート・Bad Loop 検査 4 項目・`references/loop-types.md` 参照・出力レシピの 7 見出し準拠指示があることを検証するテストを書く（RED）
- [ ] 1.5 `plugins/loops/tests/goalify-skill.bats` を作成: `skills/loops-goalify/SKILL.md` にテキスト/ファイルパス両入力・4 観点の不足分のみヒアリング（全情報が揃っていれば 0 問）・`goals/<name>.goal.md` の 5 見出し（目的 / 成功基準 / 制約 / 参照パス / エスカレーション条件）・成功基準はコマンド + 期待値・/goal 起動コマンド 1 行・レシピ昇格の促し・plan-interview-methodology.md 参照があることを検証するテストを書く（RED）
- [ ] 1.6 `plugins/loops/tests/loop-types-reference.bats` を作成: `references/loop-types.md` に 4 タイプ表（手放す対象・対応プリミティブ・使い分け・具体例）と実行機構との責務分離の節があることを検証するテストを書く（RED）

## 2. プラグイン骨格（GREEN: 1.1 を通す）

- [ ] 2.1 `plugins/loops/.claude-plugin/plugin.json` を作成する（`name: loops`、version は semver、description にレシピ集 + State 規約 + 設計ガイドの位置づけを記載。モデル ID を書かない）
- [ ] 2.2 `plugins/loops/{skills,references,templates,tests}/` のディレクトリ構成を確定し、1.1 の構成テストが PASS することを確認する

## 3. 規約とリファレンスの執筆（GREEN: 1.2・1.3・1.6 を通す）

- [ ] 3.1 `plugins/loops/references/recipe-format.md` を執筆する: 固定見出し 7 項目の規約・停止基準必須（最大試行数 / 時間 / 定量ゴールのいずれか 1 つ以上）・起動コマンドはネイティブプリミティブのコピペ文字列（独自 CLI / ラッパー禁止）・実行インターフェース宣言の範囲 4 項目とスケジューラ登録等は呼び出し側責務・schema 強制はしない旨
- [ ] 3.2 `plugins/loops/templates/recipe-template.md` を執筆する（7 見出しの雛形 + 起動コマンド節のネイティブプリミティブ注記）
- [ ] 3.3 State 規約（`loops/state/<name>.state.md`・4 節・「エージェントは忘れるが、リポジトリは記憶する」）を references に記載し、`plugins/loops/templates/state-template.md`（4 見出し + 繰り越しの silent drop 禁止注記）を執筆する
- [ ] 3.4 `plugins/loops/references/loop-types.md` を執筆する: `research/loop-engineering.md` 冒頭の公式記事セクションを配布物化した 4 タイプ表（手放す対象・対応プリミティブ・使い分け・具体例）+ 実行機構との責務分離の 1 節
- [ ] 3.5 1.2・1.3・1.6 の bats が PASS することを確認する

## 4. スキル実装（GREEN: 1.4・1.5 を通す）

- [ ] 4.1 `plugins/loops/skills/loops-design/SKILL.md` を実装する: 選択フレームワークのインタビュー → ループ型選定 → 停止基準必須ゲート（確定まで出力拒否）→ Bad Loop 検査 4 項目 → レシピ形式規約準拠の書き出し。`references/loop-types.md`・`references/recipe-format.md` を参照する
- [ ] 4.2 `plugins/loops/skills/loops-goalify/SKILL.md` を実装する: brain dump 読み込み（テキスト / ファイルパス）→ 4 観点の充足分析 → 不足分のみ AskUserQuestion（plan-interview-methodology.md の方法論を参照流用）→ `goals/<name>.goal.md` + /goal 起動コマンド 1 行の生成 → レシピ昇格の促し 1 行
- [ ] 4.3 1.4・1.5 の bats が PASS することを確認する

## 5. 統合検証とデモ

- [ ] 5.1 `find plugins -name '*.bats' -print0 | xargs -0 bats` で loops のテストを含む全テストが PASS することを確認する（既存テストの破壊が無いこと）
- [ ] 5.2 design デモ: `/loops:design` で小さなループを 1 本設計し、停止基準を出さない場合に出力が拒否されること、確定後の出力が 7 見出しを持つことを確認してログを `{longrun-dir}` に残す
- [ ] 5.3 goalify デモ: (a) 情報不足の brain dump で不足観点のみヒアリングされること、(b) 全情報が揃った brain dump でヒアリング 0 問のまま `goals/<name>.goal.md`（成功基準が全てコマンド + 期待値）と /goal 起動コマンド 1 行が生成されることを確認してログを残す
- [ ] 5.4 `plugins/loops/` 配下に独自ランタイム・モデル ID 直書きが無いことを最終 grep で確認し、`openspec validate --strict loops-plugin` が PASS することを確認する
- [ ] 5.5 廃案分の将来候補（レシピの機械検証・loop-audit 相当・schema 化）を `openspec/backlog.md` に記録する
