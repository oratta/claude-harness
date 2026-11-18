# Tasks

## 初期見積もりと範囲

基準 HEAD: `bc753b976d866fb58c0e92c0af8a7415a7b6f01f`。初期見積もりは下の **8 作業項目**（未着手 8、作業項目の増加 0 回）。編集対象は起動時の三ファイル、新規 reference 三つ、関連 bats と共通 helper、既存と新規の予算、四 capability の delta、変更記録。5 ファイル超は依頼により見込み済み。初期見積もりから作業項目が **2 回増えたときだけ** 規模超過として成果と増加理由を return する。

以下の行番号は仕様作成時点の案内。編集前に範囲を読み直す。テスト修正は文の移動に伴う検査対象の変更に限り、判定条件・否定条件・回数制約を緩めない。`pr-review-gate/` と `roles/gate-runner.md` の本文、#1686・#1693〜#1695 の対象は変更しない。今回の spec 段では下の実装項目には着手しない。

## 1. 対応表を用意する

- [x] 1.1 基準 HEAD の三ファイルの字数／bytes、段落の移動元→行き先、削除する重複の既存正本、単発 issue のどの場面なら読まなくてよいか、必読として残す規則の対応表を変更記録へ作る。確認: `git show <基準HEAD>:<path>` と `LC_ALL=en_US.UTF-8 wc -m`／`wc -c` の再現コマンドがあり、issue #1685 の対象段落を網羅する。触る範囲: plugins/dev-workflow/changes/1685.md（新規）、plugins/dev-workflow/skills/develop/SKILL.md:1-375（読取）、plugins/dev-workflow/commands/develop.md:1-78（読取）、plugins/dev-workflow/references/codex-develop.md:1-71（読取）

## 2. 本体の場面限定手順を移す

- [x] 2.1 PR トークン上限と消費の印の全文を pr-token-budget.md へ移し、本体には spawn・再開・Codex 委譲前と印を書く前の必読指示を置く。二つの既存スクリプトの連結をそのまま保つ。対応 bats の文言検査は手順書集合で確認し、必読参照は入口で別に確認する。新規 reference 用のファイル別予算検査と、超過／過剰余白の退行検査を追加する。確認: 関連 develop-skill／develop-roles／adapter と新規予算の bats が通り、上限・全終了コード・印の形が変わらない。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:235-287、plugins/dev-workflow/skills/develop/references/pr-token-budget.md（新規）、plugins/dev-workflow/tests/develop-skill.bats:1-1952、plugins/dev-workflow/tests/develop-roles.bats:1-1244、plugins/dev-workflow/tests/lib/develop-docs.bash:1-24、tests/develop-orchestrator-reference-budget.bats（新規）、tests/develop-orchestrator-reference-budget.txt（新規）
- [x] 2.2 G の状態別の本体手順を gate-result.md に移し、(4) を全 Status の行き先表にする。決める役の入力、代理投稿とその例外、同じ入力が再度返ったときの停止、区画と補足の description、CI 見張りと引継ぎの既存正本への接続を保つ。文言検査を集合へ移し、表の全行と行き先の実在を構造検査する。新規 reference の予算に追加する。確認: develop-skill／develop-roles／develop-adapter-review-routing の bats が通り、G の手順本文に差分が無い。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:141-217、plugins/dev-workflow/skills/develop/SKILL.md:225-233、plugins/dev-workflow/skills/develop/references/gate-result.md（新規）、plugins/dev-workflow/tests/develop-skill.bats:1-1952、plugins/dev-workflow/tests/develop-roles.bats:1-1244、plugins/dev-workflow/tests/develop-adapter-review-routing.bats:1-273、tests/develop-orchestrator-reference-budget.bats（新規）、tests/develop-orchestrator-reference-budget.txt（新規）
- [x] 2.3 W の空 return と破壊的 git 操作の拒否からの復旧を worker-recovery.md に移す。通常 return の拒否報告も含めて、再開／許可の前に本体が必ず読む指示を残す。内容検査は移動後も通り、規則を消すと落ちる fixture、入口の必読指示を外すと落ちる fixture を追加する。新規 reference の予算に追加する。確認: develop-skill／git-destructive-guard の関係する bats と予算検査が通り、許可の四条件・agent_id・15 分・一回限り・終了コード 3 の手順が保たれる。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:219-223、plugins/dev-workflow/skills/develop/references/worker-recovery.md（新規）、plugins/dev-workflow/tests/develop-skill.bats:1-1952、plugins/dev-workflow/tests/git-destructive-guard.bats:1-2460（手順の文言検査のみ）、plugins/dev-workflow/tests/lib/develop-docs.bash:1-24、tests/develop-orchestrator-reference-budget.bats（新規）、tests/develop-orchestrator-reference-budget.txt（新規）

## 3. 起動時の正本と骨格を整理する

- [x] 3.1 Codex の役割解決の入力・結果・起動／再開・監査記録を codex-develop.md の一つの本文に寄せ、同ファイル内の重複と SKILL.md・command の説明は必読参照にする。既存の provider／read-only／fresh thread／失敗時に別 provider へ代行しない条件を維持する。 既存の失敗ループ要件の三つの Scenario に従い、`--failure first|executor|judgment` の対応・返った model の使用・昇格で model が変わる場合の fresh thread を、モデル節からの必読参照先で確認する。文言検査を適切な手順書集合へ移し、起動の二つの名指しと一元化を検査する。確認: develop-command／develop-adapter-review-routing／model-escalation-policy の bats が通り、G の `レビュー経路: adapter` と description は変わらない。触る範囲: plugins/dev-workflow/references/codex-develop.md:5-69、plugins/dev-workflow/skills/develop/SKILL.md:24-32、plugins/dev-workflow/skills/develop/SKILL.md:163-181、plugins/dev-workflow/skills/develop/SKILL.md:302-320、plugins/dev-workflow/commands/develop.md:8-18、plugins/dev-workflow/tests/develop-command.bats:1-166、plugins/dev-workflow/tests/develop-adapter-review-routing.bats:1-273、plugins/dev-workflow/tests/model-escalation-policy.bats:1-347
- [x] 3.2 例・経緯・再掲を削除／参照化し、役割表・本体の禁止事項・工程概要・操作前の読み直し指示を先頭へ置く。UTF-8 bytes を 1 byte = 1 token とする保守的換算で骨格末尾まで 5,000 以下を検査し、fixture で骨格を範囲外へ押すと落ちることを確かめる。残りの移動で落ちる文言検査を手順書集合へ直し、起動時の三予算を実測 bytes まで下げる。 検査要件の守備範囲に従い、内容・入口・先頭位置・一元化・予算を保った同じ字数・バイト数の入替え fixture は通ることを許し、範囲外の穴の解消を完了条件に足さない。確認: develop-skill／develop-channel-mode／develop-worker-question-proxy と develop-startup-budget の bats が通り、三つの予算はすべて旧値以下で実測に一致する。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:7-80、plugins/dev-workflow/skills/develop/SKILL.md:40-63、plugins/dev-workflow/skills/develop/SKILL.md:99-140、plugins/dev-workflow/skills/develop/SKILL.md:302-375、plugins/dev-workflow/tests/develop-skill.bats:1-1952、plugins/dev-workflow/tests/develop-channel-mode.bats:1-243、tests/develop-worker-question-proxy.bats:1-99、tests/develop-startup-budget.bats:1-204、tests/develop-startup-budget.txt:1-3

## 4. 整合と統合検証を行う

- [x] 4.1 四 capability の delta と実際の移動先の一致を確認し、移動元の節を名指しする要件の取り残しを検索する。既存要件の全シナリオを保持し、参照先以外の条件を変えていないことを元 spec との比較で確認する。実装段では main specs を先行編集せず、差分の更新と strict 検証まで行う。確認: `openspec validate split-develop-startup-context --type change --strict` が exit 0、現行要件を archive で失う差分が無い。触る範囲: openspec/changes/split-develop-startup-context/specs/dev-workflow-develop/spec.md:1-535、openspec/changes/split-develop-startup-context/specs/dev-workflow-pr-token-budget/spec.md:1-98、openspec/changes/split-develop-startup-context/specs/dev-workflow-spec-review/spec.md:1-42、openspec/changes/split-develop-startup-context/specs/dev-workflow-pr-review-gate/spec.md:1-35
- [x] 4.2 全体の `./scripts/test.sh` と `./scripts/lint.sh`、新規予算・入口の退行検査・OpenSpec strict 検証を実行し、各 exit code を記録する。三ファイルと切り出し先の字数／bytes、先頭位置の換算、段落別の読込場面の対応表を更新して PR 本文用の根拠を揃え、親 #1682 に三ファイルの前後の字数をコメントする。確認: 全受け入れ条件の証拠が変更記録と測定コメントにあり、対象外の本文・スクリプトへの差分が無い。触る範囲: plugins/dev-workflow/changes/1685.md（新規）、openspec/changes/split-develop-startup-context/tasks.md（進捗更新）、scripts/test.sh:1-40（実行入口）、scripts/lint.sh:1-24（実行入口）

## Workflow follow-up

- implement 再試行2中断: 指定された3失敗・Broken pipe・EOF空行は修正済み。2.1〜3.1・4.1の照合は完了、3.2の残り文言検査と4.2の全体検証は未完了。全体テストで追加11失敗を検出し、移動追従後の関連87件は全成功、軽い通し方49件は48成功・1失敗。同じ CI 引き継ぎ入口検査が2連続で失敗したため停止。全体テストを停止（exit143）、lintは本体実行済みexit0、最終lintは本体が行う。作業項目増加0回。詳細は変更記録。

- R1 の APPROVE を issue #1685 で確認してから実装へ進む。今回は仕様 artifact までで return する。
- 終了の段で archive により四 capability の main specs に delta を同期する。同期後の配置参照を再検証する（openspec/specs/dev-workflow-develop/spec.md、dev-workflow-pr-token-budget/spec.md、dev-workflow-spec-review/spec.md、dev-workflow-pr-review-gate/spec.md）。
- 後続の Draft PR 本文へ三ファイルの前後の字数、先頭位置の換算、段落別の「単発で読まずに済む場面／必要な必読指示」、予算変更の理由と検証結果を転記する。merge・auto-merge はこの worker の対象外。
- 実行環境の注意: scripts/lint.sh は内部で `claude plugin validate` を呼ぶ。Claude の呼出し禁止が引き続き課された worker はこれを迂回・合格扱いせず、必要な検証コマンドと禁止の根拠を return し、許された実行主体で証拠を取得する。spec 段の必須検証は artifact の strict 検証であり、実装の合格をここでは宣言しない。

- implement 再試行3: W の担当範囲は全8項目完了。全体テストはCIと同じ4分割で全件exit0、strict検証exit0。今回の本体指示により最終lintと親エピックへの最終測定コメントは本体担当（Wは未実行・未投稿）。独立実装レビューとfinishは次段。詳細は変更記録。
