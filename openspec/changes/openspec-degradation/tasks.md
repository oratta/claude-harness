# Tasks: openspec-degradation

## 1. 実機検証とバージョン乖離の解消（最初に実行・以降の一次ソース）

- [x] 1.1 素の repo（openspec 未 init の一時ディレクトリ）で `openspec init --tools claude` → `openspec apply` を実機検証する。volta グローバル 1.2.0 と npx ローカル 0.23.0 の両系統で挙動を確認し、どちらを正とするかを確定する。カスタムスキーマ longrun-tdd の出所（init で入るのか、`openspec schema fork` + テンプレートコピーが必要な claude-harness 固有手順か）を確定し、実コマンド出力のエビデンス付きで `plugins/longrun/docs/openspec-cli-verification.md` に記録する（ギャップ 2 の解消）
- [x] 1.2 1.1 の結果に基づき、preflight の検出コマンド系列（npx 優先 / which 優先）と未インストール環境への導入案内文言を確定し、確定結果を `plugins/longrun/docs/openspec-cli-verification.md` に一本化して記録する（design.md には確定値を書かない。design.md の該当 Decision は同ファイルへの参照のみ）

## 2. preflight 判定（exec Step 0）

- [ ] 2.1 `plugins/longrun/tests/` を新設し、`openspec-preflight.sh` の bats テストを先に書く（RED）: PATH 操作 / stub で「npx openspec 解決不可 → `NO_CLI`」「openspec/ 不在 → `NO_INIT`」「両方 OK → `OK`」「既存 openspec あり repo で副作用なし（縮退マーカー・openspec/ への書き込みが発生しない）」を検証する
- [ ] 2.2 `plugins/longrun/scripts/openspec-preflight.sh` を実装し 2.1 の bats を全 PASS させる（GREEN）。判定値は標準出力（`OK` / `NO_CLI` / `NO_INIT`）+ exit code で返す
- [ ] 2.3 `plugins/longrun/commands/exec.md` に Step 0 を追加する: preflight スクリプト実行 → 結果に応じた AskUserQuestion を表示する。`NO_CLI` / `NO_INIT` 時は縮退モード提案（縮退で続行 / init して通常続行（NO_INIT 時のみ）/ 中断 + セットアップ案内）。**「OpenSpec 不要明示」の入力手段は「preflight OK 時も Step 0 の動作モード確認 AskUserQuestion に縮退選択肢を常時含める」方式で確定**（専用引数は追加しない。デフォルト選択肢は通常モード）。縮退選択時は `_longruns/<run>/.degraded-mode` マーカーを作成し、結果を checkpoint.md に記録する
- [ ] 2.4 `plugins/longrun/skills/longrun-orchestrator/SKILL.md` の Setup ツール検証とエラーハンドリング表を更新する: 多段フォールバック + `npm install -g` 試行を廃止し、Step 0 の判定結果（モード）を消費する形に整理。通常モードのフローは従来と完全に同一に保つ

## 3. 縮退モード artifacts（自己完結生成）

- [ ] 3.1 orchestrator の OpenSpec フェーズ（change 作成 / apply / validate）に縮退分岐を追加する: `.degraded-mode` 存在時は OpenSpec CLI を呼ばず、`_longruns/<run>/specs/<change-name>/{proposal.md,tasks.md}` を longrun-tdd テンプレート相当の形式（tasks はチェックボックス `- [ ] X.Y`、spec は WHEN/THEN）で自己完結生成し、`openspec/` 配下には一切書き込まない
- [ ] 3.2 verification-guide 生成の縮退分岐を追加する: `_longruns/<run>/specs/` 配下の Scenario（WHEN/THEN）から `_longruns/<run>/verification-guide.md` を通常モードと同等の形式で生成する
- [ ] 3.3 `plugins/longrun/commands/archive.md` に `.degraded-mode` マーカー判定の縮退分岐を追加する: マーカー存在時は OpenSpec change の移動をスキップしランディレクトリのみアーカイブする。既存の MVP 分岐（plan.md 先頭の `<!-- mvp-mode -->` マーカー判定、archive.md L15-19）とは**判定ソースが別**であることを明示し、両マーカー併存時の優先順位を定義する（判定順は `.degraded-mode` → `<!-- mvp-mode -->`。動作はいずれも「ディレクトリのみアーカイブ」で同一だが、判定根拠の表示を分ける）
- [ ] 3.4 縮退 run 完走の bats を追加する: openspec コマンド不在をシミュレートした環境で、縮退時の生成物パス（`_longruns/<run>/specs/` / `verification-guide.md`）の存在と `openspec/` 不生成、アーカイブ動作を検証する

## 4. feedback Tier 3 フォールバック

- [ ] 4.1 `plugins/longrun/skills/longrun-feedback/SKILL.md` に縮退分岐を追加する: 対象 run に `.degraded-mode` が存在する場合、Tier 3 の記録先を `_longruns/<run>/backlog.md` にフォールバックし（フォーマットは `openspec/backlog.md` と同等）、分類結果の提示で記録先を明示する。`openspec/` ディレクトリは作成しない。マーカーが無い通常 run は従来どおり `openspec/backlog.md`
- [ ] 4.2 フォールバック分岐の bats を追加する: マーカー有 → run 内 backlog に追記 + `openspec/backlog.md` 不生成、マーカー無 → `openspec/backlog.md` に追記（回帰なし）を検証する

## 5. ドキュメントとリリース

- [ ] 5.1 `plugins/longrun/README.md` に縮退モードの説明（発動条件・成果物パス・既知の制限: status は縮退非対応のまま change-2 で廃止予定）を追記し、`/longrun:status` には縮退分岐を実装していないことを明記する
- [ ] 5.2 バージョン 3 箇所同期: `plugins/longrun/.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json` top-level / 同 plugins[] を 5.2.0 → 5.3.0 に bump し、description を更新する
- [ ] 5.3 最終検証: `jq .` による plugin.json / marketplace.json の構文検証、`bats plugins/longrun/tests/` 全 PASS、既存 openspec あり repo の回帰なし確認（通常モードパスの grep / bats）
