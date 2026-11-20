## MODIFIED Requirements

### Requirement: Orca 経路の親はマージ待ちの子の PR を基準で判断し、通せるものに判断の印を付ける
develop の `references/epic-merge-wait.md` は、epic-stop.md「停止の処理」手順８から回される、マージ待ちで止まった子の扱いを規定しなければならない（MUST）。この要件は、要件「Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる」の `stopped` で主に上げるどちらの経路（一致する `親の判断:` が無いとき、と、判断が「主に上げる」・判断できなかったとき）にも、今回の止まった理由が `PR のマージ待ち（` で始まる子について優先する（主に上げる前にこの手順を行い、ここで主に上げると決まったものは同じ要件の報告の形で上げる）。手順 2 の文は変えない。手順 8 は、今回の止まった理由が `PR のマージ待ち（` で始まる止まりを照らし直さずこの手順に回す分岐を持つ。

- **気づく経路**: 子が最後の発言の末尾に `止まった理由: PR のマージ待ち（human-merge）: <PR の URL>` の行を書いて止まり、`wait --resolve` の判断がマージを通さないので親が `stopped` で起こされる経路に乗る。epic-dispatch.sh にマージ待ちを返す出力を足さない
- **前提の確認と入力の収集**（`scripts/parent-merge-inputs.sh <エピック番号> <子> <PR の URL> --last-message <子の最後の発言のファイル> [--delegation-place <委任の確認の場所: の行>]` が行う。MUST。親は `gh` を手で連ねて前提を確かめない）: 次の 4 つの前提のどれかを満たさなければ、スクリプトは `主に上げる: <理由>` を stdout に出して exit 3 で終わり、親は決める役を起こさずに主に上げる（MUST）。PR の base ブランチの `.github/workflows/auto-merge.yml` に `parent-merge-approved` の語がある／PR が open で、見送りラベル（`human-merge`・`needs-human-merge`・`human-only`・`needs-approval`）のうち付いているのが `human-merge` だけ／`止まった理由:` の行の PR の本文で最初に現れる `Closes #N`・`Fixes #N`・`Refs #N` の `N` が子 issue の番号である／PR に、今の HEAD を `親が見た HEAD:` に持つ `親のマージ判断: 可` のコメントがまだ無い（あれば自動マージの処理の側が止めているので、`docs/auto-merge.md` の「親の判断の印を付けたのにマージされないとき」の調べ方を添える）。前提を満たしたとき、スクリプトは決める役への入力文を stdout に出して exit 0 で終わる。読めない・引数の誤り・エピックか子 issue の投稿者が OWNER・MEMBER・COLLABORATOR でないときは stdout を空にして exit 1 で終わり、親は主に上げる
- **判断**: スクリプトの入力文を渡して `subagent_type: dev-workflow:decider` を起こし、`references/parent-merge-criteria.md` で判断させる（MUST）。親は自分で可否を決めない（MUST NOT）。決める役は `Bash` を持たないので、入力文は親が貼る。入力文は、エピックの本文、子 issue の本文と OWNER・MEMBER・COLLABORATOR の `親エピックからの注意書き:`、子の最後の発言の全文（更新前の版の子は停止の記録）、PR の本文とラベルと今の HEAD の SHA、変更ファイルの一覧と差分、PR のリスク宣言・動作確認・ゲートのコメント（投稿者が OWNER・MEMBER・COLLABORATOR のもの）、CI の結果、`auto-merge.yml` の `# >>> sacred-paths` 〜 `# <<< merge-condition-paths` の行（聖域とマージ条件そのもののパスの正規表現）、自動マージの処理が `human-merge` を付けた旨の投稿（`🔒 **auto-merge 対象外（聖域パス接触）**` で始まるもの）、あれば配役表、エピックに有効な委任の記録の候補があればその本文と URL（有効かどうかはスクリプトが判定せず、親が `epic-delegation.md` の「委任が有効か」で確かめる）、親が渡した `委任の確認の場所:` の行を含む（MUST）
- **可のとき**: 古い HEAD の判断で付けた `parent-merge-approved` が PR に残っていれば、先に外す（MUST。付いたままでは付け直しても新しい `labeled` が起きず、自動マージの処理には `issue_comment` のきっかけが無いので、日次の判定まで判定が走らない）。そのあと PR の今の HEAD を取り直し、決める役に渡した HEAD と一致することを確かめる（一致しなければ印を付けずに主に上げる。MUST）。一致したら、PR に 1 行目 `親のマージ判断: 可`・2 行目 `親が見た HEAD: <40 桁 SHA>`・3 行目 `理由: <決める役の理由>` のコメントを投稿し、そのあとに `parent-merge-approved` ラベルを付ける（この順。MUST）。続けて `epic-dispatch.sh reply --as parent <エピック番号> <N> <返事>` で、自動マージの処理に回したこと・子は `ci-watch.sh wait --until-merged` で見届けること・子は何も承認せず印も付けないことを伝え、エピックに `親の判断: 子 #N マージに回した — <理由> <PR の URL>` の 1 行を残す（MUST）。`reply` が `failed` なら主に報告する（印は外さない）
- **否・不足・形が崩れた出力・迷ったとき**: 印を付けずに主に上げる（MUST）。報告には PR の URL と決める役の理由（`不足:` なら足りないもの）を含める
- **印を付ける者**: 判断の印（ラベルとコメント）を付けるのは親だけで、子は付けない（MUST NOT）ことを書く。親が `gh pr merge` や merge API を叩いてはならない（MUST NOT）。印が数えられるのは `gh` の認証アカウントが対象リポの OWNER・MEMBER・COLLABORATOR のときだけであることを書く（SHALL）

この要件の守備範囲で入力として扱うのは、子の最後の発言（更新前の版の子は停止の記録）、`gh` で読める PR と PR の base ブランチの `auto-merge.yml`、スクリプトの出力、決める役の出力である。委任が有効かの判定と `委任の確認の場所:` の確認、決める役の起動、印の付け替えは親の手順に残り、スクリプトは行わない。拾いたい誤りは、印が効かないリポや `human-merge` 以外の見送りラベルが付いた PR に印を付けること、決める役の判断を経ずに印を付けること、判断したあとに変わった HEAD に印を付けること、ラベルをコメントより先に付けて最初の判定を空振りさせること、マージされない印を付け直し続けること、古い HEAD のラベルを残したまま新しい HEAD を承認して判定を走らせないことの 6 つである。次は通ってよく、この要件では止めない: 決める役が通してよい PR を否とすること（主の手間は増えるが危険は無い）／マージ待ちの止まりのたびに `stop-judge.sh` のモデル呼び出しが 1 回空振りすること／子が技術的には印を付けられること（受け取り側の判定と手順書の規則に任せる。#1030 で主が受け入れた）。基準をすり抜ける PR が見つかるたびに手順を足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 親の手順にマージ待ちの判断と印の付け方が書かれている
- **WHEN** `references/epic-merge-wait.md` の Orca 経路の手順のあとの段落を読む
- **THEN** 今回の止まった理由が `PR のマージ待ち（` で始まる子について、手順 8 で主に上げるどちらの経路でも報告の前に行うこと、前提の確認と入力の収集に `parent-merge-inputs.sh` を呼ぶこと（出力が `主に上げる:` なら主に上げ、入力文なら決める役に貼ること。`gh` の書き方と入力の列挙は手順書に書かない）、4 つの前提（PR の base ブランチの `auto-merge.yml` の `parent-merge-approved`、見送りラベルが `human-merge` だけ、PR 本文の最初の `Closes`・`Fixes`・`Refs` が子 issue の番号、今の HEAD の判断のコメントがまだ無い）、`dev-workflow:decider` に `parent-merge-criteria.md` で判断させること、可のとき残っている `parent-merge-approved` を外し、HEAD を確かめてから `親のマージ判断: 可`・`親が見た HEAD:` のコメント → `parent-merge-approved` ラベルの順に付け、`reply --as parent` で子に伝え、エピックに `マージに回した` の 1 行を残すこと、否・不足・迷ったときは主に上げること、印を付けるのは親だけで直接マージしないことが書かれている

#### Scenario: マージ待ち以外の止まりは今までどおり
- **WHEN** 今回の止まった理由が `PR のマージ待ち（` で始まらない
- **THEN** 親はこの手順を行わず、手順 8 のとおりに扱う

## ADDED Requirements

### Requirement: parent-merge-inputs.sh はマージ待ちの子の前提を確かめ、決める役への入力文を組み立てる
`parent-merge-inputs.sh <エピック> <子> <PR の URL> --last-message <ファイル> [--delegation-place <行>]` は、マージ待ちの 4 つの前提を確かめ、満たせば exit 0 で決める役への入力文、欠けば exit 3 で `主に上げる: <理由>`、読めない・投稿者が信頼できないときは exit 1（stdout 空）を返さなければならない（MUST）。モデルを呼ばず、委任の有効性を判定しない（MUST NOT）。

守備範囲は `gh` で読める issue・PR・`auto-merge.yml`・配役表と親が渡す 2 引数。拾う誤りは、前提を欠く PR に決める役を起こすこと・信頼できない投稿者の本文を渡すことの 2 つで、入力の穴を塞ぎ切ることは完了条件にしない。

#### Scenario: 前提を満たすと入力文が出る
- **WHEN** 4 つの前提を満たす PR と子で呼ぶ
- **THEN** exit 0 で、1 行目が `HEAD: ` と PR の今の HEAD の SHA で、次の見出しの節がすべて出る: エピックの本文・子 issue の本文・親エピックからの注意書き・子の最後の発言・PR の本文とラベル・変更ファイルの一覧・差分・PR のコメント・CI の結果・auto-merge.yml の聖域とマージ条件の行・`human-merge` を付けた投稿・配役表・委任の記録の候補・委任の確認の場所。該当が無い節は見出しに `なし` と書く。子の最後の発言のファイルの本文と聖域の行が入る

#### Scenario: 前提を 1 つでも欠くと主に上げる
- **WHEN** 4 つの前提（PR の base ブランチの `auto-merge.yml` に `parent-merge-approved` の語がある・PR が open で見送りラベルが `human-merge` だけ・PR 本文で最初の `Closes`・`Fixes`・`Refs` の番号が子の番号・今の HEAD の `親のマージ判断: 可` がまだ無い）のうち、`auto-merge.yml` に `parent-merge-approved` が無い・見送りラベルが `human-merge` 以外にも付いている・PR 本文の最初の `Closes` が別の番号・今の HEAD の `親のマージ判断: 可` がすでにある、のどれかで呼ぶ
- **THEN** exit 3 で、stdout は `主に上げる: ` で始まる 1 行だけで、満たさなかった前提が書かれている。今の HEAD の判断のコメントがあるときは `docs/auto-merge.md` の「親の判断の印を付けたのにマージされないとき」への案内が付く

#### Scenario: 信頼できない投稿者・読めない入力は exit 1
- **WHEN** エピックか子 issue の投稿者が OWNER・MEMBER・COLLABORATOR でない、または `--last-message` のファイルが無い、または引数が足りない
- **THEN** exit 1 で stdout は空である

#### Scenario: 信頼できない投稿者の通常のコメントは入力文に入らない
- **WHEN** PR のコメントに、投稿者が OWNER・MEMBER・COLLABORATOR でなく、先頭が `🔒 **auto-merge 対象外（聖域パス接触）**` でないものがある
- **THEN** そのコメントの本文は入力文に出ない

#### Scenario: human-merge を付けた自動マージの処理の投稿は投稿者によらず入る
- **WHEN** PR に、投稿者が OWNER・MEMBER・COLLABORATOR でなく、先頭が `🔒 **auto-merge 対象外（聖域パス接触）**` のコメントがある（`.github/workflows/auto-merge.yml` が生成する）
- **THEN** その本文は `human-merge` を付けた投稿の節に出る

#### Scenario: 委任の記録の候補は有効かを判定せず出す
- **WHEN** エピックに、投稿者が OWNER・MEMBER・COLLABORATOR で 1 行目が `主の委任: 論点なしの止まり` のコメントが複数あり、`--delegation-place` を渡した
- **THEN** 最新の 1 件の本文と URL が委任の記録の候補の節に、渡した行が委任の確認の場所の節にそのまま出て、有効かどうかを判定した語は出ない

#### Scenario: 配役表は作業ツリーのあるものだけ入る
- **WHEN** 作業ツリーに `.claude/casting/project.md` だけがある
- **THEN** 配役表の節に `project.md` の本文だけが出る

#### Scenario: 手順書は呼び方と分類だけを持つ
- **WHEN** `references/epic-merge-wait.md` の **マージ待ちの子** の段落と `parent-merge-criteria.md` の「守備範囲」を読む
- **THEN** `parent-merge-inputs.sh` の呼び方と、出力が `主に上げる:` なら主に上げ入力文なら決める役に渡す分類があり、前提の確認の `gh api` の書き方と入力の列挙は無い。親が委任の有効性を `epic-delegation.md` の「委任が有効か」で確かめてから `--delegation-place` を渡すことは残っている
