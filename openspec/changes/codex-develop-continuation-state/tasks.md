## 1. 継続設定の記録と復元

- [x] 1.1 初回確定時に選択済み記録先（issue 優先、無ければ Draft PR）へ固定マーカー・必須 6 キー・UTF-8 パーセントエンコードの継続記録を保存し、既存コメント形式を正規化する
- [x] 1.2 引数なし追加依頼で記録先を読み、一意性・run-dir・account/model/worker-state/cwd を検証して同じ run を選ぶ
- [x] 1.3 記録欠落・不正・競合・不一致時に停止し、Claude/別 Codex への fallback を行わない

## 2. 回帰テストと既存工程の保全

- [x] 2.1 設定復元、復元不能時の停止、追加依頼の委譲先固定、記録先の探索順、最新版/重複候補、予約文字の fixture テストを追加する
- [x] 2.2 既存 develop の仕様要否・レビュー・verify・finish/G と独自ゲート撤去、および coordinator/担当者の責務境界の回帰テストを実行する
- [ ] 2.3 追加依頼を含む一件を公開 PR の finish/G まで実測し、`docs/` または issue #315 のコメントに、実行コマンド、exit code、対象 HEAD、委譲記録（executor/account/model/run-dir/worker-state/cwd）、finish/G 結果と証跡 URL を記録する

## 3. ドキュメント

- [x] 3.1 develop command と Codex adapter の継続記録・復元不能時の停止契約を更新する
- [x] 3.2 issue 315 の未了項目と実測結果を既存 `manual-codex-develop` の記録へ反映する
