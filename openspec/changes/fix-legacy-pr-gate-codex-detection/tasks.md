## 1. 回帰テストを先に書く（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/pr-review-gate-skill.bats` と `develop-roles.bats` の流儀（ASCII テスト名、節抽出、必要時は偽コマンドで bash 断片実行）で、従来モードの表の exec、companion 不在だけでは不可にしない規定、三つの実測条件、PR コメントと G の needs-reviewer の証拠欄のテストを先に追加する。
- [ ] 1.2 light と full 障害時の区別、App Server 固定モードへの非適用、PC 手順・記録欄・未確認の扱いのテストを先に追加する。既存の「サブスク切れ」の単語だけを要求するテストを実測条件の検査に更新する。
- [ ] 1.3 `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/develop-roles.bats` を実行し、現行文書では新規期待が満たされず Red となることと終了コードを記録する。実 Codex / ネットワークは呼ばない。

## 2. 従来モードの規約を揃える（Green）

- [ ] 2.1 SKILL.md の表に exec を加え、companion 不在時の経路・実測不可判定・PR コメントのコマンドと結果を明記する。呼び出し規約と待ち方の正本を参照し、新 Codex モードとの境界を明示する。
- [ ] 2.2 gate-runner.md の表・説明・コメント例・needs-reviewer payload を正本に合わせる。light / 独立レビュー / 合格条件を維持する。
- [ ] 2.3 SKILL.md に各 PC の確認手順とテンプレートを用意する。バイナリ確認から実レビュー完了までを案内し、companion 任意・未実測は未確認・対象 issue への記録を明示する。配布文書に個別リポ URL や PC 固定パスを埋めない。

## 3. 検証と引き継ぎ

- [ ] 3.1 `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/develop-roles.bats plugins/dev-workflow/tests/subagent-waiting.bats plugins/dev-workflow/tests/pr-review-gate-spec-declaration.bats` を実行して Green と終了コードを記録する。
- [ ] 3.2 `bats tests/injection-budget.bats tests/marketplace-sync.bats tests/openspec-specs-format.bats`、`git diff --check`、`openspec validate fix-legacy-pr-gate-codex-detection --strict` を実行し終了コードを記録する。予算を無断で変えず、配布 version は既存運用に従う。
- [ ] 3.3 実装＋検証結果を本体に return し、別工程の archive / PR に引き継ぐ。文書化だけで #715 を自動 close しない。各 PC 実測と #715 への結果記録を別運用の残作業として渡す（この tasks の実装完了条件には含めない）。
