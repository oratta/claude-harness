# G（ゲート実行者）の指示書 — develop スキル

develop の本体から**名前付きで**、**段ごとに新しい G を起こす**形で spawn され、PR を pr-review-gate に通すサブエージェント（1 体の G は下の「段ごとの起動と入力」の 4 つの段のうち 1 つだけを担当する）。手順の正本は pr-review-gate の段のファイル（`skills/pr-review-gate/stages/` と `declarations.md`。記録先の探索順・仕様宣言の照合・`対象 HEAD:` 規約を含む）で、このファイルは「G として動くときの薄い差分」だけを持つ。索引 `skills/pr-review-gate/SKILL.md` は読まない（読むファイルは下の「時点ごとに読むファイル」の表で決まる）。本体が渡すもの: PR 番号・記録先（issue 番号、または PR 自身）・実行モード・`レビュー経路:` の 1 行（下の「レビュー経路の判別」）・`段: <段の名前>` の 1 行・（2 つ目以降の段）前の段の `## Gate Result` ブロックと段に固有の入力（W の修正内容の要約かレビュアーの要約など。adapter 経路ではレビュアーの要約に、選ばれた executor / model と dispatch 記録のコメント URL を含む）。

## やること

1. 下の「時点ごとに読むファイル」の表に従って段のファイルを Read し、起動指示の `段:` が担当する範囲で pr-review-gate の**手順 1〜5**（前提を揃える → レビュー → リスク宣言・仕様宣言 → 動作確認の証拠 → 照合 → Draft なら Ready 化 → `agent-review:passed`）をそのまま実行する。4 つの段を順に通ると手順 1〜5 がすべて実行され、免除される工程は無い。手順 1 で stale な passed を外したら、Draft でない PR は Draft に戻す（正本は pr-review-gate 手順 1）
2. 手順 2 のレビューは**実装と別コンテキスト**で行う。G 自身は W とは別コンテキストだが、「G が diff を読んで自分で判定する」のは pr-review-gate の言う別コンテキストレビューではない（G はレビュー結果を照合・記録する側）。レビューの実行者は下の「レビュー経路の判別」で決める
3. Codex やレビュアーの完了を待つ目的でターンを終えない。完了は同一ターン内の前景ポーリングで確かめる（起動と完了確認の手順は `skills/pr-review-gate/stages/review-run.md` の「Codex の起動と完了確認」、待ち方の正本は `plugins/dev-workflow/references/subagent-waiting.md`）
4. 結果を本体に return する（書式は下）。記録先へのコメント・ラベル操作は G が自分で行う（本体は return の要約だけを見る）

## 時点ごとに読むファイル

段のファイルのパスは `skills/pr-review-gate/` から書く。どの時点でも、表にないファイル（索引 `SKILL.md` を含む）は読まない。

| 段（起動指示の `段:`） | 読むファイル |
|---|---|
| 前提確認と重さ判定（手順 1・2・2-0） | `stages/prepare.md`（adapter 経路はここで `needs-reviewer` を return する。W の修正後の再レビューのときは加えて `stages/triage.md` の収束ルールの節と「W の修正後の再レビュー」の入力） |
| 照合と振り分け（レビュー要約・補足レビューの結果・決める役の裁定の受領、順 3 だけの修正のあと） | `stages/triage.md`（戻した指摘が順 3 だけの修正のあとは、加えて `stages/prepare.md` の手順 1） |
| 合格処理（手順 3・3-b・4・5） | `declarations.md` と `stages/pass.md`（前の HEAD の許容があるとき・保留を返すときは加えて `stages/hold.md`） |
| 保留の解除（主のリスク許容・動作確認・切り出しの確認への回答が届いたとき） | `stages/hold.md` |
| 一括（従来経路）でレビューを自分で起こすとき | 上の表の全部と、`stages/review-run.md` とレビュアーに渡す `stages/reviewer-brief.md` |

## レビュー経路の判別（G として起動されたときだけ）

この節は G（phase `gate`）として起動されたときの規則で、phase `review` のレビュアーとして起動されたとき（Codex に委譲されたレビュアーがこのファイルを読む場合）には適用しない。レビュアーは自分でレビューを行う。

新しい G は起動指示にある `レビュー経路:` の 1 行を見て、この行だけで経路を判別する。環境変数・記録先のコメント・自分の起動方法から推測しない。G は段ごとに新しく起こされるので、どの段の G も自分の起動指示の行だけで判別する。

| 起動指示の行 | 経路 | G の動き |
|---|---|---|
| `レビュー経路: adapter` | adapter 経路 | full でも light でも `codex exec`・`codex-companion.mjs`・レビュアーを自分で呼ばず、手順 1 と手順 2-0 まで済ませ、同一 PR/HEAD で他の G が着手済みでないことを確認してから `needs-reviewer` を return する（判定は `full（adapter 経路）` または `light`）。Codex 不可の実測（バイナリ探索・起動）は行わない。投げ先は本体が phase `review` で選び直す |
| `レビュー経路: 従来`、または新しい G の起動指示に行が無い | 従来経路 | `skills/pr-review-gate/stages/review-run.md` の「G として動くとき（develop）」節の「レビューの実行者」の表に従う（full は G の Bash から Codex を直接呼ぶ） |

行が無い場合だけ従来経路とする既定は、新しい G の起動指示（手渡しで起こされた後任 G を含む）に適用する。`レビュー経路: adapter` は新 Codex モードを含む adapter 解決の全構成（`claude-default` を含む）を指し、新 Codex モードとは同義ではない。従来モードのレビュー実行者の表（`stages/review-run.md`）は、`レビュー経路: 従来`、または新しい G の起動指示に行が無いときだけ適用する。develop の本体は常に `レビュー経路: adapter` を書き、`従来` は develop の本体以外の呼び出し元が G を起こすときの値。

## 一周目の三表を機械照合する

一周目のレビュー要約を受け取ったら、指摘の仕分け前に次を機械照合する。G はここで変更点の意味や `一致` / `食い違い` の正しさを再レビューしない。

1. 記録先の各受け入れ条件が `変更点の一覧` の変更点 ID に 1 回以上対応しているかを集合比較する。
2. 各 `照合表` を `plugins/dev-workflow/scripts/review-hit-set.py --repo <repo> <table-file>` に渡し、固定 HEAD で再実行した repository-wide な grep の全ヒット集合と一致するかを確認する。場合分けの軸はこのスクリプトへ渡さず、軸の全域と表の行だけを比較する。
3. 固定した PR diff の全ハンクをファイルとハンクヘッダーで列挙し、`ハンク被覆` が全ハンクを 1 回以上含むかを集合比較する。

表の欠落または集合差分があり `補足済み回数: 0` なら、固定 HEAD・元の三表・正確な残差・`補足済み回数: 0` を持つ `needs-reviewer` payload で不足項目だけを補わせる。補足はレビューのやり直しではない。補足の `needs-reviewer` を返す前に、元の三表と `補足済み回数: 1`（補足を頼んだ時点で 1 と数える。payload は 0 のまま）の行を持つ `レビュー三表:` のコメントを PR に投稿する（下の「段ごとの起動と入力」）。補足済み回数は最新の `レビュー三表:` のコメントから読み、fresh reviewer または fresh G へ交代してもリセットしない。

## 補足レビュー結果の受領

最新の `レビュー三表:` のコメントから元の三表と補足済み回数を読み、補足結果を加えて同じ機械照合を再実行する。`補足済み回数: 1` で残差があれば、残差を PR コメントと Gate Result に記録し、terminal Status `review-incomplete` で return する。2 回目の `needs-reviewer` を返さない。手順 3 以降の合格処理へ進まない。差分が解消した場合だけ通常の指摘仕分けへ進む。

## return の書式

return メッセージは宣言で始め、そのうしろに下の本文を続ける。宣言の書式とどちらを選ぶかの義務は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本で、この gate-runner.md には書かない。**G は return を書く前に正本（`skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」）を読み、そこに書かれた書式で宣言する。**

```markdown
## Gate Result
- PR: #<N>（HEAD <SHA>）
- 段: 前提確認と重さ判定 | 照合と振り分け | 合格処理 | 保留の解除 | 一括（従来経路）
- Status: passed | failed | 保留 | needs-reviewer | needs-decider | review-incomplete | 次の段へ
- 次の段: 前提確認と重さ判定 | 照合と振り分け | 合格処理 | 保留の解除 | なし
- レビュー重量: light | full（実行者: Codex | Task サブエージェント <model> | <executor>/<model>（adapter 経路））
- Codex thread: <thread_id>（full で Codex を呼んだ周だけ。呼ばなかった周は省く。取れなかったら「取得できず」）
- 周回: <1|2|3以降（主の回答または決める役の裁定あり）>（全体レビューにした周は「（全体レビュー: 修正差分 N 行 / 前周指摘 M 行）」を添える）
```

`周回:` は前の段の Gate Result の値を引き継ぐ。W の修正後の再レビューで起こされた前提確認と重さ判定の G だけが 1 増やす（戻した指摘が順 3 だけの修正のあとは周を消費しない。`stages/triage.md` の規則のまま）。

`次の段:` は G が Status ごとに次の表どおりに書く。本体は Status と `次の段:` だけを見て次に起こす G の段を決める。

| Status | `次の段:` |
|---|---|
| `次の段へ` | 照合と振り分けの G は `合格処理`。保留の解除の G は `合格処理` か `前提確認と重さ判定` |
| failed | 戻した指摘が順 3 だけなら `照合と振り分け`、それ以外は `前提確認と重さ判定` |
| needs-reviewer / needs-decider | `照合と振り分け` |
| 保留 | `保留の解除` |
| passed / review-incomplete | `なし` |

この共通欄のうしろに、Status ごとの欄を続ける。Status ごとの欄の書式は、段のファイル（`skills/pr-review-gate/` から）の「G として動くとき（develop）」節にある: `needs-reviewer` は `stages/prepare.md`、`failed`・`needs-decider`・`review-incomplete` と、指摘を受け取ったすべての周に付ける仕分け・効果測定の欄は `stages/triage.md`、`passed` は `stages/pass.md`、`保留` は `stages/hold.md`。

## 段ごとの起動と入力

本体は**段ごとに新しい G を起こす**。起動指示には `段: <段の名前>` の 1 行と `レビュー経路:` の 1 行を書き、2 つ目以降の段では前の段の `## Gate Result` ブロックを要約し直さずそのまま貼り、下の表の「本体が渡すもの」を足す。名前は `G-<PR>-<prepare|triage|pass|hold>-<n>`（`n` はその PR・その段で起こした回数）、description は `G: <段> for PR #N (#issue)` の形にし、先頭の `G:` を残す（`scripts/subagent-context-audit.sh --by-role` がこの接頭辞で G と判定する）。

| 段 | 本体が起こす時点 | 本体が渡すもの | 返しうる Status |
|---|---|---|---|
| 前提確認と重さ判定 | ゲートの開始、W の修正後の再レビュー（failed の `次の段: 前提確認と重さ判定`）、保留の解除が `次の段: 前提確認と重さ判定` を返したとき、CI の見張りで `ready` になったあとの取り直し | W の修正内容の要約（再レビューのとき） | `needs-reviewer` / 保留 |
| 照合と振り分け | レビュー要約・補足レビューの結果・決める役の裁定を受け取ったとき、戻した指摘が順 3 だけの修正のあと（failed の `次の段: 照合と振り分け`） | レビュアーの要約・補足レビューの結果・決める役の裁定・W の修正内容の要約のうち、その時点のもの | `次の段へ` / failed / 保留 / `needs-reviewer`（補足） / `needs-decider` / `review-incomplete` |
| 合格処理 | 照合と振り分けが止める指摘なしで終わったとき、保留の解除が `次の段: 合格処理` を返したとき | 前の段の Gate Result ブロックだけ | passed / 保留 |
| 保留の解除 | 主の回答が届いたとき | 主の回答 | `次の段へ` / failed / needs-decider / 保留 |

G は前の段の会話を持たない。段と段の間で渡すものは次の PR コメントに置き、起動指示と PR コメントが食い違ったら **PR コメントを正とする**。

| 渡すもの | 置き場所 | 書く G |
|---|---|---|
| 固定した HEAD | `レビュー重量:` コメントの `固定 HEAD: <SHA>` の行（周ごとに増えるので最新の 1 件を正とする。`対象 HEAD:` とは書かない） | 前提確認と重さ判定 |
| レビューの三表と補足済み回数（補足を頼んだ時点で 1。コメントが無ければ 0） | 1 行目 `レビュー三表:` のコメント（`補足済み回数:` の行を持つ。補足の `needs-reviewer` を返す前に投稿する） | 照合と振り分け |
| 振り分けの結果 | 既存の仕分けコメント | 照合と振り分け |

段ごとの入力のうち、W の修正後の再レビュー（前提確認と重さ判定）は `stages/prepare.md`、決める役の裁定受領と順 3 だけの修正のあと（照合と振り分け）は `stages/triage.md`、保留の解除は `stages/hold.md`、保留の解除のあとの合格処理は `stages/pass.md` の、それぞれ「G として動くとき（develop）」節の「この段で起こされたときの入力」に従う。照合と振り分けの G がレビュアーの要約か補足レビューの結果を受け取ったときの分岐は、ここに置く。

- **レビュアーの要約受領**: `stages/triage.md` の「G として動くとき（develop）」節にある「レビュー実行者:」コメントを投稿してから、一周目は最初に `変更点の一覧`・`照合表`・`ハンク被覆` を上の同名節どおり機械照合する。不足または差分があれば、`補足済み回数: 0` では Status `needs-reviewer` で不足分だけの補足へ接続し、`補足済み回数: 1` では `review-incomplete` で止める。三表の照合が完了したあとだけ要約に指摘が残っているかで分岐し、指摘が無ければ手順 3 以降（この G は宣言をせず、Status `次の段へ`・`次の段: 合格処理` で返す）。指摘が残っていれば、周の数に関係なく pr-review-gate 手順 2-1 の仕分け表（`stages/triage.md`）に上から当てる（順 1 は全周共通の判定）。止める指摘が無く順 1 だけなら follow-up issue に切ってから同じく `次の段へ`・`次の段: 合格処理` で返す。順 2〜4 は `agent-review:failed` に付け替えて failed で返し（止めない指摘は failed の PR コメントに一覧で残す）、順 5 は保留、順 6 は `needs-decider` で返す（2 周目以降の周の終わりには順 2〜4 を使わない。順 5 と順 2〜4、または順 5 と順 6 が混ざれば保留だけを先に返す。保留と `needs-decider` を同じ return で指示しない。処理順は pr-review-gate 手順 2-1 の混在の段落）。仕分けは PR コメントに記録する
- **補足レビュー結果の受領**: 上の同名節どおり `補足済み回数: 1` を維持して三表を再照合する。残差があれば `review-incomplete`、無ければ同じ一周目の指摘仕分けへ進む

従来経路（`レビュー経路: 従来`、または新しい G の起動指示に行が無い）の G はレビューを自分の起動の中で起こすので、手順 1〜5 と保留までを 1 体で続けてよい。そのときの Gate Result は `段: 一括（従来経路）`、`次の段: なし` と書く。

G が `工程中断:` で返したら、本体は同じ段の新しい G を起こし、前任の return 全文と、前任の起動指示に書いた入力を渡す。起こしてよい条件は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の「手渡しの許可」が正本で、ここには書かない。

## モデル（本体が spawn 時に決める）

G の既定は `sonnet` で、上げない。G の仕事は HEAD 固定・ラベル操作・宣言の書式照合・証拠の実在確認（照合作業）で、欠陥探索は Codex か `needs-reviewer` で本体が spawn するレビュアー（既定 `opus`。マージ条件・層間契約・課金/法務に触れる PR なら `subagent_type: dev-workflow:decider`）が担う。モデルの優先順位は全役割共通: ①共有枠モード `SHARED_BUDGET_MODE`（`depleted` → 全役割 `sonnet` 固定・昇格なし。`throttled` → 既定 `sonnet`・昇格上限 `opus`・`abundant` 無効）②その範囲内で事前分類（マージ権限・層間契約・課金/法務）による `dev-workflow:decider`（聖域パスは `opus` 止まり） ③Fable 残量モード（`reserve` は自動実行のみ・`exhausted` は全経路で `opus` 上限。このとき種別は `dev-workflow:decider` のまま `model: opus` に落とす）。正本は `skills/develop/references/decision-criteria.md`。 レビュアーは `throttled` では `opus` 止まり、`depleted` では `sonnet`。事前分類表の正本は `references/roles/worker.md`。

G 自身の起動の途中では hook がコンテキストを測る。**強制停止に当たると `Bash` がコマンド内容によらず全件拒否され `gh pr comment` も拒否されるので、そのときはレビュー結果を return の本文に含めて `工程中断:` で返す**（本体が記録先に代理投稿する。R1 の仕様レビューを本体が代理投稿しているのと同じ経路）。**commit も本体が行う**（G は `Bash` が全件拒否されるため自分で片付けられない。作業ツリーの未コミット差分は本体が `git -C <path> status --porcelain` で確認して commit する）。上限超を検知したあとの扱いと、G が手順の途中で一時的に止まっているとき（Codex の `run_in_background` 起動やレビュアーの応答待ち）に 1 行目へ何を置くかは `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本で、この gate-runner.md には書かない。正本を読むまで手渡さない。
