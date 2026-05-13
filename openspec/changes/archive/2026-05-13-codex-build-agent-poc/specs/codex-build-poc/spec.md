# Capability: codex-build-poc

## ADDED Requirements

### Requirement: Codex 利用可モデルの同定
PoC harness は Codex CLI の利用可モデル一覧を取得し、「5.5 Pro 相当」モデル ID を決定して `evaluation.md` に記録する SHALL。

#### Scenario: 利用可モデル取得
- **WHEN**: ユーザーが `bash scripts/run-poc.sh` を実行する
- **THEN**: `codex` CLI のヘルプ / モデル一覧から PoC で使うモデル ID（理想は `gpt-5.5-pro`、不在時は最上位 Pro 系）が `evaluation.md` の「環境」セクションに記載される

#### Scenario: 5.5 Pro 不在時の代替モデル
- **WHEN**: 利用可モデル一覧に `gpt-5.5-pro` を含むモデル ID がない
- **THEN**: 最上位 Pro 系モデル ID が採用され、`evaluation.md` の Go/No-Go 判定欄に「5.5 Pro 不在のため代替モデル `<id>` で判定、Phase 2 ではモデル ID 再確認が必須」と明記される

### Requirement: Sandbox サンプル change の Codex 経由 TDD 完走
PoC harness は sandbox 内のサンプル change を Codex 経由で TDD 実装させ、その過程の RED→GREEN ループを確認できなければならない (MUST)。

#### Scenario: TDD ループ成立（#6a）
- **WHEN**: ユーザーが `bash scripts/run-poc.sh` を実行する
- **THEN**: Codex 実行ログ（stdout / sandbox 内の実行ログファイル）に `npm test` の RED 出力 → GREEN 出力が 1 セット以上含まれる

#### Scenario: コミット粒度（#6b）
- **WHEN**: `run-poc.sh` 完走後、sandbox 内で `git log --name-only` を確認する
- **THEN**: テストファイル (`*.test.ts`) を含む先行コミットの後に、プロダクションファイル (`src/**/*.ts`) を含む実装コミットが存在する。**6b 不成立でも 6a 成立なら Conditional Go として記録**

### Requirement: フォールバック動作検証
Codex 経路が利用不可な場合、PoC harness は Opus 経由（`longrun-builder` Agent もしくはローカル Claude による同等処理）にフォールバックして sample change を完走できなければならない (MUST)。

#### Scenario: 擬似 Codex ダウン
- **WHEN**: ユーザーが `bash scripts/run-fallback.sh --simulate-codex-down` を実行する
- **THEN**: codex 経路が stderr / exit code から障害として検出され、Opus 経由で sample change の TDD 完走テストが PASS する

### Requirement: コスト / 時間計測
PoC harness は Codex 実行と Opus 実行の wall-clock 時間を計測し、`evaluation.md` に記録する SHALL。

#### Scenario: 時間記録
- **WHEN**: `run-poc.sh` および `run-fallback.sh` が完走する
- **THEN**: `evaluation.md` の比較表に Codex 実行時間と Opus 実行時間が双方 wall-clock 秒で記載される（サンプル数 n=1 で良いが、その旨を注記）

### Requirement: TDD 忠実度計測
PoC は git log を機械的に走査して TDD 忠実度を算出する SHALL。

#### Scenario: 忠実度算出
- **WHEN**: ユーザーが `bash scripts/measure-tdd-fidelity.sh` を実行する
- **THEN**: 各 commit が「テストファイルのみ」「プロダクションファイルのみ」「両方」「どちらも含まない」に分類され、`(プロダクションのみ commit 数) / (全 commit 数)` の「テスト無し率」が標準出力および `evaluation.md` に記録される

### Requirement: Sandbox 外書き込み事前ガード
PoC harness は Codex 暴走による sandbox 外書き込みを事前 + 事後 + テストの三重防御で阻止する MUST。

#### Scenario: 実行前 worktree クリーン化
- **WHEN**: `run-poc.sh` が起動した時点で worktree に未追跡 / 未コミット差分がある
- **THEN**: スクリプトは非ゼロ exit して終了する（暴走時の差分判別を阻害しないため）

#### Scenario: sandbox 外への書き込み検出
- **WHEN**: Codex 実行直後の `git diff --name-only HEAD` に `_longruns/2026-05-13_codex-build-agent-eval/sandbox/` の外のパスが含まれる
- **THEN**: スクリプトは該当パスを `git checkout -- <path>` で破棄し、非ゼロ exit する

#### Scenario: ガード自体のテスト (#12)
- **WHEN**: Bats テスト `scripts/tests/run-poc.bats` の「擬似的に sandbox 外にファイルを書く」ケースを実行する
- **THEN**: テストは PASS し、`run-poc.sh` が暴走パターンを検出して非ゼロ exit することを保証する

### Requirement: 評価レポート (evaluation.md) の生成
PoC は最終成果物として `evaluation.md` を生成し、4 軸スコア表 + Phase 2 引き継ぎリスク + Go/Conditional Go/No-Go 判定を含める MUST。

#### Scenario: 4 軸スコア記載
- **WHEN**: PoC 全工程が完了する
- **THEN**: `evaluation.md` に以下が含まれる:
  - 環境セクション（実行日時、Codex CLI version、利用可モデル一覧、採用モデル ID）
  - 結果サマリ表（TDD 完走 / フォールバック / コスト時間 / TDD 忠実度の 4 軸）
  - Phase 2 引き継ぎ技術リスク **最低 5 件**、うち下記 4 件が必須:
    (a) Codex タイムアウト検出方針 / (b) 部分成功時のロールバック方針 / (c) サブスク残量切れの判別 / (d) ネットワーク断 vs 認証エラーの判別
  - Go / Conditional Go / No-Go 判定 + 根拠

#### Scenario: 既存ファイル不変
- **WHEN**: PoC 完了後、`git diff main -- plugins/longrun plugins/codex openspec/specs` を実行する
- **THEN**: 出力が空である（受け入れ条件 #4 / #11 と一致）
