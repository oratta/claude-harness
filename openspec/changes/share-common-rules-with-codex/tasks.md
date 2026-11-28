# Tasks

実装開始は issue #1853 の R1 APPROVE 確認後とする。依存は生成 → 配布 → worker、生成・配布 → 容量検査、全自動検査 → 実機証拠。実装と自動テストは一時ディレクトリ内のホームで行い、実ホームへの適用は6.1の権限確認まで行わない。以下の行番号は仕様化時点の案内であり、編集前に該当範囲を読む。

## 1. 正本からの生成

- [x] 1.1 `tests/codex-shared-instructions.bats` に公開全文・README除外・安定順序・harness全文と適用範囲・readable要点の生成検査を追加し、正本を一行変え未再生成なら失敗すること、再生成後に一致することを使い捨てコピーで確かめる。触る範囲: tests/codex-shared-instructions.bats（新規）、tests/rules-sync.bats:9-30（fixture参考）
- [x] 1.2 共通生成処理を作り、公開生成物を追跡する。個人版を加える生成はローカル限定とし、1.1のテストを通す。生成対象の正本は変更せず、見出し・区切りを含む生成物の一致で検証する。触る範囲: scripts/codex-shared-instructions.py（新規）、generated/codex/AGENTS.md（新規）、rules/communication-style.md:1-15（参照）、AGENTS.md:1-43（参照）
- [x] 1.3 生成・再生成・一致検査の実際の CLI と公開/個人の境界を docs に書き、記載した生成・一致検査コマンドが一時領域で動くことを確かめる。触る範囲: docs/codex-shared-instructions.md（新規）

## 2. 明示配布と既存ホームの保持

- [x] 2.1 配布の回帰テストを追加する。従来引数でCodexホーム不変、--codex/--no-pull併用、対象和集合・実体重複除去、両登録形式と不正入力、冪等性、既存7行のバイト保持、許可外/取消済みoverlay除外、非空override・破損/重複区画・管理外リンクの拒否を使い捨てホームで確認する。触る範囲: tests/codex-shared-instructions.bats（1で新規）、tests/rules-sync.bats:1-30、tests/rules-sync.bats:484-557（既存許可取消テスト参照）
- [x] 2.2 sync のオプション解析とCodex配布を実装する。登録表は既存契約を使い、管理区画だけを作成/置換し、2.1と既存 rules-sync テストを通す。別台帳・ホーム探索は追加しない。触る範囲: scripts/sync.sh:1-261、scripts/codex-shared-instructions.py（1で新規）、plugins/dev-workflow/scripts/codex-develop.py:403-409（参照）、plugins/dev-workflow/scripts/codex-develop.py:521-548（参照）
- [x] 2.3 容量キーの最低値131072、既存の大きい値の維持、profile等の小さい有効値への対応、認証/MCP/他設定の保持を実装し、各ケースをTOMLとして検査するテストを通す。触る範囲: scripts/codex-shared-instructions.py（1で新規）、tests/codex-shared-instructions.bats（1で新規）
- [x] 2.4 対象ホーム・登録形式・明示実行・拒否条件・管理区画の復旧・容量更新を docs に書き、一時ホームで同期と復旧の手順を確認する。触る範囲: docs/codex-shared-instructions.md（1で新規）

## 3. worker の共通区画継承

- [x] 3.1 fake app-server に runtime AGENTS/config の観測を追加し、選択したaccountの区画だけがコピーされ、区画外指示と親MCPが入らず、容量131072が毎回生成されるテストを書く。未配布・破損区画でturn/start前に非0となり同期を案内することも検査する。触る範囲: plugins/dev-workflow/tests/test_codex_worker.py:15-47、plugins/dev-workflow/tests/test_codex_worker.py:105-128、plugins/dev-workflow/tests/test_codex_worker.py:329-348、plugins/dev-workflow/tests/test_codex_worker.py:437-440
- [x] 3.2 runtime構築を更新し、認証リンク・既存隔離設定・0700・TMPDIR/TMPPREFIX継承を維持したまま管理区画と容量設定を追加する。共通区画の未配布/破損を起動前に拒否し、`python3 -B plugins/dev-workflow/tests/test_codex_worker.py` を通す。触る範囲: plugins/dev-workflow/scripts/codex-worker.py:211-241、plugins/dev-workflow/scripts/codex-worker.py:722-745、scripts/codex-shared-instructions.py（1で新規）
- [x] 3.3 既存workerテストのaccount fixtureを配布済みに揃え、他の既存テストに影響するfixtureも確認する。未配布を試すケース以外が偶然起動拒否されないようにし、対象テストが実際に本来の挙動まで到達して成功することを確かめる。workerの同期前エラーと継承境界をdocsに記載する。触る範囲: plugins/dev-workflow/tests/test_codex_worker.py:105-128、docs/codex-shared-instructions.md（1で新規）、plugins/dev-workflow/tests/test_codex_develop.py:745-795（関連fixtureの確認）

## 4. UTF-8 容量と ponta 固定入力

- [x] 4.1 裁定の測定元に基づき非公開入力の相対ファイル名・実測bytes・SHA-256・測定元をmanifestへ記録する。個人rulesと人格本文は転載せず、同サイズの決定的UTF-8ダミー本文と末尾マーカーを生成し、サイズと再現性をテストする。触る範囲: tests/fixtures/codex-shared-instructions/manifest.json（新規）、tests/codex-shared-instructions.bats（1で新規）、scripts/codex-shared-instructions.py（1で新規）
- [x] 4.2 共通区画・harness全文・生成見出し/区切り・区画外ホーム指示・flatmateルート/pontaの全体容量を検査する。公開入力は実生成物を測り、日本語・131072以内・上限ちょうど・1バイト超過をテストして、文字数でなくbytesで判定されることを確かめる。触る範囲: scripts/codex-shared-instructions.py（1で新規）、tests/codex-shared-instructions.bats（1で新規）、tests/fixtures/codex-shared-instructions/manifest.json（4で新規）
- [x] 4.3 ローカル実物の探索結果を検査する経路と利用手順を追加する。AGENTS/CLAUDE同居の選択をfixtureで検査し、同階層の二重計上が無いこと、不在時に実物成功と報告しないことを確認する。flatmate側の生成・配置は変更しない。触る範囲: scripts/codex-shared-instructions.py（1で新規）、tests/codex-shared-instructions.bats（1で新規）、docs/codex-shared-instructions.md（1で新規）

## 5. docs と変更記録

- [x] 5.1 READMEから配布・容量検査・workerの手順へ案内し、自動メモリを探索/コピー/リンクしないこと、記憶混入を防ぐ理由、明示的な知識提供は可能であることをdocsに明記する。生成/配布テストに自動メモリが取り込まれない確認を加え、記載した手順を一時ホームで確認する。触る範囲: README.md:28-52、docs/codex-shared-instructions.md（1で新規）、tests/codex-shared-instructions.bats（1で新規）
- [x] 5.2 配布方式・容量の測定根拠・代案・自動メモリ非取込・互換性と復旧・#1850/#2160との境界を変更記録に書く。`tests/injection-budget.txt` を変更していないことと、非公開本文や個人の固定パスを含まないことをdiffで確認する。触る範囲: docs/changes/1853.md（新規）、docs/codex-shared-instructions.md（1で新規）

## 6. 実機証拠（本体の適用権限確認後）

- [ ] 6.1 本体が適用対象ホーム、AGENTS/configの具体差分、復旧方法を提示して適用権限を確認し、主または承認された本体がsync経由で配布する。検証前後の状態をローカルで確認し、適用と復旧の手順をissue #1853へ記録する。仕様化workerは実ホームへ書かない。触る範囲: docs/codex-shared-instructions.md（1で新規、手順参照）、issue #1853（実機記録。実ホームは承認されたsyncのみ）
- [ ] 6.2 新規Codexセッションに破壊的git・commit・主への聞き方の内容を答えさせ、出力と正本の照合結果、対象HEAD・コマンド・exit codeをissueへ貼る。通信完走を合格とせず、内容が三規則に合っていることを確認する。触る範囲: issue #1853（実機記録）、rules/（照合用、編集しない）
- [ ] 6.3 flatmate/pontaの作業ディレクトリで実物容量検査と新規セッションを実行し、実際の人格の最後の節を答えた出力を正本と照合してissueへ記録する。固定入力だけの成功を実物成功にしない。非公開本文を公開repoへ保存せず、人格全体をissueへ転載しない。触る範囲: issue #1853（実機記録）、docs/codex-shared-instructions.md（1で新規、実物検査手順参照）
- [ ] 6.4 選択済みaccount homeから起動したworkerに検証用変更をcommitさせ、SHA・メッセージ・コマンド・exit codeと既存履歴の日本語形式との照合結果をissueへ記録する。固定のcodex-standard/currentを維持し、本文の品質判定を実行結果と区別する。触る範囲: issue #1853（実機記録）、plugins/dev-workflow/scripts/codex-worker.py:699-745（起動経路参照）

## 7. 統合確認

- [x] 7.1 `bats tests/codex-shared-instructions.bats tests/rules-sync.bats tests/agents-md-sync.bats tests/injection-budget.bats`、`python3 -B plugins/dev-workflow/tests/test_codex_worker.py`、`openspec validate share-common-rules-with-codex --type change --strict`、`git diff --check` を実行しexit 0を記録する。新設Batsを追跡後に `scripts/test.sh` の全件検査も実行し、対象HEAD・成功/総件数・exit codeを残す。触る範囲: tests/codex-shared-instructions.bats（1で新規）、tests/rules-sync.bats:1-557、tests/agents-md-sync.bats:1-73、tests/injection-budget.bats:1-1405（既存、予算値は変更しない）、plugins/dev-workflow/tests/test_codex_worker.py:1-1114（既存）、scripts/test.sh:1-60（全件発見方式参照）、issue #1853（結果記録）

実装工程の検証記録: 全件は書込可能な一時 TMPDIR を使い、CI と同じ `TEST_SHARD=1/4`〜`4/4 scripts/test.sh` の和集合で実行した。1組1422・2組1415・3組1412・4組1413、合計5662/5662成功、skip 0、各exit 0。全件で検出したコメントの一覧照合と新規公開部品の登録漏れは修正し、該当スイート7件・50件と3組全体の再実行も成功した。6.1〜6.4の実ホーム適用・実機読込の証拠は依頼に従い未実施。
