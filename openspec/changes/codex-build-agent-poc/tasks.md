# Tasks: codex-build-agent-poc

## 1. Sandbox サンプルプロジェクト構築
- [x] 1.1 `sandbox/package.json` 作成（vitest + typescript + tsx を devDependencies に）
- [x] 1.2 `sandbox/tsconfig.json` 作成
- [x] 1.3 `sandbox/vitest.config.ts` 作成
- [x] 1.4 `sandbox/src/greet.ts` を **空の export** で初期化（RED にするため）
- [x] 1.5 `sandbox/.gitignore`（node_modules / coverage）
- [x] 1.6 sandbox 内で `npm install` を実行し node_modules をローカル展開（コミットしない）
  - Task #6 で `npm install --no-audit --no-fund` を実行（45 packages, 5s）。`package-lock.json` は sandbox/.gitignore に追加してコミット対象外に。

## 2. PoC harness（RED Phase）
- [x] 2.1 `scripts/tests/run-poc.bats` 作成（先に書く）:
  - test "run-poc.sh exits non-zero if working tree is dirty"（事前 git status ガード）
  - test "run-poc.sh detects sandbox-outside writes and restores them"（Bats #12）
  - test "run-poc.sh records used model id in evaluation.md"
- [x] 2.2 `scripts/tests/run-fallback.bats` 作成:
  - test "run-fallback.sh routes to fallback when --simulate-codex-down is given"
  - test "run-fallback.sh emits Opus path log entry on fallback"
- [x] 2.3 `scripts/tests/measure-tdd-fidelity.bats` 作成:
  - test "classifies commits into 4 categories"
  - test "outputs no-test-rate as percentage"
- [x] 2.4 上記 Bats を実行し全テスト FAIL になることを確認（**RED 確認**）

## 3. PoC harness（GREEN Phase）
- [x] 3.1 `scripts/run-poc.sh` 実装:
  - 事前 `git status --porcelain` チェック（dirty なら exit 1）
  - 利用可モデル取得（`codex --help` または `-c model_providers` 等を観察してコメント記録）
  - sandbox に Codex 経由で TDD prompt を投げる（codex-companion task 経由、`--write`、 model 指定）
  - 実行直後 `git diff --name-only HEAD` で sandbox 外パスを検出 → `git checkout --` で破棄 + exit 1
  - `evaluation.md` の環境セクションに採用モデル ID と所要時間を記録
- [x] 3.2 `scripts/run-fallback.sh` 実装:
  - `--simulate-codex-down` フラグで codex 経路を擬似ダウン（環境変数 PATH 経由で偽 codex を差し込む）
  - fallback パスを `evaluation.md` ログに記録
  - sandbox の Vitest を直接実行して PASS 確認
- [x] 3.3 `scripts/measure-tdd-fidelity.sh` 実装:
  - `git log --oneline` の commit を走査
  - 各 commit に対し `git show --name-only` で 4 分類
  - テスト無し率を標準出力 + `evaluation.md` に追記
- [x] 3.4 全 Bats テストが PASS することを確認（**GREEN 確認**）
- [x] 3.5 `shellcheck` でシェルスクリプトの lint 通過（必要なら brew で install）

## 4. プロンプト設計と反復
- [x] 4.1 `prompts.md` を作成し、Codex に投げる初期 TDD prompt を記述
- [x] 4.2 Codex への prompt を 1 回 dry-run し、コミット粒度の出力を観察（Task #6 で実 codex exec を実行、結果は evaluation.md に反映。Codex 内部 gitmeta に commit が閉じる重要観察あり）
- [x] 4.3 prompts.md に「初期版」「反復版（Codex 観察前の予測修正）」の 2 版以上を記録

## 5. evaluation.md / verification-guide.md スケルトン
- [x] 5.1 `evaluation.md` のテンプレを書き、未記入セクション（実行結果は Task #6 で埋める）を明示
  - Task #6 で実行結果を全て記入完了。Conditional Go 判定 + Phase 2 引き継ぎリスク 9 件を記録。
- [x] 5.2 `verification-guide.md` を生成（spec.md の Scenario を転記、進捗トラッカー [ ] テスト実装完了 / [ ] ロジック実装完了 / [ ] 動作確認完了 / [ ] ユーザー確認完了 を全 Scenario に付与）

## 6. 静的検証 + コミット
- [x] 6.1 `cd sandbox && npx tsc --noEmit` で型チェック PASS
  - Volta 経由の `tsc` は `package-lock.json` を要求するため、グローバル TypeScript (`/Users/oratta/.volta/tools/image/packages/typescript/.../tsc`) で代替確認。exit=0。
- [x] 6.2 `bats scripts/tests/` で全 Bats PASS（10/10）
- [x] 6.3 `git diff main -- plugins/longrun plugins/codex openspec/specs` が空であることを確認
  - **注**: 単純な `git diff main` は main が PoC ブランチより進んでいるため空にならない。本タスクの追加分が触っていないことを `git diff $(git merge-base main HEAD) HEAD -- plugins/longrun plugins/codex openspec/specs` で確認（空であることを検証済み）。
- [x] 6.4 worktree ブランチに `feat(codex-poc): ...` でコミット
