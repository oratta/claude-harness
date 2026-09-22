## Why

PR #356（#354）で入れた止める指摘の仕分け表に、Codex レビューが 3 つの穴を見つけた（レビューコメント https://github.com/oratta/claude-harness/pull/356#issuecomment-5771515009 ）。順 3（一覧の一致で閉じる）は、W が表を投稿してから push すると、G が検索した時点ではヒットが置換後で消えていて集合が一致しない（#357）。順 6（決める役の裁定）の依頼には記録先の本文と W の return が入っておらず、決める役は入力契約どおり判断せずに不足を返すので、裁定の経路が止まる（#358）。混在の規則は「順 5＋順 2〜4」しか扱っておらず、順 5 と順 6 が同じ周に残ると、主の回答待ちのまま修正サイクルに戻ったり、順 5 側の質問が漏れたりする（#359）。

次の #355 は、W の一覧表の書式に照合表を揃える前提で進む。表の列をここで確定させる必要がある。

## What Changes

- **順 3 の照合対象を修正前と修正後で分ける（#357）**: W の一覧表のコメントに、修正前 SHA（W が修正に着手する直前の HEAD）を記録する。G は、その SHA で実行した検索のヒット集合と表の全行を照合し、次に HEAD で同じ検索を実行して、残ったヒットがすべて「該当しない理由」の行に対応するかを照合する。表の書式（コメントの見出し行と列）を SKILL.md 順 3 の節に明記し、worker.md はそれを参照する
- **順 6 の依頼に必須入力を足す（#358）**: develop の SKILL.md (4) の `needs-decider` の行の入力に、記録先の本文・判断に必要な関連コメント・W の直近の return を足す。決める役が「足りないもの」を返したら、それを裁定として扱わず（G に渡さない）、本体が補って 1 回だけ依頼し直す
- **順 5 と順 6 が同じ周に混ざったときの処理順を決める（#359）**: G は全件の仕分けを PR コメントに記録して保留を先にする。主の回答が来たら、未処理の順 6 を `needs-decider` で返して裁定を受ける。両方が済んでから、残る修正を 1 回の `agent-review:failed` で W に戻す。手順 6 の「切り出しの確認」行と gate-runner.md の再開節（保留の解除・決める役の裁定受領）を、この処理順に合わせる

範囲外: 1 周目の網羅と照合表の新設（#355）、`agents/decider.md` の入力契約・出力契約（既存の契約に本体の依頼を揃える側の変更なので、decider.md は変えない）、仕分け表の順番と各順の当てる条件そのもの。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 順 3 の照合（修正前 SHA と HEAD の 2 段の照合、一覧表の書式）、W の指示書の一覧表の参照、順 5 と順 6 の混在の処理順、手順 6 の「切り出しの確認」行と順 6 の裁定受領が、未処理の保留・裁定があるうちは failed に進まないこと
- `dev-workflow-develop`: G の `needs-decider` を受けた本体の動き（入力に記録先の本文・関連コメント・W の return を足す、決める役が不足を返したときの扱い）

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`: 手順 2-1 の混在の段落、順 3 の節、順 6 の節の裁定受領の文、手順 6 の保留表の「切り出しの確認」行
- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`: `### 保留のとき`、`### needs-decider のとき`、`## 再開` の「W の修正後の再レビュー」（順 3 の照合）・「レビュアーの要約受領」（混在で保留だけを先に返す）・「保留の解除」・「決める役の裁定受領」
- `plugins/dev-workflow/skills/develop/references/roles/worker.md`: 順 3 の一覧の段落（修正前 SHA を記録すること。書式は SKILL.md 順 3 を参照）
- `plugins/dev-workflow/skills/develop/SKILL.md`: (4) の `needs-decider` の行
- `openspec/specs/dev-workflow-pr-review-gate/spec.md` と `openspec/specs/dev-workflow-develop/spec.md`（archive 時に delta を反映）
- テスト: `plugins/dev-workflow/tests/pr-review-gate-skill.bats`、`plugins/dev-workflow/tests/develop-roles.bats`
- `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の version、`plugins/dev-workflow/CHANGELOG.md`
