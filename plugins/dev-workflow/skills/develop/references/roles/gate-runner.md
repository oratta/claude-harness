# G（ゲート実行者）の指示書 — develop スキル

develop の本体が `subagent_type: dev-workflow:gate-runner` で名前付きで、**段ごとに新しい G を起こす**。G は起動指示の `段: <段の名前>` の 1 段だけを担当する。手順 1〜5 の正本は `skills/pr-review-gate/stages/` と `declarations.md`（記録先・仕様宣言・`対象 HEAD:` 規約を含む）。索引 `skills/pr-review-gate/SKILL.md` は読まない。入力: PR 番号・記録先（issue または PR）・実行モード・`レビュー経路:` の 1 行・`段:`。2 段目以降は前の `## Gate Result` ブロックと、その段の入力（W の修正内容かレビュアーの要約など）。adapter 経路のレビュー要約は、選ばれた executor / model と dispatch 記録のコメント URL を含む。

## やること

1. 下の「時点ごとに読むファイル」の表に従って段のファイルを Read し、起動指示の `段:` が担当する範囲で pr-review-gate の**手順 1〜5**（前提を揃える → レビュー → リスク宣言・仕様宣言 → 動作確認の証拠 → 照合 → Draft なら Ready 化 → `agent-review:passed`）をそのまま実行する。4 つの段を順に通ると手順 1〜5 がすべて実行され、免除される工程は無い。手順 1 で stale な passed を外したら、Draft でない PR は Draft に戻す（正本は pr-review-gate 手順 1）
2. 手順 2 のレビューは**実装と別コンテキスト**で行う。G 自身は W とは別コンテキストだが、「G が diff を読んで自分で判定する」のは pr-review-gate の言う別コンテキストレビューではない（G はレビュー結果を照合・記録する側）。レビューの実行者は下の「レビュー経路の判別」で決める
3. Codex やレビュアーの完了を待つ目的でターンを終えない。完了は同一ターン内の前景ポーリングで確かめる（起動と完了確認の手順は `skills/pr-review-gate/stages/review-run.md` の「Codex の起動と完了確認」、待ち方の正本は `plugins/dev-workflow/references/subagent-waiting.md`）
4. 結果を本体に return する（書式は下）。記録先へのコメント・ラベル操作は G が自分で行う（本体は return の要約だけを見る）
5. 一時ファイルを消すときの書き方は `skills/develop/references/roles/worker/common.md`「一時ファイルを消すときの書き方」に従う（`cd` とワイルドカードを組み合わせず絶対パスで書く）

## 時点ごとに読むファイル

段のファイルのパスは `skills/pr-review-gate/` から書く（`skills/` で始まるパスはプラグイン直下から）。どの時点でも、表にないファイル（索引 `SKILL.md` を含む）は読まない。

| 段（起動指示の `段:`） | 読むファイル |
|---|---|
| 前提確認と重さ判定（手順 1・2・2-0） | `stages/prepare.md` と `stages/prepare-step1.md`（adapter 経路はここで `needs-reviewer` を return する。W の修正後の再レビューのときは加えて `stages/convergence.md` と `stages/triage.md` の「W の修正後の再レビュー」の入力） |
| 照合と振り分け（レビュー要約・補足レビューの結果・決める役の裁定の受領、順 3 だけの修正のあと） | `stages/triage.md` と、その冒頭の表で当たる条件のファイル（`stages/triage-summary.md`・`stages/triage-row3.md`・`stages/triage-nonblocking.md`・`stages/triage-failed.md`・`stages/triage-escalation.md`）。一周目の要約と補足の結果は加えて `skills/develop/references/roles/gate-runner-triage.md`。戻した指摘が順 3 だけの修正のあとは加えて `stages/prepare-step1.md` |
| 合格処理（手順 3・3-b・4・5。引き継ぎの判定の受領を含む） | `declarations.md` と `stages/pass.md`（真正性確認に入るときは加えて `stages/authenticity.md`、前の HEAD の許容があるとき・`needs-carryover-judge` を返すときは加えて `stages/carryover.md`、保留を返すときは加えて `stages/hold.md`） |
| 保留の解除（主のリスク許容・動作確認・切り出しの確認への回答が届いたとき） | `stages/hold.md` |
| 一括（従来経路）でレビューを自分で起こすとき | 上の表の全部と、`stages/review-run.md` とレビュアーに渡す `stages/reviewer-brief.md` |

## レビュー経路の判別（G として起動されたときだけ）

この節は G（phase `gate`）として起動されたときの規則で、phase `review` のレビュアーとして起動されたとき（Codex に委譲されたレビュアーがこのファイルを読む場合）には適用しない。レビュアーは自分でレビューを行う。

新しい G は起動指示にある `レビュー経路:` の 1 行を見て、この行だけで経路を判別する。環境変数・記録先のコメント・自分の起動方法から推測しない。G は段ごとに新しく起こされるので、どの段の G も自分の起動指示の行だけで判別する。

| 起動指示の行 | 経路 | G の動き |
|---|---|---|
| `レビュー経路: adapter` | adapter 経路 | full でも light でも `codex exec`・`codex-companion.mjs`・レビュアーを自分で呼ばず、手順 1 と手順 2-0 まで済ませ、同一 PR/HEAD で他の G が着手済みでないことを確認してから `needs-reviewer` を return する（判定は `full（adapter 経路）` または `light`）。Codex 不可の実測（バイナリ探索・起動）は行わない。投げ先は本体が phase `review` で選び直す |
| `レビュー経路: 従来`、または新しい G の起動指示に行が無い | 従来経路 | `skills/pr-review-gate/stages/review-run.md` の「G として動くとき（develop）」節の「レビューの実行者」の表に従う（full は G の Bash から Codex を直接呼ぶ。slash command `/codex:adversarial-review` と `codex:codex-rescue` サブエージェントは G からは使えない） |

行が無い場合だけ従来経路とする既定は、新しい G の起動指示（手渡しで起こされた後任 G を含む）に適用する。`レビュー経路: adapter` は新 Codex モードを含む adapter 解決の全構成（`claude-default` を含む）を指し、新 Codex モードとは同義ではない。従来モードのレビュー実行者の表（`stages/review-run.md`）は、`レビュー経路: 従来`、または新しい G の起動指示に行が無いときだけ適用する。develop の本体は常に `レビュー経路: adapter` を書き、`従来` は develop の本体以外の呼び出し元が G を起こすときの値。

## return の書式

return メッセージは宣言で始め、そのうしろに下の本文を続ける。宣言の書式とどちらを選ぶかの義務は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本で、この gate-runner.md には書かない。**G は return を書く前に正本（`skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」）を読み、そこに書かれた書式で宣言する。**

```markdown
## Gate Result
- PR: #<N>（HEAD <SHA>）
- 段: 前提確認と重さ判定 | 照合と振り分け | 合格処理 | 保留の解除 | 一括（従来経路）
- Status: passed | failed | 保留 | needs-reviewer | needs-decider | needs-fix-check | review-incomplete | needs-carryover-judge | 次の段へ
- 次の段: 前提確認と重さ判定 | 照合と振り分け | 合格処理 | 保留の解除 | なし
- レビュー重量: light | full（実行者: Codex | Task サブエージェント <model> | <executor>/<model>（adapter 経路））
- Codex thread: <thread_id>（full で Codex を呼んだ周だけ。呼ばなかった周は省く。取れなかったら「取得できず」）
- 周回: <1|2|3以降（直し方の判定・主の回答・決める役の裁定のどれかあり）>（全体レビューにした周は「（全体レビュー: 修正差分 N 行 / 前周指摘 M 行）」を添える）
```

`周回:` は前の段の Gate Result の値を引き継ぐ。W の修正後の再レビューで起こされた前提確認と重さ判定の G だけが 1 増やす（戻した指摘が順 3 だけの修正のあとは周を消費しない。`stages/triage.md` の規則のまま）。

`次の段:` は G が Status ごとに次の表どおりに書く。本体は Status と `次の段:` だけを見て次に起こす G の段を決める。

| Status | `次の段:` |
|---|---|
| `次の段へ` | 照合と振り分けの G は `合格処理`。保留の解除の G は `合格処理` か `前提確認と重さ判定` |
| failed | 戻した指摘が順 3 だけなら `照合と振り分け`、それ以外は `前提確認と重さ判定` |
| needs-reviewer / needs-decider / needs-fix-check | `照合と振り分け` |
| needs-carryover-judge | `合格処理` |
| 保留 | `保留の解除` |
| passed / review-incomplete | `なし` |

この共通欄のうしろに、Status ごとの欄を続ける。Status ごとの欄の書式は、段のファイル（`skills/pr-review-gate/` から）の「G として動くとき（develop）」節にある: `needs-reviewer` は `stages/prepare.md`、`failed`・`needs-decider`・`needs-fix-check`・`review-incomplete` と、指摘を受け取ったすべての周に付ける仕分け・follow-up issue・効果測定の欄は `stages/triage.md`、`passed` は `stages/pass.md`、`保留` は `stages/hold.md`、`needs-carryover-judge` は `stages/carryover.md`。`passed` の真正性確認の書式は `stages/authenticity.md`。

## 段ごとの入力

G は前の段の会話を持たない。段と段の間で渡すものは次の PR コメントに置き、起動指示と PR コメントが食い違ったら **PR コメントを正とする**。

| 渡すもの | 置き場所 | 書く G |
|---|---|---|
| 固定した HEAD | `レビュー重量:` コメントの `固定 HEAD: <SHA>` の行（周ごとに増えるので最新の 1 件を正とする。`対象 HEAD:` とは書かない） | 前提確認と重さ判定 |
| レビューの三表と補足済み回数（補足を頼んだ時点で 1。コメントが無ければ 0） | 1 行目 `レビュー三表:` のコメント（`一周目の区画:` と `補足済み回数:` の行を持つ。補足の `needs-reviewer` を返す前に投稿する） | 照合と振り分け |
| 振り分けの結果 | 既存の仕分けコメント | 照合と振り分け |

段ごとの入力のうち、W の修正後の再レビュー（前提確認と重さ判定）は `stages/prepare.md`、決める役の裁定受領・直し方の判定の受領と順 3 だけの修正のあと（照合と振り分け）は `stages/triage.md`、保留の解除は `stages/hold.md`、保留の解除のあとの合格処理は `stages/pass.md` の、それぞれ「G として動くとき（develop）」節の「この段で起こされたときの入力」に従う。照合と振り分けの G がレビュアーの要約か補足レビューの結果を受け取ったときは `skills/develop/references/roles/gate-runner-triage.md` の「レビュー要約の入力」に従う。

従来経路（`レビュー経路: 従来`、または新しい G の起動指示に行が無い）の G はレビューを自分の起動の中で起こすので、手順 1〜5 と保留までを 1 体で続けてよい。そのときの Gate Result は `段: 一括（従来経路）`、`次の段: なし` と書く。

## コンテキスト上限

G 自身の起動の途中では hook がコンテキストを測る。強制停止で `Bash` が全件拒否され `gh pr comment` も拒否されたら、レビュー結果を return 本文に含め `工程中断:` で返す（本体が代理投稿し、commit も本体が行う）。上限超・待ち・宣言の扱いは `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本。正本を読むまで手渡さない。
