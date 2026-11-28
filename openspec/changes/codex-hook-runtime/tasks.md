# Tasks

spec 段では以下を実行しない。R1 APPROVE の記録後に実装を始める。実ホームの変更・破壊的操作の実 repo での試験・版上げは対象外。実行先の主の指定は #1863 の記録を維持する。

## 1. 隔離環境で信頼方式を確定する

- [x] 1.1 repo 外の一時 CODEX_HOME・git repo/feature linked worktree・ローカル bare remote とダミー秘密だけを使う再現手順を具体化し、redirect/include/alias/git hook による外部作用を除去して fetch/push 先を照合する。既存一覧の安全手順に、準備コマンド・前後比較・期待値・中止条件を追記して照合結果を #1863 に残す。触る範囲: plugins/dev-workflow/docs/codex-hook-inventory.md:65-82、openspec/changes/codex-hook-runtime/design.md:38-44
- [x] 1.2 実行版/help/公式文書を確認し、design の管理 hook と invocation 限定 bypass を CLI 本体/app-server で比較する。拒否と無害な対照を実測し、使えない候補は理由を残す。採用理由・source の確認方法・再現コマンドを design と #1863 に記録し、両候補未成立なら止める。現在の worker 制約で起動できない対象は下記 follow-up の依頼文とともに返し、合格扱いしない。触る範囲: openspec/changes/codex-hook-runtime/design.md:25-32、plugins/dev-workflow/docs/codex-hook-inventory.md:65-82

## 2. 配布入口と worker 接続を実装する

- [x] 2.1 明示した一時 target の未使用 hook 領域に既存定義を配布する helper を追加し、adapter と全依存/実行系を絶対パスで解決する。既存の最小 auth/config の保持、欠落・親のパス上書き・配置移動・その他の既存設定の誤上書きの反例と、git/秘密/印付き同期質問の deny・無害な入力の対照を repo 外の fixture でテストする。親の `DEV_WORKFLOW_CODEX_GUARD_DIR`・`DEV_WORKFLOW_CODEX_GIT_GUARD`・`DEV_WORKFLOW_CODEX_SECRET_GUARD`・`DEV_WORKFLOW_CODEX_ASK_GUARD` が未設定でも別の配置を指していても、helper が返す4変数は helper の実体から解決した配布元の絶対パスであることを確認する。`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_hook_runtime.py -v` が exit 0。触る範囲: plugins/dev-workflow/scripts/codex-hook-runtime.py（新規）、plugins/dev-workflow/tests/test_codex_hook_runtime.py（新規）
- [x] 2.2 helper を runtime 準備と App Server 起動へ接続し、1.2 で成立した方式だけを使う。全roleへの配置、thread/start の信頼用 config 上書き、依存欠落時に server/turn 未開始、無人印/off・TMPDIR/TMPPREFIX 継承、auth/account/role policy の維持、成功/失敗/中断の cleanup を fake server と一時認証 fixture で検証する。worker delta の「guard のパスだけを配布元へ固定する」に対応し、親の4つの guard パス変数が未設定の場合と別の配置を指す場合の双方で、書込役・読取役の子環境が配布元の絶対パスへ固定されること、無人印/off・TMPDIR/TMPPREFIX とその他の継承対象は親のままで、従来の認証変数と Git パス変数の除外も維持されることを確認する。元 profile の hooks/config/requirements が不変であることも確認し、`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py -v` が exit 0。触る範囲: plugins/dev-workflow/scripts/codex-worker.py:39-45、plugins/dev-workflow/scripts/codex-worker.py:220-245、plugins/dev-workflow/scripts/codex-worker.py:359-364、plugins/dev-workflow/scripts/codex-worker.py:734-767、plugins/dev-workflow/tests/test_codex_worker.py:21-170、plugins/dev-workflow/tests/test_codex_worker.py:411-440
- [x] 2.3 本体向け導入コマンド/設定差分・既存 Orca 登録を保つ手順・主の承認と信頼操作・更新時の再確認/戻し方を説明し、worker の環境/認証の説明を配布後の実態に合わせる。手順は一時 target で再現し、実ホームには適用しない。触る範囲: plugins/dev-workflow/scripts/CODEX-WORKER.md:29-37、plugins/dev-workflow/docs/codex-develop.md:1-13、plugins/dev-workflow/docs/codex-hook-inventory.md:39-57

## 3. 対象別の実機記録と共用記録を仕上げる

- [ ] 3.1 1.1 の隔離環境で git 対象9種と代表変形を本体/native subagent/worker から、ダミー秘密表示を本体/worker から要求し、無害な対照と合わせて記録する。worker は書込roleを使い砂場の拒否で代用しない。各セルの実 tool 拒否と未実行の前後比較、版/HEAD/role/source/信頼/印/off/入力/cwd/時刻/exit code を #1863 に貼る。native 子の起動と要求を結び、取れないセルは理由・試したこと・主の具体的再現コマンドを記す。触る範囲: plugins/dev-workflow/docs/codex-hook-inventory.md:5-57、plugins/dev-workflow/docs/codex-hook-inventory.md:65-82
- [x] 3.2 一覧の当該登録行と `changes/1858.md` に対象別の証跡 URL または未取得理由/主の手順を反映する。印付き同期質問の到達/拒否の確認も配布結果として記録し、#1862 の未確認質問経路は未完了を維持する。AC と証跡を突き合わせ、未確認を成功にしない。`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_hook_inventory.py -v` が exit 0。触る範囲: plugins/dev-workflow/docs/codex-hook-inventory.md:5-57、plugins/dev-workflow/changes/1858.md:10-17

## 4. 統合検査

- [ ] 4.1 `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_pretool_guards.py -v`、`bats plugins/dev-workflow/tests/git-destructive-guard.bats plugins/dev-workflow/tests/unattended-ask-guard.bats plugins/capability-registry/tests/secret-guard.bats tests/injection-budget.bats`、`scripts/test.sh`（Python suites を含む全件）、`scripts/lint.sh`、`openspec validate codex-hook-runtime --type change --strict`、`git diff --check` を実行し、件数・exit code・対象 HEAD と省略項目を #1863 に記録する。起動禁止が続く Claude CLI の lint 部分等は未実施と明示し、勝手に起動しない。injection budget の値と版は変更しない。触る範囲: plugins/dev-workflow/changes/1858.md:10-17、plugins/dev-workflow/tests/test_codex_hook_runtime.py（新規）、plugins/dev-workflow/tests/test_codex_worker.py:21-170、plugins/dev-workflow/tests/test_codex_worker.py:411-440

## Workflow follow-up

- 本体への実機依頼が必要な場合の文面: 「#1863、対象 HEAD と採用信頼方式を固定し、一覧の隔離手順を使って Codex 本体/native subagent/worker の各対象から git の対象9種、秘密表示は本体/worker、無害な対照を試し、対象別の tool 拒否と前後不変・版/HEAD/source/信頼/入力/時刻/exit code を記録してください。実ホーム変更、実 repo での破壊操作、本物の秘密表示は行わないでください」。W は subagent を起こさず coordinator に返す。
- archive・Draft PR 作成・仕様宣言・独立レビューは coordinator の canonical workflow の後続段が扱う。PR は `Closes #1863` のみ。merge/auto-merge はしない。

## implement 試行1の進捗

1.1 のみ完了。[照合記録](https://github.com/oratta/claude-harness/issues/1863#issuecomment-7236485481)。1.2 は help/公式文書のみ確認し、実機 deny は未取得。agent/subagent・codex exec の起動禁止により信頼方式は未成立で、1.2 の停止条件を適用した。2.1–3.1 は未着手、3.2/4.1 は部分記録・部分検査のみでチェックしない。採用方式を実測で確定してから再開する。

## implement 試行2の進捗

本体の[追試](https://github.com/oratta/claude-harness/issues/1863#issuecomment-7236567986)でtask 1.2の方式を確定（app-serverの実拒否は3.1へ残す）。2.1–2.3を実装し、3.2は対象別証跡と未取得理由・本体の再現手順を反映した。3.1は未完了を維持。4.1の全体テストはcanonical workerのCI委譲規則に従ってCI test matrixへ任せ、Claude CLI部分も起動禁止により未実施。検査の実行結果は#1863の試行2コメントとreturnに記録する。全件実機成功・品質承認は宣言しない。

## implement 試行3の進捗

[本体の app-server 追試](https://github.com/oratta/claude-harness/issues/1863#issuecomment-7236723402) に基づき、無効な起動フラグを外して配布済み一時 runtime の thread/start.params.config に boolean の bypass_hook_trust を渡す形へ修正。CLI 本体 / codex exec のフラグとは区別し、全roleの fake server で params を検証する。修正後 worker の実機セルは本体の再取得待ちで、3.1・4.1の未完了は維持する。
