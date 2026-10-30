# 合格処理

`$R`=`<owner>/<repo>`、`$N`=PR番号。

LLM の直接マージ（`gh pr merge`・REST merge API）は禁止。

## 入口

宣言後。許容待ちは hold。

### 4. 動作確認

条件別に実行・観測を PR 投稿:

```
## 動作確認
対象 HEAD: <$HEAD_SHA 40桁フル>

| 受け入れ条件 | 実行した手順 | 結果 |
|---|---|---|
| <条件> | <再現可能な手順> | ✅ <観測した実際の出力/画面> |
```

「テストが通った」だけは証拠にならない。

テストの全体実行を手元で行わない。対象 HEAD の CI の結果（`gh pr checks $N --repo $R`・run URL）。成功として書かない対象=未決着・失敗。作業者が PR に載せた証拠は URL・コマンド・exit code を写す（自分の実行にしない）。
| 対象 HEAD の CI | 結果の欄 |
|---|---|
| 成功 | ✅ と run の URL |
| 結論がまだ無い（Draft 未実行も含む） | 状態・run URL。CI の見張りで確認、手順5可 |
| 既に失敗 | 失敗した run の URL、CI の見張りで修正。合格可 |

自力検証不能だけ主に依頼、手順6で保留:

```
## 動作確認: 主に依頼
1. 自力検証できなかった理由: <何が足りなかったか。「面倒」「時間」は理由にならない>
2. 主にやってほしい具体的手順: <URL・クリック順・期待される結果まで書く>
3. 次回から自力検証できるようにする改善提案: <テスト整備・認証情報の登録・seed データ等。issue 化するならリンク>
```

依頼は `~/.claude/output-styles/readable.md` 節3。3点目無しは不可。

### 5. 合格処理

全周共通の判定で止まる指摘（`blocking` かつ `confirmed`、G が引用を照合済みか例外3種）のうち、主が切り出すと答えて follow-up issue に切ったものと、G が順 3 の集合一致で閉じたもの（閉じた PR コメント URL を仕分け欄に残す）以外が 0 件。主が切り出すと答えた止める指摘の置き場所: triage 2-1、hold 6の「切り出しの確認」行。手順4投稿済み・次表必須。

| 宣言の状態 | 合格処理 |
|---|---|
| 「**リスクなし**」を投稿済み | 可 |
| 回答リンク ＋ 真正性確認 | 可 |
| 会話で受領 ＋ 真正性確認 | 可 |
| 親経由で受領 ＋ 真正性確認 | 可 |
| 親経由で受領（委任） ＋ 真正性確認 | 可 |
| 引き継ぎ（3-c の4行） | 可 |
| issue で承認済み（3 の 3 行）＋ 再確認 | 可 |
| 未投稿 / 上記いずれの許容済み条件も満たさない | **不可**（手順6へ） |

宣言は許容必要のまま `主の回答: 許容 — <回答リンク>（<日時>）` 等を追記。

**リンク**: 開いて主本人の許容を確認、 `真正性確認: 済 — 確認者 <エージェント名> / <日時>` を追記。GitHub author:

```bash
gh api repos/$R/issues/comments/<comment_id> --jq '.user.login'   # 主のアカウント名と一致すること
```

外部は目視。開けない・本人でない・許容無しは手順6。

**会話で受けた許容（会話で受領）の真正性確認。** 本体の値:

```
主の回答: 許容 — 会話で受領（セッション <セッション ID> / <日時>）原文: <原文>
```

```bash
bash <plugin>/scripts/owner-reply-check.sh <セッション ID> <原文>
# 出力: 一致した主の発言ごとに MATCH: <timestamp> <本文の全文> / 最後に MATCHES=<件数>
# 終了コード: 0 = 主の発言として実在する / 1 = 実在しない / 2 = 確かめられない（引数の不備・この PC に会話ログが無い）
```

同じ timestamp の `MATCH:` 全文で意思確認。宣言コメントの作成日時（`gh api repos/$R/issues/comments/<comment_id> --jq '.created_at'`）より後のこの宣言への返事だけ有効。通れば `真正性確認: 済 — 確認者 <エージェント名> / <日時>（owner-reply-check.sh 終了コード 0）`。

- 終了コード 0 でも同じ timestamp の `MATCH:` 無し・全文が `許容しない` なら合格させない
- 宣言より前・同時、別の PR・記録先・リスクへの返事も合格させない
- 終了コード 1 は手順6（記録改変禁止）
- exit 2 は通さず理由を伝え、PR コメントか同じ PC の `/develop <記録先> 許容する` で受け直す

守備範囲: 会話ログの改変は対象外。決まった頭 `主の返事（親エピック #` / `親エピック #` は除外。頭の無い文は識別不可。

**親経由で受けた許容（親経由で受領）の真正性確認。** 本体の値（日時・原文=`MATCH:`）:

```
主の回答: 許容 — 親経由で受領（親セッション <セッション ID> / 発言 <uuid> / <日時>）停止の記録: <URL> 原文: <原文>
```

親ログで全条件必須（不成立・exit 1/2 は合格不可、手順6）:

1. `gh api repos/$R/issues/comments/<comment_id> --jq '{body, author_association, issue_url, html_url, created_at}'` で先頭行=`子の停止: 主の返事待ち`、author_association=OWNER/MEMBER/COLLABORATOR、issue_url=記録先を確認。`created_at`・`html_url` を取得。`gh api repos/$R/issues/<記録先>/comments --paginate --jq '[.[] | select(.author_association == "OWNER" or .author_association == "MEMBER" or .author_association == "COLLABORATOR") | select((.body | split("\n")[0]) == "子の停止: 主の返事待ち")] | last | .html_url'` で最新の停止の記録と URL 一致必須。不一致は手順6。

2. ID・uuid と 1 で取った `created_at`・`html_url` で実行。exit 0・同 timestamp。不一致 URL は `html_url` で実行・宣言に追記

   ```bash
   bash <plugin>/scripts/owner-reply-check.sh --relayed <セッション ID> <uuid> <停止の記録の作成日時> <停止の記録の URL>
   # 出力: 通れば MATCH: <timestamp> <本文の全文> と MATCHES=1 / 通らなければ REASON=<理由> と MATCHES=0
   # 終了コード: 0 = 通る / 1 = 通らない / 2 = 確かめられない（引数の不備・この PC に親の会話ログが無い）
   # REASON: not-found（その uuid の行が無い）/ not-owner（主の入力でない行。ツールの結果・親の発言・要約・hook の差し込み・決まった頭の打ち込み）/ not-after（停止の記録より前の発言）/ not-asked（停止の記録より後でその行より前に、URL を書いた親の発言が無い）/ not-direct（URL を書いた最後の親の発言とその行のあいだに、別の主の発言がある）
   ```

3. 全文がこの子・この PR への許容で、別の PR・別の記録先・別の子・別のリスクだけを名指しした答えでない。名指しが無い許容・この子を含む複数への許容は通す
4. timestamp が宣言コメントの作成日時より後

通れば `真正性確認: 済 — 確認者 <エージェント名> / <日時>（owner-reply-check.sh --relayed 終了コード 0）`。不成立は手順6で子のタブへ。

守備範囲: 親の会話ログの改変・頭を付けずに打ち込まれた文は塞ぎ切る対象外。

**主の委任で親経由に受けた許容（親経由で受領（委任））の真正性確認。** 本体の値（日時・原文=`MATCH:`）:

```
主の回答: 許容 — 親経由で受領（委任）（親セッション <セッション ID> / 委任の確認 <uuid> / <日時>）委任の記録: <URL> 停止の記録: <URL> 原文: <原文>
```

`--relayed` で確かめない（`not-after` になる）。

1. 親経由1の `gh api` で `子の停止: 主の返事待ち` の本文・投稿者・記録先・日時を再確認。`--jq '... | last | .html_url'` で最新の停止の記録と一致必須
2. 委任の記録が、①エピック #<E> の issue のコメントで、1〜4 行目が定型の文ちょうど、2 行目の番号が <E> ②投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` のどれか ③エピックの、投稿者が同じ 3 種の `主の委任:` で始まるコメントのうち最新 ④`lastEditedAt` が null ⑤エピックが開いている ⑥子 issue がエピックの子（sub-issue か本文の子の表にある）。<E> は子に届いた返事の頭 `主の返事（親エピック #<E> 経由）` の番号で、委任の記録 URL の issue 番号と一致必須（定型文: develop `references/epic.md`）
3. ①子 issue の番号を、本文で最初に現れる `Closes #N`・`Fixes #N`・`Refs #N` の `N` に持つ開いた PR に `needs-approval` が付いている ②その PR の、投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` で `## リスク宣言` で始まる最新のコメントが `主のリスク許容が必要。` の行を持ち、`対象 HEAD:` が PR の今の HEAD と同じで、`主の回答:` で始まる行をまだ持たない（G では、今確かめている委任の形の記録の行だけは除く） ③停止の記録の作成日時が、そのコメントの作成日時と委任の確認の timestamp の両方より後 ④停止の記録の `推奨:` の値（先頭の空白を除く）が `許容する` で始まる
4. 委任の日時（`gh api repos/$R/issues/comments/<comment_id> --jq .created_at`）・停止日時で実行。exit 0・同 timestamp の `MATCH:` 全文に任せる意思が必須

   ```bash
   bash <plugin>/scripts/owner-reply-check.sh --delegated <セッション ID> <uuid> <委任の記録の作成日時> <委任の記録の URL> <停止の記録の作成日時>
   # 出力: 通れば MATCH: <timestamp> <本文の全文> と MATCHES=1 / 通らなければ REASON=<理由> と MATCHES=0
   # 終了コード: 0 = 通る / 1 = 通らない / 2 = 確かめられない（引数の不備・この PC に親の会話ログが無い）
   # REASON: not-found（その uuid の行が無い）/ not-owner（主の入力でない行）/ not-after（委任の記録より後でない発言）/ not-asked（委任の記録より後でその行より前に、委任の記録の URL を書いた親の発言が無い）/ not-direct（URL を書いた最後の親の発言とその行のあいだに、別の主の発言がある）/ not-before（停止の記録より前でない発言）
   ```

通れば `真正性確認: 済 — 確認者 <エージェント名> / <日時>（owner-reply-check.sh --delegated 終了コード 0）`。不成立・exit 1/2 は合格させず手順6で子のタブへ。

守備範囲（委任の形）: 親が起動し直したものは可。ログ改変・穴を塞ぎ切る対象外。

**issue で承認済みの確かめ直し。** `declarations.md` 3の全条件を確かめ直す（`owner-reply-check.sh`・`agent-proposed`・`lastEditedAt`・`EPIC_DISPATCH_PARENT_EPIC`・`--unmanned`・事後報告を届ける先・返事が答えた起票の提案に目的と引用した各効果、子は承認された提案の範囲内）。不成立は手順6（不足条件も）。通れば:

```
確かめ直し: 済 — 確認者 <エージェント名> / <日時>（手順 5）
```

`真正性確認: 済` の行は足さない（3-c「前の宣言の選び方」）。

無人運用（loop-dev-agent）・主に事後報告を届ける先が無い経路は issue で承認済みを当てない。あっても手順6。

事後報告は 1 回: 宣言コメントの URL・引用・分類（G は return）。後日の不許容は手順6（revert 等）。

HEAD を実測:

```bash
HEAD_SHA=$(gh api repos/$R/pulls/$N --jq '.head.sha')
gh api repos/$R/issues/$N/comments --jq \
  "[.[] | select(.body | contains(\"$HEAD_SHA\")) | .body | split(\"\n\")[0]]"
```

3 見出し（リスク宣言・仕様宣言・動作確認）すべて必須。不足は再投稿・再確認まで停止。

**仕様宣言は記録先の記録と突き合わせる。** 最初の `Closes #N` / `Fixes #N` / `Refs #N`（大小不問）、issue 参照が無ければ PR 自身。issue 側が正。最新判断の `通し方:`・`直す文:` も確認。

```bash
ISSUE=$(gh api repos/$R/pulls/$N --jq '.body' | grep -oiE '(closes|fixes|refs) #[0-9]+' | head -1 | grep -oE '[0-9]+')
REC=${ISSUE:-$N}   # 記録先の番号: issue 参照があればその issue、無ければ PR 自身
# jq の ^ $ は行頭・行末に掛からない（文字列全体の先頭・末尾）ので、1 行目を split で切り出してから照合する。
# コメントは 30 件でページが切れるので --paginate --slurp で全ページを取り（--slurp は --jq と併用不可なので jq へパイプ）、add で 1 配列にしてから「最新 1 件」を選ぶ
gh api --paginate --slurp repos/$R/issues/$REC/comments | jq -r 'add | [.[] | select(.body | split("\n")[0] | test("^仕様化判断: (する|しない)$"))] | last | .body | split("\n")[0]'
gh api --paginate --slurp repos/$R/issues/$REC/comments | jq -r 'add | [.[] | select(.body | split("\n")[0] | test("^仕様レビュー: (APPROVE|REQUEST_CHANGES)$"))] | last | .body | split("\n")[0]'
# 2 つ目の出力が「仕様レビュー: APPROVE」ちょうどであること（最新のレビュー結果が正。古い APPROVE の後に REQUEST_CHANGES が出ていれば不合格）
bash <plugin>/scripts/spec-touch-check.sh $R $N   # SPEC_TOUCH / OPENSPEC_DIFF / 触れた規範パス。終了コード 2 = 規範パスに触れて openspec 差分なし
# 文言合わせの通し方かどうかは、同じ最新の仕様化判断のコメントの本文（2 行目以降）で見分ける
DEC=$(gh api --paginate --slurp repos/$R/issues/$REC/comments | jq -r 'add | [.[] | select(.body | split("\n")[0] | test("^仕様化判断: (する|しない)$"))] | last | .body')
WAY=$(printf '%s\n' "$DEC" | grep -cx '通し方: 文言合わせ')   # 1 以上なら文言合わせの通し方。0 件のとき grep の終了コードは 1 になるので、終了コードではなく出力の値で判定する
FIXES=$(printf '%s\n' "$DEC" | grep '^直す文: ')             # 直す要件ごとに 1 行
echo "$WAY"; printf '%s\n' "$FIXES"
# ここから下の 3 本は WAY が 1 以上のときだけ実行する。場所は PR の HEAD の作業ツリー（git rev-parse HEAD の出力が $HEAD_SHA と一致すること）。CHANGE には仕様宣言が指す change 名を入れる
ls openspec/changes/archive/*-"$CHANGE"/specs/*/spec.md | wc -l          # ちょうど 1（archive 済みで、差分が 1 ファイル）
grep -cE '^## (ADDED|REMOVED|RENAMED) Requirements' openspec/changes/archive/*-"$CHANGE"/specs/*/spec.md   # 0（ここも終了コードではなく出力の値で判定する）
grep -h '^### Requirement: ' openspec/changes/archive/*-"$CHANGE"/specs/*/spec.md | sed 's/^### Requirement: //' | while IFS= read -r REQ; do printf '%s\n' "$FIXES" | grep -qF "「${REQ}」" || echo "直す文に無い要件: ${REQ}"; done   # 何も出力されなければ、要件名はすべて直す文の行にある
```

| 記録先（issue、無ければ PR 自身）の記録 | 合格に必要な状態 |
|---|---|
| `仕様化判断: する`（`通し方: 文言合わせ` の行なし） | 「更新した」＋ PR の `openspec/` 差分か base の `openspec/changes/archive/*-<change-name>/` を実測。最新の `仕様レビュー:` コメントが `APPROVE`（REQUEST_CHANGES は不可） |
| `仕様化判断: する`＋`通し方: 文言合わせ` の行あり | `仕様レビュー:` のコメントは照合しない。実測: ①更新した＋ `仕様レビュー: 省いた（文言合わせ。` ②HEAD の `openspec/changes/archive/*-<change-name>/specs/*/spec.md` ちょうど 1 つ ③ADDED / REMOVED / RENAMED 見出しなし ④全要件名が `直す文:` の `「<要件名>」` にある。1 つでも満たさなければ合格しない。修正か、`通し方:` の行の無い仕様化判断を投稿し直して artifact 一式・仕様レビューへ |
| `仕様化判断: しない` | 「変更なし＋理由」、`openspec/` 差分は矛盾で不可。`spec-touch-check.sh` exit 2 は規範パス接触の理由必須 |
| 記録なし | 合格しない。判断からやり直す。参照無し PR は自身に記録（`gh api -X POST repos/$R/issues/$REC/comments`） |

行が無い PR は `仕様レビュー: 省いた` でも `仕様レビュー: APPROVE` 必須。

Ready 前に needs-approval。解消済みは `gh api -X DELETE repos/$R/issues/$N/labels/needs-approval`、未解消は手順6。

Draft は Ready → passed。逆順は labeled が draft でスキップされ日次まで待つ。

**Ready 化に失敗したら passed を付けず停止**。draft 不明も停止。

```bash
gh api repos/$R/issues/$N --jq '.labels[].name'   # needs-approval が無いことを確認（あれば上のとおり）
DRAFT=$(gh api repos/$R/pulls/$N --jq .draft)
case "$DRAFT" in true|false) ;; *) echo "draft を取得できない（$DRAFT）。passed を付けずに中断する" >&2; exit 1 ;; esac
if [ "$DRAFT" = true ]; then   # Draft なら Ready にする。失敗したら passed を付けずに中断する
  gh pr ready $N --repo $R || { echo "gh pr ready に失敗。passed を付けずに中断する" >&2; exit 1; }
fi
gh api -X POST repos/$R/issues/$N/labels -f 'labels[]=agent-review:passed'
gh api -X DELETE repos/$R/issues/$N/labels/agent-review:pending
gh api repos/$R/issues/$N --jq '.labels[].name'   # 実測確認（ラベル）
gh api repos/$R/pulls/$N --jq .draft              # 実測確認（Draft）
```

最後の実測確認は次の4点必須:

| 確認項目 | 期待 |
|---|---|
| `agent-review:passed` | **ある** |
| `agent-review:pending` | **ない** |
| `needs-approval` | **ない** |
| PR の `draft` | **`false`** |

needs-approval 残存は未完了。
復旧: 原因報告・解消後に再実行。Draft＋passed は外して Ready 後に再付与。判定漏れは `docs/auto-merge.md`。

聖域=SACRED、PRに明記。

未配備は「マージは人間の操作待ち」を記録。失敗か未決着なら CI の状態・見張りが結論を出すまでマージしない旨も。

**CI の見張り**: 合格実測後だけ開始。

- メイン: `references/ci-watch.md` に従い `scripts/ci-watch.sh wait` を `run_in_background` で起動
- サブエージェント: 見張りを始めずに `passed` を return（本体が開始）

正本: `references/ci-watch.md`。直しで commit が積まれたら passed を外し CI・修正後 `ready` で手順 1 から。合格するまでマージ待ち・マージ依頼に進まない。

## G として動くとき（develop）

### return の書式（passed）

```markdown
### passed のとき
G は CI の見張りを始めずに `passed` を return する（背景タスクの完了で起こされないため。見張りは本体が `references/ci-watch.md` で行う）。
- 付与ラベル: agent-review:passed（手順 5 の API 実測の結果）
- Ready 化: 実施した | 対象外（元から非 Draft）（手順 5 で `draft` が `false` になったことを実測した結果）
- コメント URL: リスク宣言 / 仕様宣言 / 動作確認証拠
- issue で承認済み: <宣言コメントの URL> / <当たった分類> / 「<引用した issue の文>」（issue で承認済みで合格したときだけ書く。無ければ行ごと省く）
```

### この段で起こされたときの入力

- 前の Gate Result が `段: 照合と振り分け`: `declarations.md` 手順3へ。前許容は宣言前に hold 3-c
- `段: 保留の解除`: 現 HEAD の `対象 HEAD:`・`## リスク宣言` 有り→5の真正性確認、無し→ `declarations.md` の手順 3。HEAD 変更＋前許容は先に hold 3-c
- **引き継ぎの判定のあと**（`段: 合格処理`・Status `needs-carryover-judge`）: `declarations.md` の手順 3 から入り直し、hold 3-c の判定の記録（`引き継ぎ判定:`）。一致する記録が無ければ `needs-carryover-judge` を返し直さず手順6。
return: 保留・needs-carryover-judge は `stages/hold.md`。

## 出口

未合格は hold、合格は終了。
