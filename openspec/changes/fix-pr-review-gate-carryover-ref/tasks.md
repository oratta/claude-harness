## 1. 参照先の修正

- [ ] 1.1 change の delta を archive して `openspec/specs/dev-workflow-pr-review-gate/spec.md` に反映し、要件末尾の参照先が新しい文になったことを確かめる。触る範囲: openspec/specs/dev-workflow-pr-review-gate/spec.md:1018（3-c の例外の文）
- [ ] 1.2 変更の記録を書く。触る範囲: plugins/dev-workflow/changes/1423.md（新規）
- [ ] 1.3 確認: `gate-runner.md` の再レビュー を、バッククォートなし・ありの両方の形で `openspec/specs` から grep して 0 件。新しい文 `stages/triage.md` の「W の修正後の再レビュー」の同趣旨の文 が 1 件入ったこと。`openspec validate dev-workflow-pr-review-gate --type spec --strict` が通ること
