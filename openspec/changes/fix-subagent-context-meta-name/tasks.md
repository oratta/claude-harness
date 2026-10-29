# Tasks

R1 の APPROVE が issue #590 に記録されてから着手する。行番号は spec 作成時点の案内であり、編集前に範囲を読み直す。

## 1. metadata による名前探索と回帰テスト

- [x] 1.1 metadata の `name` 完全一致から実在する対応ログを候補に加え、従来のファイル名候補と統合・重複除去する。スクリプト冒頭の探索説明も更新する。名前の無いファイル名での成功・完全一致のみの採用・従来のファイル名による成功を bats に追加し、`bats plugins/dev-workflow/tests/subagent-context.bats` が exit 0 になることを確認する（条件 1・2）。触る範囲: plugins/dev-workflow/scripts/subagent-context.sh:26-28、plugins/dev-workflow/scripts/subagent-context.sh:75-105、plugins/dev-workflow/tests/subagent-context.bats:19-94
- [x] 1.2 cwd 一致優先・その中でログの mtime が最新・cwd 一致が無ければ全候補で最新という既存の選択規則を維持する。同名の metadata を複数セッションに置くケースと、metadata 候補とファイル名候補が混在するケースを bats に追加し、選ばれた `file` と `context_tokens` を検証する。時刻を明示した fixture で `bats plugins/dev-workflow/tests/subagent-context.bats` が exit 0 になることを確認する（条件 3）。触る範囲: plugins/dev-workflow/scripts/subagent-context.sh:83-105、plugins/dev-workflow/tests/subagent-context.bats:19-94
- [x] 1.3 metadata が無い・不一致・壊れた JSON・非オブジェクト・name 欠落・対応ログ欠落を個別に扱い、探索を妨げないようにする。ファイル名で見つかる場合は成功、両方で見つからない場合は `transcript not found` / exit 1 を bats に追加して検証する。`--file` 等の既存テストを含む `bats plugins/dev-workflow/tests/subagent-context.bats` が exit 0 になることを確認する（条件 5）。触る範囲: plugins/dev-workflow/scripts/subagent-context.sh:75-105、plugins/dev-workflow/tests/subagent-context.bats:19-94、plugins/dev-workflow/tests/subagent-context.bats:110-164

## 2. 統合検証

- [x] 2.1 `./scripts/test.sh` を実行し、exit 0 を確認する。失敗時は結果と原因を記録して共通の昇格トリップワイヤーに従う。version は変更しない（条件 4）。触る範囲: scripts/test.sh:363-374（実行確認のみ）

## Workflow follow-up

- coordinator の次段指示で archive・PR 作成・仕様宣言を行う。spec 段では実装・archive・PR 作成・merge を行わない。
