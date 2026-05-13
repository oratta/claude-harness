# Plan: Codex Build Agent — Phase 1 PoC + 評価

## 生成情報
- 作成日: 2026-05-13
- Brain Dump元: セッション内（/wt-setup 引数経由）
- 質問回数: 4問（うち1問 multiSelect）

## ゴール
longrun の Build フェーズ担当 Agent（`longrun-builder`）の代替として、Codex（5.5 Pro 相当モデル）を**サブスク範囲**で利用する構成が実現可能かを、PoC で評価する。サブスクが使えない／失敗した場合は現行 Opus 構成にフォールバックする設計の動作も検証し、Phase 2 本実装に進むか否か（Go/No-Go）の判断材料を `evaluation.md` に残す。

**Phase 2 の本実装（`longrun-builder-codex` Agent 新設 / orchestrator 分岐）は本 plan のスコープ外**。本 plan の成果物は PoC harness + sandbox サンプル + 評価レポートに閉じる。

## ビジネスコンテキスト
- 対象ユーザー: longrun を日常運用している自分（oratta）
- 提供価値:
  - Codex サブスクの定額枠を活用し Opus トークン消費を削減できる可能性
  - サブスク不可時の自動フォールバックで運用継続性を担保できるかの実証
- 成功指標:
  - PoC で「Codex で TDD サイクル（RED→GREEN→PASS）が完走する」「フォールバックが動く」が両方確認できれば Go
  - どちらか不成立なら No-Go（理由を evaluation.md に記録）

## 技術要件
- スタック:
  - Bash（PoC harness scripts）
  - Node.js（既存 `codex-companion.mjs` を呼ぶ）
  - TypeScript + Vitest（sandbox 内のサンプル実装対象）
  - 既存 `codex` プラグイン v1.0.4（`~/.claude/plugins/marketplaces/openai-codex/plugins/codex/`）
  - 既存 `longrun-builder` Agent（Opus、フォールバック側）
- 参照パターン:
  - `plugins/codex/agents/codex-rescue.md`: codex-companion task のフォワーダー実装
  - `plugins/codex/skills/codex-cli-runtime/SKILL.md`: 呼び出し契約（--write / --model / --resume-last）
  - `plugins/longrun/agents/longrun-builder.md`: 比較対象（Opus 版）
- 制約:
  - `plugins/longrun/` 配下に変更を加えない（Phase 2 のスコープ）
  - `openspec/` の本体 specs を変更しない（PoC 用 change は archive 行き想定）
  - Codex CLI 認証情報を sandbox に書き込まない（既存 `~/.codex/` を読むだけ）
- テストフレームワーク: Vitest（sandbox サンプル change 内）+ Bats（PoC harness シェルスクリプト用）
- テスト実行コマンド:
  - sandbox: `cd _longruns/2026-05-13_codex-build-agent-eval/sandbox && npm test`
  - harness: `bats _longruns/2026-05-13_codex-build-agent-eval/scripts/tests/`

## スコープ

### 含むもの
- Codex CLI 利用可モデルの調査と「5.5 Pro 相当」モデル ID の同定（`codex --help` / 既知の `gpt-5.3-codex-spark` `gpt-5.4` 系から最新を採用）
- **Codex への TDD コミット粒度指示プロンプトの設計**（最低 2 回のプロンプト反復で粒度改善を試す。プロンプト本文と反復ログを `prompts.md` に残す）
- PoC harness スクリプト（`scripts/run-poc.sh` ほか）
- **Sandbox 外書き込み事前ガード**（`scripts/run-poc.sh` の責務として、Codex 実行直後に `git diff --name-only` を取得し sandbox 外 path を検出したら `git checkout -- <外側のパス>` で破棄して非ゼロ exit）
- Sandbox サンプル change 一式（小規模 TypeScript 関数 + spec.md + tasks.md + Vitest テスト）
- Codex 経由の TDD 完走検証
- フォールバック動作検証（Codex 認証無効化を擬似的に再現し Opus 側で再実行）
- コスト / 時間計測（Codex vs Opus を同一 sample change で比較）
- TDD 忠実度評価スクリプト `scripts/measure-tdd-fidelity.sh`（git log を機械的に走査し commit ごとにテストファイル / プロダクションファイルの有無を分類、「テスト無し commit 率」を算出）
- `evaluation.md` に4軸スコア表 + Go/No-Go 判定 + 根拠

### 含まないもの
- `longrun-builder-codex` Agent の本実装（理由: Phase 2 で別 plan）
- `longrun-orchestrator` への分岐ロジック追加（理由: Phase 2）
- `plugins/longrun/` のバージョン bump / リリース（理由: Phase 2）
- Codex サブスク残量の事前検出 API（理由: 仕様未確認、Phase 2 で必要なら追加）
- openspec の `specs/` 更新（理由: PoC 用 change のため delta なし）
- 実プロジェクト（block-app 等）での検証（理由: PoC は本リポ内 sandbox に閉じる）

## Changes分解

### change-A: codex-build-agent-poc
- **スコープ**: PoC harness + sandbox サンプル + 評価実行 + evaluation.md 生成までを一括
- **使用スキル**: なし（既存 codex プラグイン CLI と longrun-builder Agent を呼ぶだけ）
- **依存関係**: 独立（このplan は単一changeで完結）
- **config.yaml rules**:
  - "PoC 用ディレクトリ `_longruns/2026-05-13_codex-build-agent-eval/sandbox/` の外を編集してはならない"
  - "Codex CLI 認証情報を sandbox 内にコピー / 出力してはならない（`~/.codex/auth.json` 等を読むのは可、書き出しは禁止）"
  - "`~/.codex/` 配下を一切書き換えない（読み取りのみ）"
  - "`openspec/specs/` を変更しない（PoC 用 change は delta なしで完了）"
  - "evaluation.md には Codex 出力の raw stdout を貼らない（モデル名・所要時間・成功可否などのメタ情報のみ）"
  - "`run-poc.sh` 実行前に `git status --porcelain` を取得し未追跡 / 未コミット差分があれば失敗終了（暴走の差分判別を阻害するため）"
  - "Codex 実行直後に `git diff --name-only HEAD` で sandbox 外パスを検出した場合、`git checkout -- <該当パス>` で即時破棄し非ゼロ exit"
- **生成物**:
  - `_longruns/2026-05-13_codex-build-agent-eval/sandbox/`（TypeScript + Vitest プロジェクト）
  - `_longruns/2026-05-13_codex-build-agent-eval/prompts.md`（Codex への指示プロンプトと反復ログ）
  - `_longruns/2026-05-13_codex-build-agent-eval/scripts/run-poc.sh`
  - `_longruns/2026-05-13_codex-build-agent-eval/scripts/run-fallback.sh`
  - `_longruns/2026-05-13_codex-build-agent-eval/scripts/measure-tdd-fidelity.sh`
  - `_longruns/2026-05-13_codex-build-agent-eval/scripts/tests/*.bats`
  - `_longruns/2026-05-13_codex-build-agent-eval/evaluation.md`

## 画面・UI設計
（なし — CLI のみの PoC）

## データモデル
（なし — 評価結果は evaluation.md にマークダウン表で残すのみ）

`evaluation.md` の構造（参考スケッチ）:

```
# Codex Build Agent PoC 評価レポート

## 環境
- 実行日時 / Codex CLI version / 利用可モデル一覧
- 採用モデル ID（"5.5 Pro 相当"）

## 結果サマリ
| 軸 | 結果 | 備考 |
|----|------|------|
| TDD 完走（Codex） | PASS/FAIL | RED→GREEN サイクル数、テスト件数 |
| フォールバック動作 | PASS/FAIL | 切替トリガ、所要時間 |
| コスト / 時間（Codex vs Opus） | 比較表 | sample change の wall-clock 時間 |
| TDD 忠実度 | スコア | テスト先行率、テスト無し commit 件数 |

## Go/No-Go 判定
- 判定: Go / No-Go
- 根拠: ...
- Phase 2 への引き継ぎ事項: ...
```

## 受け入れ条件

**必須条件（常に含める）:**
1. [ ] change-A の OpenSpec 仕様（proposal / spec / tasks）が作成・レビュー済み
2. [ ] change-A のテスト（sandbox の Vitest + harness の Bats）が作成され全てPASS
3. [ ] ビルドエラーなし（sandbox の `tsc --noEmit` および harness スクリプトの shellcheck 相当が通る）
4. [ ] sandbox 外の既存ファイル（特に `plugins/longrun/` `plugins/codex/` `openspec/specs/` `~/.codex/`）に対する `git diff main` および `stat -f %m` 差分が空である（リポ全体 `npm test` 相当は本リポに存在しないため対象外）

**機能固有の条件:**

5. [ ] `evaluation.md` に Codex CLI で利用可能なモデル一覧と「採用モデル ID」が記載されている。`gpt-5.5-pro` が存在しない場合は **最上位の Pro 系モデル**（一つ前の世代でも可）を採用し、Go/No-Go 判定欄に「5.5 Pro 不在のため代替モデル `<id>` で判定、Phase 2 ではモデル ID 再確認が必須」を明記する

6a. [ ] sandbox 内サンプル change を Codex 経由で `run-poc.sh` から実行し、**Codex 実行ログまたは stdout に `npm test` の RED 出力 → GREEN 出力が 1 セット以上含まれる**ことを確認できる（TDD ループそのものの成立条件）

6b. [ ] 上記実行の最終 `git log` で、テスト先行コミット → 実装コミットの順序が確認できる（コミット粒度制御の成立条件）。**6b が不成立でも 6a が成立すれば「コミット粒度はプロンプト調整余地」として Conditional Go の対象になる**（後述「Phase 2 への引き継ぎ条件」参照）

7. [ ] `run-fallback.sh --simulate-codex-down` で Codex 経路を擬似ダウンさせると、stderr / exit code から検出して Opus 経由 (`longrun-builder` Agent もしくはローカル Claude による同等処理) で sample change を完走できる

8. [ ] `evaluation.md` に Codex 実行 / Opus 実行の wall-clock 時間が双方記録されている（サンプル数 n=1 で良いが、その旨を注記）

9. [ ] `scripts/measure-tdd-fidelity.sh` を実行し、各 commit を `git show --name-only` で「テストファイル (`*.test.ts` / `*.spec.ts`) のみ含む」「プロダクションファイル (`src/**/*.ts`) のみ含む」「両方含む」「どちらも含まない」に分類した結果と、`(プロダクションのみ commit 数) / (全 commit 数)` を「テスト無し率」として evaluation.md に記録

10. [ ] evaluation.md 末尾に Go / No-Go 判定と、Phase 2 plan に引き継ぐべき技術リスクが **最低 5 件** 箇条書きされ、**以下 4 件を必ず含む**:
    - (a) Codex タイムアウト（応答途中で hang）検出方針
    - (b) 部分成功（テストファイルのみ書いて中断）時のロールバック方針
    - (c) サブスク残量切れの判別方法（特定 exit code / stderr パターン）
    - (d) ネットワーク断 vs 認証エラーの判別方法

11. [ ] `plugins/longrun/` 配下のファイルが本 PoC で一切変更されていない（`git diff main -- plugins/longrun` が空）

12. [ ] **Bats テストに「`run-poc.sh` が sandbox 外への書き込みを検出した場合に非ゼロ exit する」ケースが含まれ PASS**（Codex 暴走時の事前ガード自体のテスト）

## 意思決定ガイドライン
- 優先順位: 評価の正確性 > 自動化の完成度 > スクリプトの再利用性
- リスク許容度: 中程度（PoC なので失敗を許容、ただし「失敗した」と明確に記録できる必要あり）
- 不明点の扱い:
  - Codex CLI の挙動で不明な点は手動で 1 回 `codex` を実行してログを取得し、evaluation.md に貼る
  - フォールバック検出ロジックが Codex 側エラーメッセージに依存する場合、観測した stderr パターンを evaluation.md に記録（Phase 2 の検出ルール仕様の素材になる）
  - 「サブスク残量」の事前取得が CLI で不可能と判明したら、それ自体を Phase 2 へのリスクとして記載するだけで本 plan のスコープは閉じる
- **TDD 完走能力とコミット粒度制御能力の混線回避**: 受け入れ条件 #6a が成立し #6b が不成立だった場合、「Codex の TDD 能力は OK だがコミット粒度はプロンプト調整余地あり」と解釈する。即 No-Go にせず、Conditional Go として Phase 2 で「コミット粒度プロンプトテンプレート設計」をタスク化する旨を evaluation.md に記録

## Phase 2 への引き継ぎ条件

evaluation.md の末尾で本 PoC の最終判定を以下の 3 分岐で記録する。**判定セクションは必須**。

- **Go**: 受け入れ条件 #6a #6b #7 がすべて PASS、かつ TDD 忠実度の「テスト無し率」が 0%（テスト無し commit 0 件） → Phase 2 plan (`longrun-builder-codex` Agent 新設 + orchestrator 分岐) の起票を推奨
- **Conditional Go**: #6a と #7 が PASS、#6b と忠実度のいずれかが条件付き → Phase 2 plan で「先に解決すべき技術リスク（コミット粒度プロンプト設計 / TDD 規律強化）」として引き継ぐ
- **No-Go**: #6a または #7 が FAIL、もしくは Bats #12 で sandbox 外書き込みガードが破れた → Phase 2 plan は起票せず、evaluation.md で打ち切り。Codex を Build 委譲先として採用しない理由を記録

## 動作確認方法

- 開発サーバー: なし（CLI のみ）
- テスト:
  - sandbox: `cd _longruns/2026-05-13_codex-build-agent-eval/sandbox && npm install && npm test`
  - harness: `cd _longruns/2026-05-13_codex-build-agent-eval && bats scripts/tests/`
  - リポジトリ全体（regression 確認）: 既存 CI / `npm test` 相当があれば実行、なければ「N/A」と evaluation.md に明記
- 確認手順:
  1. `codex` CLI が認証済みかを `node ${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs status` 相当で確認（プラグインドキュメント参照）
  2. `bash _longruns/2026-05-13_codex-build-agent-eval/scripts/run-poc.sh` を実行し Codex 経由で sandbox change を完走させる
  3. sandbox の `git log --oneline` でテスト先行コミット → 実装コミット → リファクタコミットの順序を目視確認
  4. `bash _longruns/2026-05-13_codex-build-agent-eval/scripts/run-fallback.sh --simulate-codex-down` を実行し、Opus 経由でも sample change が完走することを確認
  5. `cat _longruns/2026-05-13_codex-build-agent-eval/evaluation.md` で 4 軸スコア / Go-NoGo 判定 / Phase 2 引き継ぎ事項を確認
  6. `git diff main -- plugins/longrun` が空であることを確認（受け入れ条件 #11）

## Brain Dumpからの原文メモ
> longrun:plan longrunのbuild部分のエージェントをcodex5.5 proに任せられないかと思っているんだけど、検討して。codex5.5 proをサブスク範囲で使うんだけど、サブスクが使えなかったらopusでフォールバックするイメージ

## 補足: 設計判断ログ（Synthesis 中の決定）

| 判断 | 採用 | 根拠 |
|------|------|------|
| アーキ | 別 Agent 新設 + orchestrator 分岐方針（Phase 2 で実装） | 影響範囲を限定し A/B 比較可能。現 longrun-builder を温存できフォールバックも素直 |
| フォールバック検出 | 実行失敗検出（stderr/exit code 解析） | Codex CLI に quota 事前取得 API が無い前提で最も堅牢。PoC でも擬似ダウンで検証可能 |
| スコープ | Phase 1 = PoC のみ、Phase 2 は別 plan | ブランチ名 `codex-build-agent-eval` の含意と整合。実装まで一気にやるとサブスク仕様未知で stuck リスク |
| 検証対象 | oratta-claude-harness 内 PoC 専用ダミー change | OpenSpec / longrun インフラが手元に揃い、Codex 暴走時の被害範囲を sandbox に閉じられる |
| モデル ID 同定 | PoC 中に `codex` で利用可モデルを調査し、5.5 Pro 相当を採用 | 「5.5 pro」の実在 ID が現時点では不明。PoC で確定させる方が安全 |
| PoC 評価軸 | 完走 / フォールバック / 時間コスト / TDD 忠実度 の 4 軸全採用 | 単独軸では Go/No-Go の根拠が薄い。4 軸あれば Phase 2 リスクも併せて抽出できる |
