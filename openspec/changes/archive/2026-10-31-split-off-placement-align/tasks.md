## 1. triage.md・spec・bats

- [x] 1.1 `stages/triage.md` の置き場所の段落に、「この件の『follow-up issue に切る』は、新しい issue を作る場合と、段 C の表のとおり既存 issue で受ける場合の両方を指す」旨の 1 文を足し、さらに `stages/triage.md` の「主が切り出すと答えた止める指摘の置き場所」の「必ず follow-up issue にする」を「必ず issue で追跡する（新しい issue を作るか、段 C の表のとおり既存 issue の受け入れ条件に足す）」に直す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:119-119
- [x] 1.2 `bats` の検査行を新しい文言に直し、has_all にその定義の語（「既存 issue で受ける」）を足す。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:778-778
- [x] 1.3 delta が specs/ に作成済みであることを確かめる（main の spec は change の archive で更新される）

## 2. gate-runner.md

- [x] 2.1 「時点ごとに読むファイル」の表の保留の解除の行に、切り出しの確認に「切り出す」と答えられたときは加えて `stages/triage.md` の置き場所の段落・候補探し・段 C の節を読む、と書く。触る範囲: plugins/dev-workflow/skills/develop/references/roles/gate-runner.md:22-24
- [x] 2.2 `develop-roles.bats` に保留の解除の行の検査を足す（既存の gate-runner の表の検査の近く）。触る範囲: plugins/dev-workflow/tests/develop-roles.bats:850-885

## 3. 記録と push 前の確認

- [x] 3.1 変更の記録 `plugins/dev-workflow/changes/1016.md` を書く
- [ ] 3.2 push 前に origin/main と開いた PR を確かめる。PR #1436（#580）は置き場所の段落を `stages/triage-nonblocking.md` に移す。まだ開いている間は triage.md を直し、移っていたら移った先の同じ段落を直す。PR #1436 が先にマージされたら、`gate-runner.md` の保留の解除の行（22 行付近）と、要件の定義の文にある `stages/hold.md` のパス（切り出しの確認の行は `stages/hold-resume.md` へ移る）も読み替える
