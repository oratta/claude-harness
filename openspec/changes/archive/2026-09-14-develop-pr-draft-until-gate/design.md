## Context

develop の 1 ループは W → R1 → W → G で回り、W の (3b) が PR を Ready にしてから G が pr-review-gate の手順 1〜5 を実行する。flatmate は CI を「Draft でない PR だけ」で回す設定にしたので、Ready を G の合格時まで遅らせれば CI はゲート合格後の 1 回だけになる。Draft で CI を止める設計は flatmate 固有ではなく、harness が配布する `plugins/infra/templates/workflows/ci.yml.template` も同じ形である（`pull_request` の types に `ready_for_review` を含め、Draft 中は job 側の `draft == false` ガードで skip する）。

auto-merge workflow（`templates/auto-merge/` から展開し、harness 自身にも配備済み）は次の 3 つのイベントで PR を判定する。

| イベント | 判定のタイミング | draft の PR |
|---|---|---|
| `pull_request_target: labeled` | ラベルが付いた瞬間 | スキップ |
| `workflow_run: CI completed` | CI の run が終わった瞬間 | スキップ |
| `schedule`（日次 20:23 UTC） | 1 日 1 回 | スキップ |

CI green の判定は必須チェックの名前ごとに最新 run の conclusion だけを見るので、Draft 中の skipped と Ready 後の success が同じ SHA に並んでも green になる（flatmate で実測済み）。

CI の設定はリポで違う。flatmate は Draft で CI を止め、Ready 化（`ready_for_review`）で走らせる。harness 自身の `.github/workflows/ci.yml` は `pull_request:` の既定 types（opened / synchronize / reopened）だけで、Draft でも走り、Ready 化では走らない。

## Goals / Non-Goals

**Goals:**

- develop 経由の PR はゲート合格まで Draft のまま進み、合格処理で Draft が外れる
- CI を Draft で止めるリポでも止めないリポでも、合格から auto-merge までの時間が今より延びない
- 人間が作った非 Draft の PR をゲートに通しても手順が壊れない
- 合格後に commit を積んでゲートを取り直すあいだも Draft に戻し、CI を Draft で止めるリポでの取り直し 1 周あたりの CI を、合格後の最初の push で 1 回と合格時の Ready 化で 1 回に収める（Draft に戻すのは G の手順 1 なので、その前の最初の push は非 Draft の PR への synchronize として CI が走る）

**Non-Goals:**

- flatmate の無人ループの憲法（`docs/agent-loop.md`）の書き換え。flatmate 側で別 issue にする
- auto-merge workflow と `docs/auto-merge.md` の変更（draft スキップと workflow_run の拾い直しは既にある）
- harness 自身の ci.yml を Draft で止める設定にすること
- リポ直下の `CLAUDE.md` / `AGENTS.md` の PR 運用ルールの文言（「動作確認まで終わったら Ready for Review に切り替えて merge する」は、ゲート合格時に Ready になる新しい流れと矛盾しない。聖域でもあるので触らない）

## Decisions

### Ready 化とラベル付与の順序: `gh pr ready` → `agent-review:passed`

issue #304 の本文は「passed を付けたあとに `gh pr ready`」を指定しているが、この change は逆の「Ready にしてから passed」を採る。

passed → Ready の順だと、passed を付けた瞬間の labeled イベントは PR が draft なのでスキップされる。そのあと Ready 化で CI が走るリポ（flatmate）は CI 完了の workflow_run で拾われるが、Ready 化で CI が走らないリポ（harness 自身。CI は Draft 中に済んで green）では次に来るイベントが日次 schedule しかなく、合格からマージまで最大 24 時間待つ。issue 本文の「CI を Draft で止めていないリポでは壊れるものは無い」は、auto-merge を配備したリポでは成り立たない。

Ready → passed の順だと、どちらのリポでも待ちが生じない。

| リポの CI 設定 | Ready 化の時点 | passed 付与（labeled）の時点 | 結果 |
|---|---|---|---|
| Draft で止める（flatmate） | CI が走り始める | CI 実行中なら green でないのでスキップ | CI 完了の workflow_run で passed が見えてマージ |
| 同上で、CI が passed 付与より先に終わった場合 | CI 完了の workflow_run は passed が無くスキップ | CI が green なのでマージ | マージ |
| Draft で止めない（harness） | 何も起きない（CI は Draft 中に green） | green なのでマージ | マージ |

issue 本文が心配した「CI 完了時点で合格ラベルが無く auto-merge が拾えない時間」は、その直後の labeled イベントが拾うので生じない。

検討した他の案:

- passed → Ready → auto-merge を `workflow_dispatch` で起動する: 操作が 1 つ増え、G に workflow 起動の権限と手順が要る。Ready → passed の順だけで足りるので採らない
- passed → Ready のまま、Draft で止めないリポでは Ready を先に済ませる: リポの CI 設定を G が読み分ける必要があり、判定を誤ると 24 時間待ちに戻る

### Ready 化は「Draft なら」だけ行い、実測確認に `draft: false` を加える

手順 5 で `gh api repos/$R/pulls/$N --jq .draft` が `true` のときだけ `gh pr ready $N` を実行する。人間が作った非 Draft の PR では何もしない。合格処理の最後の実測確認（ラベル 3 点）に「PR の `draft` が `false`」を足す。`gh` は静かに失敗することがあり、draft のまま passed が付くと auto-merge が永久にスキップするため。

### 取り直しで Draft に戻す条件: stale passed を外したときに Draft でなければ

手順 1 で stale な `agent-review:passed` を外したとき、PR が Draft でなければ `gh pr ready --undo $N` を実行する。passed が付いていなかった PR（初回のゲート、failed からの再レビュー、保留からの再開）では何もしない。

- 初回のゲートで常に Draft に戻す案は採らない。人間が非 Draft で作った PR が、ゲートの結果が failed や保留になったまま Draft で残る
- Draft に戻さない案は採らない。合格後に commit を積んだ PR は非 Draft のままなので、取り直しの周回ごとに CI が走り、この change の目的に反する
- 人間が作った非 Draft の PR が一度合格してから取り直しになった場合は、この条件で Draft に戻り、次の合格で Ready に戻る。保留で止まればその間 Draft のまま見える（下の Risks）

### W の (3b) は PR を Draft のまま用意する

記録先が Draft PR ならそのまま使い、issue が記録先なら interactive でも `gh pr create --draft` で作る（unmanned は既に Draft）。worker.md と SKILL.md の (3b) の記述は「Draft のまま G に渡す（Ready 化は G が pr-review-gate 手順 5 で行う）」とし、「Ready に切り替える」を W の作業として書かない。受け入れ条件の `grep -n "Ready"` で出てくる行は、W が Ready にしないこと、または G が行うことを述べる行だけにする。

### flatmate の実 PR での確認はマージ後に issue で行う

受け入れ条件のうち「flatmate の実 PR 1 本で、合格まで CI が skipped、Ready 化で CI が 1 回、auto-merge でマージ」は、この change がマージされ flatmate 側のプラグインが更新されたあとでないと実施できない。harness の PR 本文は `Refs #304` とし（pr-review-gate の記録先の解決は `Refs` でも issue #304 を指す）、マージで issue を閉じない。確認結果（run ID と jobs API の出力）を issue #304 にコメントしてから閉じる。harness の PR のゲート合格条件には含めない。

## Risks / Trade-offs

- [Ready 化と passed 付与のあいだで G が止まると、passed の無い非 Draft の PR が残る] → 次にゲートを回すと手順 1 では passed が無いので Draft に戻らず、取り直しの周回で CI が走る。止まった直後の再開では手順 5 から続けるので実害は CI 1〜数回ぶん
- [Ready 化と passed 付与のあいだで止まり、passed を付けたあとの判定イベントを取り逃がした] → `docs/auto-merge.md` の手動実行（`workflow_dispatch` の `pr` 入力）で再判定できる
- [取り直しでは CI が 1 周あたり 2 回走る（合格後の最初の push が非 Draft への synchronize で 1 回、合格時の Ready 化で 1 回）] → Draft に戻すのは push を受けて G が手順 1 を始めたときなので、最初の 1 回は避けられない。戻さなければ取り直しの push のたびに走る
- [人間が作った非 Draft の PR が合格後の取り直しで保留になると、主の回答待ちの間 Draft に見える] → 保留コメントに Draft に戻した旨が残る。主の回答後に合格すれば Ready に戻る
- [flatmate の憲法が自分で Ready にしていると、無人ループでは CI が今までどおり走る] → flatmate 側の別 issue で揃える。harness 側の変更だけでは壊れない
- [Ready 化で CI が走らないリポで、Draft 中の CI が失敗していた場合] → labeled 時点で green でないのでマージされない（今と同じ fail-closed）

## Migration Plan

dev-workflow のバージョンを上げて配布する。古いキャッシュの worker.md を読んだ W は (3b) で Ready にするが、その場合も手順 5 の Ready 化は「Draft なら」なので二重実行にならない。ロールバックは PR の revert で足りる。

## Open Questions

（なし。順序を issue 本文から変えた判断は本体と R1 の確認対象）
