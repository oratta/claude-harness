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
.github/workflows/staging-smoke.yml  # staging デプロイ後の外形スモーク + auto-revert（staging を持つリポのみ）
.claude/settings.json                # LLM に gh pr merge / main 直 push / force push を禁じる deny 設定（既存設定にマージする）
docs/auto-merge.md                   # 運用ガイド（停止・PAT・巻き戻し・調べ方の正本）
scripts/test-auto-merge-workflow.sh  # 安全不変条件の攻撃再現テスト（CI で毎 PR 実行）
```

## 展開手順

1. **コピー**（このディレクトリの構造をそのままリポルートへ）:

   ```sh
   TPL=<このディレクトリへのパス>
   cp "$TPL"/.github/workflows/auto-merge.yml "$TPL"/.github/workflows/revert-pr.yml <repo>/.github/workflows/
   cp "$TPL"/docs/auto-merge.md      <repo>/docs/
   cp "$TPL"/scripts/test-auto-merge-workflow.sh <repo>/scripts/
   ```

   `staging-smoke.yml` は staging デプロイ（`Deploy to Staging` という名前の workflow）を持つリポだけ
   コピーする（手順 6）。`.claude/settings.json` は cp ではなくマージする（手順 7）。

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

6. **staging スモーク + auto-revert**（staging デプロイを持つリポのみ。無ければ飛ばす）:

   auto-merge が main に入れた変更を staging で外形確認し、壊れていたら revert PR と incident issue を
   自動起票する（`docs/auto-merge.md` の「staging スモーク」節）。購読側の前提は
   `Deploy to Staging` という名前の workflow が main push で走ること（infra プラグインの
   `deploy-staging.yml.template` が生成する workflow がこの名前）。

   ```sh
   cp "$TPL"/.github/workflows/staging-smoke.yml <repo>/.github/workflows/
   ```

   | # | 箇所 | やること |
   |---|---|---|
   | 1 | `staging-smoke.yml` の `check` 呼び出し（`# >>> smoke-checks` マーカーの間） | 展開先プロダクトの代表的な導線（トップ・料金・利用規約など）のパスと期待文字列に書き換える。既定はパス 3 本・期待文字列なし（200 のみ確認） |
   | 2 | `vars.STAGING_DOMAIN` | staging の固定ドメインをリポの Actions variables に登録する。**未設定の間はスモークをスキップして警告だけ出す**（revert は起きない） |
   | 3 | `secrets.VERCEL_AUTOMATION_BYPASS_SECRET` | Vercel の Deployment Protection を staging に掛けている場合のみ。Protection Bypass for Automation の secret を登録する。未登録で保護に弾かれた場合は「検証不能」の警告 issue が立ち、**revert はしない**（誤検知ガード） |

   revert PR の push と作成には手順 2 の `AUTOMERGE_PAT` を共用する（未設定なら自動 revert は失敗し、
   人間対応のエラーログだけ残る）。誤検知ガード（全チェックが 3xx/401/403 で落ちたときは revert しない）は
   プラグイン側の bats テストが固定しているので、`# >>> smoke-script` マーカーの間の判定ロジックは変えない。

7. **deny 設定を `.claude/settings.json` にマージする**（auto-merge を配備する全リポで必須）:

   auto-merge は「LLM が `gh pr merge` や main への直接 push を**しない**」ことを前提にした仕組みで、
   その前提を守るのは Claude Code の permissions deny（ハーネスが実行前にブロックする層）。
   テンプレートの `.claude/settings.json` にある deny リスト 7 件を、展開先の `.claude/settings.json` に
   **既存の deny を消さずに**足す:

   ```sh
   # 展開先に .claude/settings.json が無ければそのままコピー
   [ -f <repo>/.claude/settings.json ] || cp "$TPL"/.claude/settings.json <repo>/.claude/settings.json
   # あれば deny 配列を和集合でマージ（既存の deny・他のキーは保持）
   jq -s '.[0] as $cur | .[1] as $tpl | ($cur * $tpl)
          | .permissions.deny = (($cur.permissions.deny // []) + ($tpl.permissions.deny // []) | unique)' \
     <repo>/.claude/settings.json "$TPL"/.claude/settings.json > <repo>/.claude/settings.json.merged \
     && mv <repo>/.claude/settings.json.merged <repo>/.claude/settings.json
   ```

   マージ後に `jq '.permissions.deny' <repo>/.claude/settings.json` で `Bash(gh pr merge:*)` と
   `Bash(git push --force:*)` が入っていることを確認する。`.claude/settings.json` は聖域（既定の `SACRED`
   に含まれる）なので、この変更を含む PR は human-merge になる。

## 変えてはいけないもの（安全不変条件）

以下は flatmate でのアドバーサリアルレビューで塞いだ攻撃経路そのもの。変更するとテストが落ちる:

- **素の `pull_request` トリガーを足さない**（PR head 側の改変版 workflow が実行され、聖域判定を消した版が自分をマージできてしまう）
- **`actions/checkout` を足さない**（`pull_request_target` の安全性は「PR head のコードを一切実行しない」ことの上に成立している）
- **`gh pr merge` に戻さない**（REST + SHA ピンでないと、検証後に push されたコミットが未検証のままマージされる）
- **`AUTOMERGE_PAUSED` / PAT 未設定の fail-closed を外さない**

運用（緊急停止・巻き戻し・マージされないときの調べ方）: 展開後の `docs/auto-merge.md` を参照。

## 配備済みリポ一覧（伝播先の正本）

どのリポに配備済みか・テンプレ改修時にどこへ伝播するかの正本は
**プラグインの `../../docs/auto-merge-deployments.md`**。テンプレ改修を入れたら必ずそこを見て、
載っている全リポへ展開する。新規展開したらそこに 1 行足す。
（このテンプレ配下はリポ非依存の記述に限る — 具体的なリポ名は上記の正本にのみ書く。
`tests/automerge-templates.bats` の portability テストが強制している）
