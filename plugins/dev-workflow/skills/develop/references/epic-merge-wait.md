# 親がマージ待ちの子を扱うとき（develop）

処理前に `references/epic-loop.md`「主への報告」、`references/epic-stop.md` 手順 8 を読む。委任がある場合は `references/epic-delegation.md`、別 repo の子なら `references/epic-multirepo.md` を先に読む。

**マージ待ちの子**: 手順 8 で主に上げることになった子（一致する `親の判断:` が無いときと、それ以外のときのどちらも）のうち、今回の止まった理由が `PR のマージ待ち（` で始まる子は、主に上げる前に次を行う（子の側の手順は `references/ci-watch.md` の「`ready` を受けたあと」。それ以外の止まりは手順 8 のとおり）。前提の確認と入力の収集は `scripts/parent-merge-inputs.sh <エピック番号> <子> <PR の URL> --last-message <子の最後の発言のファイル>` を呼び、下表で分類する（更新前の版の子は停止の記録をファイルにする）。委任を使う親は `references/epic-delegation.md` の「委任が有効か」で確かめてから、親が確かめた `委任の確認の場所:` の行を `--delegation-place <行>` で渡す。入力文なら `subagent_type: dev-workflow:decider` を起こし、`references/parent-merge-criteria.md` で判断させる（本体は自分で可否を決めない）。決める役は `Bash` を持たないので、親がスクリプトの入力文を貼る。`裁定: 可` なら、古い HEAD の判断で付けた `parent-merge-approved` が PR に残っていれば先に外し（`gh api -X DELETE "repos/<owner>/<repo>/issues/<PR番号>/labels/parent-merge-approved"`。付いたままでは付け直しても新しい `labeled` が起きず、自動マージの処理には `issue_comment` のきっかけが無いので日次の判定まで走らない）、そのあと PR の今の HEAD を `headRefOid` で取り直して決める役に渡した HEAD と一致することを確かめ（一致しなければ印を付けずに主に上げる）、PR に 1 行目 `親のマージ判断: 可`・2 行目 `親が見た HEAD: <40 桁 SHA>`・3 行目 `理由: <決める役の理由>` のコメントを投稿してから `parent-merge-approved` ラベルを付ける（ラベルが付いた瞬間に自動マージの判定が走るので、コメントを先に置く）。続けて `scripts/epic-dispatch.sh reply --as parent <エピック番号> <N> <返事>` で、自動マージの処理に回したこと・子は `ci-watch.sh wait --until-merged` で見届けること・子は何も承認せず印も付けないことを伝え、エピックに `親の判断: 子 #N マージに回した — <理由> <PR の URL>` の 1 行を残す（`通した` と書かない。`stop-judge.sh` が同じ子の `通した` を繰り返しの判定に使うため）。`reply` が `failed` なら主に報告する（印は外さない）。否・不足・形が崩れた出力・迷ったときは、印を付けずに`references/epic-stop.md` の手順 8 の形で主に上げ、PR の URL と決める役の理由（`不足:` なら足りないもの）を含める。判断の印（ラベルとコメント）を付けるのは本体だけで、子は付けない。印が数えられるのは、`gh` の認証アカウントが対象リポの OWNER・MEMBER・COLLABORATOR のときだけ。

| exit | 出力 | 親が行うこと |
|---|---|---|
| 0 | `HEAD:` で始まる入力文 | 決める役に渡す |
| 3 | `主に上げる: <理由>` | 決める役を起こさず、理由を添えて手順 8 の形で主に上げる |
| 1 | stdout 空（読めない・信頼できない入力） | 決める役を起こさず、調べ直す必要を添えて手順 8 の形で主に上げる |
