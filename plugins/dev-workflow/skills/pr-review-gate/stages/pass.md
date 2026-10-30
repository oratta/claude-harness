# 合格処理（手順 5）

`$R`=`<owner>/<repo>`、`$N`=PR番号。

LLM の直接マージ（`gh pr merge`・REST merge API）は禁止。

## 入口

手順 4（`stages/pass-verify.md`）のあと。許容待ちは hold（依頼の文面は `~/.claude/output-styles/readable.md` 節3）。

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

許容済みの宣言（「リスクなし」と引き継ぎの 4 行以外）は、宣言の形のファイル（回答リンク・会話で受領は `stages/authenticity.md`、親経由で受領は `stages/authenticity-relayed.md`、親経由で受領（委任）は `stages/authenticity-delegated.md`、issue で承認済みは `stages/issue-approved.md` の確かめ直し）で真正性を確認してから先へ進む。不成立は手順6。

HEAD:

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
gh api --paginate --slurp repos/$R/issues/$REC/comments | jq -r 'add | [.[] | select(.body | split("\n")[0] | test("^仕様化判断: (する|しない)$"))] | last | .body | split("\n")[0]'
gh api --paginate --slurp repos/$R/issues/$REC/comments | jq -r 'add | [.[] | select(.body | split("\n")[0] | test("^仕様レビュー: (APPROVE|REQUEST_CHANGES)$"))] | last | .body | split("\n")[0]'
# 2 つ目の出力が「仕様レビュー: APPROVE」ちょうどであること（最新のレビュー結果が正。古い APPROVE の後に REQUEST_CHANGES が出ていれば不合格）
bash <plugin>/scripts/spec-touch-check.sh $R $N   # SPEC_TOUCH / OPENSPEC_DIFF / 触れた規範パス。終了コード 2 = 規範パスに触れて openspec 差分なし
DEC=$(gh api --paginate --slurp repos/$R/issues/$REC/comments | jq -r 'add | [.[] | select(.body | split("\n")[0] | test("^仕様化判断: (する|しない)$"))] | last | .body')
WAY=$(printf '%s\n' "$DEC" | grep -cx '通し方: 文言合わせ')   # 1 以上なら文言合わせの通し方（`stages/pass-wording.md`）。grep の終了コードではなく出力の値で判定する
echo "$WAY"
```

| 記録先（issue、無ければ PR 自身）の記録 | 合格に必要な状態 |
|---|---|
| `仕様化判断: する`（`通し方: 文言合わせ` の行なし） | 「更新した」＋ PR の `openspec/` 差分か base の `openspec/changes/archive/*-<change-name>/` を実測。最新の `仕様レビュー:` コメントが `APPROVE`（REQUEST_CHANGES は不可） |
| `仕様化判断: する`＋`通し方: 文言合わせ` の行あり | `仕様レビュー:` のコメントは照合しない。`stages/pass-wording.md` の実測 4 点。満たさなければ合格しない |
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

## 出口

未合格は hold、合格は終了。
