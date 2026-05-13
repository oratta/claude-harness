## 1. Sanitize logic snapshot (削除前先行コピー)

- [x] 1.1 旧 SKILL.md (Step 4) の Layer 1 正規表現セットを `plugins/experience-to-skill/scripts/sanitize.sh` の新規ファイルとしてコピー（Red: tests/sanitize.bats を書いて失敗を確認）
- [x] 1.2 旧 SKILL.md (Step 5) の Layer 2 LLM 意味判定方針を新 SKILL.md のドラフトに転写
- [x] 1.3 コピー結果を grep で確認（流用元喪失を回避）

## 2. New plugin assets (新規実装)

- [x] 2.1 `tests/sanitize.bats` を作成（Red: AWS / OpenAI / Anthropic / GitHub / JWT / PEM / email 各パターンの redact をテスト）
- [x] 2.2 `scripts/sanitize.sh` を実装し 2.1 を PASS させる（Green）
- [x] 2.3 `tests/jsonl-finder.bats` を作成（Red: 正規化関数 + 4 段スキャン順序のテスト）
- [x] 2.4 `scripts/jsonl-finder.sh` を実装し 2.3 を PASS させる（Green）
- [x] 2.5 `tests/fixtures/sample-session.jsonl` を作成（PII/secret 不在を事前確認）
- [x] 2.6 新 `skills/experience-to-skill/SKILL.md` を作成（auto-trigger は「スキル化依頼」フレーズのみ）
- [x] 2.7 新 `commands/e2s-distill.md` を作成（対話完結 1 コマンド、jsonl 探索 → 候補絞り込み → サニタイズ → SKILL.md 生成）

## 3. Old asset deletion (削除実行)

- [x] 3.1 旧 6 commands を削除（e2s-commit / e2s-ok / e2s-rewind / e2s-status / e2s-reflect / 旧 e2s-distill）
- [x] 3.2 旧 SKILL.md を新版で上書き済みであることを確認（差分検証）

## 4. Plugin metadata update

- [x] 4.1 `plugin.json` の commands 配列を `["./commands/e2s-distill.md"]` のみに更新
- [x] 4.2 `plugin.json` の version を `0.2.0` 以上に bump、description / keywords も新設計に合わせる
- [x] 4.3 `.claude-plugin/marketplace.json` の experience-to-skill エントリの version / description / keywords を同期

## 5. README rewrite

- [x] 5.1 `plugins/experience-to-skill/README.md` を新設計（jsonl 起点・対話完結 1 コマンド・スキル化専門）で全面書き直し

## 6. Reference cleanup (他参照修正)

- [x] 6.1 リポジトリ全体から `/e2s:(commit|ok|rewind|status|reflect)` 参照を grep し、削除 or 言い換え
- [x] 6.2 ファイル名ベース検索 `find . -name 'e2s-commit.md' -o ...` が 0 件
- [x] 6.3 plugin.json の commands 配列に `e2s-distill` のみ含まれていることを確認
- [x] 6.4 意図的に残す参照を `_longruns/2026-05-13_e2s-skill-llm-logs/decisions.md` の「許可リスト」セクションに明示

## 7. Verification

- [x] 7.1 `bats plugins/experience-to-skill/tests/*.bats` 全 PASS
- [x] 7.2 `openspec validate experience-to-skill-jsonl-refocus --strict` PASS
- [x] 7.3 `jq` で plugin.json と marketplace.json の整合性確認
- [x] 7.4 verification-guide.md のテスト実装完了 / ロジック実装完了 を [x] にマーク
