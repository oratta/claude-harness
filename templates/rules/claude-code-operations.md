# Claude Code Operations

## Model 使い分け

- **Haiku**: 単純なリファクタリング、フォーマット、簡単な説明、ルーチン
- **Sonnet**: 機能実装、バグ修正、コードレビュー、ドキュメント、日常作業
- **Opus**: アーキテクチャ設計、複雑なデバッグ、大規模リファクタ、システム設計

## Context Window 管理

- 有効 MCP は 10 個以下を目安に
- active tools は 80 個以下を目安に
- context が埋まったら `/compact` を使う
- 並行作業は会話を fork する

### Compaction 前にやること

- 重要なコンテキストを保存する
- 決定事項をメモする
- 参照中のファイルパスを記録する
