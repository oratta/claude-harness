## 1. テスト先行（Red）

- [x] 1.1 `plugins/dev-workflow/tests/spec-decision-and-review.bats` を新設し、SKILL.md（Step B の `^仕様化判断: (する|しない)$` 記録手順・unmanned 非免除・Step D の ff→レビュー→apply の順序・縮退経路のレビュー・workflow 型の代替・2 周キャップと needs-approval・`^仕様レビュー: (APPROVE|REQUEST_CHANGES)$` の投稿手順・model 明示と既定 opus・reserve は自動実行のみ）と `references/spec-review.md`（存在・5 観点・読み取り専用・grep 先行・最新 1 件規則・PR→issue の Closes/Fixes/Refs 解決規則）を grep で検証するテストを書き、失敗を確認する。既存文（Step D の事前分類節・残量モード行）で偽合格しないよう、仕様レビュー節を awk で切り出してから grep する

## 2. 参照文書

- [x] 2.1 `plugins/dev-workflow/skills/github-issue/references/spec-review.md` を新設（前提ツール・入力・5 観点・出力書式・往復上限 2 周・結果コメントの正規表現・複数記録時は最新 1 件・PR→issue の解決規則・モデル選択と残量モード・workflow 型の代替・読み取り専用・grep 先行）
- [x] 2.2 `references/decision-criteria.md` の Step B 節に記録書式への参照を 1 行足す

## 3. SKILL.md

- [x] 3.1 Step B 末尾に判定結果の issue コメント記録手順（正規表現・`gh issue comment` の例・両モード共通・記録前に先へ進まない）を追記
- [x] 3.2 Step D の「仕様化する場合」のコマンド列を `ff → 仕様レビュー → apply → verify → archive` に改め、レビューの spawn 方法（model 明示・既定 opus・事前分類表で fable・残量モード）・APPROVE までの停止・REQUEST_CHANGES の扱い（差分再レビュー 1 回・2 周で needs-approval）・結果コメントの投稿手順（`^仕様レビュー: ...$`）・workflow 型の代替を書く。「重要実装の事前分類」節が `### Step D` 見出しより後にある位置関係は保つ
- [x] 3.3 縮退経路（openspec CLI 直叩き）の記述に同じレビューを追記
- [x] 3.4 SKILL.md の frontmatter version を 1.3.0 に上げ、description と冒頭の概要行のパイプライン列挙に仕様レビュー工程を足す。実行モード表・Step C の interactive 記述（`ff → apply → verify → archive` の列）で記録とレビューが免除されないことを明記

## 4. 配布

- [x] 4.1 `plugins/dev-workflow/.claude-plugin/plugin.json` の version を 1.12.0 に上げ description に仕様レビュー工程を追記、`.claude-plugin/marketplace.json` の dev-workflow の version と description を揃える
- [x] 4.2 `bats plugins/dev-workflow/tests/` を全件実行し exit 0 を確認
