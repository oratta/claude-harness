## 設計と実装
- [x] 現行developの役割と委譲箇所を確認
- [x] App Server worker adapterと手動実行入口
- [x] 全役割のprovider変換・独立レビュー・差し戻し
- [x] 導入READMEとfake worker完走テスト
- [x] #706との主要4工程の統合実測（親CodexがCLIでcoordinator操作、VERIFICATION.md参照）
- [ ] Claude slashから公開PRのfinish/Gまで一件完走を実測

## provider差による仕様必須化の訂正
- [x] 文書と仕様を既存developの品質判断へ一元化
- [x] adapterの独自品質ゲートを削除し、仕様不要経路の回帰を確認（親担当、worker20+adapter12件の最終検証を親が実施）
- [x] 送信到達不明の旧pendingを保存requestのままretryでき、identity不一致を拒否する（親実装）
