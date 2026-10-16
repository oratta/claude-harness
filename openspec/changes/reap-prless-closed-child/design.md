## Context

`cmd_reap`（`plugins/dev-workflow/scripts/epic-dispatch.sh`）は、子ごとに 1〜7 の確認を順に行い、全部通った子だけを消す。7 は「マージ済み PR の `headRefOid` と子の HEAD の完全一致」で、`--head <ブランチ>` と `--search <HEAD>` の 2 段で探し、一致しなければ出力の有無で `no-merged-pr` か `head-mismatch` を返す。この確認の役目は、マージで main に取り込まれていない作業（push していない commit、マージされていない PR）を持つワークツリーを消さないことである。

PR を伴わない記録先 issue の子は、作業を commit しない（受け入れ条件がリポジトリの変更を求めない）ので、HEAD は launch のときの `origin/main` の先端のまま残ることが多い。この HEAD はマージ済み PR の先端ではないので 7 で必ず外れる。さらに、main の先端は普通は squash マージの commit なので、`--search <HEAD>` がその commit を含む PR を返し、`headRefOid` が違うため `head-mismatch` になることがある。

エピック #1038 は並行して動く子が多く、`epic-dispatch.sh` と SKILL.md の他の節は他の子の範囲である。

## Goals / Non-Goals

**Goals:**

- PR を作らず issue を閉じて `mark done` した子のワークツリーを、作業を失わない根拠があるときに `reap` で片付ける
- 片付けないときは、理由が `kept <N> <理由>` の 1 語で読める
- マージされていない PR を持つ子を消さない既存の判定（`no-merged-pr`・`head-mismatch`）を弱めない

**Non-Goals:**

- `.gitignore` の対象（`LLM/` 以外）を守ること。既存の reap と同じく守らない
- `reap` への `--base` フラグの追加。launch と同じ環境変数 `EPIC_DISPATCH_BASE` だけを読む
- `reap` の中での `git fetch`。古い `origin/<base>` は消さない側に倒れるだけなので取りにいかない
- issue の `state_reason` による区別
- 既存の 1〜7 の確認と、片付け（close → rm → ブランチの削除）の手順の変更

## Decisions

### 消してよい根拠は「PR が 1 件も無い・issue が閉じている・HEAD が origin/<base> に含まれる」の 3 つ全部

7 で一致する行が無く HEAD が取れた子について、次の順に確かめる。どれかで外れたらそこで止め、それ以上呼ばない。

1. `gh pr list --head <ブランチ> --state all --json number --jq '.[].number'` が非 0 なら `kept <N> pr-lookup-failed`。出力があれば（マージされていない PR、閉じた PR、または HEAD と違う先端のマージ済み PR がある）従来の理由（7 の 1 段と 2 段の出力がどちらも空なら `no-merged-pr`、どちらかに出力があれば `head-mismatch`）を出す
2. `gh api repos/{owner}/{repo}/issues/<N> --jq .state` が非 0 なら `kept <N> issue-lookup-failed`。出力が `closed` でなければ従来の理由を出す
3. `git -C <子のパス> merge-base --is-ancestor <HEAD> refs/remotes/origin/<base>` が exit 0 なら通る。exit 1 なら `kept <N> unmerged-commits`、それ以外は `kept <N> git-failed`

3 つ全部を通った子は、7 を通った子と同じ手順で片付ける（ローカルブランチの削除も、先端が HEAD と同じときだけ）。

選んだ理由と、検討した他の案:

- **HEAD が origin/<base> に含まれること**が、作業を失わない直接の根拠になる。含まれていれば、ワークツリーとブランチを消しても main から同じ commit に辿り着ける。検討した案「issue が閉じていてワークツリーが clean なら消す」は、commit したが PR を作らなかった子の作業を失う。「ブランチの先端が launch のときの起点と同じ」は起点を記録していないので判定できず、main の祖先かどうかで同じ安全を得られる
- **PR が状態を問わず 1 件も無いこと**を別に確かめるのは、受け入れ条件 (2) を文字どおりに守るため。マージされていない PR の先端が main の祖先であることは普通は無いが（PR には main に無い commit がある）、空の PR や、main に取り込まれたあとで閉じた PR の子は 3 だけでは止まらない。その子は従来どおり `no-merged-pr`・`head-mismatch` で残し、オーナーの判断にする
- **issue が閉じていること**は、`mark done` が誤って付いた子（PR の経路の子がマージ前に `done` を付けた、オーナーがボードで手で `completed` に動かした）を、従来どおり 7 の理由で止めるため。issue が開いていれば、PR を作る前の子である可能性が残る
- 3 の判定は、`--search <HEAD>` の出力の有無を問わずに行う。PR の無い子の HEAD は main の squash マージの commit であることが多く、その PR が検索に出て `head-mismatch` に見えるため
- 新しい理由語は 2 つに絞る。`unmerged-commits` は「main に入っていない commit が残る」をそのまま言い、エピックへ `子 #N のワークツリーを残した（unmerged-commits）` と転記されても読める。`issue-lookup-failed` は既存の `pr-lookup-failed` と並ぶ形にした。PR がある子と issue が開いている子に新しい語を作らず従来の理由を返すのは、その子は今までと同じ理由で止まっていて、SKILL.md「エピックの扱い」手順 3 の扱いも変わらないから

### issue の `state_reason` は見ない

消してよいかは「作業が失われないか」で決まり、それは 3 の祖先の判定が担う。`not_planned` で閉じた子も、main に無い commit が無ければ消して失うものは無い。SKILL.md は PR を伴わない記録先 issue を `--reason completed` で閉じると決めているので、普段は `completed` しか来ない。`state_reason` を条件にすると、`not_planned` で閉じて `mark done` した子が `kept` で残り、オーナーの手が要る場面を増やすだけになる。

### base は `EPIC_DISPATCH_BASE`（既定 `main`）、fetch しない

launch は `--base` か `EPIC_DISPATCH_BASE`（既定 `main`）から子を作るので、同じ環境変数を読む。`--base` で別のブランチから起動した親が `EPIC_DISPATCH_BASE` を設定していなければ、子の HEAD は `origin/main` の祖先でないことがあり、`unmerged-commits` で残る（消さない側）。`origin/<base>` が手元に無ければ `merge-base` が exit 128 を返し `git-failed` で残る。`origin/<base>` が古くても、古い先端の祖先は新しい先端の祖先でもあるので、消してはいけない子を消す側には倒れない（子が自分で pull して新しい main に進んでいた場合は `unmerged-commits` で残る。親が次に fetch したあとの `reap` で通る）。

### SKILL.md は「ループの終わり」の 1 項に 1 文足すだけ

親が PR の無い子を片付けられるようになるので、子に `mark` を呼ばせる手順（#1035 で足した）はそのまま使う。足すのは、親の `reap` がこの子を片付ける条件と、commit を積んだまま閉じると `kept <N> unmerged-commits` で残ることの 1 文。「エピックの扱い」手順 3 は `kept <N> <理由>` を理由の語によらずエピックに転記するので、変えない。

### 仕様は既存の要件を MODIFIED せず、優先する要件を ADDED で足す

既存の要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」は 150 行を超え、並行して動く他の子が同じ要件を直す見込みがある。全文を写す MODIFIED は他の子の変更と衝突しやすいので、この spec で既に使われている「この要件は、要件「…」のうち次に優先する」の形で、7 の外れたときの扱いに優先する要件を足す。「ループの終わり」の規定も同じ理由で ADDED にする。

## Risks / Trade-offs

- [PR を伴わない子が作業を commit して閉じた（記録のメモを足した等）] → `kept <N> unmerged-commits` で残る。エピックに理由が転記され、オーナーが中身を見て手で消すか PR にする。頻度は低い（PR を伴わない記録先の定義が「リポジトリの変更を求めない」）
- [親が `--base` で main 以外から起動し `EPIC_DISPATCH_BASE` を設定していない] → PR の無い子は `unmerged-commits` で残る。消さない側なので受け入れる
- [`gh pr list --state all` は fork の同名ブランチの PR も拾う] → 出力があれば従来の理由で残るだけで、消す側には倒れない
