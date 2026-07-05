# Tasks: proactive-routines

各サブマイルストーン（グループ 1〜6）は独立 commit で完結させる。1 ルーチンのデモ失敗は他のルーチンの実装・デモをブロックしない（失敗時は当該グループのみ保留し、次グループへ進む）。

## 1. backlog 消化ルーチン（レシピ実装・独立 commit）

- [ ] 1.1 bats テストを先に書く: `routine-backlog-triage.md` の固定見出し 7 節（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）の存在、非破壊制約（Draft PR まで + merge・close・force 禁止の列挙）、処理数上限の数値記載、繰り越し記録（silent drop 禁止）、2 連続失敗凍結の各キーフレーズを grep 検証する（この時点では FAIL）
- [ ] 1.2 `plugins/loops/recipes/routine-backlog-triage.md` を執筆する: /schedule 起動 → discovery（backlog.md + open issues、処理数上限明記）→ worktree 隔離実装 → 第二エージェントレビュー → Draft PR まで → state 更新（処理済み / 繰り越し / 引き継ぎ待ち）。停止基準は /goal「選定タスクが全て Draft PR または凍結記録に到達するまで」+ 同一タスク 2 連続失敗凍結。起動コマンドはネイティブプリミティブのコピペ可能文字列のみ
- [ ] 1.3 references の規約検査手順（停止基準必須・Bad Loop 検査 4 項目）をこのレシピに手動適用し、全項目 PASS を確認する
- [ ] 1.4 1.1 の bats テストが全て PASS することを確認し、レシピ + テストを独立 commit する

## 2. backlog 消化ルーチン（1 サイクルデモ・独立 commit）

- [ ] 2.1 デモ計画を確定する: このリポジトリの実 backlog に安全な小タスクがあればそれを、なければ安全なサンドボックスを使う（処理数上限 1 件で実行）
- [ ] 2.2 1 サイクルを実行する: discovery → 実装 → 第二エージェントレビュー → Draft PR 作成（またはサンドボックス相当物）→ state 更新・繰り越し記録
- [ ] 2.3 実行ログ（Draft PR 作成・state 更新・繰り越し記録の確認結果 + 1.3 の手動規約検査結果）を `{longrun-dir}` に evidence として保存し、独立 commit する

## 3. 長期ビルドルーチン（レシピ + feature-list リファレンス実装・独立 commit）

- [ ] 3.1 bats テストを先に書く: `routine-long-build.md` の固定見出し 7 節、1 サイクル 1 項目、smoke check が実装より前、evidence（verification exit 0）必須の passes 更新 + 自己申告禁止、凍結条件（同一項目 2 連続 FAIL + 削除禁止）、および `references/feature-list-format.md` の 4 キー（id / description / verification / passes）・`passes:false` 初期値・削除禁止の記載を grep 検証する（この時点では FAIL）
- [ ] 3.2 `plugins/loops/references/feature-list-format.md` を執筆する（形式記載のみ。JSON Schema ファイルは作らない）
- [ ] 3.3 `plugins/loops/recipes/routine-long-build.md` を執筆する: 1 サイクル = smoke check → `passes:false` 先頭 1 項目のみ実装 → exit 0 evidence 確認後に `passes:true` 更新 → 説明的 commit → progress 追記。停止基準は /goal「全項目 passes:true、同一項目 2 連続 FAIL で凍結して人間へ」。発火時プロンプトに自己申告更新禁止を含める
- [ ] 3.4 references の規約検査手順（停止基準必須・Bad Loop 検査）をこのレシピに手動適用し、全項目 PASS を確認する
- [ ] 3.5 3.1 の bats テストが全て PASS することを確認し、レシピ + リファレンス + テストを独立 commit する

## 4. 長期ビルドルーチン（複数サイクル完走デモ・独立 commit）

- [ ] 4.1 3 項目以上の feature-list.json を実在の verification コマンド（bats / grep / jq 等、exit code が本物のもの）で用意する
- [ ] 4.2 2 サイクル以上に分けて完走させる: 各サイクルの smoke check 結果・実装した 1 項目・verification exit code・passes 更新・progress 追記をログに記録する
- [ ] 4.3 1 項目を故意に 2 連続 FAIL させ、凍結（feature-list から削除されない）+ 人間へのエスカレーション記録（progress notes）を確認する
- [ ] 4.4 実行ログ（4.2 + 4.3 + 3.4 の手動規約検査結果）を `{longrun-dir}` に evidence として保存し、独立 commit する

## 5. レシピ採掘メタループ（レシピ実装・独立 commit）

- [ ] 5.1 bats テストを先に書く: `routine-recipe-miner.md` の固定見出し 7 節、ローカル実行必須の制約（`~/.claude/projects/` jsonl）+ 実行登録は呼び出し側責務、サブエージェント隔離（生ログをメインに載せない）+ 4 種の抽出候補、1 サイクル最大 3 提案、Draft PR 出力・自動 merge 禁止、検査不通過提案の見送り記録、state 3 区分（提案済み / 見送り理由 / 繰り越し）、候補ゼロの「提案なし」正常終了の各キーフレーズを grep 検証する（この時点では FAIL）
- [ ] 5.2 `plugins/loops/recipes/routine-recipe-miner.md` を執筆する: discovery（サブエージェント + llm-log-compactor の jq パターン流用で直近 7 日を圧縮解析）→ 生成（停止基準必須・Bad Loop 検査を通した新規案/更新 diff、最大 3 件）→ 出力（この marketplace リポジトリへ Draft PR、自動 merge 禁止）→ persistence（state 記録）。スケジューラ登録手順は書かない
- [ ] 5.3 references の規約検査手順（停止基準必須・Bad Loop 検査）をこのレシピ自身に手動適用し、全項目 PASS を確認する（メタループ自身も規約に従う）
- [ ] 5.4 5.1 の bats テストが全て PASS することを確認し、レシピ + テストを独立 commit する

## 6. レシピ採掘メタループ（手動 1 サイクルデモ・独立 commit）

- [ ] 6.1 直近の実セッションログに対して 1 サイクルを手動起動で実行する（定期実行への登録は行わない）: サブエージェント解析 → 候補抽出 → 規約検査（references 手順の手動実行、各項目 PASS/FAIL を記録）→ 提案 Draft PR または「提案なし」の正常終了
- [ ] 6.2 state 更新（提案済み / 見送り理由 / 繰り越し）を確認する。候補ゼロの場合は「提案なし」正常終了として異常系と区別して記録する
- [ ] 6.3 実行ログ（6.1 + 6.2 + 5.3 の手動規約検査結果）を `{longrun-dir}` に evidence として保存し、独立 commit する

## 7. 統合検証

- [ ] 7.1 `find plugins -name '*.bats' -print0 | xargs -0 bats` で本 change 分を含む全テストが PASS することを確認する
- [ ] 7.2 全レシピ（recipes/*.md）が固定見出し 7 節を持ち、停止基準の無いレシピが 0 件であることを grep で横断確認する（受け入れ条件 6）
- [ ] 7.3 `plugins/loops/` に独自ランタイム（常駐スクリプト・カスタム driver）が存在せず、3 ルーチンの起動コマンドが全てネイティブプリミティブであることを確認する（受け入れ条件 7）
- [ ] 7.4 受け入れ条件 10・11・12 の各項目（レシピ内容 4 点セット + デモ evidence の実在）を検証コマンドで最終確認し、結果を記録する
- [ ] 7.5 実装中に見つけた拡張候補（レシピ schema 化・イベント駆動等）があれば `openspec/backlog.md` に記録する（実装しない）
