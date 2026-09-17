# 検証記録

## 自動テスト
`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py -v`

17件のfake App Server境界試験: 親submit終了後の完了/取消、結果回収、同一ID再受付・同時3受付、複数台帳排他、unknown保持、readonly/model/approval/network送信設定、quota不明/枯渇の拒否、認証不一致/変更/リンク切替、main checkout拒否、Git環境変数隔離、user MCP config非継承、project設定拒否、重複workerによる稼働中状態上書き防止。

OpenSpec strict、git diff --checkも実施。fake結果は実モデルのsandbox強制や外部ツール不在の実測とは区別する。

## 未検証・未実装
- 実モデル・#707を通した手動一件完走は親の統合確認担当。
- token refresh時も保守的停止する制約、メール照合が完全なworkspace IDを保証しない制約。
- burn起動、send/steer、unknown運用回復、既存broker再利用。
- 別ホスト／HOMEを分ける管理者起動での分散排他。

このPR単体で#706全体を完了・closeしない。mergeしない。
