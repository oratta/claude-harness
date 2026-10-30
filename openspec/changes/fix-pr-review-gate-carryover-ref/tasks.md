## 1. 参照先の修正

- [x] 1.1 archive の前に確認する: `openspec validate fix-pr-review-gate-carryover-ref --type change --strict` が通ること（archive 後は change として実行できない。`openspec validate dev-workflow-pr-review-gate --type spec --strict` は HEAD の時点で既存の WARNING 53 件により exit 1 なので完了条件にしない）
- [ ] 1.2 change の delta を archive して `openspec/specs/dev-workflow-pr-review-gate/spec.md` に反映する。触る範囲: openspec/specs/dev-workflow-pr-review-gate/spec.md:1018（3-c の例外の文）
- [ ] 1.3 archive 後に `grep -rn` で確かめる: `grep -rn 'gate-runner.md の再レビュー' openspec/specs` と `` grep -rn '`gate-runner.md` の再レビュー' openspec/specs `` がどちらも 0 件。`grep -rn '`stages/triage.md` の「W の修正後の再レビュー」の同趣旨の文' openspec/specs` が 1 件（`-r` なしだとディレクトリ指定でエラーになり、見た目が 0 件になる）
- [x] 1.4 変更の記録を書く。範囲外の注意として次を含める: Draft PR #1436 が triage.md を分割すると「手順 1 から全工程をやり直す」は stages/prepare.md にだけ残り、今回の参照先が再び古くなる。PR #1195 は同じ spec の 1018 行目を書き換えていて、衝突の解消で丸ごと採ると今回の直しが消える。触る範囲: plugins/dev-workflow/changes/1423.md（新規）
