## MODIFIED Requirements

### Requirement: G が passed を返したら本体が CI を見張る
`skills/develop/SKILL.md` の (4) は、G が `passed` を return したあと、本体が `plugins/dev-workflow/references/ci-watch.md` の手順で CI の見張りを始めることを書かなければならない（MUST）。G の `passed` の return に `issue で承認済み:` の行があれば、本体は見張りを始める前に、主へその行（宣言コメントの URL・当たった分類・引用した issue の文）を 1 回伝えなければならない（MUST。pr-review-gate 手順 5 の事後報告。auto-merge 配備リポではマージまで主との会話が起きないため、本体の手順に置かないと報告が起きない）。見張りの一手が `fix` のときは、本体が W に直させる（MUST）。担当と段の分岐は `references/decision-criteria.md` Step B の軽い通し方の小節に定め、SKILL.md の passed 分岐と共有 reference の直し方から参照できなければならない（MUST）。軽い通し方（記録先の最新の仕様化判断に `通し方: 軽い` の行がある PR）では、本体が同じ worktree に W を `段: spec` で新しく起こし、PR・記録先・`fix` の観測（`ci-fail` または `conflict` と失敗したチェック・run などの修正材料）を渡す（SHALL）。起動指示には `plugins/dev-workflow/references/ci-watch.md`「7. 直し方」に従うこと（最初の push の前に手順 3 の passed 解除・Draft 化・pending 付与）と、`ci-fail` の関係確認を仕様化判断の再投稿より先に行うことを含める（SHALL）。存在しない W の再開や本体による直接修正をしてはならない（MUST NOT）。新しい W は、`ci-fail` では仕様化判断の手順に入る前に共有手順「7. 直し方」手順 2 の失敗ログと PR 差分の関係確認を行い、同文書「5. `--unrelated` を渡す基準」で差分と無関係と判断できた場合は、仕様化判断を投稿し直さず、artifact 作成・修正・push をせずにチェック名と根拠を本体へ返さなければならない（MUST）。この場合は最新の `通し方: 軽い` の判断を保持し、passed 解除・Draft 化・pending 付与にも進まず、本体が同じ PR・同じ状態ファイルで既存の `next --unrelated <チェック名> --after-fix` を 1 回だけ実行してその一手に従う（SHALL）。関係がある場合、または無関係と判断できない場合は、この確認のあと、実装前に同じ記録先へ `通し方:` の行の無い仕様化判断を投稿し直す（SHALL。「する」か「しない」かは W が決め直す）。`conflict` はこの無関係返却の対象とせず、従来どおり判断を投稿し直す（SHALL）。修正に進む場合、以後は通常の通し方で、仕様化するなら artifact 一式と R1 の APPROVE を経て実装し、どちらの判断でもテストを書き、修正を同じ PR に積む（SHALL）。同じ記録先へ `通し方: 軽い` を投稿し直してはならない（MUST NOT）。通常経路で既存 W がある場合（軽い通し方から既に通常へ戻った PR を含む）は、W を `段: implement` で再開し、再開か手渡しかは `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」に従う（SHALL）。この場合は CI 見張りの `fix` だけを理由に `段: spec` へ戻したり仕様化判断を投稿し直したりしない（SHALL）。軽い通し方から戻した W の仕様化途中の push では見張りに戻らず、通常経路の (1) → R1（仕様化する場合）→ (3a) → (3b) を進め、(3b) の return を受けてから `wait` → `next` に戻る（SHALL）。通常経路の既存 W が push したら本体が passed を外したまま同じ状態ファイルで `wait` → `next` を続け（CI のやり直し・再度の直しもここで処理する）、`ready` になってから前提確認と重さ判定の G を新しく起こしてゲートを取り直させ、G が再び `passed` を返したら見張りの続き（reference の「`ready` を受けたあと」）に進むこと、合格するまでマージ待ち・マージ依頼に進まないことを書く（MUST）。見張りの中身は reference を参照し、SKILL.md に言い換えて再掲してはならない（MUST NOT）。

**復帰判定の守備範囲**: 入力は CI 見張りが返した `fix` の観測（`ci-fail` / `conflict`、チェック・run など）、記録先（issue または Draft PR）の最新の仕様化判断、本体が把握している W の有無と再開・手渡しの可否である。この判定は、存在しない W の再開、本体による直接修正、軽い判断を残したままの implement 起動、古い判断に基づく通常復帰後の spec 再起動を拾うために、担当・起動段・判断記録の接続を定める。CI 失敗と PR 差分の因果関係まで保証するものではなく、見張りが `fix` と判定した失敗を W がログ確認後に差分と無関係と判断し、修正・push せず本体へ返し、共有手順の `next --unrelated <チェック名> --after-fix` に進むことを許す。軽い通し方から起きた新しい W では、この関係確認は通常判断の再投稿より前に行い、無関係と判明した失敗では最新判断だけを通常化してはならない（MUST NOT）。完了条件は上記の接続を手順と関係テストで確認することであり、観測や W の判断に残る穴をすべて塞ぎ切ることを完了条件にしてはならない（MUST NOT）。

G の指示書 `skills/develop/references/roles/gate-runner.md` は、G が CI の見張りを始めずに `passed` を return することを書かなければならない（MUST）。unmanned モードは (4) を回さないので、この見張りの対象外とする。

#### Scenario: (4) の passed のあとに本体が見張る
- **WHEN** `skills/develop/SKILL.md` の (4) を読む
- **THEN** `passed` を受けた本体が `references/ci-watch.md` の手順で見張りを始めること、`fix` なら W に直させ、軽い通し方から戻した W は (3b) の return 後、通常経路の既存 W は push のあと passed を外したまま `wait` → `next` を続けて `ready` になってから G にゲートを取り直させることが書かれている

#### Scenario: G は見張りを始めない
- **WHEN** `skills/develop/references/roles/gate-runner.md` を読む
- **THEN** G が CI の見張りを始めずに `passed` を return することが書かれている

#### Scenario: issue で承認済みの passed は見張りの前に主へ伝える
- **WHEN** `skills/develop/SKILL.md` の (4) の passed の行を読む
- **THEN** return に `issue で承認済み:` の行があれば、CI の見張りを始める前に主へその行（宣言 URL・分類・引用）を 1 回伝えることが書かれている

#### Scenario: 軽い通し方の passed 後に CI 失敗の fix を受ける
- **WHEN** W 未起動で、記録先の最新の仕様化判断に `通し方: 軽い` の行がある PR に対して、CI 見張りが `ci-fail` による `fix` を返す
- **THEN** 本体は同じ worktree に新しい W を `段: spec` で起こし、PR・記録先・失敗したチェックと run を含む観測を渡す。本体は自分で直さず、W は仕様化判断の手順に入る前に共有手順で失敗ログと PR 差分の関係を確かめる。関係がある、または無関係と判断できない場合は、確認のあと実装前に `通し方:` の無い仕様化判断を同じ記録先へ投稿し直す

#### Scenario: 軽い通し方の passed 後に競合の fix を受ける
- **WHEN** 同じ軽い通し方の PR に対して、CI 見張りが `conflict` による `fix` を返す
- **THEN** CI 失敗の場合と同じく、新しい W が `段: spec` から通常経路への判断を記録し直す。競合だけを理由に本体修正や `段: implement` の新規起動に短絡しない

#### Scenario: 新しい W が仕様化すると判断する
- **WHEN** 軽い通し方の fix から起きた W が `仕様化判断: する` を投稿し直す
- **THEN** `通し方:` の行は付けず、artifact 一式を作り R1 の APPROVE 後にテストと修正を同じ PR に積む

#### Scenario: 新しい W が仕様化しないと判断する
- **WHEN** 軽い通し方の fix から起きた W が `仕様化判断: しない` を投稿し直す
- **THEN** `通し方:` の行は付けず、通常経路の実装工程でテストと修正を同じ PR に積む。過去の軽い判断は履歴に残っても最新の判断としては使わない

#### Scenario: 通常経路の既存 W が CI の fix を直す
- **WHEN** 最新の仕様化判断が軽い通し方ではなく、通常経路の既存 W がいる PR に CI 見張りが `fix` を返す
- **THEN** 本体は既存 W を `段: implement` で再開する。手渡しは正本の許可条件を満たすときだけ行い、CI の fix だけを理由に spec 段や仕様化判断の投稿をやり直さない

#### Scenario: 通常経路へ戻した後にもう一度 fix を受ける
- **WHEN** 軽い通し方から通常へ戻した PR で、W の修正 push 後に CI 見張りが再び `fix` を返す
- **THEN** 最新の仕様化判断には `通し方: 軽い` が無いので、既存 W の `段: implement` の再開／許可された手渡しを使い、新しい spec 段の W を重ねて起こさない

#### Scenario: 軽い通し方から戻した W の仕様化途中の push では見張りを再開しない
- **WHEN** 軽い通し方の fix から起きた W が仕様化の段で push し、R1 の APPROVE と (3b) の return がまだない
- **THEN** 起動指示で渡した「7. 直し方」の手順 3 により最初の push 前に passed 解除・Draft 化・pending 付与を済ませる。本体は見張りの wait / next に戻らず、R1 の APPROVE を経て (3a) → (3b) を進める

#### Scenario: 両経路とも同じ見張りの続きからゲートを取り直す
- **WHEN** 新しく起きた W が CI 見張りの fix を直して (3b) の return を返す、または通常経路の既存 W が修正を同じ PR に push する
- **THEN** 本体は passed を外したまま同じ状態ファイルの `wait` → `next` を続け、`ready` になってから前提確認と重さ判定の G を新しく起こす。合格するまでマージ待ち・マージ依頼に進まない

#### Scenario: 新しい W が失敗を差分と無関係と判断したら軽い判断を保持する
- **WHEN** 最新判断が `通し方: 軽い` の PR の `ci-fail` による fix から起きた新しい spec 段 W が、判断再投稿前のログと差分の確認で、共有手順の無関係の 2 条件を満たすと判断する
- **THEN** W は仕様化判断の再投稿・artifact 作成・修正・push をせず、チェック名と根拠を本体へ返す。最新判断は軽いままで、passed 解除・Draft 化・pending 付与に進まない。本体は同じ PR・同じ状態ファイルで `next --unrelated <チェック名> --after-fix` を 1 回だけ実行し、その一手に従う

#### Scenario: 判断不能なら関係確認のあと通常復帰する
- **WHEN** 同じ新しい W がログと PR 差分を確かめても、共有手順の無関係の 2 条件を両方満たすとは判断できない
- **THEN** 無関係として返さず、確認のあと `通し方:` の行の無い仕様化判断を投稿し直す。「する」なら artifact 一式と R1 の APPROVE を経て実装し、どちらの判断でもテストと修正を同じ PR に積む

#### Scenario: spec 段の一般手順より先に CI 失敗の関係を確認する
- **WHEN** 軽い通し方の CI fix から新しい W を起こす指示と `roles/worker/spec.md` を読む
- **THEN** decision-criteria.md の復帰手順へ接続し、`ci-fail` の関係確認を仕様化判断の投稿より先に行い、無関係なら判断記録の手順へ入らず返すことが一意に定まる
