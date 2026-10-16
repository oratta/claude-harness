# product-handover

プロダクトをエージェントに引き渡すときにだけ必要になる固有部品を配るプラグイン。
持っているのは雛形4種だけで、オーケストレーターもスキルも持たない。

| 部品 | 置き場所 | 展開先の目安 |
|---|---|---|
| 法務ドラフト（利用規約・プライバシーポリシー・返金ポリシー・特定商取引法に基づく表記） | `templates/legal/` | `docs/legal-drafts/` |
| インシデント対応手順書（個人情報漏えいの法定報告期限を含む） | `templates/ops/incident-runbook.md` | `docs/ops/incident-runbook.md` |
| サポート窓口メールの設定 | `templates/support-desk.md` | `docs/ops/support-desk.md` |
| 教訓ログ | `templates/autonomy-lessons-skeleton.md` | `docs/ops/autonomy-lessons.md` |

```bash
/plugin install product-handover@oratta-claude-harness
```

雛形はコピーして使う。展開先で問題が見つかったら、展開先だけを直して終わらせず
このプラグイン側を直す PR を出す（次のプロダクトで同じ問題を踏まないため）。

## 引き渡しの順番

引き渡しは5段階で、このプラグインは4番目だけを担う。前の3つは他のプラグインが持っているので、
ここから起動はせず、順番だけを示す。

1. **インフラ** — `/infra:infra-setup`（Vercel + Supabase + GitHub Actions）
2. **開発ワークフローの導入** — dev-workflow プラグインの導入コマンド（#204 のマージ後は `develop` スキルが正本）
3. **auto-merge の配線** — dev-workflow の `templates/auto-merge/` をリポに展開する
4. **運営の引き渡し** — このプラグインの雛形4種を展開し、窓口・法務ドラフト・インシデント対応手順書を用意する
5. **マーケ運転** — `/sns-autopilot:sns-autopilot-setup`（SNS 運用をするなら）

auto-merge の配線を先に済ませてから運営の引き渡しに入る。マージが機械判定になっていない
状態で法務ドラフトだけ置いても、エージェントに任せられる範囲は広がらない。

配線するとき、`auto-merge.yml` の聖域パス（`SACRED`。`# >>> sacred-paths` マーカーの間）と
マージ条件のパス（`MERGE_CONDITION`。`# >>> merge-condition-paths` マーカーの間）の両方に
**金・DB・法務**を足す。dev-workflow の既定は自己言及コア（`.github/workflows/`・`.claude/`・
`CLAUDE.md`・憲法 doc）だけなので、価格ロジックと決済導線、DB マイグレーション、公開する法務
ページを展開先のパスで書き足す。法務ページを両方に足さないと、下の法務ドラフトが
人間のマージ判断を経ずに main に入る経路が残る。

2 つの違いは、親の判断の印があるときの扱い。聖域に触れる PR は、印があれば `human-merge` が
外れて自動マージされうる。`MERGE_CONDITION` に触れる PR は、印があっても `human-merge` が
外れず、主が手でマージする。`MERGE_CONDITION` に入れたパスは必ず `SACRED` にも入れる
（`MERGE_CONDITION` は `SACRED` の部分集合）。`SACRED` にだけ足したパスは、親の判断で
マージされうる。金・DB・法務を必ず人間がマージするパスにするには `MERGE_CONDITION` にも足す。

足したら、同梱の `scripts/test-auto-merge-workflow.sh` の `SACRED` 用と `MERGE_CONDITION` 用の
must-match リストそれぞれにも代表パスを足す。片方だけ直すとテストが実態を見なくなる
（手順の正本は dev-workflow の `templates/auto-merge/README.md`）。

## リポ側と住人側の分担

引き渡しには「プロダクトのリポジトリに何を置くか」と「そのプロダクトを担当する住人を
どう用意するか」の2面がある。**このプラグインはリポ側だけを扱う。**

| | 担当 | 中身 |
|---|---|---|
| リポ側 | このプラグイン（と infra / dev-workflow / sns-autopilot） | 法務ドラフト・窓口設定・教訓ログ・auto-merge 配線・CI |
| 住人側 | flatmate の `new-resident` | workspace の作成、定期実行（cron）の配線、連絡チャンネルの用意 |

住人側は flatmate 側で完結するので、こちらから起動も設定もしない。逆に、住人を用意しただけでは
リポ側の雛形は入らないので、両方を通して初めて引き渡しが済む。

## 変更履歴

このプラグインは 2026-08-29 に旧名のプラグインを作り直したもの。入れ替え手順（旧プラグインの
アンインストールと再インストール）と、そのとき何を捨てたかは [CHANGELOG.md](CHANGELOG.md) にある。
