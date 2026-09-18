## 1. 継続設定の記録と復元

- [ ] 1.1 初回確定時に issue/Draft PR へ継続記録を保存し、既存コメント形式を正規化する
- [ ] 1.2 引数なし追加依頼で記録先を読み、一意性・run-dir・account/model/worker-state/cwd を検証して同じ run を選ぶ
- [ ] 1.3 記録欠落・不正・競合・不一致時に停止し、Claude/別 Codex への fallback を行わない

## 2. 回帰テストと既存工程の保全

- [ ] 2.1 設定復元、復元不能時の停止、追加依頼の委譲先固定のテストを追加する
- [ ] 2.2 既存 develop の仕様要否・レビュー・verify・finish/G と独自ゲート撤去の回帰テストを実行する
- [ ] 2.3 追加依頼を含む一件を公開 PR の finish/G まで実測し、対象 HEAD と結果を記録する

## 3. ドキュメント

- [ ] 3.1 develop command と Codex adapter の継続記録・復元不能時の停止契約を更新する
- [ ] 3.2 issue 315 の未了項目と実測結果を既存 `manual-codex-develop` の記録へ反映する
