# #705 仕様レビュー依頼

対象: このディレクトリのproposal.md、design.md、tasks.md、specs/codex-appserver-connection/spec.md。
管理issue: https://github.com/genetta-inc/flatmate/issues/705
Draft PR: https://github.com/oratta/claude-harness/pull/311

実装・モデル実測は未着手。次をレビューしてください。
- 現行停止原因を推測で断定していないか。companion内部App Serverとexecの区別は妥当か。
- 一件の受付・進捗・結果・中断を検証できるか。完了競合・切断・待機期限で二重実行しないか。
- #706本番worker、#707品質工程、#708バーン統合の範囲を取り込んでいないか。
- アカウント確認が不能な場合・未対応server request・利用量欠落を正直に扱うか。

指摘には対象見出し、具体的失敗例、必須修正か改善提案かを添えてください。ユーザーの仕様レビューが終わるまで実装に進みません。
