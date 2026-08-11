# auto-merge テンプレート — リポ展開手順

`agent-review:passed` が付いた PR を決定論的な条件だけで機械マージするロボット
（auto-merge.yml）と、ワンクリック巻き戻し（revert-pr.yml）、安全不変条件を CI で固定する
攻撃再現テスト（test-auto-merge-workflow.sh）の一式。genetta-inc の flatmate リポで
アドバーサリアルレビュー3周と実運用（初回バッチ 10 PR）を通過した実装が正本。

pr-review-gate スキル（dev-workflow プラグイン）とセットで使う:
スキルがレビュー・リスク宣言・動作確認を経て `agent-review:passed` を付け、
この workflow がマージ条件（ラベル / CI green / 聖域非接触 / 緊急停止なし）を機械判定してマージする。

## 構成（このディレクトリは展開先ツリーの鏡写し）

```
.github/workflows/auto-merge.yml     # マージロボット本体
.github/workflows/revert-pr.yml      # revert PR のワンクリック生成
docs/auto-merge.md                   # 運用ガイド（停止・PAT・巻き戻し・調べ方の正本）
scripts/test-auto-merge-workflow.sh  # 安全不変条件の攻撃再現テスト（CI で毎 PR 実行）
```

## 展開手順

1. **コピー**（このディレクトリの構造をそのままリポルートへ）:

   ```sh
   TPL=<このディレクトリへのパス>
   cp "$TPL"/.github/workflows/*.yml <repo>/.github/workflows/
   cp "$TPL"/docs/auto-merge.md      <repo>/docs/
   cp "$TPL"/scripts/test-auto-merge-workflow.sh <repo>/scripts/
   ```

2. **差し替え必須3点**（テンプレートのままでは動かない/合わない箇所）:

   | # | 箇所 | やること |
   |---|---|---|
   | 1 | `auto-merge.yml` の `SACRED`（`# >>> sacred-paths` マーカーの間） | 展開先リポの聖域（常に人間マージするパス）に合わせる。既定は `.github/workflows/` / `.claude/` / `CLAUDE.md` / `docs/agent-loop*`。**足したら `test-auto-merge-workflow.sh` の must-match リストにも代表パスを足す**（片方だけだとテストが落ちる） |
   | 2 | `auto-merge.yml` の `REQUIRED_CHECKS`（`# >>> required-checks` マーカーの間） | 展開先リポの ci.yml のジョブ `name:` と**完全一致**させる（既定: `shellcheck` / `bats suites`）。ズレると永久にマージされない（fail-closed）。一致はテストが CI で機械検証する |
   | 3 | `AUTOMERGE_PAT` | Fine-grained PAT（Contents: RW / Pull requests: RW、対象リポのみ）を発行して リポの Actions secrets に登録する。手順の詳細: `docs/auto-merge.md`。**登録するまで 1 件もマージされない**（dry_run で判定ログだけ確認できる） |

3. **テストを CI に組み込む**（ci.yml に 1 ステップ追加）:

   ```yaml
   - name: auto-merge workflow invariants
     run: scripts/test-auto-merge-workflow.sh
   ```

4. **ラベルを用意する**（`human-merge` は workflow が自動作成するので不要）:

   ```sh
   R=<owner>/<repo>
   gh label create "agent-review:pending" --repo "$R" --color FBCA04 --description "レビューゲート通過待ち"
   gh label create "agent-review:passed"  --repo "$R" --color 0E8A16 --description "レビューゲート通過。auto-merge 対象"
   gh label create "agent-review:failed"  --repo "$R" --color D93F0B --description "レビューで欠陥検出。修正サイクルへ"
   gh label create "needs-approval"       --repo "$R" --color 5319E7 --description "主のリスク許容待ち / 動作確認代行待ち"
   ```

5. **動作確認**: PAT 登録前に `workflow_dispatch` で `dry_run` を有効にして実行し、
   判定ログ（スキップ理由・全条件充足）が出ることを確認する。詳細: `docs/auto-merge.md` の dry run 節。

## 変えてはいけないもの（安全不変条件）

以下は flatmate でのアドバーサリアルレビューで塞いだ攻撃経路そのもの。変更するとテストが落ちる:

- **素の `pull_request` トリガーを足さない**（PR head 側の改変版 workflow が実行され、聖域判定を消した版が自分をマージできてしまう）
- **`actions/checkout` を足さない**（`pull_request_target` の安全性は「PR head のコードを一切実行しない」ことの上に成立している）
- **`gh pr merge` に戻さない**（REST + SHA ピンでないと、検証後に push されたコミットが未検証のままマージされる）
- **`AUTOMERGE_PAUSED` / PAT 未設定の fail-closed を外さない**

運用（緊急停止・巻き戻し・マージされないときの調べ方）: 展開後の `docs/auto-merge.md` を参照。
