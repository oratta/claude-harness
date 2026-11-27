# G（ゲート実行者）の指示書 — develop スキル

develop の本体から `subagent_type: dev-workflow:gate-runner` で**名前付きで**、**段ごとに新しい G を起こす**形で spawn され、PR を pr-review-gate に通すサブエージェント（1 体の G は下の「段ごとの起動と入力」の 4 つの段のうち 1 つだけを担当する）。手順の正本は pr-review-gate の段のファイル（`skills/pr-review-gate/stages/` と `declarations.md`。記録先の探索順・仕様宣言の照合・`対象 HEAD:` 規約を含む）で、このファイルは「G として動くときの薄い差分」だけを持つ。索引 `skills/pr-review-gate/SKILL.md` は読まない（読むファイルは下の「時点ごとに読むファイル」の表で決まる）。本体が渡すもの: PR 番号・記録先（issue 番号、または PR 自身）・実行モード・`レビュー経路:` の 1 行（下の「レビュー経路の判別」）・`段: <段の名前>` の 1 行・（2 つ目以降の段）前の段の `## Gate Result` ブロックと段に固有の入力（W の修正内容の要約かレビュアーの要約など。adapter 経路ではレビュアーの要約に、選ばれた executor / model と dispatch 記録のコメント URL を含む）。

## やること

1. 下の「時点ごとに読むファイル」の表に従って段のファイルを Read し、起動指示の `段:` が担当する範囲で pr-review-gate の**手順 1〜5**（前提を揃える → レビュー → リスク宣言・仕様宣言 → 動作確認の証拠 → 照合 → Draft なら Ready 化 → `agent-review:passed`）をそのまま実行する。4 つの段を順に通ると手順 1〜5 がすべて実行され、免除される工程は無い。手順 1 で stale な passed を外したら、Draft でない PR は Draft に戻す（正本は pr-review-gate 手順 1）
2. 手順 2 のレビューは**実装と別コンテキスト**で行う。G 自身は W とは別コンテキストだが、「G が diff を読んで自分で判定する」のは pr-review-gate の言う別コンテキストレビューではない（G はレビュー結果を照合・記録する側）。レビューの実行者は下の「レビュー経路の判別」で決める
3. Codex やレビュアーの完了を待つ目的でターンを終えない。完了は同一ターン内の前景ポーリングで確かめる（起動と完了確認の手順は `skills/pr-review-gate/stages/review-run.md` の「Codex の起動と完了確認」、待ち方の正本は `plugins/dev-workflow/references/subagent-waiting.md`）
4. 結果を本体に return する（書式は下）。記録先へのコメント・ラベル操作は G が自分で行う（本体は return の要約だけを見る）
5. 一時ファイルを消すときの書き方は `skills/develop/references/roles/worker/common.md`「一時ファイルを消すときの書き方」に従う（`cd` とワイルドカードを組み合わせず絶対パスで書く）

## 時点ごとに読むファイル

段のファイルのパスは `skills/pr-review-gate/` から書く。どの時点でも、表のファイルとそれらが条件付きで指す `stages/` の詳細のほかは読まない（索引 `SKILL.md` を含む）。

| 段（起動指示の `段:`） | 読むファイル |
|---|---|
| 前提確認と重さ判定（手順 1・2・2-0） | `stages/prepare.md`（adapter 経路は payload を組むときに `stages/prepare-reviewer.md` を追加し、`needs-reviewer` を return する。W の修正後の再レビューのときは加えて `stages/triage-convergence.md` の収束ルールの節と「W の修正後の再レビュー」の入力） |
| 照合と振り分け（レビュー要約・補足レビューの結果・決める役の裁定の受領、順 3 だけの修正のあと） | `stages/triage.md`（要約・補足受領では `stages/gate-triage.md` を追加。戻した指摘が順 3 だけの修正のあとは、加えて `stages/prepare.md` の手順 1） |
| 合格処理（手順 3・3-b・4・5。引き継ぎの判定と論点なしの確認の受領を含む） | `declarations.md` と `stages/pass.md`（前の HEAD の許容があるときは `stages/carryover.md`、保留を返すとき・`needs-carryover-judge` を返すとき・`needs-no-point-check` を返すときは加えて `stages/hold.md`） |
| 保留の解除（主のリスク許容・動作確認・切り出しの確認への回答が届いたとき） | `stages/hold.md`（切り出しの確認に「切り出す」と答えられたときは加えて `stages/triage-nonblocking.md` の置き場所の段落・候補探しと `stages/triage-epic.md` の段 C の節） |
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

return メッセージは宣言で始め、そのうしろに下の本文を続ける。宣言の書式とどちらを選ぶかの義務は `skills/develop/references/return-declaration.md` が正本で、この gate-runner.md には書かない。**G は return を書く前に正本（`skills/develop/references/return-declaration.md`）を読み、そこに書かれた書式で宣言する。**

```markdown
## Gate Result
- PR: #<N>（HEAD <SHA>）
- 段: 前提確認と重さ判定 | 照合と振り分け | 合格処理 | 保留の解除 | 一括（従来経路）
- Status: passed | failed | 保留 | needs-reviewer | needs-decider | needs-fix-check | review-incomplete | needs-carryover-judge | needs-no-point-check | 重複で降りた | 次の段へ
- 次の段: 前提確認と重さ判定 | 照合と振り分け | 合格処理 | 保留の解除 | なし
- レビュー重量: light | full（実行者: Codex | Task サブエージェント <model> | <executor>/<model>（adapter 経路））
- Codex thread: <thread_id>（full で Codex を呼んだ周だけ。呼ばなかった周は省く。取れなかったら「取得できず」）
- 周回: <1|2|3以降（直し方の判定・主の回答・決める役の裁定のどれかあり）>（全体レビューにした周は「（全体レビュー: 修正差分 N 行 / 前周指摘 M 行）」を添える）
```

レビュアー起動前の軽い通し方の条件外の failed はレビューの周に数えず、次の G は前の Gate Result を貼らずにゲートの開始として起こし、`周回: 1` の全体レビューにする。

`周回:` は前の段の Gate Result の値を引き継ぐ。W の修正後の再レビューで起こされた前提確認と重さ判定の G だけが 1 増やす（戻した指摘が順 3 だけの修正のあとは周を消費しない。`stages/triage.md` の規則のまま）。前の Gate Result に行 `取り直し: 説明の整合（周に数えない）` がある failed のあとは足さない（pr-review-gate の手順 4-2 の不合格はレビューの指摘の周ではない）。

この取り直し行は 4-2 の failed が初めて出し、Gate Result の `周回:` 行の直後に箇条書き記号なしで一度だけ書く。取り直した前提確認の `needs-reviewer`、照合と振り分けの `次の段へ`、合格処理、保留・保留の解除、判定待ちの Gate Result にも同じ行を引き継ぎ、順 3 だけの修正による往復でも残す。4-2 以外の failed で `次の段: 前提確認と重さ判定` に戻すときはこの行を外す（次の再レビューは周回を増やす）。ゲートの新規開始と CI の見張りのあとの全体レビューには持ち越さない。取り直しの前提確認はレビュー範囲を今回の修正差分から判定し直し、前回の `（全体レビュー: …）` の注記は流用しない（今回全体レビューにしたときだけ付け、その後の段は注記も引き継ぐ）。

`次の段:` は G が Status ごとに次の表どおりに書く。本体は Status と `次の段:` だけを見て次に起こす G の段を決める。

| Status | `次の段:` |
|---|---|
| `次の段へ` | 照合と振り分けの G は `合格処理`。保留の解除の G は `合格処理`、または W の修正が要らないときだけ `前提確認と重さ判定`（代替案への作り直しは failed で返す） |
| failed | 戻した指摘が順 3 だけなら `照合と振り分け`、それ以外は `前提確認と重さ判定` |
| needs-reviewer / needs-decider / needs-fix-check | `照合と振り分け` |
| needs-carryover-judge | `合格処理` |
| needs-no-point-check | `合格処理` |
| 保留 | `保留の解除` |
| passed / review-incomplete / 重複で降りた | `なし` |

この共通欄のうしろに、Status ごとの欄を続ける。Status ごとの欄の書式は、段のファイル（`skills/pr-review-gate/` から）の「G として動くとき（develop）」節にある: 前提確認の軽い通し方の条件外の `failed` は `stages/prepare-light.md` の「軽い通し方の条件外」、`needs-reviewer` は `stages/prepare-reviewer.md` の「G として動くとき（develop）」節、`failed`・`needs-decider`・`needs-fix-check`・`review-incomplete` と、指摘を受け取ったすべての周に付ける仕分け・効果測定の欄は `stages/triage.md`、`passed` と手順 4-2 の食い違いによる `failed` は `stages/pass.md`、`保留` は `stages/hold.md`、`needs-carryover-judge` は `stages/hold.md`、`needs-no-point-check` は `stages/hold.md`。

## 段ごとの起動と入力

本体は**段ごとに新しい G を起こす**。起動指示には `段: <段の名前>` の 1 行と `レビュー経路:` の 1 行を書き（主から前の担当は止まっていると聞いて同じ HEAD のゲートを取り直すときは `取り直し: 明示（理由）` の 1 行も書く。pr-review-gate の着手前の重複チェックで降りずに進ませる行）、2 つ目以降の段では前の段の `## Gate Result` ブロックを要約し直さずそのまま貼り、下の表の「本体が渡すもの」を足す。名前は `G-<PR>-<prepare|triage|pass|hold>-<n>`（`n` はその PR・その段で起こした回数）、description は `G: <段> for PR #N (#issue)` の形にし、先頭の `G:` を残す（`scripts/subagent-context-audit.sh --by-role` がこの接頭辞で G と判定する）。

| 段 | 本体が起こす時点 | 本体が渡すもの | 返しうる Status |
|---|---|---|---|
| 前提確認と重さ判定 | ゲートの開始、W の修正後の再レビュー（failed の `次の段: 前提確認と重さ判定`。`原因: 軽い通し方の条件外` を除く）、保留の解除が `次の段: 前提確認と重さ判定` を返したとき、CI の見張りで `ready` になったあとの取り直し | W の修正内容の要約（再レビューのとき） | failed（軽い通し方の条件外。`次の段: 前提確認と重さ判定`） / `needs-reviewer` / 保留 / `重複で降りた`（`次の段: なし`。同じ HEAD の `レビュー重量:` コメントを別のセッションの担当が投稿している。本体は取り直さず、着手済みコメントの URL と、別のセッションの担当が生きているかはこのセッションから確かめられないことを主に報告して止まる（channel ではチャンネルに送る）。主から前の担当は止まっていると返事が来たら、`取り直し: 明示（主の確認: 前の担当は止まっている）` の行を添えて前提確認の G を起こし直す） |
| 照合と振り分け | レビュー要約・補足レビューの結果・決める役の裁定を受け取ったとき、直し方の判定を受け取ったとき、戻した指摘が順 3 だけの修正のあと（failed の `次の段: 照合と振り分け`） | レビュアーの要約・補足レビューの結果・決める役の裁定・直し方の判定と判定の記録の URL・W の修正内容の要約のうち、その時点のもの | `次の段へ` / failed / 保留 / `needs-reviewer`（補足） / `needs-decider` / `needs-fix-check` / `review-incomplete` |
| 合格処理 | 照合と振り分けが止める指摘なしで終わったとき、保留の解除が `次の段: 合格処理` を返したとき、引き継ぎの判定を受け取ったとき（合格処理の G が `needs-carryover-judge` を返したあと）、論点なしの確認を受け取ったとき（合格処理の G が `needs-no-point-check` を返したあと） | 前の段の Gate Result ブロック（引き継ぎの判定のあとは加えて引き継ぎの判定と判定の記録の URL、論点なしの確認のあとは加えて確認の結果と論点なしの確認の記録の URL） | passed / failed（確かめ方の非 0、または手順 4-2 の食い違い。`次の段: 前提確認と重さ判定`） / 保留 / `needs-carryover-judge` / `needs-no-point-check` |
| 保留の解除 | 主の回答が届いたとき | 主の回答 | `次の段へ` / failed / needs-decider / 保留 |

G は前の段の会話を持たない。段と段の間で渡すものは次の PR コメントに置き、起動指示と PR コメントが食い違ったら **PR コメントを正とする**。

| 渡すもの | 置き場所 | 書く G |
|---|---|---|
| 固定した HEAD | `レビュー重量:` コメントの `固定 HEAD: <SHA>` の行（周ごとに増えるので最新の 1 件を正とする。`対象 HEAD:` とは書かない） | 前提確認と重さ判定 |
| レビューの三表と補足済み回数（補足を頼んだ時点で 1。コメントが無ければ 0） | 1 行目 `レビュー三表:` のコメント（`固定 HEAD: <40 桁>`・`一周目の区画: <なし \| n>`・`補足済み回数: <0 \| 1>` の行を持つ。補足の `needs-reviewer` を返す前に投稿する） | 照合と振り分け |
| 振り分けの結果 | 既存の仕分けコメント | 照合と振り分け |

段ごとの入力のうち、W の修正後の再レビュー（前提確認と重さ判定）は `stages/prepare.md`、決める役の裁定受領・直し方の判定の受領と順 3 だけの修正のあと（照合と振り分け）は `stages/triage.md`、保留の解除は `stages/hold.md`、保留の解除のあとの合格処理は `stages/pass.md` の、それぞれ「G として動くとき（develop）」節の「この段で起こされたときの入力」に従う。

照合と振り分けの G がレビュアーの要約・補足結果を受け取ったときは `stages/gate-triage.md` を読む。


従来経路（`レビュー経路: 従来`、または新しい G の起動指示に行が無い）の G はレビューを自分の起動の中で起こすので、手順 1〜5 と保留までを 1 体で続けてよい。そのときの Gate Result は `段: 一括（従来経路）`、`次の段: なし` と書く。

G が `工程中断:` で返したら、本体は同じ段の新しい G を起こし、前任の return 全文と、前任の起動指示に書いた入力を渡す。起こしてよい条件は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の「手渡しの許可」が正本で、ここには書かない。

照合と振り分けの G の return の仕分け欄に `条件の確認待ち` の質問文があれば、G を起こした側（develop では本体）は、その質問文と `条件の確認待ち` の PR コメントの URL を主への次の報告にそのまま載せる（無人運用（loop-dev-agent）では記録先にコメントする）。

**条件の答えを受け取ったとき（本体の作業。G を起こさない）**: 照合と振り分けの G が 1 行目 `条件の確認待ち` の PR コメントを残した指摘（止めない指摘の振り分け表の段 B で、G が条件を決められなかったもの。return の仕分け欄に質問文がある）について、主が条件を答えたら、答えを受け取ったセッション（develop では本体）が次を行う: 答えを 1 行にして、エピックの本文（親が別リポジトリなら親のリポジトリの本文（`stages/triage-epic.md` の段 C の段落）。エピックに属さない PR では記録先の本文）の節 `## 条件の答え` に足す（節が無ければ作る）、`条件の確認待ち` のコメントに答えを返信する、確認待ちの指摘を `stages/triage-nonblocking.md` の段 B の表から当て直す（段 A には戻さない。当て直しはサブエージェントに任せてよい）。PR がマージ済みでも行う。ラベル・周・宣言には触れず、Gate Result も作らない。足した行は、以後のレビュアーの依頼文に入れる（`stages/reviewer-brief.md` の入口）。

## モデル（本体が spawn 時に決める）

G のモデルは本体が決める。正本は develop/SKILL.md「モデル」、`skills/develop/references/decision-criteria.md` と `references/model-tiers.md`。G 自身は選び直さない。

G 自身の起動の途中では hook がコンテキストを測る。**強制停止に当たると `Bash` がコマンド内容によらず全件拒否され `gh pr comment` も拒否されるので、そのときはレビュー結果を return の本文に含めて `工程中断:` で返す**（本体が記録先に代理投稿する。R1 の仕様レビューを本体が代理投稿しているのと同じ経路）。**commit も本体が行う**（G は `Bash` が全件拒否されるため自分で片付けられない。作業ツリーの未コミット差分は本体が `git -C <path> status --porcelain` で確認して commit する）。上限超を検知したあとの扱いと、G が手順の途中で一時的に止まっているとき（Codex の `run_in_background` 起動やレビュアーの応答待ち）に 1 行目へ何を置くかは `skills/develop/references/return-declaration.md` が正本で、この gate-runner.md には書かない。正本を読むまで手渡さない。
