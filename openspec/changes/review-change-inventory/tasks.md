## 1. テストを先に書く（TDD）

- [ ] 1.1 `plugins/dev-workflow/tests/pr-review-gate-skill.bats` に、手順 2-1 の `text` ブロック内で `変更点の一覧` → `照合表` → `ハンク被覆` → 自己点検 → 指摘の順になること、各受け入れ条件への対応・検索語・revision-safe な検索コマンド・全ヒット・ハンクごとの指摘番号または `問題なし` を要求することの検査を足す
- [ ] 1.2 同 bats に、固定書式の `場所` 欄の「diff と重なる範囲で 10 行以内」と同じ行に、食い違いの指摘は diff 外を含む 2 か所を書ける但し書きがあること、および Codex 優先度出力の読み替え表が三表の欠落を完全な結果として扱わないことの検査を足す
- [ ] 1.3 照合スクリプト用の bats を追加し、照合表に無いヒットを 1 件含む入力が exit 1 と差分の `file:line` を返すケース、一致する入力が exit 0 のケース、検索結果に無い表の行も差分になるケースを先に書く
- [ ] 1.4 `plugins/dev-workflow/tests/develop-roles.bats` に、G が受け入れ条件・照合表・ハンク被覆を機械照合すること、不足項目だけの追加依頼は 1 回までで残差があれば `needs-reviewer` になること、二周目以降の指摘の四分類を Gate Result に記録することの検査を足す
- [ ] 1.5 `plugins/dev-workflow/tests/test_codex_develop.py` と必要な既存テストに、review phase が gate-runner.md と pr-review-gate SKILL.md を正本として渡し、従来の Codex 雛形と needs-reviewer payload も同じレビュアー向け指示ブロックを参照することの検査を足す
- [ ] 1.6 追加・変更したテストだけを実行し、現行実装に対して期待どおり Red になることを記録する

## 2. 一周目レビュアー契約を実装する

- [ ] 2.1 `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` 手順 2-1 のレビュアー向け `text` ブロックへ、`変更点の一覧`・`照合表`・`ハンク被覆` の固定見出しと表の列、`変更点の一覧 → 照合表 → ハンク被覆 → 自己点検 → 指摘` の順序を追加する。照合表の revision-safe な検索コマンドと全ヒット表は仕分け表の順 3 の一覧契約に揃える
- [ ] 2.2 同ブロックに、変更点ごとの受け入れ条件と検索語、diff 外を含む全ヒットの `一致` / `食い違い: <finding ID>`、全ハンクの finding ID / `問題なし`、保証範囲は一覧に載った項目までであることを追加する
- [ ] 2.3 固定書式の `場所` 欄に、食い違いの指摘だけは変更箇所と diff 外の既存箇所の 2 か所を書ける但し書きを足し、`Codex が優先度付きの形で返したときの読み替え` に三表が出なかった場合の扱いを足す
- [ ] 2.4 `grep -c '変更点の一覧\|照合表\|ハンク被覆' plugins/dev-workflow/skills/pr-review-gate/SKILL.md` が 3 以上で、三語がすべて手順 2-1 のレビュアー向け `text` ブロック内にあることを確認する
- [ ] 2.5 `grep -n 'diff と重なる範囲で 10 行以内' plugins/dev-workflow/skills/pr-review-gate/SKILL.md` の該当行に、食い違いの指摘は diff 外を含む 2 か所を書ける旨があることを確認する

## 3. G の機械照合と効果測定を実装する

- [ ] 3.1 `plugins/dev-workflow/scripts/` に、レビュアーの照合表のヒット集合と G が再実行した grep のヒット集合を比較し、一致なら exit 0、差分があれば exit 1 と missing/extra の `file:line` を出すスクリプトを追加して 1.3 を Green にする
- [ ] 3.2 `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` の一周目処理に、受け入れ条件から変更点 ID への被覆、照合スクリプトによる全ヒット集合、固定 diff の全ハンク被覆を指摘の仕分け前に照合する手順を追加する
- [ ] 3.3 同ファイルに、差分があればレビュー全体ではなく不足項目だけを 1 回追加依頼し、それでも残れば差分を記録して `needs-reviewer` で return し、合格処理へ進まない分岐を追加する
- [ ] 3.4 Gate Result の return/PR コメント契約に、二周目以降の各指摘を `同じ文が複数か所`・`場合分けの漏れ`・`直したつもりで直っていない`・`直しで新しく入った` のいずれか 1 つに分類する欄を追加し、この分類が停止判定と仕分け順を変えないことを書く
- [ ] 3.5 `grep -c '同じ文が複数か所' plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` が 1 以上であることを確認する

## 4. 全レビュー経路を揃えて実測する

- [ ] 4.1 `plugins/dev-workflow/references/subagent-waiting.md` と gate-runner.md の needs-reviewer payload が、三表を含む SKILL.md 手順 2-1 のレビュアー向け指示ブロックを参照することを確認し、足りない参照だけを更新する（表の定義は再掲しない）
- [ ] 4.2 `plugins/dev-workflow/references/codex-develop.md` と `plugins/dev-workflow/scripts/codex-develop.py` の review phase が gate-runner.md と pr-review-gate SKILL.md を fresh reviewer に渡すことを確認し、テストが示す契約欠落があれば更新する
- [ ] 4.3 待ち方の正本と既存の不可条件に従い、レビュアー向け指示ブロックを渡した `codex exec` を 1 回実測し、三表が出たか、出なければ実際の出力形と欠けた表（実測不能なら実測した不可条件）を記録する
- [ ] 4.4 (3b) で 4.3 の実測結果を PR コメントへ投稿し、そのコメント URL を動作確認証拠に含める

## 5. 検証・仕様・版

- [ ] 5.1 `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/develop-roles.bats` と照合スクリプト用 bats を実行し、すべて exit 0 を確認する
- [ ] 5.2 `python3 -m unittest plugins/dev-workflow/tests/test_codex_develop.py` を実行し、exit 0 を確認する
- [ ] 5.3 `bash scripts/test.sh` を実行し、`tests/injection-budget.bats` を含む全件が exit 0 になることを確認する
- [ ] 5.4 `openspec validate review-change-inventory --strict` と `openspec validate --specs --strict` を実行し、どちらも exit 0 になることを確認する
- [ ] 5.5 `origin/main` と open PR の version 変更を確認してから、`plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow version を 1 つ上げ、`plugins/dev-workflow/CHANGELOG.md` に三表・機械照合・四分類を記録する
- [ ] 5.6 issue #355 の受け入れ条件 8 件が、tasks 2.4・2.5・1.3/3.1・4.3/4.4・5.1・5.3・5.4・3.4/3.5 のいずれかに対応していることを最終確認する
