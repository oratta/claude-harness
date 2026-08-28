# product-handover

プロダクトをエージェントに引き渡すときにだけ必要になる固有部品を配るプラグイン。
持っているのは雛形3種だけで、オーケストレーターもスキルも持たない。

| 部品 | 置き場所 | 展開先の目安 |
|---|---|---|
| 法務ドラフト（利用規約・プライバシーポリシー・返金ポリシー） | `templates/legal/` | `docs/legal-drafts/` |
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
4. **運営の引き渡し** — このプラグインの雛形3種を展開し、窓口と法務ドラフトを用意する
5. **マーケ運転** — `/sns-autopilot:sns-autopilot-setup`（SNS 運用をするなら）

auto-merge の配線を先に済ませてから運営の引き渡しに入る。マージが機械判定になっていない
状態で法務ドラフトだけ置いても、エージェントに任せられる範囲は広がらない。

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
