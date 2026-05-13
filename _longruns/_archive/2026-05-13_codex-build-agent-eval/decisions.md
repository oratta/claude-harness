# Decisions Log

## Plan フェーズで確定済みの意思決定（plan.md 由来）

### D-001: アーキ方針 — 別 Agent 新設 + orchestrator 分岐
- **コンテキスト**: longrun-builder を Codex 5.5 Pro に委譲する方法の選択
- **選択**: Phase 2 で `longrun-builder-codex` Agent を新設し orchestrator 側で分岐
- **却下案**: ①現行 builder 内部を Bash 委譲化（フォールバック実装が複雑）/ ②Hybrid（Codex 委譲量が薄く効果不明）
- **根拠**: 影響範囲を限定 + A/B 比較が容易 + フォールバックを素直に書ける
- **エビデンス**: AskUserQuestion 回答（"別 Agent 新設 + orchestrator 分岐（推奨）"）

### D-002: フォールバック検出 — 実行失敗検出
- **選択**: codex-companion task の exit code / stderr / stdout 解析で 429・quota・auth エラーを検出 → opus 経由再実行
- **却下案**: ①事前ヘルスチェック（Codex CLI に quota 取得 API 不在）/ ②両方併用（PoC スコープに対し重い）
- **根拠**: PoC 段階で十分。Phase 2 でタイムアウト・部分成功などのエッジを追加可能
- **エビデンス**: AskUserQuestion 回答 + longrun-reviewer 指摘3への対応（受け入れ条件 #10 で網羅）

### D-003: スコープ — Phase 1 PoC のみ
- **選択**: 本 plan は PoC + 評価レポートまで。本実装は Phase 2 で別 plan
- **根拠**: ブランチ名 `codex-build-agent-eval` の含意と整合。サブスク仕様未知で実装まで一気にやると stuck リスク
- **エビデンス**: AskUserQuestion 回答 + plan.md 「Phase 2 への引き継ぎ条件」セクション

### D-004: 検証対象 — oratta-claude-harness 内 sandbox
- **選択**: `_longruns/2026-05-13_codex-build-agent-eval/sandbox/` にダミー実装
- **根拠**: OpenSpec / longrun が手元に揃う + Codex 暴走時の被害を sandbox に閉じられる
- **エビデンス**: AskUserQuestion 回答

### D-005: モデル ID — PoC 中に同定
- **選択**: `codex` CLI で利用可モデル一覧を取得し「5.5 Pro 相当」を採用。不在時は最上位 Pro 系で代替
- **根拠**: 「5.5 pro」の実在 ID が plan 時点で未確認
- **エビデンス**: AskUserQuestion 回答 + longrun-reviewer 指摘2への対応

### D-006: PoC 評価軸 — 4 軸全採用
- **選択**: TDD 完走 / フォールバック / コスト時間 / TDD 忠実度
- **根拠**: 単独軸では Go/No-Go 根拠が薄い。4 軸あれば Phase 2 リスクも抽出できる
- **エビデンス**: AskUserQuestion 回答（multiSelect 全選択）

## Plan Review（longrun-plan 内）での確定事項

### D-007: 受け入れ条件 #6 を #6a / #6b に分割
- **コンテキスト**: longrun-reviewer 指摘1 (BLOCKER) — Codex の TDD 完走能力とコミット粒度制御能力が混線する
- **選択**: #6a = RED→GREEN ループ成立、#6b = git log コミット順序確認。#6a 成立 + #6b 不成立 → Conditional Go
- **根拠**: Codex の能力評価とプロンプト設計の出来を独立軸として分離
- **エビデンス**: longrun-reviewer レビュー（2 ラウンド目で APPROVE）

### D-008: Codex 暴走対策の三重防御
- **コンテキスト**: longrun-reviewer 指摘4 (BLOCKER) — sandbox 外書き込みが事後検出のみ
- **選択**: ①事前 `git status` クリーン化、②実行直後 `git diff --name-only` で sandbox 外即時破棄、③Bats でガード自体をテスト (#12)
- **根拠**: Codex CLI に `--cd` / `--sandbox` 相当はあるが、PoC 段階で過信せず多段防御
- **エビデンス**: plan.md change-A config.yaml rules + 受け入れ条件 #12

## Build フェーズで確定した意思決定

### D-009: Bats テストは fake repo で隔離実行
- **コンテキスト**: 本物の worktree で `run-poc.sh` を回すと dirty 検出ガードで全テストが落ちる、または評価用 evaluation.md を毎テスト書き換えてしまう
- **選択**: `BATS_TEST_TMPDIR` 配下に最小レイアウト (`_longruns/.../{scripts,sandbox,evaluation.md}`) を作って `git init` し、`scripts/*.sh` をコピーしてテスト
- **却下案**: ①本物の worktree 直叩き（破壊的）/ ②`docker` コンテナ（依存重い）
- **根拠**: 各テストが完全に独立。本物の git 履歴・ファイルに副作用ゼロ
- **エビデンス**: `scripts/tests/helpers.bash` の `setup_fake_repo` + 10/10 Bats PASS

### D-010: スクリプトの REPO_ROOT 解決は script-dir 起点
- **コンテキスト**: Bats から `bash run-poc.sh` を叩くと、CWD が caller の dir のままになり `git rev-parse --show-toplevel` が本物の worktree を返してしまう（fake repo が無視される）
- **選択**: 全 scripts で `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` 経由で `git -C "$SCRIPT_DIR" rev-parse --show-toplevel`
- **却下案**: ①テスト側で `cd $FAKE_REPO` 強制（運用時の罠を増やす）/ ②REPO_ROOT を env 強制注入（CLI から使いにくい）
- **根拠**: 「scripts は自分が住んでいる repo に対して動く」が直感的。Bats でも実運用でも同じ挙動
- **エビデンス**: 修正後の bats 全 PASS

### D-011: `npm install` は本タスクで実行しない
- **コンテキスト**: tasks.md §1.6 は `npm install` を要求するが、リポジトリ容量と Volta lockfile 要求の衝突あり
- **選択**: §1.6 は `[ ]` のまま残し、Task #6 で必要に応じ実行する。型チェックはグローバル TypeScript で代替確認
- **却下案**: ①sandbox に lockfile commit（差分が大きすぎる）/ ②本タスクで `npm install` 実行（user instruction 違反）
- **根拠**: user instruction で明示禁止された
- **エビデンス**: tasks.md §1.6 のコメント、§6.1 のコメント

### D-012: `git diff main` は merge-base 経由で検証
- **コンテキスト**: 単純 `git diff main -- ...` は main が PoC ブランチより進んでいる場合に「PoC が変えた」のではなく「main が進んだ」差分まで拾う
- **選択**: 検証は `git diff $(git merge-base main HEAD) HEAD -- ...` を使う
- **却下案**: 単純 `git diff main`（false positive 多い）
- **根拠**: 受け入れ条件 #11 / #4 の「本 PoC で一切変更されていない」という意味論を正確に反映
- **エビデンス**: tasks.md §6.3, verification-guide.md S12 / S11

### D-013: 実 Codex 呼び出しは Task #6 に委譲
- **コンテキスト**: 本タスクは「harness の構造とガード機構を実装するだけ」が user instruction
- **選択**: `run-poc.sh` 内に codex-companion 呼び出しの行をコメントアウトで埋め込み、`CODEX_DRY_RUN=1` で skip 可能にする。Bats でも `CODEX_DRY_RUN=1` を必ず付与
- **却下案**: 実 Codex 呼び出し付き（user instruction 違反 + Bats が遅くなる）
- **根拠**: user instruction「★最重要」セクションの明示要求
- **エビデンス**: run-poc.sh の `CODEX_DRY_RUN` 分岐, evaluation.md の TBD プレースホルダ

## Task #6（PoC 実行）で確定した意思決定

### D-014: モデル ID は `gpt-5.5`（`gpt-5.5-pro` は実在せず）
- **コンテキスト**: `codex` CLI 0.130.0 にはモデル一覧 API が無い。`~/.codex/config.toml` のデフォルトモデルは `gpt-5.5`
- **選択**: 「5.5 Pro 相当」として `gpt-5.5` を採用、evaluation.md に「`gpt-5.5-pro` 不在 / `gpt-5.5` を最上位 Pro 系として採用」を明記
- **エビデンス**: `~/.codex/config.toml` の `model = "gpt-5.5"` 行 + Codex completion 165s + GREEN 観測

### D-015: 実 Codex 呼び出しは `codex exec` 直接利用（codex-companion 経由ではなく）
- **コンテキスト**: `codex-companion.mjs` は `CLAUDE_PLUGIN_ROOT` 環境変数を要求し、Claude Code Skill 外から手動 bash で呼ぶには依存解決が面倒
- **選択**: `codex exec -m gpt-5.5 -C <sandbox> -s workspace-write --skip-git-repo-check < /tmp/prompt-v2.txt` で直接実行
- **却下案**: codex-companion 経由（Skill 外で動かしにくい）
- **根拠**: PoC 主目的は Codex の能力評価。ラッパー選択は Phase 2 で決める
- **エビデンス**: Task #6 の Bash 実行ログ、evaluation.md の Environment セクション

### D-016: `--skip-git-repo-check` で Codex が gitmeta/ を作る挙動を観察
- **コンテキスト**: PoC で Codex commit が親 repo に乗らない致命的挙動を発見
- **選択**: 観察結果を evaluation.md「重要観察（Phase 2 必読）」+ Phase 2 carry-over リスク #5 に明記
- **却下案**: 即座に修正して再実行（PoC スコープを Phase 2 にはみ出す）
- **根拠**: PoC は Phase 2 plan のリスク抽出が主目的。観察を残すこと自体が成果
- **エビデンス**: evaluation.md の重要観察セクション + Phase 2 carry-over #5（Codex commit を親 repo に乗せる方式案 A/B/C）

### D-017: 判定は Conditional Go
- **コンテキスト**: #6a / #7 / Bats #12 は PASS、#6b と no-test-rate は shortfall
- **選択**: Conditional Go として Phase 2 plan の起票を推奨、ただし Phase 2 の最初のタスクとして「Codex commit を親 repo に乗せる方式の確立」を必須化
- **エビデンス**: evaluation.md 判定セクション
