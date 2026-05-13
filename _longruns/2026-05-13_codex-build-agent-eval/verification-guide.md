# Verification Guide — codex-build-agent-poc

## 環境
- 実行コマンド:
  - PoC: `bash _longruns/2026-05-13_codex-build-agent-eval/scripts/run-poc.sh`
  - Fallback: `bash _longruns/2026-05-13_codex-build-agent-eval/scripts/run-fallback.sh --simulate-codex-down`
  - 忠実度計測: `bash _longruns/2026-05-13_codex-build-agent-eval/scripts/measure-tdd-fidelity.sh`
- テスト:
  - Sandbox: `cd _longruns/2026-05-13_codex-build-agent-eval/sandbox && npm test`
  - Harness Bats: `bats _longruns/2026-05-13_codex-build-agent-eval/scripts/tests/`

## change-A: codex-build-agent-poc

### S1: Codex 利用可モデル取得（R1）
- WHEN: `run-poc.sh` を実行する
- THEN: `evaluation.md` 環境セクションに採用モデル ID が記載される
- [x] テスト実装完了 — `scripts/tests/run-poc.bats` "records used model id"
- [x] ロジック実装完了 — `run-poc.sh` の `CODEX_MODEL` 解決 + awk による evaluation.md 書換
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: 5.5 Pro 不在時の代替モデル（R1）
- WHEN: 利用可モデル一覧に `gpt-5.5-pro` がない
- THEN: 最上位 Pro 系モデルを採用し、Go/No-Go 判定欄に代替モデル明記
- [x] テスト実装完了 — `CODEX_MODEL=test-model-x` で任意モデル ID を受理する経路を Bats でカバー
- [x] ロジック実装完了 — `CODEX_MODEL` env override は default `gpt-5.5-pro` から差し替え可能。実 codex 取得結果と Go/No-Go 文の埋め込みは Task #6
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: TDD ループ成立 #6a（R2）
- WHEN: `run-poc.sh` が Codex を呼び TDD を進める
- THEN: 実行ログに `npm test` の RED → GREEN 出力が 1 セット以上含まれる
- [x] テスト実装完了 — prompts.md V2 で `\`\`\`red` / `\`\`\`green` マーカを必須化し、収集を機械可能に
- [x] ロジック実装完了 — harness 側スキャフォールド完成（実 Codex 呼び出しは Task #6）
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: コミット粒度 #6b（R2）
- WHEN: `run-poc.sh` 完走後の `git log --name-only`
- THEN: テストファイル先行コミット → 実装コミットの順序が確認できる。不成立は Conditional Go
- [x] テスト実装完了 — `measure-tdd-fidelity.sh` が `production-only` カテゴリを検出可能（Bats で 4 分類検証済み）
- [x] ロジック実装完了 — fidelity classifier 実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: 擬似 Codex ダウン → フォールバック（R3）
- WHEN: `run-fallback.sh --simulate-codex-down` を実行
- THEN: codex 経路が検出され Opus 経由（擬似化）で sample が完走
- [x] テスト実装完了 — `run-fallback.bats` × 3 ケース
- [x] ロジック実装完了 — PATH 上に fake codex 注入 → auth 系 stderr 検出 → Opus 経路ログ
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: 時間記録（R4）
- WHEN: `run-poc.sh` および `run-fallback.sh` が完走
- THEN: `evaluation.md` に Codex / Opus の wall-clock 時間が記載
- [x] テスト実装完了 — bats `records wall-clock` × 2 (poc/fallback)
- [x] ロジック実装完了 — `date +%s` 差分を秒で awk 経由置換
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: TDD 忠実度算出（R5）
- WHEN: `measure-tdd-fidelity.sh` を実行
- THEN: commit が 4 分類され「テスト無し率」が標準出力 + `evaluation.md` に記録
- [x] テスト実装完了 — `measure-tdd-fidelity.bats` × 3 ケース
- [x] ロジック実装完了 — 4 分類 + awk による percent 計算
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: 事前 worktree クリーン化（R6）
- WHEN: `run-poc.sh` 起動時に未追跡 / 未コミット差分がある
- THEN: スクリプトは非ゼロ exit する
- [x] テスト実装完了 — bats "exits non-zero when working tree is dirty"
- [x] ロジック実装完了 — `git status --porcelain` ガード
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: sandbox 外書き込み検出（R6）
- WHEN: Codex 実行直後の diff に sandbox 外パスが含まれる
- THEN: 該当パスを `git checkout --` で破棄し非ゼロ exit
- [x] テスト実装完了 — bats "detects sandbox-outside writes and restores them"
- [x] ロジック実装完了 — tracked → `git checkout --`, untracked → `rm -f` の両対応
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: ガード自体のテスト #12（R6）
- WHEN: Bats テストで擬似的に sandbox 外にファイルを書く
- THEN: `run-poc.sh` が暴走パターンを検出して非ゼロ exit することを保証
- [x] テスト実装完了 — `CODEX_FAKE_WRITES=outside:plugins/longrun/agents/rogue.md` で再現
- [x] ロジック実装完了 — S9 と一体
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: 4 軸スコア記載（R7）
- WHEN: PoC 全工程が完了
- THEN: `evaluation.md` に環境セクション + 4 軸結果サマリ表 + Phase 2 引き継ぎリスク（最低 5 件、必須 4 件: タイムアウト / 部分成功 / 残量 / NW vs 認証）+ Go/Conditional Go/No-Go 判定 + 根拠が含まれる
- [x] テスト実装完了 — テンプレ内に Phase 2 リスク 6 件記載済（必須 4 件 + stretch 2 件）
- [x] ロジック実装完了 — テンプレ完成、実行結果欄は Task #6 で埋める
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: 既存ファイル不変（R7）
- WHEN: PoC 完了後 `git diff main -- plugins/longrun plugins/codex openspec/specs`
- THEN: 出力が空
- [x] テスト実装完了 — `git diff $(git merge-base main HEAD) HEAD -- plugins/longrun plugins/codex openspec/specs` で検証（merge-base 経由で main の前進影響を排除）
- [x] ロジック実装完了 — 全変更を `_longruns/2026-05-13_codex-build-agent-eval/` 配下に閉じ込めた
- [ ] 動作確認完了
- [ ] ユーザー確認完了
