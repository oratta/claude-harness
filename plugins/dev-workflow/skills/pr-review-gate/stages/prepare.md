# 前提確認と重さ判定 — pr-review-gate

以下 `$R` = `<owner>/<repo>`、`$N` = PR 番号。段の一覧と手順番号の対応表は索引 `SKILL.md`（pr-review-gate の直下）にある。

このファイルが番号で指す他の段の手順は次のファイルにある（パスは pr-review-gate の直下から）: `stages/review-run.md`（2-1 のレビュー実行者）、`stages/reviewer-brief.md`（2-1 のレビュアー向け指示）、`stages/triage.md`（2-1 の止める判定と仕分け・2-2）、`declarations.md`（手順 3・3-b）、`stages/pass.md`（手順 4・5）、`stages/hold.md`（手順 3-c・6）。

## 入口

ゲートは常にこの段から始まる。PR を作ったとき、`agent-review:failed` からの再レビュー、保留からの再開で手順 1 からやり直すときに読む。

## 前提と理由（この段で使うもの）

- **stale passed**: 開始時に残っている `agent-review:passed` は前回 HEAD の遺物（passed 後に積まれたコミットは未レビュー）。auto-merge workflow は「対象 HEAD: <現 HEAD>」コメントの照合で stale passed を機械的に無効化する（未レビュー HEAD はマージされない）が、**手順として開始時に外すことは変わらず必要** — passed が残っている間は人間からもボードからも「合格済み」に見え、再レビューで欠陥・保留に転んだ事実が隠れるため。

## 手順

### 1. 前提を揃える

1. PR に `agent-review:pending` が付いていることを確認（無ければ付ける）。**`agent-review:failed` からの再レビューもここが起点** — 修正を push したら `failed` を外して `pending` に戻し（`gh api -X DELETE repos/$R/issues/$N/labels/agent-review:failed` → `-X POST ... -f 'labels[]=agent-review:pending'`）、手順1から全工程をやり直す（前回の合格部分を流用しない。ただし再レビューの範囲は手順2の収束ルールに従い**差分限定**。方式の書き換えの後は全体レビューにし、周回は数え続ける）。
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
3. 記録先の**受け入れ条件**を取得する。判定の唯一の根拠はこれ。記録先は PR 本文で最初に現れる `Closes #N` / `Fixes #N` / `Refs #N`（大文字小文字不問）が指す issue で、**issue 参照が無い PR（Draft PR を記録先にした依頼）では PR 本文そのもの**が受け入れ条件になる（develop スキルの W は受け入れ条件を PR 本文に書く）。
   記録先の本文が空・`null`・空白のみなら受け入れ条件なし＝ **`agent-review:failed` にして終了する**（合格処理へ進めない。記録先に受け入れ条件を書いてから手順 1 からやり直す）。この検査は issue 本文経路・PR 本文経路の両方に同じく掛かり、下のコマンドが機械的に判定する（空出力を G が目で見て止まる運用に頼らない）:
   ```bash
   ISSUE=$(gh api repos/$R/pulls/$N --jq '.body' | grep -oiE '(closes|fixes|refs) #[0-9]+' | head -1 | grep -oE '[0-9]+')
   if [ -n "$ISSUE" ]; then BODY=$(gh api repos/$R/issues/$ISSUE --jq '.body // ""'); else BODY=$(gh api repos/$R/pulls/$N --jq '.body // ""'); fi
   if [ -z "$(printf '%s' "$BODY" | tr -d '[:space:]')" ]; then echo "受け入れ条件なし（記録先の本文が空・null・空白のみ）→ agent-review:failed にして終了。記録先に受け入れ条件を書いてから手順 1 からやり直す" >&2; false; else printf '%s\n' "$BODY"; fi
   ```
4. `git fetch origin` → `origin/main` をブランチへマージ（rebase + force-push は禁止）。コンフリクトが実装判断を要する規模なら `agent-review:failed` にして終了。
5. **対象 HEAD を固定する**（main 追従の push を済ませた**後**に取る。マージすると HEAD が動くため）:
   ```bash
   HEAD_SHA=$(gh api repos/$R/pulls/$N --jq '.head.sha')
   ```

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

**light で変わるのはレビュー実行者だけで、免除される工程は無い** — 実装と別コンテキストであること・手順3のリスク宣言・手順4の動作確認証拠・手順5の HEAD SHA 照合と合格前の API 実測・下の収束ルールはすべてそのまま適用する。

**区画の判定（一周目のレビューだけ）**: light / full の行数判定は上記のまま行う。別に、PR files API のファイルごとの追加＋削除を `plugins/dev-workflow/scripts/review-partitions.sh` に渡し、合計が 600 行を超えたらファイル単位の区画を作る。パス順に 400 行以下を目安に詰め、1 ファイルで 400 行を超えるものは単独の区画にする。0 行のファイルは直前の区画（先頭なら区画 1）に置く。入力は `gh api repos/$R/pulls/$N/files --paginate --jq '.[] | "\(.additions + .deletions)\t\(.filename)"' | plugins/dev-workflow/scripts/review-partitions.sh`。入力エラーで exit 2 なら止め、区画を推測しない。区画に分けるのは Claude のレビュアーだけで、Codex には差分全体を渡す。二周目以降の差分限定レビューと方式書き換え後の全体レビューには区画を使わない。従来経路で Task サブエージェントを起こす側も同じスクリプトを使う。

判定結果と根拠を PR コメントに残す（後から light 判定をサンプリング再判定できるようにするため）。2 行目には手順 1 で固定した HEAD を `固定 HEAD: <SHA>`（40 桁）の形で書く。このコメントは周ごとに増えるので、あとの段は最新の 1 件を正とする（auto-merge が宣言の照合に使う別の行と取り違えないよう、この行は固定 HEAD と書く）:

```bash
gh api -X POST repos/$R/issues/$N/comments \
  -f body="$(printf 'レビュー重量: light — docs のみ 12 行（挙動定義ファイルなし）\n固定 HEAD: %s\n合計: 12 行\n区画: なし' "$HEAD")"
```

`レビュー重量:` コメントの 3 行目以降に `review-partitions.sh` の出力（`合計:` と `区画:`、区画がある場合は一覧）をそのまま載せる。あとの G は最新コメントの区画を正とする。

## G として動くとき（develop）

この節は develop の G（`skills/develop/references/roles/gate-runner.md` の指示で動くゲート実行者）だけに関係する。develop 以外の読み手は読み飛ばしてよい。

### needs-reviewer の return（本体にレビュアーの spawn を委ねる）

G は手順 1（前提を揃える・HEAD SHA の固定）と手順 2-0（light / full の判定と `レビュー重量:` コメント）まで済ませてから、次の payload で本体に return する。本体はこれを読んでレビュアー（既定は `subagent_type: general-purpose` に `model: opus`。マージ条件・層間契約・課金/法務に触れれば `subagent_type: dev-workflow:decider` で spawn する。`general-purpose` に `model: fable` は付けない。聖域パスだけでは上げない）を spawn し、照合と振り分けの G を新しく起こしてその要約を渡す。adapter 経路（`レビュー経路: adapter`）では、本体が phase `review` で投げ先を選び直して dispatch 記録に残してからレビュアーを起動し（develop `SKILL.md` の (4)）、要約と選ばれた executor / model・dispatch 記録のコメント URL を G に渡す。adapter 経路の payload では証拠欄 5 つ（選んだ経路・実行コマンド・終了コード・出力の要点・実待ち時間）をすべて `未実行（adapter 経路）` と書き、Codex の証拠を作らない。`推奨モデル` は参考値で、実際の投げ先は本体の選び直しが決める。Codex 不可・light 判定・adapter 経路による通常の初回レビュー依頼は下の基本 payload を使う。一周目の三表照合で不足が出た補足要求の場合に限り、同じ payload に固定 HEAD・元の三表・残差・`補足済み回数: 0` を加え、同じレビューの不足した項目だけを補わせる（adapter 経路では補足要求も本体の選び直しを通る）。

```markdown
## needs-reviewer
- 判定: light | full（Codex 不可） | full（adapter 経路）
- 根拠: <2-0 の判定材料（変更ファイル一覧・行数・挙動定義ファイルの有無）、full なら Codex が使えなかった理由>
- PR 番号: #<N>
- HEAD SHA: <40 桁フル SHA（手順 1 で固定したもの）>
- 区画: <なし | review-partitions.sh の出力の区画の一覧>
- 選んだ経路: <full: exec / companion / バイナリ探索で不在、light: 未実行、adapter 経路: 未実行（adapter 経路）>
- 実行コマンド: <full: 実際の探索・起動・待機コマンド、adapter 経路: 未実行（adapter 経路）>
- 終了コード: <取得できた値 | 未取得 | 未実行（adapter 経路）>
- 出力の要点: <full: 実測した不可条件と応答、adapter 経路: 未実行（adapter 経路）>
- 実待ち時間: <タイムアウト時の実測値、完了未確認、adapter 経路: 未実行（adapter 経路）>
- 推奨モデル: opus | dev-workflow:decider（種別で指定する。`general-purpose` に `model: fable` は付けない）
- 推奨モデルの根拠: <マージ条件・層間契約・課金/法務への接触の有無、usage snapshot の残量>
- 受け入れ条件の所在: <issue #N 本文 | PR #N 本文>
- レビュアーに渡す範囲: <diff の範囲（`gh pr diff N`）、再レビューなら前回指摘の一覧>
- レビュアーに渡す指示: `skills/pr-review-gate/stages/reviewer-brief.md` の手順 2-1 のレビュアー向け指示ブロック（三表と固定書式）をそのまま貼る
- 補足 payload（一周目照合の補足要求の場合だけ）: 固定 HEAD: <SHA> / 一周目の区画: <なし | n> / 元の三表: <変更点の一覧・照合表・ハンク被覆> / 残差: <不足項目を補足先の区画ごとに分ける> / 補足済み回数: 0
- 補足指示（一周目照合の補足要求の場合だけ）: 元の三表を置き換えず、残差に挙げた不足した項目だけを補う
```

本体は executor が claude のときだけ区画ごとに起こす（develop の SKILL.md の (4) の ③）。補足は `一周目の区画:` の構成を使い、区画を計算し直さない。

レビュー要約は照合と振り分けの G が受け取る。レビュー実行者を記録する PR コメントの投稿と、そのあとの分岐は `stages/triage.md` の「G として動くとき（develop）」節と `gate-runner.md` の「段ごとの起動と入力」の「レビュアーの要約受領」に従う。

### この段で起こされたときの入力

- **ゲートの開始・CI の見張りのあとの取り直し**: 起動指示の `段: 前提確認と重さ判定` と `レビュー経路:` の行だけで手順 1 から始める。`周回:` は取り直しなら前の Gate Result の値を引き継ぎ、ゲートの開始なら 1 とする
- **W の修正後の再レビュー**（前の Gate Result が failed で `次の段: 前提確認と重さ判定`）: `stages/triage.md` の収束ルールの節（手順 2-1 の周回の規則）と、同じファイルの「この段で起こされたときの入力」の「W の修正後の再レビュー」を読む（規則はそちらが正本で、ここには写さない）。前の周の指摘は PR の仕分けコメントから読み、前の G の会話は持たない前提で動く。差分限定か全体レビューかは自分で判定し、全体レビューにしたときは修正差分の行数と前周の指摘の対象行数の 2 つを PR コメントに記録する。`周回:` は前の Gate Result の値に 1 を足す
- **保留の解除のあと**（前の Gate Result が `段: 保留の解除` で `次の段: 前提確認と重さ判定`）: 許容せず代替案で手順 2 からやり直す場合なので、手順 1 から始め、`周回:` は前の Gate Result の値を引き継ぐ

## 出口

- 手順 1 で主の許容待ちが残っていて `needs-approval` を付けたままにしたら、`stages/hold.md`（手順 6）を続ける。
- 2-0 まで済んだらレビューを起こす。レビューを起動する側（develop 以外の本体、従来経路の G）は `stages/review-run.md` を読む。レビュアーに渡す指示は `stages/reviewer-brief.md` にある。develop の G（adapter 経路）はこのファイルの「G として動くとき（develop）」節の needs-reviewer を return する。
- レビュー結果を受け取ったら、指摘が残っていれば `stages/triage.md`、残っていなければ `declarations.md`（手順 3・3-b）へ進む。
