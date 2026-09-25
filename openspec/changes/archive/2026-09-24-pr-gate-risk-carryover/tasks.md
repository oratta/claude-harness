## 1. 判定スクリプト（テストを先に書く）

- [x] 1.1 `plugins/dev-workflow/tests/risk-carryover-check.bats` を書く。一時ディレクトリに base 用の main と PR ブランチを持つ git リポジトリを組み、spec「risk-carryover-check.sh が差分の範囲と根拠ファイルの無変更を判定する」の 9 シナリオ（衝突なしの取り込み／版番号と CHANGELOG の衝突解消だけ／根拠ファイルが変わった／main 以外の commit／許可リスト外の衝突解消／JSON の版以外の行／CHANGELOG の新しい文／前の HEAD が祖先でない／根拠ファイルなし）を 1 件ずつ確かめる。この時点で全件 Red であることを確認する
- [x] 1.2 `plugins/dev-workflow/scripts/risk-carryover-check.sh` を実装する（Bash 3.2 で動く書き方。gh を呼ばない。git 2.38 未満は終了コード 2）。design.md「差分が main の取り込みだけの定義」「衝突解消の中身の定義と許すファイル」どおりに判定し、出力は `CARRYOVER=` / `MAIN_MERGES=` / `RESOLVED_FILES=` / `NG:` 行
- [x] 1.3 1.1 の bats が全件 Green になることを確認する

## 2. pr-review-gate の手順書

- [x] 2.1 SKILL.md の記述検査を bats に足す（`plugins/dev-workflow/tests/pr-review-gate-skill.bats` に追記）: 雛形の `- 根拠ファイル:` 行、引き継ぎの小節の 4 条件（条件④は「`対象 HEAD:` 行を除いて本文が同一」の文言）、前の HEAD の宣言の選び方、「流用しない」の唯一の例外の文、捏造防止の 3 条件、引き継いだ宣言の 4 行の書式、手順 5 の表の引き継ぎの行、手順 6 の表からの参照。既存の「雛形ブロックが 2 つ」の検査が 3-c を足しても通ることも確かめる。Red を確認する
- [x] 2.2 SKILL.md 手順 3 の「主のリスク許容が必要」の雛形に `- 根拠ファイル: <パス>, <パス>` の行を足す
- [x] 2.3 SKILL.md 手順 3 に小節「3-c. 前の HEAD の許容の引き継ぎ」を 3-b の後ろに足す: いつ試すか（「主のリスク許容が必要」と判定し、前の HEAD の宣言に許容が記録済みのとき）、前の HEAD の宣言の選び方（同じ PR の `## リスク宣言` コメントのうち `主の回答: 許容` 系の行と `真正性確認: 済` の行の両方を持つ最新 1 件。その `対象 HEAD:` の SHA をスクリプトの前 HEAD に渡す）、スクリプトの呼び方、G が確かめる条件（元の回答の真正性の再確認・`対象 HEAD:` 行を除いて本文が前の宣言と同一）、引き継いだ宣言の 4 行の書式、省けるのは主への質問だけでこれが手順 1 の「前回の合格部分を流用しない」（と gate-runner.md の同趣旨の文）の唯一の例外であること、引き継げないときは `NG:` 行を添えて手順 6 へ。書式ブロックは追記 4 行だけにし、`## リスク宣言` で始まる完全な例を置かない（既存 bats `pr-review-gate-skill.bats` が手順 3〜3-b の範囲の雛形ブロックを 2 つと数えるため）
- [x] 2.4 SKILL.md 手順 5 の合格条件の表に「引き継ぎで許容済み」の行を足す
- [x] 2.5 SKILL.md 手順 6 の復帰の表の「リスク許容待ち」に、HEAD が動いたときは 3-c を先に試す旨を参照として足す（条件は再掲しない）
- [x] 2.6 2.1 の bats が Green になることを確認する

## 3. G の指示書

- [x] 3.1 `gate-runner.md` の取り直しの記述の検査を bats に足す（`plugins/dev-workflow/tests/develop-roles.bats` など G の指示書を検査している既存スイートに追記）。Red を確認する
- [x] 3.2 `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` の再開節に、許容済みの PR で HEAD が動いたときは主に聞く前に pr-review-gate 手順 3-c を試すことを 1 行で足す（条件は再掲しない）
- [x] 3.3 3.1 の bats が Green になることを確認する

## 4. 記録と全体確認

- [x] 4.1 `plugins/dev-workflow/changes/441.md` を既存の changes/*.md の形式で書く（版は上げない）
- [x] 4.2 `scripts/test.sh` を全件流し、exit code と失敗件数を記録する
- [x] 4.3 `openspec validate pr-gate-risk-carryover --strict` が通ることを確認する
