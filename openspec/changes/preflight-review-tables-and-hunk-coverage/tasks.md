# Tasks

行番号は仕様作成時の HEAD 700c49415109f276059174b0d1f36ac43e4e0125 による案内。編集前に該当箇所を読み直す。実装開始は記録先の R1 APPROVE 確認後とする。

## 1. 投稿前の照合表の自己検査（受け入れ条件 1）

- [ ] 1.1 reviewer-brief.md の自己点検に、最終の語ごとの表を既存の review-hit-set.py で投稿前に検査し、非 0 なら直して再実行する手順を書く。抜粋・列名変更・零件のプレースホルダ・パスのバッククォート、要約の既存契約、実行不可時の報告、要約の語数／コマンド／exit code を明記する。指示ブロックの順序と区画の読む範囲は維持し、1.3 の契約テストで確認する。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/reviewer-brief.md:28-40（自己点検）
- [ ] 1.2 合成 Git リポジトリで 4 種の不正形をそれぞれ渡す回帰テストを既存の検査スイートに追加する。不正な表が exit 1 で具体的な contract:/missing:/extra: を出し、同じ SHA・検索語・判定を保った修正版が exit 0 になること、0 ヒットの空表・正しい全ヒット要約は成功することを `bats plugins/dev-workflow/tests/review-hit-set.bats` で確認する。スクリプト本体の許容形式は変えない。触る範囲: plugins/dev-workflow/tests/review-hit-set.bats:1-869（既存 fixture と検査）
- [ ] 1.3 新しい自己検査指示が投稿前の最終表・語ごとのコマンド・修正後の再実行・結果の記録を要求し、実行不可を成功扱いしないことを契約テストに追加し、`bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` が成功することを確認する。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:1170-1289（三表と自己点検の契約）

## 2. 補足要求前の未被覆ハンク一覧（受け入れ条件 2）

- [ ] 2.1 G の既存の全ハンク集合比較に、新規ファイルを含むこと、全区画の実際の行だけを被覆に数えること、補足要求前にファイルと正確なヘッダーで残差を全件列挙することを明記する。文章だけの「他区画で被覆済み」や「新規」をヘッダーの代用にしない。補足先と回数の規則は既存のままにし、2.2 の契約テストで確認する。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/gate-triage.md:5-19（一周目の照合と補足受領）
- [ ] 2.2 G の指示が `@@ -0,0 +1,N @@` の新規ハンク・ファイルとヘッダーによる残差一覧・補足前の列挙・実際の被覆行との比較を要求する契約テストを追加する。補足後の残差は review-incomplete のままであることも `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` で確認する。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:1170-1400（三表・区画の照合契約）

## 3. 固定 HEAD の再照合と統合確認（受け入れ条件 3）

- [ ] 3.1 design.md に列挙した #1703 の元の表＋補足 3 コメントを取得し、固定 HEAD f5c801dc4985c664e99ac8cc7ff0b10367523964 で最新の語ごとの表を抽出する。原資料と修正版・ログは cwd 外の一時ディレクトリへ置く。4 種の不正形を検出→同じ SHA・検索語・判定で書式修正→全対象語の exit 0 を確かめ、語ごとの出力・終了コードと URL を変更記録に残す。後の HEAD の表への置換、元のコメントの編集はしない。触る範囲: plugins/dev-workflow/changes/1765.md（新規）
- [ ] 3.2 同じ固定 HEAD の PR diff と実際の被覆行の和集合を突き合わせ、新規 3 ファイル（gate-result.md / pr-token-budget.md / worker-recovery.md）とヘッダーが「新規」だけの changes/1685.md の残差を列挙する。実行コマンド・終了コード・ファイルとヘッダーの残差一覧を変更記録へ残し、2.1 の指示で補足前に示す内容と一致することを確認する。触る範囲: plugins/dev-workflow/changes/1765.md（新規）
- [ ] 3.3 `bats plugins/dev-workflow/tests/review-hit-set.bats plugins/dev-workflow/tests/pr-review-gate-skill.bats tests/gate-reading-budget.bats` と `openspec validate preflight-review-tables-and-hunk-coverage --type change --strict`、`git diff --check` を実行し、各終了コードを記録する。予算の引上げや新規スクリプトが必要だと判明した場合は、範囲を広げる前に本体へ報告する。触る範囲: plugins/dev-workflow/changes/1765.md（新規）

## Workflow follow-up

- finish 段で通常の仕様同期と archive を行う。同期対象は openspec/specs/dev-workflow-pr-review-gate/spec.md:448-482 と :887-928 の 2 要件。
- PR 本文に「載せる前の自己検出」の選択と design.md の採用理由、#1703 の再照合記録への案内を載せる。PR 作成は (3b) で行う。
