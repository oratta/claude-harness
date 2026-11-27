# Tasks

## 1. 判定を TDD でスクリプトへ移し、手順書を置き換える

- [x] 1.1 新しい `develop-mode.bats` を先に追加し、script がまだ無い状態で Red を確認する。spec の各 Scenario を実行する: 正常出力の全文と末尾改行、stderr 空、exit 0、フラグの順序/重複、未設定/空/0/非空文字列、ASCII と Unicode の空白、help、引数誤り、処理系不在、外部コマンドの不使用。stdout/stderr は分けて検査する。確認: `bats plugins/dev-workflow/tests/develop-mode.bats` が未実装のため非 0 であることを記録する。触る範囲: plugins/dev-workflow/tests/develop-mode.bats（新規）
- [x] 1.2 spec と design の契約に沿って `develop-mode.sh` を実装し、実行可能にする。hook は読み書きも source も実行もしない。`.strip()` 相当の正規化を維持し、4 通りの開始コメント行を返す。確認: 1.1 の同じ bats が exit 0 となること、`shellcheck --severity=warning plugins/dev-workflow/scripts/develop-mode.sh` が exit 0 となること。触る範囲: plugins/dev-workflow/scripts/develop-mode.sh（新規）
- [x] 1.3 SKILL.md の変更前に bytes と Unicode 字数を測り、変更後も同じ方法で測る。起点 230b839e の SKILL.md は 53,351 bytes / 26,289 字（小節本文は 2,059 bytes / 967 字）。design「消す説明と残す指示の境界」に従い、小節の番号付き判定と印の説明を呼び方 1 行・分類表に置き換える。開始コメントの形、途中で変えないこと、引き継ぎの値の使用、最後の channel.md 案内全文は残す。旧 `develop-channel-mode.bats` の説明検査を script 案内・フラグ条件・分類表と残す動作の検査へ更新し、失われる値分岐の検査は 1.1 の script 実行テストで引き受ける。確認: `bats plugins/dev-workflow/tests/develop-mode.bats plugins/dev-workflow/tests/develop-channel-mode.bats plugins/dev-workflow/tests/develop-skill.bats` が exit 0、特に channel.md を直後に読む既存テストは変更なしで通る。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:238-250「モードの決め方」、plugins/dev-workflow/tests/develop-channel-mode.bats:71-81「mode decision」
- [x] 1.4 変更後の SKILL.md の bytes まで startup 予算の同ファイルの値を下げる。固定注入は既存の測定ヘルパーで再測定し、既に 44,032 bytes と一致する injection-budget.txt を変更しない理由を記録する。場面別の集合を確認し、SKILL.md を含まず実測が変わらない epic/worker/reference の予算は維持する。確認: `bats tests/develop-startup-budget.bats tests/injection-budget.bats tests/develop-epic-scene-budget.bats tests/develop-worker-stage-budget.bats tests/develop-orchestrator-reference-budget.bats` が exit 0。確認結果と前後の実測値を変更の記録に残す。触る範囲: tests/develop-startup-budget.txt:1、plugins/dev-workflow/changes/1686.md:1-16（今回の追記）

## 2. 統合確認

- [x] 2.1 新規 bats と script を git の追跡に入れ、動的列挙する `./scripts/test.sh` と `./scripts/lint.sh` を実行し、ともに exit 0 を記録する。`openspec validate extract-develop-mode-decision --type change --strict` も exit 0 とし、未チェックの tasks が無いことを確認する。確認: 実行コマンドと終了コードの記録、`git diff --check` が exit 0、既存 script と hook と epic reference に差分が無いこと。触る範囲: openspec/changes/extract-develop-mode-decision/tasks.md:5-14（進捗のみ）

## Workflow follow-up

- この spec 段では artifact を commit/push して return し、実装は R1 の APPROVE を確認した別の段で行う。
- finish 段で archive・Draft PR・仕様宣言を行う。PR 本文には判定箇所と SKILL.md 全体の前後の字数/bytes、startup 予算を下げた理由、固定注入実測 44,032 と維持理由、(b) を出さなかった理由、(c) の後続候補を記録する。`Closes #1686` / `Fixes #1686` は書かず、継続中の issue として参照する。
- (b) は本体の再確認と既存 `reap`/`wait` の判定が同値でなく、出力だけに任せると動作が変わる。(c) は停止・マージ・委任・別 repo の入力収集を定める別 change `collect-parent-merge-inputs` の候補として return する。

## 実装試行 3 の検査記録

- 引き継いだ script は変更せず、bats の Unicode 空白を UTF-8 バイト表記に修正。`bats plugins/dev-workflow/tests/develop-mode.bats`: exit 0（8 件）。script 不在の隔離 fixture に同テストをコピーした再確認は exit 1（期待する Red）。これはこの試行で新たに script を実装する前の実行ではなく、引き継ぎ後の Red 再確認。
- 文書テストの先行更新後、旧文書に対する `bats plugins/dev-workflow/tests/develop-channel-mode.bats`: exit 1（mode decision だけ失敗）。文書を置き換えた後の `bats plugins/dev-workflow/tests/develop-mode.bats plugins/dev-workflow/tests/develop-channel-mode.bats plugins/dev-workflow/tests/develop-skill.bats`: exit 0（196 件）。
- `bats tests/develop-startup-budget.bats tests/injection-budget.bats tests/develop-epic-scene-budget.bats tests/develop-worker-stage-budget.bats tests/develop-orchestrator-reference-budget.bats`: exit 0（129 件）。実測値は `plugins/dev-workflow/changes/1686.md` に記録。
- `shellcheck --severity=warning plugins/dev-workflow/scripts/develop-mode.sh`: exit 0。
- `PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin ./scripts/lint.sh`: exit 0。Claude 起動禁止に従い PATH から claude を除外したため、内包する `claude plugin validate` は未実行。shellcheck は全追跡 sh を検査し指摘なし。
- `./scripts/test-auto-merge-workflow.sh`: exit 0（145 passed, 0 failed、actionlint も成功）。CI の lint ジョブが lint.sh と併せて実行する検査。
- `openspec validate extract-develop-mode-decision --type change --strict`: exit 0。
- `./scripts/test.sh`: exit 0。本体が固定 HEAD `5e33b3a9e09fd32e3ec241c49d5fcaf18a958514` で手元実行を完走し、`1..5330`、bats 全スイート pass、excluded 0 を確認した（https://github.com/oratta/claude-harness/issues/1686#issuecomment-7040962092）。実装試行 3 の待ち上限停止に代わる完走結果として task 2.1 を完了とする。finish では全体テストを再実行しない。
- 関連テスト検索: `git grep -l -e 'develop-mode.sh' -e 'develop-channel-mode.bats' -e 'skills/develop/SKILL.md' -e 'develop-startup-budget.txt' -e 'changes/1686.md' -- '*test*' '*.bats'`（exit 0）。全体テストの完走結果は上記の本体の記録を引き継ぐ。
- `git diff --check`: exit 0。channel.md 案内の末尾段落全文は起点と同一、判定 script 本体・hook・epic-loop.md に起点 09aa530f からの差分なし。
- 統合確認は完了。finish 段で archive・Draft PR・仕様宣言を行い、独立レビューは本体へ返す。

## finish の検査記録

- `bats plugins/dev-workflow/tests/develop-mode.bats plugins/dev-workflow/tests/develop-channel-mode.bats plugins/dev-workflow/tests/develop-skill.bats tests/develop-startup-budget.bats tests/injection-budget.bats`: exit 0（294 件）。
- archive 前の `openspec validate extract-develop-mode-decision --type change --strict`: exit 0。全タスク完了を確認後、`openspec archive extract-develop-mode-decision --yes`: exit 0。archive 先の存在と元ディレクトリの不存在を確認。
- `openspec validate dev-workflow-develop --type spec`: exit 0。追加の `--strict` は exit 1（既存 115 WARNING、ERROR なし）。固定 HEAD 5e33b3a9 の spec を隔離 fixture で同じ CLI にかけ、警告の level/path/message が全件同一であることを照合（exit 0）。
- `openspec validate --archived`: exit 1（386 passed / 27 failed）。今回の archive は valid、失敗した 27 件はいずれも差分のない既存 archive。JSON による照合は exit 0。
- `git diff --check`: exit 0。全体テストは本体の完走結果を引き継ぎ、再実行しない。
