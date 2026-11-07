# Tasks

## 1. CI 見張りの修正担当の引き継ぎを手順と関係テストにする

- [ ] 1.1 既存の develop-trivial-light-path.bats に、通常判断で W 不明の本体が CI 用引き継ぎを使って implement に手渡すケースと、引き継ぎ無し・必要項目不足・return 参照不能・工程中断で停止確認無し・手渡し不可・対象不一致・未コミット差分なら起動せず停止先へ報告するケースの文書契約テストを加える。さらに既存 W の再開／新しい W への手渡しそれぞれで、起動／再開前に不可の投稿成功を確認し、投稿失敗なら起動しない契約を検査する。起動後まだ HEAD・作業ツリーが変わらない間に本体が交代し、ci-watch.md 2 の中断済み fix へ戻る場合も、最新の不可を読み古い可へ遡らず二人目を起こさない回帰ケースを含める。検証: `bats plugins/dev-workflow/tests/develop-trivial-light-path.bats` で追加ケースが現行手順に対して red になることを確認する。触る範囲: plugins/dev-workflow/tests/develop-trivial-light-path.bats:66-126（CI fix の関係テスト）
- [ ] 1.2 handover.md に CI 用の独立した節を足し、通常経路の待ちの前に本体が PR へ残す情報、最新の記録の読取り、対象と必要項目の照合、既存の手渡し許可の根拠、情報不足の停止先を定める。通常経路の W の起動／再開前に許可を確認して依頼入力を保持し、最新の不可の投稿成功後だけ指示する順序と、今回の工程完了／停止確認後だけ可へ更新する規則を書く。主の返事待ちの既存書式と許可条件は変えない。1.1 に、見張り前・修正後の記録、既存項目の継承、古い可へのフォールバック禁止、主の続行指示による代用禁止、今回の工程完了と停止確認それぞれによる再許可、以前の完了／停止確認や push・idle だけでは再許可しない検査を足す。delta spec の守備範囲（入力元・拾う誤り・通ることを許す誤報告の具体例・穴を塞ぎ切らない限界）を手順にも反映し、文書契約テストで確認する。検証: `bats plugins/dev-workflow/tests/develop-trivial-light-path.bats plugins/dev-workflow/tests/develop-handover.bats` で該当検査を通し、未接続分は 1.3 で解消する。触る範囲: plugins/dev-workflow/skills/develop/references/handover.md:1-55（既存の保留用手順と末尾の追記位置）、plugins/dev-workflow/tests/develop-trivial-light-path.bats:66-126
- [ ] 1.3 decision-criteria.md の CI fix 分岐に通常判断で W 不明の場合の handover.md への接続を足し、既存 W の再開と新しい W への手渡しの両方を、起動／再開前の不可の記録と今回の完了／停止確認後の再許可へ接続する。ci-watch.md 7 から見張り前の記録、9 から同じ fix の担当分岐を辿れるようにする。ci-watch.md 2 の中断済み fix の再開にも同じ担当の準備を適用する。関係テストで ci-fail / conflict、9 と 2 の参照、既存 W の implement 再開、軽い経路の新規 spec、通常復帰後の再 fix、passed 解除・Draft 化・pending、同じ PR/状態ファイル、既存の報告先を確認し 1.1-1.2 を green にする。検証: `bats plugins/dev-workflow/tests/develop-trivial-light-path.bats plugins/dev-workflow/tests/develop-handover.bats plugins/dev-workflow/tests/ci-watch.bats` が exit 0。触る範囲: plugins/dev-workflow/skills/develop/references/decision-criteria.md:58-65（CI 見張りの fix からの戻し方）、plugins/dev-workflow/references/ci-watch.md:18-34（見張り開始・再開）、plugins/dev-workflow/references/ci-watch.md:99-132（直し方・再起動）、plugins/dev-workflow/tests/develop-trivial-light-path.bats:66-126
- [ ] 1.4 #1597 の変更記録を追加し、W 不明の場合に使う情報・手渡しの可否・停止先を記す。検証: `git diff` で本 change の要件と対応し、#1583/#1590 と他の子の変更や重複整理を含まないことを確認する。触る範囲: plugins/dev-workflow/changes/1597.md（新規）

## 2. 接続全体を verify する

- [ ] 2.1 関係テスト `bats plugins/dev-workflow/tests/develop-trivial-light-path.bats plugins/dev-workflow/tests/develop-handover.bats plugins/dev-workflow/tests/ci-watch.bats plugins/dev-workflow/tests/ci-watch-entry.bats plugins/dev-workflow/tests/develop-skill.bats tests/develop-startup-budget.bats` と `openspec validate develop-ci-fix-worker-handover --type change --strict` が exit 0 であることを確認する。`git diff --check` と差分確認で #1597 に範囲を限定し、起動時予算対象の 3 ファイルや過去の archive を変更していないことを確かめる。触る範囲: plugins/dev-workflow/tests/develop-trivial-light-path.bats:1-283、plugins/dev-workflow/skills/develop/references/handover.md:1-55、plugins/dev-workflow/skills/develop/references/decision-criteria.md:58-65、plugins/dev-workflow/references/ci-watch.md:18-132

## Workflow follow-up

- R1 の APPROVE が #1597 に記録されるまで実装へ進まない。
- verify 後の finish で本 delta を archive し、既存 capability dev-workflow-develop に反映する。過去の archive や既存の passed 要件を便宜的に書き換えない。
- 予定の実装編集先は手順 3・既存テスト 1・変更記録 1 の 5 ファイル。追加が必要なら規模超過の正本に従って本体へ return する。
- 起動時予算対象の変更が必要になった場合は、周辺文を圧縮せず OWNER の指示どおり該当予算を追記の増加バイト分まで上げ、PR 本文に理由と https://github.com/oratta/claude-harness/issues/1586 を書く。
- PR 作成・仕様宣言は finish 工程。merge／auto-merge はしない。
