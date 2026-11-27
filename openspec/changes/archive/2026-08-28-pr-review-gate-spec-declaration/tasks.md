## 1. テスト先行（Red）

- [x] 1.1 `plugins/dev-workflow/tests/spec-touch-check.bats` を新設し、spec の 4 Scenario（規範接触＋差分なし→2 / 差分あり→0 / 非接触→0 / `.spec-touch-paths` 置き換え）を `SPEC_TOUCH_FILES` 経由で検証するテストを書く
- [x] 1.2 `plugins/dev-workflow/tests/pr-review-gate-spec-declaration.bats` を新設し、SKILL.md（冒頭必須点・手順 3 の 2 形テンプレ・手順 5 の 3 見出し実測・整合表 3 行・issue→PR の順・spec-touch-check 参照・auto-merge 範囲外）と manifest/skill の version を grep で検証する。手順 3・5 は awk で節を切り出してから grep する

## 2. スクリプト

- [x] 2.1 `plugins/dev-workflow/scripts/spec-touch-check.sh` を実装（bash・`set -euo pipefail`・`SPEC_TOUCH_FILES` / `gh pr diff --name-only` / `.spec-touch-paths` / 終了コード 0・1・2）

## 3. SKILL.md

- [x] 3.1 冒頭の必須点を 4 点に改め、「前提と理由」に仕様宣言の位置づけ（判断記録の契約は `github-issue/references/spec-review.md`）と auto-merge 範囲外を追記
- [x] 3.2 手順 3 に仕様宣言（`## 仕様宣言`・`対象 HEAD:`・2 形テンプレ）を追加。既存のリスク宣言の文言は変えない
- [x] 3.3 手順 5 の「両方」を「3 見出しすべて」に書き換え、冒頭「前提と理由」の HEAD SHA 段落にも仕様宣言を足す。手順 5 に 3 見出しの実測・archive 済み change の実測（スタック PR）・「しない」＋openspec 差分ありの矛盾・issue 記録との整合表・issue→PR の順・`spec-touch-check.sh` の実行と exit 2 時の要求を追加。`grep -cF '層間契約'` / `'聖域パス・マージ権限'` の件数（model-escalation-policy.bats が 1 件固定）を増やさない

## 4. 配布

- [x] 4.1 plugin.json 1.13.0・skill frontmatter version 上げ・marketplace.json 同期（description に仕様宣言を追記）
- [x] 4.2 `bats plugins/dev-workflow/tests/ tests/` 全件 exit 0 を確認
