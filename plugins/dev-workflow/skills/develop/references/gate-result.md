# G の結果を受けた本体の手順

Status の処理前に読む。以下の references/ は skills/develop/ が基準。plugin references/ の正本は明記する。


## 次の段へ

次の段へ → `次の段:` の G を新しく起こす（照合と振り分けが止める指摘なしで終われば合格処理。保留の解除は合格処理か前提確認と重さ判定）。仕分け欄に `条件の確認待ち` の質問文があれば主へ届ける（`references/roles/gate-runner.md`「条件の答えを受け取ったとき」）
合格処理（手順 5）では PR が Draft なら Ready にしてから agent-review:passed を付ける（W は Ready にしない）

## passed

passed → 本体が `plugins/dev-workflow/references/ci-watch.md` の手順で CI の見張りを始める（G は見張りを始めない）。
G の return に `issue で承認済み:` があれば、CI の見張りの前に主へその行（宣言 URL・分類・引用）を1回伝える（pr-review-gate `stages/issue-approved.md`）。
見張り・修正担当の引き継ぎ・`stopped` / `killed` 通知は、開始前に `plugins/dev-workflow/references/ci-watch.md` 全文を必ず Read して従う。同正本の7が `references/handover.md`「CI 見張りの修正担当の引き継ぎ」へ接続する。
`fix` の担当と段は `references/light-path.md`「CI 見張りの fix からの戻し方」を必ず Read する。通常経路のゲート取り直しは前提確認と重さ判定の新しい G から。unmanned は (4) を回さないので対象外。


## needs-reviewer

needs-reviewer → adapter 経路では G は full でも light でもこれを返す。本体は次の順で進む:
     ① `plugins/dev-workflow/references/codex-develop.md`「起動と role 解決」を必ず Read し、phase `review` の投げ先を選び直す。
     ② 同正本の監査項目を dispatch 記録として投稿する。投稿に成功するまでレビュアーを起動しない
     ③ 同正本の provider 操作でレビュアーを起動する
        一周目で payload に区画があり executor が claude なら、区画ごとに 1 体ずつ並列に起こす。description は
        `Reviewer: 区画 <k>/<n> for PR #<N> (#<issue>)` とする。executor が codex なら区画を使わず差分全体を 1 つの request に渡す。
     ④ レビュー要約と、選ばれた executor / model・dispatch 記録のコメント URL を G に渡す。review phase の executor が codex なら、worker の結果 JSON の `execution.model_resolution.requested` / `execution.model_resolution.resolved` も G に渡す。resolved が未観測なら null をそのまま渡し、要求値や dispatch 時の model で補完しない。Claude の G は照合と振り分けの G を新しく起こし、前の Gate Result ブロックと一緒に起動指示で渡す
        （pr-review-gate stages/prepare-reviewer.md「needs-reviewer の return」）。Codex の G は新しい phase gate を開始してその入力に渡す（codex-develop.md「品質と transport 差分」）
        全区画の要約が揃ってから、各要約の先頭に `区画 <k>/<n>` の見出しを付けてまとめ、照合と振り分けの G を 1 体だけ起こして渡す（G は見出しの有無で区画レビューかを判定する）。
     通常の初回レビュー依頼も補足要求も同じ ①〜④ で進める。`needs-reviewer` が一周目照合の補足要求である場合に限り、③ のレビュアーへ
     同じレビューの固定 HEAD・元の三表・残差・補足済み回数を payload のまま渡し、不足分だけを補わせる。補足結果は照合と振り分けの G を新しく起こして渡す（補足済み回数は G が最新の `レビュー三表:` の PR コメントから読むので、fresh thread でもリセットされない）
     補足は `一周目の区画:` の構成と既存 ID のまま、元の三表を置き換えず残差だけを補う。区画を計算し直さず、差分全体のレビューを始めない。
     一周目に区画があり補足の executor が claude なら、残差のある区画だけを 1 体ずつ並列に起こし、description を
     `Reviewer: 補足 区画 <k>/<n> for PR #<N> (#<issue>)` とする。一周目に区画があり executor が codex なら、
     1 つの request に残差のある区画ごとに番号・ファイル一覧・元の三表・残差を分けて載せ、`P<k>-` の ID で補わせる。
     一周目に区画が無く executor が claude なら補足レビュアーを 1 体だけ起こし、1 組の三表と残差を接頭辞の無い ID で補わせる。
     一周目に区画が無く executor が codex なら今までどおり 1 つの補足 request にする。補足済み回数は PR で 1 つだけ数える。
     develop の本体以外から G を起こす従来経路の手順（呼び出し元がレビュアーを起こす）は gate-runner.md のまま

## 重複で降りた

重複で降りた → 取り直さず主に報告

## review-incomplete

review-incomplete → reviewer を再起動しない。`agent-review:pending` のまま Gate Result の残差を報告して工程を止め、合格処理へ進まない

## failed

failed 後の W 起動／再開前に、最新 CI 用引き継ぎが可なら `references/handover.md`「起動／再開前の無効化と再許可」に従い不可を投稿し、投稿成功後だけ指示する
軽い通し方の failed → W を `段: spec` で新規起動。条件外と通常の failed の戻し方は `references/light-path.md`。以後 G は前提確認と重さ判定から
failed → 原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出／段 A だけ（昇格なし））で決める。モデルを上げるのは実装品質起因のときだけで、上げるのは決める役か実行役の一方だけ（実行側は `request --phase implement --failure executor`、判断側は `request --phase decider --failure judgment`（ゲートの 1 回目は `first`）の返す model で起こし、model が変われば新しい thread に手渡す。操作前に plugin の `references/codex-develop.md`「起動と role 解決」を必ず Read する）。
     仕様が曖昧なら仕様修正、誤検出なら反証で返す（どちらもモデルを上げない）。段 A だけなら W を据え置きで再開する
     → W を再開（再開指示に `段: implement`。再開前に測る。上限超のあとの扱いは (3) と同じく正本に従う）→ W の修正のあと、failed の Gate Result の `次の段:` どおりの G を新しく起こして再レビュー（順 3 だけなら照合と振り分け、それ以外は前提確認と重さ判定。
     2 周キャップ。範囲と 3 周目の扱いは pr-review-gate の収束ルールに従う）

## 保留

保留 → needs-approval のまま本体がオーナーに 1 アクション（許容する／しない、動作確認の結果、切り出しの確認への回答（切り出す／この PR で直す））で依頼する。止まる前に `references/handover.md` どおり記録先へ引き継ぎを残し、主に新しいセッションでの再開を案内する（channel では新しいセッションを案内せず、同ファイルの channel の案内をチャンネルに送る）。依頼を出したあとに同じ保留の通知・報告の再送が届いたときは、同ファイルの「依頼の出し直し」に従う。回答が届いたら保留の解除の G を新しく起こし、回答を渡す（新しいセッションなら同ファイルの再開手順から）。リスク許容を会話で受けたら主に PR へのコメントを求めず、自分のセッション ID（`$CLAUDE_CODE_SESSION_ID`）・その発言の日時（会話ログの timestamp。`owner-reply-check.sh` を回す前に `references/handover.md` の「会話で受けた返事の日時の取り方」を Read し、その手順で取る）・原文を G に渡す（記録の書式と真正性確認は pr-review-gate 手順 5 の「会話で受領」が正本）。エピックの子が親経由で許容を受けたときは、自分のセッション ID で確かめず、`references/epic-child-stop.md` の「親から届いた返事」の手順で確かめてから G に渡す

## needs-fix-check

needs-fix-check → 2 周目以降の周の終わりに残った指摘の直し方の判定（G が判定に回す条件は `triage-convergence.md` の周の終わりの段落）。
     本体は `references/fix-check.md` を Read し、その節「レビューの周を主に聞かずに続ける（直し方の判定）」の手順で、PR トークン上限を測ってから dev-workflow:decider を起こして判定を受け取り、
     判定の記録を記録先に投稿し、判定（決まっている／選び直しが要る）と判定の記録の URL を渡して照合と振り分けの G を新しく起こす。
     本体は自分でラベルを付け替えず、W も再開しない（W に戻す指摘の一覧とラベルは G が決める）。判定が「決まっている」で開いた周の結果
     （その周の照合と振り分けの G の return）を受け取ったら、同じ節の書式で事後報告を記録先に投稿する

4 例外の共通 resolver と dispatch 記録は `references/codex-develop.md` に従う。以下の判定役は開始時と同じ指定で request を通し、起動不可なら起こさず理由を記録し、既存の「判断できない」と URL を fresh G に渡す。起動許可かつ depleted 以外だけ通常起動する。

## needs-carryover-judge

needs-carryover-judge → 許容済みの PR で HEAD が動き、risk-carryover-check.sh が終了コード 4 を返した（G が判定に回す条件は pr-review-gate の `stages/carryover-judge.md` 手順 3-c の「終了コード 4 の判定役」）。
     本体は `request --phase decider --request-kind carryover-judge` の許可後、PR トークン上限を測ってから、`stages/carryover-judge.md` 手順 3-c の依頼の書き方で subagent_type: dev-workflow:decider・model: `opus` の判定役を起こし
     （入力は G の return の前 HEAD・新しい HEAD・前の宣言・EVIDENCE_PR_CHANGED= のファイルから作る。作業の文脈は渡さない）、判定の記録を PR に代理投稿し（書式は 3-c が正本）、
     判定と判定の記録の URL を渡して合格処理の G を新しく起こす。SHARED_BUDGET_MODE=depleted なら判定役を起こさず、3-c の書式で
     `引き継ぎ判定: 判断できない` の記録を投稿して同じく合格処理の G を新しく起こす（G が手順 6 で主に聞く）。
     本体は判定を受けて自分で宣言を投稿せず、ラベルを付けず、主に聞かない（引き継ぐか主に聞くかは合格処理の G が決める）。
     ただし、判定を受けて起こした合格処理の G が同じ前 HEAD・新しい HEAD・根拠ファイルの組で再び needs-carryover-judge を返したときは、
     判定役を起こし直さず、投稿した記録の URL を添えて主に聞く（G 側の止めが外れたときに opus の判定役を繰り返し起こさないため）

## needs-no-point-check

needs-no-point-check → 論点なしの宣言を決める役の確認に回す（`stages/no-point-check.md` 6-0 が正本）。本体は `request --phase decider --request-kind no-point-check` の許可後、PR トークン上限を測り、subagent_type: dev-workflow:decider・model: `opus` の確認役に
     宣言の本文と PR の差分だけを渡し、確認の記録を PR に投稿して合格処理の G を新しく起こす。SHARED_BUDGET_MODE=depleted なら起こさず `論点なしの確認: 判断できない` を投稿する。
     本体はラベルを付けず、主に聞かない。同じ宣言・同じ HEAD で再び返ったら確認役を起こし直さず、記録の URL を添えて主に聞く

## needs-decider

needs-decider → 仕分け表の順 6（同じ型の再発）。本体が subagent_type: dev-workflow:decider を `request --phase decider` が返した `model` で起こし、
     入力に decider.md の入力契約どおり、記録先の本文・判断に必要な関連コメント（`仕様化判断:` の記録・G の仕分けの PR コメント・順 3 の一覧表の
     PR コメントがあればそれ）・同じ型の指摘と前の周の指摘の原文・対象ファイルのパス・G の仕分け欄・W の直近の return を貼って、「この PR の中で
     同じ型を全部列挙してから直すべきか（可）、切り出すべきか（否）」を問う（順 6 の依頼はマージ可否と同じ可否と根拠の形で問う。decider.md は変えない）。
     依頼文で返答の 1 行目を `裁定: 可`・`裁定: 否`・`不足: <足りないもの>` のどれかちょうどに指定し、本体はその 1 行目で分岐する（本文の読み取りで分岐しない）。
     `裁定: 可` を「全部列挙してから直す」、`裁定: 否` を「切り出す」に読み替え、根拠とともに照合と振り分けの G を新しく起こして渡す。1 行目が `不足:` なら裁定として扱わず
     G に渡さない。足りないものを補って同じ問いで 1 回だけ依頼し直す。1 行目が 3 形のどれにも一致しなければ `不足:` と同じに扱う（1 回だけ依頼し直す）。
     2 回目も不足（または 3 形に一致しない）なら「裁定なし（入力不足）」と足りなかったものを、照合と振り分けの G を新しく起こして渡す（G は「切り出す」として主に聞く）。
     本体は裁定を代理投稿しない（G が `決める役の裁定:` の PR コメントとして記録する）
