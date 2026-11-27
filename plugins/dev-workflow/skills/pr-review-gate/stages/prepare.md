# 前提確認と重さ判定 — pr-review-gate

以下 `$R` = `<owner>/<repo>`、`$N` = PR 番号。段の一覧と手順番号の対応表は索引 `SKILL.md`（pr-review-gate の直下）にある。

このファイルが番号で指す他の段の手順は次のファイルにある（パスは pr-review-gate の直下から）: `stages/review-run.md`（2-1 のレビュー実行者）、`stages/reviewer-brief.md`（2-1 のレビュアー向け指示）、`stages/triage.md`（2-1 の止める判定と仕分け）、`stages/triage-escalation.md`（2-2）、`declarations.md`（手順 3・3-b）、`stages/pass.md`（手順 4・5）、`stages/carryover.md`（手順 3-c）、`stages/hold.md`（手順 6）。

## 入口

ゲートは常にこの段から始まる。PR を作ったとき、`agent-review:failed` からの再レビュー、保留からの再開で手順 1 からやり直すときに読む。

## 前提と理由（この段で使うもの）

- **stale passed**: 開始時に残っている `agent-review:passed` は前回 HEAD の遺物（passed 後に積まれたコミットは未レビュー）。auto-merge workflow は「対象 HEAD: <現 HEAD>」コメントの照合で stale passed を機械的に無効化する（未レビュー HEAD はマージされない）が、**手順として開始時に外すことは変わらず必要** — passed が残っている間は人間からもボードからも「合格済み」に見え、再レビューで欠陥・保留に転んだ事実が隠れるため。

## 手順

### 1. 前提を揃える

**着手前の重複チェック（手順 1 の 1 より前に行う）**: ラベルの操作や main の取り込みに入る前に、PR の現在の HEAD（`gh api repos/$R/pulls/$N --jq .head.sha`）と、最新の `レビュー重量:` コメントの `固定 HEAD:` と `担当セッション:` を見る。`固定 HEAD:` が現在の HEAD と一致し、`agent-review:passed` が付いておらず、`担当セッション:` が自分のセッション ID（`$CLAUDE_CODE_SESSION_ID`）と違う（行が無い・自分の ID が取れないときも違うとみなす）ときは、別のセッションの担当が同じ HEAD で着手済みなので、手順 1 以降を何もせず降り、降りた旨・着手済みコメントの URL・その `担当セッション:` の値を return に書く（develop の G は Status `重複で降りた`・`次の段: なし`）。それ以外（HEAD が動いた・コメントが無い・passed が付いている・`担当セッション:` が自分と同じ）は通常どおり進む。同じセッションの担当は、そのセッションの本体が自分の会話と `ListAgents` で確かめられるので、ここでは止めない。別のセッションの担当は、こちらから生きているかを確かめられず止めることもできないので、降りた return を受けた本体は取り直さずに主に報告する（develop の本体の動きは `skills/develop/references/roles/gate-runner.md` の段の表）。起動指示に `取り直し: 明示（理由）` の行がある起動と、前の段の `## Gate Result` を貼って起こされた起動（保留の解除のあと・W の修正後の再レビュー）は、同じ HEAD でも降りずに進む。develop を通さない本体が、主から前の担当は止まっていると聞いて自分で取り直すときも、自分に `取り直し: 明示（理由）` の行があるものとして扱う。確認と投稿は不可分でないので、ほぼ同時の起動は防げない（最後の止め役は手順 5 の HEAD 照合）。前のセッションの担当が参照できなくても生きている場合があり、そのまま待機している担当と同じ HEAD に二重で走る事故があった（#249）。

1. PR に `agent-review:pending` が付いていることを確認（無ければ付ける）。**`agent-review:failed` からの再レビューもここが起点** — 修正を push したら `failed` を外して `pending` に戻し（`gh api -X DELETE repos/$R/issues/$N/labels/agent-review:failed` → `-X POST ... -f 'labels[]=agent-review:pending'`）、手順1から全工程をやり直す（前回の合格部分を流用しない。唯一の例外は手順 3-c の主の許容の引き継ぎ（`stages/carryover.md`）。ただし再レビューの範囲は手順2の収束ルールに従い**差分限定**。方式の書き換えの後は全体レビューにし、周回は数え続ける）。
   このとき **`needs-approval` の要否も判断する** — 保留理由が解消しているなら
   `gh api -X DELETE repos/$R/issues/$N/labels/needs-approval` で外し、
   まだ主の許容待ちが残っているなら**付けたまま**にして手順6を続行する。黙って持ち越さない。
2. **stale な `agent-review:passed` を必ず外す**（理由はこのファイルの「前提と理由」の stale passed）。外してからレビューを始める（合格なら手順5で付け直す）。
   passed を外したら、PR が Draft でなければ `gh pr ready --undo` で Draft に戻す（手順5の合格処理で Ready にした PR に commit が積まれた取り直しのあいだ、周回ごとに CI を走らせないため。次の合格で Ready に戻る）。
   passed が付いていなかったとき（初回のゲート・failed からの再レビュー・保留からの再開）は Draft に戻さない（人間が非 Draft で作った PR を、failed や保留のまま Draft に残さないため）:
   ```bash
   if gh api repos/$R/issues/$N --jq '.labels[].name' | grep -qx 'agent-review:passed'; then   # passed が付いていたら
     gh api -X DELETE repos/$R/issues/$N/labels/agent-review:passed                           # 外して
     if [ "$(gh api repos/$R/pulls/$N --jq .draft)" = false ]; then gh pr ready --undo $N --repo $R; fi   # 非 Draft なら Draft に戻す
   fi
   ```
3. 記録先の**受け入れ条件**を取得する。判定の唯一の根拠はこれ。記録先は PR 本文で最初に現れる `Closes #N` / `Fixes #N` / `Refs #N`（大文字小文字不問）が指す issue で、**issue 参照が無い PR（Draft PR を記録先にした依頼）では PR 本文そのもの**が受け入れ条件になる（develop スキルの W は受け入れ条件を PR 本文に書く）:
   ```bash
   ISSUE=$(gh api repos/$R/pulls/$N --jq '.body' | grep -oiE '(closes|fixes|refs) #[0-9]+' | head -1 | grep -oE '[0-9]+')
   if [ -n "$ISSUE" ]; then gh api repos/$R/issues/$ISSUE --jq '.body'; else gh api repos/$R/pulls/$N --jq '.body'; fi
   ```
4. `git fetch origin` → `origin/main` をブランチへマージ（rebase + force-push は禁止）。コンフリクトが実装判断を要する規模なら `agent-review:failed` にして終了。
5. **対象 HEAD を固定する**（main 追従の push を済ませた**後**に取る。マージすると HEAD が動くため）:
   ```bash
   HEAD_SHA=$(gh api repos/$R/pulls/$N --jq '.head.sha')
   ```

6. HEAD 固定後、最新の仕様化判断に `通し方: 軽い` の行があるときだけ、`stages/prepare-light.md` の確認を行う。行が無ければ確認も投稿もせず手順 2-0 へ進む。

### 2. レビュー（実装と別コンテキスト）

**実装したコンテキストで自己レビューしない。** これは light / full のどちらでも変わらない。

#### 2-0. レビュー重量の判定（light / full）

レビューの重さを**変更内容から先に決める**。Codex レビューは重い（実測: 3回中1回は10分でタイムアウト、成功しても14分）。ドキュメントの誤字修正にこの待ち時間を毎回払う価値はない一方、判定を印象で行うと急いでいるときほど軽い側に倒れる。そこで**判定材料を機械的に取る**:

```bash
gh pr diff $N --name-only                       # 変更ファイル一覧
gh pr diff $N | grep -c '^[+-][^+-]'            # 変更行数（追加＋削除）
```

| 重量 | 条件 | レビュー実行者 |
|---|---|---|
| **light** | 下の (a) か (b) の**片方をすべて**満たす | Task サブエージェント（Codex を省く） |
| **full**（**既定**） | それ以外。判定が付かない場合を含む | Codex CLI →（使えなければ）Task サブエージェント |

**light にしてよい条件**:

- **(a) ドキュメントのみ** — 変更ファイルがすべて `*.md` であり、かつ**エージェントの行動を定義するファイルを1つも含まない**（`CLAUDE.md` / `AGENTS.md`、`.claude/` 配下、`.github/workflows/`、スキル・コマンド・エージェント定義、憲法 doc）。これらは読み物ではなく**実行される規約**なので、拡張子が md でも full。
- **(b) 挙動を変えない微修正** — 合計変更が **30 行以下**、かつ diff を読んだ結果**挙動を変えない**と判断できる（コメント・typo・文言修正・テストデータのみ）。実行される分岐・条件・入出力に1行でも触れていれば full。

**迷ったら full に倒す（fail-closed）。「判断がつかない」は light の理由にならない。** 誤りは片側だけ危険で、full を light にすると重い変更が独立性の低いレビューで auto-merge に乗るのに対し、light を full にした損失は待ち時間だけ。

**light で変わるのはレビュー実行者だけで、免除される工程は無い** — 実装と別コンテキストであること・手順3のリスク宣言・手順4の動作確認証拠・手順5の HEAD SHA 照合と合格前の API 実測・収束ルール（stages/triage-convergence.md）はすべてそのまま適用する。

**区画の判定（一周目のレビューだけ）**: light / full の行数判定とは別に、600 行以下でも次のコマンドを走らせる。`${CLAUDE_PLUGIN_ROOT}` が未設定のときは、この段のファイル（stages/prepare.md）の位置から `../../../scripts/review-partitions.sh` を絶対パスに解決して使う。入力は 2 段で作る（1 本のパイプにしない。パイプだと `gh api` が失敗しても空の入力が渡り、「合計 0 行」と区別できない）。

```bash
f="$(mktemp)"
gh api repos/$R/pulls/$N/files --paginate --jq '.[] | "\(.additions + .deletions)\t\(.filename)"' > "$f" || { echo "gh api 失敗: 区画を推測せず止める"; exit 1; }
${CLAUDE_PLUGIN_ROOT}/scripts/review-partitions.sh < "$f"
```

(a) `gh api` が失敗したら止め、区画を推測しない（取得失敗を「合計 0 行」として扱わない。exit 2 で止めるのと同じ扱い）。(b) `review-partitions.sh < "$f"` の `合計:` を `gh api repos/$R/pulls/$N --jq '.additions+.deletions'` と比べ、一致しなければ止める。exit 2 に限らず 0 以外ならすべて止め（exit 127 = スクリプトが見つからない場合を含む）、区画を推測しない。区画に分けるのは Claude のレビュアーだけで、Codex には差分全体を渡す。二周目以降の差分限定レビューと方式書き換え後の全体レビューには区画を使わない。従来経路で Task サブエージェントを起こす側も同じスクリプトを使う。

合計が 600 行を超えた一周目だけ、区画を作る詳細として `stages/prepare-partitions.md` を読む。


判定結果と根拠を PR コメントに残す（後から light 判定をサンプリング再判定できるようにするため）。2 行目には手順 1 で固定した HEAD を `固定 HEAD: <SHA>`（40 桁）の形で書く。最後の行には `担当セッション: <$CLAUDE_CODE_SESSION_ID の値>`（取れなければ `担当セッション: 不明`）を書く（手順 1 の冒頭の重複チェックが、別のセッションの担当かを見分けるのに使う）。このコメントは周ごとに増えるので、あとの段は最新の 1 件を正とする（auto-merge が宣言の照合に使う別の行と取り違えないよう、この行は固定 HEAD と書く）:

```bash
gh api -X POST repos/$R/issues/$N/comments \
  -f body="$(printf 'レビュー重量: light — docs のみ 12 行（挙動定義ファイルなし）\n固定 HEAD: %s\n合計: 12 行\n区画: なし\n担当セッション: %s' "$HEAD" "${CLAUDE_CODE_SESSION_ID:-不明}")"
```

`レビュー重量:` コメントの 3 行目から `担当セッション:` の行の前までに `review-partitions.sh` の出力（`合計:` と `区画:`、区画がある場合は一覧）をそのまま載せる。あとの G は最新コメントの区画を正とする。二周目以降（差分限定・全体レビューの周）は区画に分けないので、`区画: なし` を載せる。

## G として動くとき（develop）

この節は develop の G（`skills/develop/references/roles/gate-runner.md` の指示で動くゲート実行者）だけに関係する。develop 以外の読み手は読み飛ばしてよい。

軽い通し方の条件外の failed は `stages/prepare-light.md` を読む。

adapter 経路・Codex 不可・オフ・light の needs-reviewer の出口では `stages/prepare-reviewer.md` を読む。

### この段で起こされたときの入力

- **ゲートの開始・CI の見張りのあとの取り直し**: 起動指示の `段: 前提確認と重さ判定` と `レビュー経路:` の行だけで手順 1 から始める。`周回:` は取り直しなら前の Gate Result の値を引き継ぎ、ゲートの開始なら 1 とする
- **W の修正後の再レビュー**（前の Gate Result が Status failed で `次の段: 前提確認と重さ判定`。`原因: 軽い通し方の条件外` を除く。前の `段:` は問わない。保留の解除の G が代替案への作り直しで返した failed もここに入る）: `stages/triage-convergence.md` の収束ルールの節（手順 2-1 の周回の規則）と、同じファイルの「この段で起こされたときの入力」の「W の修正後の再レビュー」を読む（規則はそちらが正本で、ここには写さない）。前の周の指摘は PR の仕分けコメントから読み、前の G の会話は持たない前提で動く。差分限定か全体レビューかは自分で判定し、全体レビューにしたときは修正差分の行数と前周の指摘の対象行数の 2 つを PR コメントに記録する。`周回:` は前の Gate Result の値に 1 を足す
- **保留の解除のあと**（前の Gate Result が `段: 保留の解除` で Status `次の段へ`・`次の段: 前提確認と重さ判定`。W の修正が要らないときだけ。failed の場合は上の再レビューの入口に入る）: 手順 1 から始め、`周回:` は前の Gate Result の値を引き継ぐ（足さない）

## 出口

- 手順 1 で主の許容待ちが残っていて `needs-approval` を付けたままにしたら、`stages/hold.md`（手順 6）を続ける。
- 2-0 まで済んだらレビューを起こす。レビューを起動する側（develop 以外の本体、従来経路の G）は `stages/review-run.md` を読む。レビュアーに渡す指示は `stages/reviewer-brief.md` にある。develop の G（adapter 経路）は`stages/prepare-reviewer.md` の「G として動くとき（develop）」節の needs-reviewer を return する。
- レビュー結果を受け取ったら、指摘が残っていれば `stages/triage.md`、残っていなければ `declarations.md`（手順 3・3-b）へ進む。
