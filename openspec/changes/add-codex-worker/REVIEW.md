# #706 手動workerレビュー

対象: proposal/design/spec/tasksと `plugins/dev-workflow/scripts/codex-worker.py`、`tests/test_codex_worker.py`。
参照issue: genetta-inc/flatmate#706。Draft PR: https://github.com/oratta/claude-harness/pull/312

独立worker、重複受付、台帳を跨ぐaccount/cwd所有、unknownの保持、role sandbox、認証帰属、quota unknownの拒否を重点確認。CLIが完了を返すことは品質ゲート通過を意味しない。品質工程は#707。

未実装のburn/send/自動復旧を完了として数えない。モデル実測は親の#707統合時に行い、このPR内の検証はfake App Serverが中心。
