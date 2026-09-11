## 1. path スコープの実機確認（最初に行う。結果で 3 の内容が変わる）

- [ ] 1.1 検証用ルール 1 本を `~/.claude/rules/` に実ファイルで置く（harness の `rules/` には入れない）。frontmatter に `paths:` を 1 つ書き、本文に検索しやすい固有の文字列を入れる
- [ ] 1.2 対象パスに一致するファイルを読むセッションを起動し、その固有文字列が載るか確認する（証拠のスクリーンショットかテキストを控える）
- [ ] 1.3 対象パスに一致するファイルを読まないセッションを起動し、その固有文字列が**載らない**ことを確認する。ここが「載る」なら path スコープは効いていない
- [ ] 1.4 検証用ルールを片付け、両方向の結果と採否の判断を issue #260 にコメントする（証拠つき）
- [ ] 1.5 採用しない場合は 3.1 と 4 を飛ばす旨を tasks に追記する

## 2. rules の縮約と移設（常時性を手放せない 2 本は触らない）

- [ ] 2.1 `rules/plugin-editing.md`（5,376）を縮約する。開発場所の詳細は `CLAUDE.md` の「開発場所」節と `docs/worktree-recovery.md` が既に持つので、rules 側は発火条件と禁止事項の要点まで削る
- [ ] 2.2 `rules/communication-style.md`（4,833）を縮約する。全文の正本 `output-styles/readable.md` へのポインタを残し、サブエージェント向けの要点だけにする
- [ ] 2.3 `rules/subagent-model-selection.md`（3,219）を縮約する。ティア対応表と「`model` 必須」を残し、経緯・適用範囲・強制層の説明を `plugins/dev-workflow/references/model-tiers.md` へ移す
- [ ] 2.4 `rules/perspective-casting.md`（2,710）を縮約する。5 手順の見出しを残し、各手順の説明を `plugins/casting/skills/casting/SKILL.md` へ移す（既に正本があるなら重複を消すだけ）
- [ ] 2.5 `rules/git-commit-policy.md`（2,383）を縮約する。「承認なしに実行しない操作の一覧」を残し、PR 運用 / ローカル main 運用の判定手順と pr-review-gate 連携を `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` へ移す
- [ ] 2.6 `rules/browser-infra-env-capture.md`（2,070）を縮約する。「表示された次のアクションで保存」を残し、1Password への昇格手順を `capability-registry` スキルへ移す（既に正本があるなら重複を消すだけ）
- [ ] 2.7 `rules/link-when-requesting-review.md`（859）を縮約する。書式の注意（裸 URL を括弧で囲まない）を残し、理由の説明を削る
- [ ] 2.8 `rules/destructive-git-guard.md` と `rules/dev-server.md` は常時注入に残す。削減対象に入れていないことを確認する
- [ ] 2.9 縮約した各ルールの本文に移設先パスを 1 行で書き、そのパスが実在することを確認する
- [ ] 2.10 `rules/README.md` のファイル一覧表に、ルールごとの移設先を書き足す

## 3. path スコープの適用（1 で採用と判断した場合のみ）

- [ ] 3.1 `rules/plugin-editing.md` と `rules/browser-infra-env-capture.md` に `paths:` を付ける。対象は harness の編集（`rules/**`・`plugins/**`・`scripts/**`）とインフラ操作に当たるパス

## 4. 予算テストの集計変更（1 で採用と判断した場合のみ）

- [ ] 4.1 `paths:` を持つルールを合計から外し、別行として内訳に出す検査を `tests/injection-budget.bats` にテストとして先に書く（Red）
- [ ] 4.2 集計ヘルパを直して通す（Green）
- [ ] 4.3 `paths:` を持つルールが無いときに従来どおりの合計になることをテストで確認する

## 5. description の縮約

- [ ] 5.1 `plugins/worktree/skills/wt-clean/SKILL.md`（1,297）の description を発火条件だけに削り、手順と背景を本文冒頭へ移す
- [ ] 5.2 `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`（1,022）を同様に縮約する
- [ ] 5.3 `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`（756）を同様に縮約する
- [ ] 5.4 `plugins/daily-report/skills/daily-report/SKILL.md`（756）を同様に縮約する
- [ ] 5.5 `plugins/dev-workflow/skills/develop/SKILL.md`（712）を同様に縮約する
- [ ] 5.6 `plugins/worktree/commands/wt-clean.md`（691）・`plugins/skill-pack/skills/skill-pack/SKILL.md`（544）・`plugins/casting/skills/casting/SKILL.md`（531）・`plugins/dev-workflow/skills/issueify/SKILL.md`（470）・`plugins/dev-workflow/skills/push-guard-setup/SKILL.md`（435）を同様に縮約する
- [ ] 5.7 縮約した skill のうち 1 件を、その skill が想定する実際の依頼文で呼び、起動することを確認する（証拠を控える）

## 6. CLAUDE.md の縮約

- [ ] 6.1 `CLAUDE.md`（5,732）を縮約する。開発場所と PR 運用の要点を残し、経緯と長い説明を `docs/` へ移す
- [ ] 6.2 `AGENTS.md` に同じ内容を反映する（`tests/agents-md-sync.bats` が同一性を強制する）

## 7. 測定と予算の引き下げ

- [ ] 7.1 `scripts/test.sh injection-budget` で削減後の実測と内訳を取り、合計が 36,395 バイト以下であることを確認する
- [ ] 7.2 届いていなければ 2 と 5 に戻って追加で削る（どこを削ったかを記録する）
- [ ] 7.3 `tests/injection-budget.txt` を削減後の実測に対して上下どちらのラチェットにも当たらない値（実測 × 1.05 前後）に引き下げる。予算ファイルは聖域なので、PR 本文に引き下げの理由と着手前後の実測を書く

## 8. 仕上げ

- [ ] 8.1 `scripts/test.sh` 全件を実行し、exit code 0 を確認する（`rules-sync` と `agents-md-sync` を含む）
- [ ] 8.2 変更したプラグインの `plugin.json` のバージョンを上げる（merge-base からの bump を S131 が要求する）
- [ ] 8.3 openspec スキルの二重掲載（`openspec-*` と `opsx:*`）が本 change の対象外であることと、その理由（外部プラグイン側の構成）を PR 本文に書く
- [ ] 8.4 着手前の内訳・削減後の内訳・移設対応表を PR 本文に載せる
