# Tasks

行番号は dispatch HEAD 時点。既存 Claude 本体は参照のみ。**現成果は文脈容量超過により再計画待ち。以下を開始してはならない。** 更新計画の確定後も、入力確認ゲートに失敗したら実装・対応完了を宣言せず design の要求を本体へ返す。実装開始には記録先の R1 APPROVE が必要。

## 1. 入力契約を確認し入口を作る

- [ ] 1.1 対象 Codex 版の shell/unified exec、apply_patch、同期/非同期質問、公開名/名前空間と nested call の hook 入力を design のゲートに従って確認する。文書・合成・実測の別と未確認理由を fixture のメタ情報へ記し、実測できない質問経路は未完了で返す。確認: 各対応名・フィールド・根拠と取得方法をレビュー可能にし、未確認を実測と呼んでいない。触る範囲: plugins/dev-workflow/tests/fixtures/codex-pretool/（新規）、plugins/dev-workflow/docs/codex-hook-inventory.md:5-11（参照）
- [ ] 1.2 `hooks/codex/hooks.json` と `pretool-guard.py` を追加し、stdin の event/tool 選別、依存パスの解決、非対象・apply_patch・壊れた入力の無出力、未検査の stderr を実装する。同じタスクで入力の正負テストを追加する。確認: `python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_pretool_guards.py` が入力型/別event/非対象/依存欠落の反例を含め exit 0。触る範囲: plugins/dev-workflow/hooks/codex/hooks.json（新規）、plugins/dev-workflow/hooks/codex/pretool-guard.py（新規）、plugins/dev-workflow/tests/test_codex_pretool_guards.py（新規）、plugins/dev-workflow/tests/fixtures/codex-pretool/（新規）

## 2. 判定の再利用と各受け入れ条件の検証

- [ ] 2.1 git 判定を NO_ASK 固定・親子許可なしで再利用し、Codex 向け deny を組み直す。同時に対象9種・wrapper/連結・dry-run・無害git・FORCE/agent_id/permit・繰返し拒否の正負テストを追加する。確認: 同 unittest が有効な deny と禁止出力の不存在を検査し、pending command を実行しない。ルールの既知の非検出例は対応成功と数えない。触る範囲: plugins/dev-workflow/hooks/codex/pretool-guard.py（新規）、plugins/dev-workflow/tests/test_codex_pretool_guards.py（新規）、plugins/dev-workflow/tests/fixtures/codex-pretool/（新規）、plugins/dev-workflow/scripts/git-destructive-guard.sh:40-59,650-775,935-1065（参照）、rules/destructive-git-guard.md:11-24（参照）
- [ ] 2.2 secret の既存 Bash 判定を再利用し、同時に変数表示/環境表示/秘密ファイル/Keychain/op と値を出さない利用・off の正負テストを追加する。確認: 同 unittest がダミーのコマンド文字列だけで deny/無出力と独立した無効化を検査し、実際の秘密やファイル内容を取得しない。触る範囲: plugins/dev-workflow/hooks/codex/pretool-guard.py（新規）、plugins/dev-workflow/tests/test_codex_pretool_guards.py（新規）、plugins/dev-workflow/tests/fixtures/codex-pretool/（新規）、plugins/capability-registry/scripts/secret-guard.py:113-215（参照）、plugins/capability-registry/scripts/secret-guard.sh:1-17（参照）
- [ ] 2.3 1.1で確認した質問経路だけを無人質問の判定へ接続し、印の値の表・git off/FORCEとの独立・無関係ツールの正負テストを同時に追加する。確認: 同 unittest により主への確認済み質問入力が印付きで deny、印なしで無出力となる。合成fixtureのみなら AC3 を完了にしない。触る範囲: plugins/dev-workflow/hooks/codex/pretool-guard.py（新規）、plugins/dev-workflow/tests/test_codex_pretool_guards.py（新規）、plugins/dev-workflow/tests/fixtures/codex-pretool/（新規）、plugins/dev-workflow/scripts/unattended-ask-guard.sh:9-36（参照）
- [ ] 2.4 対象3登録の判定状態・移植先・検証根拠だけを一覧へ追記し、共用 changes/1858.md にG002の成果・入力確認結果・未完了を記録する。確認: `python3 plugins/dev-workflow/tests/test_codex_hook_inventory.py` が exit 0、3対象の未取得の配布/信頼/実機を確認済みに変えていない。触る範囲: plugins/dev-workflow/docs/codex-hook-inventory.md:5-11,27-37、plugins/dev-workflow/changes/1858.md:11-15

## 3. 統合確認と後続への契約

- [ ] 3.1 Codex unittest と一覧テストを再実行し、`bats plugins/dev-workflow/tests/git-destructive-guard.bats plugins/dev-workflow/tests/unattended-ask-guard.bats plugins/capability-registry/tests/secret-guard.bats` で既存Claude経路の回帰を確認する。確認: 全て exit 0、実装差分が既存hooks.json・CLAUDE.md・権限設定・注入予算を変更していない。触る範囲: plugins/dev-workflow/tests/test_codex_pretool_guards.py（新規・実行）、plugins/dev-workflow/tests/test_codex_hook_inventory.py:1-118（実行）、plugins/dev-workflow/tests/git-destructive-guard.bats:1-160（実行入口）、plugins/dev-workflow/tests/unattended-ask-guard.bats:1-110（実行入口）、plugins/capability-registry/tests/secret-guard.bats:1-150（実行入口）
- [ ] 3.2 `openspec validate codex-pretool-guards --type change --strict` を通し、#1863へ hook入口・依存scriptの所在指定・確認済み質問名・未確認経路・既知の限界を記録先で引き継ぐ。確認: exit 0 と handoff の根拠を記録し、fixture成功と実機有効を区別する。触る範囲: openspec/changes/codex-pretool-guards/（本change・検証）、plugins/dev-workflow/changes/1858.md:11-15（引継ぎ追記）

## Workflow follow-up

- 実装＋verifyまでで本体へreturnする。archive/PR/仕様宣言は本体からfinish工程を指示されてから行う。merge/auto-mergeは行わない。
- #1863の配布・信頼・本体/native subagent/workerの実機記録はこのチェックリストの完了と別に残す。
