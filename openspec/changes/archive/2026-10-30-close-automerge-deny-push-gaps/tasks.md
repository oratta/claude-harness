# Tasks

## 1. deny の境界を拡張し回帰検証と説明を揃える

R1 の APPROVE が issue #629 に記録されるまで実装しない。行番号は固定 HEAD 219ccc5a 時点の案内。編集前に当該範囲を読む。実装対象は以下の 5 ファイル内に留める。

- [x] 1.1 公式仕様の照合再現を既存 Bats の deny 節に追加する。design.md のモデル対照と前後のケース表を基に、前置/中置/後置の 4 オプション、値付き lease、main/master の短縮・完全修飾 refspec（末尾/後続引数あり/複数 refspec）、通常 feature push と `main-fix` / `master-fix` の非一致を、読み込んだ実際の JSON 配列で検証する。テスト用に現在の旧 7 件を使い追加前の穴も対照として確認する。公式例によるモデル対照を入れ、モデル検証を実マッチャー実測と呼ばない。新しいテストは現在の 7 件だけでは拒否追加ケースで失敗することを一度確認し、同じ失敗を繰り返さない。触る範囲: plugins/dev-workflow/tests/automerge-templates.bats:284-320（deny 節）
- [x] 1.2 design.md の 18 件を deny 配列に追加し、既存 7 件を保持する。`jq -e '.permissions.deny | length == 25 and (unique | length == 25)' plugins/dev-workflow/templates/auto-merge/.claude/settings.json` と `bats plugins/dev-workflow/tests/automerge-templates.bats` が exit 0 となり、1.1 の一致/不一致と既存マージ手順の保持テストが通ることを確認する。触る範囲: plugins/dev-workflow/templates/auto-merge/.claude/settings.json:3-11（permissions.deny）
- [x] 1.3 README の 7 件を 25 件に直し、配布用ガイドの deny 表にオプション位置・refspec 境界・照合範囲を説明する。`git push origin feature/foo` と `git push -u origin feature/foo` は deny 非一致であることと、既存 deny を保持する展開手順を確認する。`bats plugins/dev-workflow/tests/automerge-templates.bats` の docs / マージ手順テストが exit 0。triage の deny 表の実在箇所はテンプレート内で、ルートの docs/auto-merge.md ではない。触る範囲: plugins/dev-workflow/templates/auto-merge/README.md:92-114、plugins/dev-workflow/templates/auto-merge/docs/auto-merge.md:331-350
- [x] 1.4 `plugins/dev-workflow/changes/629.md` に参照 URL・公式仕様の確認日・照合再現の範囲・既存/追加後の結果・過剰一致の棄却例・実行コマンド/終了コードを残す。`claude` は起動せず、公開された決定論的な実マッチャー呼出方法が確認できなければ「公式仕様に基づく照合の再現、実マッチャー未実測」と明記する。実測したと宣言しない。追加 18 / 合計 25 件と既存保護の保持を確認し、版を上げない。触る範囲: plugins/dev-workflow/changes/629.md（新規）

## Workflow follow-up

- 上の検証結果を付して implement 段を return する。issue 本文の「実マッチャーで確認済み」と同等の実測証拠はないため、triage の再現経路で評価した事実と限界をレビュアーへ渡す。
- archive、PR、レビューと状態遷移は担当する後続工程で行う。マージ・auto-merge 有効化はこの worker では行わない。
