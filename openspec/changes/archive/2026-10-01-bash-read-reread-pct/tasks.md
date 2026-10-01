## 1. 実装

- [x] 1.1 `scan_full` の Bash `tool_use` から `command` を取り出し、D1・D2 の規則でファイル引数のベースネームを `reads` に足す関数を作って呼ぶ 触る範囲: plugins/dev-workflow/scripts/subagent-context-audit.sh:297-360（`scan_full` の `name == "Read"` 分岐の隣）、同ファイル（新しい関数は `scan_full` の直前に追加）
- [x] 1.2 ヘッダコメントの `reread_pct` の説明（Read の file_path のみ、という記述）を Bash の読みを含む形に直す 触る範囲: plugins/dev-workflow/scripts/subagent-context-audit.sh:53-55、295-297

## 2. テスト

- [x] 2.1 先行が Read、後続が `sed -n` で同じファイルを読む固定トランスクリプトで `reread_pct` が 0 でなく 100.0 になる bats を足す 触る範囲: plugins/dev-workflow/tests/subagent-context-audit.bats（既存の reread_pct のテストの近く）
- [x] 2.2 `cat` / `head` / `tail` の各形で数える bats、スクリプト・オプション値・リダイレクトを数えない bats を足す 触る範囲: plugins/dev-workflow/tests/subagent-context-audit.bats
- [x] 2.3 Read だけのトランスクリプトで変更前と同じ値になることを確かめる（既存の bats が通ることに加え、1 件明示的に足す） 触る範囲: plugins/dev-workflow/tests/subagent-context-audit.bats

## 3. ドキュメントと記録

- [x] 3.1 `reread_pct` の説明に、Bash の `sed -n` / `cat` / `head` / `tail` の引数を含めること・対象外（grep など）を書く 触る範囲: plugins/dev-workflow/docs/usage-audit.md:148-154
- [x] 3.2 変更記録を書く 触る範囲: plugins/dev-workflow/changes/651.md（新規）
- [x] 3.3 `./scripts/test.sh` が exit 0 になることを確かめる
