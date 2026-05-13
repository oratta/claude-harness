# Codex Build Agent PoC — Evaluation Report

> **Status**: Filled in by Task #6 orchestrator after a real Codex CLI session.

## Environment

- Run date: 2026-05-13 13:26–13:29 JST
- Codex CLI version: codex-cli 0.130.0 (`/Users/oratta/.superset/bin/codex`)
- Available Codex models (raw discovery method):
  - `codex` CLI 0.130.0 は `codex models` 等のリスト API を提供していない。`codex --help` の `-m, --model <MODEL>` で任意モデル ID を受け付け、無効ならエラー返す方式。
  - `~/.codex/config.toml` の `model = "gpt-5.5"` がデフォルト指定。「`gpt-5.5-pro`」というモデル ID は config に存在せず、`gpt-5.5` が現役の主力モデル。
- Codex model: **`gpt-5.5`**（plan.md「5.5 Pro 相当」として採用。`gpt-5.5-pro` は CLI 上に存在せず、現役 Pro 系最上位の `gpt-5.5` で代替）
- Codex auth source: `~/.codex/auth.json` 存在、`codex login status` → "Logged in using ChatGPT"（サブスク認証）
- Opus auth source: 擬似化（D-002）。本 PoC では Opus 経路を「Vitest を直接実行する fake fallback」として再現。実 longrun-builder Agent 起動は Phase 2。
- Host: Darwin 25.4.0 (arm64)
- Tokens used (Codex single-shot): **45,559**
- Codex sandbox mode used: `workspace-write` + `--skip-git-repo-check` + `-C <sandbox abs path>`

## Results summary (4 axes)

| Axis                                | Result            | Notes                                                                                          |
|-------------------------------------|-------------------|------------------------------------------------------------------------------------------------|
| TDD loop completed (Codex, #6a)     | ✅ PASS            | RED 観測（2 failed `NOT_IMPLEMENTED`）→ GREEN 観測（2 passed）。`prompts.md V2` の `red`/`green` fenced block マーカーで機械的に確認可能 |
| Commit granularity (#6b)            | ⚠️ Conditional     | Codex 内部 git では `test:` → `feat:` の順序を踏んだが、テストコミットは `--allow-empty` の noop。**テストファイル先行**の趣旨を厳密には満たさない |
| Fallback drill (#7)                 | ✅ PASS            | `run-fallback.sh --simulate-codex-down` で fake codex stderr `authentication failed` → exit 64 を検出 → Opus 経路に分岐、1s で fake fallback 完走 |
| Cost / wall-clock (Codex vs Opus)   | n=1               | Codex: **165s** / Opus(擬似): 1s。Opus は擬似化のため比較は意味なし、Phase 2 で実 Opus パスを使った再計測必要                       |
| TDD fidelity (no-test-rate)         | ⚠️ See breakdown  | 親 repo 集計は 1.7% だが本 PoC のスコープ外履歴を含む。**Codex 内部 git では 50%（1/2 commit が production-only）** が真の値 |

### Raw numbers (filled by scripts; do not hand-edit)

- Codex wall-clock: 165s
- Opus wall-clock: 1s
- no-test-rate: 1.7%（親 repo, n=58。**実評価では下の "Codex 内部 git" 行を使うこと**）
- no-test-rate (Codex internal gitmeta, n=2): **50%** — `5711050 test(greet) (noop, empty)` は `neither` バケット、`be9f957 feat(greet)` は `production-only`

## Per-scenario outcomes

| Scenario | Status | Evidence |
|----------|--------|----------|
| S1  Codex model discovery        | ✅ PASS | `~/.codex/config.toml` 経由で `gpt-5.5` を採用。`codex --help` に列挙 API はない旨も記載 |
| S2  5.5 Pro fallback (if absent) | ✅ PASS | `gpt-5.5-pro` は実在せず `gpt-5.5` を最上位 Pro 系として採用（本セクション「Codex model」参照） |
| S3  TDD RED→GREEN loop           | ✅ PASS | Codex 出力に `red` fenced block + `green` fenced block（V2 prompt 仕様通り）。npm test も別途 GREEN 確認 |
| S4  Test-first commit order      | ⚠️ Conditional | gitmeta 内: 5711050 (test, empty) → be9f957 (feat, src/greet.ts)。順序は守られたが test commit が空のため Conditional Go |
| S5  Codex-down -> Opus           | ✅ PASS | `run-fallback.sh` ログ: `codex probe exit=64, stderr='codex: authentication failed (simulated)'` → `routing to Opus fallback` |
| S6  Wall-clock recorded          | ✅ PASS | Codex 165s / Opus 1s 双方記録 |
| S7  TDD fidelity %               | ✅ PASS | `measure-tdd-fidelity.sh` 出力（親 repo 計測）+ Codex 内部 git の手動分類（50%）を双方記載 |
| S8  Pre-guard (dirty worktree)   | ✅ PASS | Bats `run-poc.bats:7` "exits non-zero when working tree is dirty" 10/10 PASS |
| S9  Post-guard (outside writes)  | ✅ PASS | Bats `run-poc.bats:8` "detects sandbox-outside writes and restores them" 10/10 PASS |
| S10 Guard self-test (#12)        | ✅ PASS | Bats `run-poc.bats` の sandbox 外書き込み検出ケース PASS、`CODEX_FAKE_WRITES=outside:plugins/longrun/agents/rogue.md` で再現 |
| S11 4-axis report present        | ✅ PASS | 本ファイル（テーブル + Per-scenario + Phase 2 risks + 判定欄を網羅） |
| S12 Existing files unchanged     | ✅ PASS | `git diff $(git merge-base main HEAD) HEAD -- plugins/longrun plugins/codex openspec/specs` = 空 |

## 重要観察（Phase 2 必読）

**Codex は親 repo に直接 commit を打たない**:
- `codex exec -C <sandbox> -s workspace-write --skip-git-repo-check` の組み合わせで、Codex は sandbox 内に独立 `gitmeta/` ディレクトリを作って独自 git history を管理した
- 親 repo（`codex-build-agent-eval` ブランチ）の `git log` には Codex 由来のコミットが**一切現れない**
- これにより plan.md 受け入れ条件 #6b 「**最終 git log でテスト先行コミット → 実装コミットの順序**」を親 repo で検証する設計は成立しない
- 親 repo に commit させるには別の呼び出し方（`-C` を親 repo に向ける、`--skip-git-repo-check` を外す、または codex 内部 git の export 手段）が必要
- 実装の差分自体は親 repo に残った（`src/greet.ts` が編集された）ので、Codex の動作価値は失われていない

## Phase 2 carry-over risks

1. **(a) Codex timeout / hang detection** *（必須）*
   - Risk: Codex セッションが途中で hang する可能性（partial stdout / no exit）
   - Phase 2 plan: `codex-companion task` を `timeout 600 ...` で wrap し、SIGTERM を「Opus フォールバック」シグナルとして扱う

2. **(b) Partial-success rollback** *（必須）*
   - Risk: Codex がテスト追加 commit 後に crash した場合、sandbox が半完成状態で残る。post-guard は **外** への書き込みのみ検出、**incomplete TDD ladder** は検出しない
   - Phase 2 plan: 各 Codex turn 後に `test:` と `feat:` の pair が N turn 以内に揃わなければ `git reset --hard` で `run-poc.sh` 開始時点の SHA に巻き戻す

3. **(c) Subscription-quota distinction** *（必須）*
   - Risk: Codex CLI に「quota 残量取得」フラグなし。429 / `quota exceeded` 観測でしか反応できない
   - Phase 2 plan: 本 PoC で観測した stderr fingerprint（本回は `authentication failed` を擬似的に注入）を catalogue 化し `run-fallback.sh` の正規表現に追加。現状 `auth|quota|429|unauthorized` は最低限カバーだが、本物の 429 を観測する機会が無いため Phase 2 で実観測必要

4. **(d) Network-down vs auth-failure** *（必須）*
   - Risk: 両者とも non-zero exit で見分けがつかない。Network-down は transient（retry すべき）、auth-failure は hard-fail
   - Phase 2 plan: stderr で分類（`ENOTFOUND` / `ETIMEDOUT` vs `401` / `unauthorized`）し、Codex path に `--retry` 回数を追加

5. **★最重要: Codex の git history が gitmeta/ に閉じる**
   - Risk: 本 PoC で発見した致命的挙動。Codex の commit が親 repo に乗らないと、orchestrator の verification-guide.md / merge ロジックが Codex builder と統合できない
   - Phase 2 plan:
     - 案 A: `codex exec` を **親 repo の root で実行**し、Codex に sandbox path のみを書き換えさせる（`-C` を親 repo の root に変更）
     - 案 B: gitmeta/ を fast-forward して親 repo にマージするヘルパー（`git -C sandbox/gitmeta format-patch` + `git am`）
     - 案 C: `codex apply` サブコマンド（codex CLI に存在）を使って Codex の diff を親 repo に適用
     - これらをすべて PoC して最良案を採用

6. **TDD fidelity drift under longer changes**（必須 4 件超え、stretch）
   - Risk: PoC sample (`greet`) は 1 関数。実 builder workload（多ファイル、refactor）では Codex の commit 粒度が劣化する可能性
   - Phase 2 plan: fidelity classifier を「files touched」「diff size」でバケット分けし、最低 1 個の実 change で再評価

7. **(stretch) Empty-test-commit anti-pattern**
   - Risk: V2 prompt が `--allow-empty` の noop test commit を許容したため、Codex は「TDD 順序を守った」とログ上は見えるが内容は空。これは TDD 規律の本質を損なう
   - Phase 2 plan: builder-codex Agent の prompt から `noop` 許容を削除し、「既存テストで spec が満たされる場合は **commit を打たず** Step 2 に直行」へ書き換える

8. **(stretch) `~/.codex/` immutability under concurrent sessions**
   - Risk: 2 つの `run-poc.sh` race で `~/.codex/` corruption
   - Phase 2 plan: `flock` で `~/.codex/` 読み取りを排他化

9. **(stretch) measure-tdd-fidelity.sh のスコープ**
   - Risk: 親 repo 全履歴を見るため本 PoC では n=58 の中で 1 件しか分母にカウントされず意味のある数値にならない
   - Phase 2 plan: `main..HEAD` でスコープ限定するオプションを追加

## Go / Conditional Go / No-Go

- **Decision**: **Conditional Go**
- **Rationale**:
  - ✅ #6a (TDD RED→GREEN ループ): PASS — Codex は実 sandbox で 2 failed → 2 passed を達成
  - ⚠️ #6b (commit 粒度): Codex 内部 gitmeta では順序成立だが test commit が `--allow-empty`。厳密な「テストファイル先行」は不成立
  - ✅ #7 (フォールバック): 擬似 codex-down → opus 経路ログまで観測
  - ⚠️ no-test-rate: gitmeta 計測で 50%（プロダクションのみ commit が半数）。0% ではない
  - ✅ Bats #12: 10/10 PASS、ガード自体は壊れていない
  - 大きな新規発見：**Codex commit が親 repo に乗らない**（重要観察セクション）。これは Phase 2 で `codex exec` の呼び出し方を確立する課題
- **Phase 2 carry-over への引き継ぎ**:
  - 必須 4 件（a–d）、★最重要 1 件（gitmeta 統合）、stretch 4 件 = 合計 9 件をリスク列挙
  - Phase 2 plan の 1 タスク目: 「Codex commit を親 repo に乗せる方式の確立（案 A/B/C のうちどれか）」
  - Phase 2 plan の 2 タスク目: 「prompt から `noop` empty test 許容を撤去」
  - Phase 2 plan の 3 タスク目: 「`longrun-builder-codex` Agent 新設 + orchestrator 分岐」（本来の Phase 2 主題）

### Decision rubric (recap of plan.md)

- **Go** if #6a, #6b, #7 all pass AND no-test-rate is 0%. → **本 PoC は不成立**（#6b 不成立、no-test-rate 50%）
- **Conditional Go** if #6a and #7 pass but #6b or fidelity has shortfalls. → **本 PoC はこれに該当**
- **No-Go** if #6a or #7 fail, OR Bats #12 (guard self-test) breaks. → 該当せず

→ **Conditional Go** で Phase 2 plan の起票を推奨。ただし以下を Phase 2 plan の前提条件とする:
1. 「Codex commit を親 repo に乗せる方式」の確立を Phase 2 の最初のタスクに置く
2. prompt 設計を見直し「テスト先行 commit が必ずテストファイルを変更する」よう書き換える

---

- fallback path engaged: yes（`[run-fallback] Opus path: would invoke longrun-builder Agent here (deferred to Task #6)` を実観測）
