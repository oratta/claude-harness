## 1. Worker の検証と RPC（先に実装）

- [x] 1.1 `test_codex_worker.py` に Red を追加する: optional effort の型/空値、未知 role/未登録 account、model/list の全ページ/hidden/model と id の違い、luna/ultra 拒否、未知モデル、一覧取得失敗、広告された新 effort を検証する。submit 時の静的検証（`validate_request` 側）での拒否は job が作られないことを assert する。`initialize` 後・`thread/start` 前のモデル別検証での拒否は thread/turn が0回、turn_submitted=false の failed job が残り、unknown にならないことを assert する。
- [x] 1.2 submit の静的検証と initialize 後・thread/start 前のモデル別検証を実装する。model/list の supportedReasoningEfforts のオブジェクト形式を使い、固定 enum と fallback を設けない。
- [x] 1.3 両 RPC の model、turn/start だけの effort、旧 request の effort 省略を fake RPC でテストして実装する。account identity、read-only、#320 の一時領域/砂場/cleanup、unknown の所有権を維持する。
- [x] 1.4 payload/hash を変更しない nullable execution metadata の DB 拡張と公開 status/result をテストして実装する。requested/effective/evidence、job/thread/turn ID、未観測=null、要求との不一致、旧台帳、thread/turn 観測の優先をカバーする。

## 2. Develop の設定セットと pending（worker の後）

- [x] 2.1 `test_codex_develop.py` に両セットの役割対応、旧フラグ併用拒否、外部設定の厳密形式/完全性/登録 account、非codex拒否、init snapshot/hash と外部ファイル変更/削除後の不変性の Red を追加する。
- [x] 2.2 `references/codex-role-profiles.json` と共通 loader/resolver、`init --profile NAME [--profile-file PATH]`、version/profile/roles/hash の保存を実装する。旧 init/account/model と旧 run の読み取りを維持する。探索/要約は read-only 補助 role/phase として既存役割に対応させる。
- [x] 2.3 role 別 account/model/effort の dispatch と pending_execution/pending_payload_hash の submit 前保存を実装する。retry の全照合対象、snapshot改変、各entry改変、送信応答喪失、既存結果、unknown、旧 prompt の再送と旧 payload hash 不変を先に回帰テストする。
- [x] 2.4 公開 execution を ack 時の run history に取り込み、role/executor/account/model/effort と ID の同一性を検証する。metadata 追加が request hash に影響しないことを確認する。
- [x] 2.5 旧形式/標準/節約で同じ coordinator fixture を回し、仕様不要/必要、独立レビュー、差戻し、finish/gate、失敗時の判断/順序/上限が変わらないことをテストする。手動とバーン呼出し fixture が同じ init/resolver と snapshot を使う例を残す（バーン接続は実装しない）。

## 3. 継続記録と利用入口

- [x] 3.1 継続記録 v1 の既存6キー、v2 の7キー/順序/encoding、版混在の最新候補、不正最新から旧版へ戻らないこと、profile/版/hash/パス/所有者/0700、v1-v2/run形式不一致、外部設定を読まないことを先にテストする。
- [x] 3.2 formatter/parser/restore/validate を v1-v2 対応にする。旧 run は v1、profile run は v2 を生成する。coordinator による取得/記録/代理操作と品質判断の境界を維持する。
- [x] 3.3 `commands/develop.md`、`references/codex-develop.md`、`docs/codex-develop.md`、`scripts/CODEX-WORKER.md` に起動例、旧フラグ競合、profile-file の役割別 account 例、retry/pending、二段階検証、v2、未観測の扱いを反映する。`references/model-tiers.md` に既存 roles と Codex の対応表/設定正本への参照を加える。
- [x] 3.4 先行 `openspec/changes/manual-codex-develop/specs/manual-codex-develop/spec.md` を本 change の同名 spec と同期し、全委譲同accountは旧形式の契約であると明記する。後日 archive しても契約が戻らないことを照合する。

## 4. 一つの PR の検証と受け入れ証跡

- [x] 4.1 `plugins/statusline/tests/statusline-codex.bats` を先例に、`test_codex_*.py` 全件を一度呼ぶ薄い bats ラッパーを追加する。`scripts/test.sh` が git tracked の bats を列挙することを踏まえ、coordinator の記録操作後にラッパーが対象に含まれることを確認する。実モデル試験はラッパーに入れない。
- [x] 4.2 `plugins/dev-workflow/.claude-plugin/plugin.json` の現行版を確認して 2.13.8 から次版へ bump する。常時注入の description 等を不要に増やさず、`tests/injection-budget.txt` は変更しない。もし予算変更が不可避なら理由付きで coordinator に返す。
- [x] 4.3 `python3 -m unittest discover -s plugins/dev-workflow/tests -p 'test_codex_*.py'`、`scripts/test.sh`、`openspec validate codex-develop-role-profiles --strict --no-interactive`、`git diff --check` を実行し、件数・exit code・対象 HEAD を記録する（baseline は coordinator 実測80 tests、約51秒）。
- [ ] 4.4 coordinator に両セット各1件の実モデル実行を依頼し、spec→独立spec-review→implement→独立review の要求/実効 model/effort、account、executor、観測元、job/thread/turn ID、HEAD、コマンド/exit code、各工程の品質結果を証跡にする。要求どおりの実効値を確認できない工程は未達のまま報告する。
- [ ] 4.5 回帰結果と実機証跡を同じ PR の受け入れ条件に対応付けて coordinator に返す。GitHub記録/push、独立レビュー、工程遷移は coordinator の担当とし、worker は merge/auto-merge を行わない。
