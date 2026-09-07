# product-handover Changelog

現行版のドキュメントは [README.md](README.md) を参照。本ファイルは版履歴のみを記録する。

## v0.1.0 — `agent-owner` からの作り直し（claude-harness#206）

`agent-owner` プラグインを `product-handover` に作り直した。名前と中身の両方を変えている。

### 移行手順

旧プラグインを入れている環境では、入れ替えが必要になる。

```
/plugin uninstall agent-owner@oratta-claude-harness
/plugin install product-handover@oratta-claude-harness
```

旧プラグインが展開したファイル（`docs/legal-drafts/`・`docs/ops/` 配下、
`.github/workflows/auto-merge.yml` 等）は展開先リポジトリの資産なので、
入れ替えでは消えないし、消す必要もない。

### 名前を変えた理由

旧名は「エージェントオーナープロジェクト（＝エージェントがオーナーになるプロジェクト）」を
縮めたものだったが、修飾の向きが落ちて「エージェントの所有者（＝人間）」と読めていた。
`product-handover`（プロダクトをエージェントに引き渡す）に変えた。
`autonomous-*` は flatmate 側の「自走型」と紛れるため避けた。

### 中身を絞った内容

固有部品は法務ドラフト・窓口・教訓ログの3つだけだったので、そこに絞った。

- **6フェーズを AskUserQuestion で進めるオーケストレーターを削除**。フェーズの実体は
  他プラグインの呼び出しで、順番以外に持っている情報が無かった。順番は README に残した。
- **`/loops:dev-agent-install` への依存を外した**（loops の解散は claude-harness#205）。
  README では「dev-workflow プラグインの導入コマンド」を指す。
- **法務ドラフトの雛形を新設**（`templates/legal/terms.md` / `privacy-policy.md` /
  `refund-policy.md`）。旧版はスキル本文から genetta-inc/suimei の実装を毎回 `gh api` で
  取得する形で、参照先リポジトリが読めないと何も出せなかった。雛形をこのプラグインに置いた。
- **サポート窓口の設定を雛形化**（`templates/support-desk.md`）。ハイフン区切りを使う理由
  （Cloudflare Email Routing が `+` を完全一致解決しない）と catch-all を使わない理由は
  スキル本文からここに移した。
- **教訓ログの雛形はそのまま移設**（`templates/autonomy-lessons-skeleton.md`）。

### 捨てたテンプレート

後継があって捨てたのは `auto-merge.yml` の1件だけで、残り3件は**後継が無いまま捨てている**。
product-handover の受け入れ条件（claude-harness#206）が中身を法務・窓口・教訓ログの雛形だけに
限定しているため、ここに残す選択肢が無かった。

| ファイル | 後継 | 捨てた理由 |
|---|---|---|
| `templates/auto-merge.yml` | **あり** — dev-workflow の `templates/auto-merge/.github/workflows/auto-merge.yml` | 移設先は flatmate リポでアドバーサリアルレビュー3周と実運用を通過した版で、攻撃再現テストと運用ガイドも揃っている。二重管理をやめて片方を捨てた |
| `templates/staging-smoke.yml` | **無し** — 移設先を決める issue: claude-harness#213 | staging の外形スモークと auto-revert。dev-workflow の `revert-pr.yml` は `workflow_dispatch` で人間が PR 番号を手入力する巻き戻しであり、デプロイ完了イベントの購読も自動起票もしないので代替にならない。捨てた時点では「staging にデプロイはするが壊れても誰も気づかない」状態になる |
| `templates/settings-permissions-deny.json` | **無し** — 同上 claude-harness#213 | `gh pr merge` と force push の deny 設定。auto-merge 配線とセットで入るべきものだが、dev-workflow の auto-merge テンプレートの展開手順は `.claude/settings.json` に触れない。現状の唯一の残存箇所は loops の dev-agent-install スキルで、loops は claude-harness#205 で解散予定 |
| `templates/master-plan-issue.md` | **不要** | 運営責任マスタープラン issue の雛形。6フェーズのオーケストレーターが起票する前提の部品で、オーケストレーターを捨てたため起票する主体がいなくなった。設計判断の記録先としては教訓ログが残る |

旧ファイルは git 履歴から読める（例: `git show 0e38057:plugins/agent-owner/templates/staging-smoke.yml`）。
