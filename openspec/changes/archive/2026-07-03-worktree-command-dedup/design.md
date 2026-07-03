# Design: worktree-command-dedup

## Context

`plugins/worktree/` は **command** と **skill** で同一の実行フロー本文を二重に持っている。

- `skills/wt-clean/SKILL.md`（v2.0.0, 506 行）が **正**。squash マージ検出（検証 A/B/C）・「AskUserQuestion 回答到着後の別ターンで破壊操作を実行する絶対禁則」・Step 0-C の全フローを備える
- `commands/wt-clean.md`（476 行）は SKILL.md の**旧世代コピー**。診断分類表が旧仕様（`AHEAD_COUNT>0 → 🔴`, 付録 D の line 226-245 相当）のまま取り残されており、squash 検出も絶対禁則の再掲も無い。command 経由で起動すると squash 済みブランチを 🔴 Active と誤判定し、誤削除事故が再発しうる（付録 D-1）
- `commands/wt-setup.md`（133 行）も `skills/wt-setup/SKILL.md`（169 行）とほぼ全文重複しており drift の温床（付録 D-2）

散文契約が 2 箇所にあると、片方だけ更新されて無言でドリフトする。これは本 run 全体の根本課題であり、change-4 は worktree プラグインについてそれを根治する。

参照実装は `plugins/lr/commands/e.md`。これは対象（`longrun/commands/exec.md`）を Read tool で読み込み、その指示に従ってメインセッションでインライン実行する薄いラッパーである。本 change はこの方式を worktree の 2 command に適用する。ただし e.md の参照先が **command** であるのに対し、本 change の参照先は **SKILL.md** である点が異なる。

バージョン: worktree 2.1.1 → 2.2.0（plugin.json）。marketplace.json の version・description 最終同期は change-7 が全編集プラグインをまとめて行うため、本 change は marketplace.json に触れない（付録 F-6 の責務分担に準拠）。

## Goals / Non-Goals

**Goals:**

- 実行フロー本文の正を SKILL.md の 1 箇所に一本化し、command はそれを Read して実行する薄いラッパーに落とす
- squash マージ検出と AskUserQuestion 別ターン実行の絶対禁則を一言一句失わず SKILL.md に保全する
- command 経由と skill 経由で同一の診断フローになることを構造的に保証する（command 側に別フロー定義を残さない）
- command frontmatter（`allowed-tools` / `argument-hint`）を維持し、`$ARGUMENTS` を SKILL.md 実行に透過する
- `wt-setup.sh` の `find -path` グロブと `settings.local.json` symlink の実挙動を確認し、意図を文書化する

**Non-Goals:**

- SKILL.md 側のフロー本文の書き換え・改善（squash 検出・禁則を含め現状を保全する。安全性ロジックへの手入れは本 change の範囲外）
- wt-clean / wt-setup の機能追加・オプション追加
- 他プラグインの command のラッパー化（worktree のみ対象）
- marketplace.json の同期（change-7 が担当）

## Decisions

### D1: 正の一本化先は SKILL.md（command ではなく）

- **選択肢**: (a) command を正にして skill を薄くする / (b) SKILL.md を正にして command を薄くする
- **決定**: (b)
- **理由**:
  - **SKILL.md 側が既に v2.0.0 の最新版**であり、squash 検出・絶対禁則を備えている。command 側が旧世代コピーで取り残されている（付録 D-1）。新しい方を正にするのが自然で、情報の欠落が起きない
  - skill はネイティブのスキル自動発見でも起動され、`description` によるトリガーを持つ第一級の起動経路である。command はその薄い別名入口という位置づけが妥当
  - `plugins/lr/commands/e.md` の既存実装（command が対象 .md を Read してインライン実行）と同じ方向であり、リポジトリ内のパターンに整合する

### D2: ラッパー方式は「Read tool で SKILL.md を読み、メインセッションでインライン実行」（lr/commands/e.md 方式）

- **選択肢**: (a) command から Skill tool で skill を呼ぶ / (b) command が SKILL.md ファイルを Read してインライン実行する
- **決定**: (b)。`plugins/lr/commands/e.md` と同じ方式
- **理由**:
  - command は既に「ユーザーが起動した slash command」という起動コンテキストを持つ。ここから Skill tool で同名 skill を再起動するのは二重起動的で、AskUserQuestion のターン制御（絶対禁則 1）に余計な間接層を挟む
  - Read tool でファイル本文を読み込んでインライン実行すれば、command の frontmatter（`allowed-tools`）配下でそのまま SKILL.md の手順が走り、ツール権限・引数透過が単純になる
  - e.md と同じく `CLAUDE_PLUGIN_ROOT` を第一候補に、marketplace / installed 配下を探索するフォールバックでファイルを特定する
- **含意（fork/model frontmatter）**: `skills/wt-setup/SKILL.md` は frontmatter に `context: fork` / `model: sonnet` を持つが、command ラッパー経由のインライン実行ではこれらの skill frontmatter は適用されず、command の frontmatter 配下でメインセッションで実行される。wt-setup は環境セットアップ作業であり fork/model 指定が無くても機能上問題ない。skill として直接起動された場合は従来どおり fork/sonnet で走る。この差はユーザー体験上許容する（診断・破壊操作を含む wt-clean 側は fork 指定を持たないため影響なし）

### D3: 安全性クリティカル記述は SKILL.md にのみ置き、command には一切コピーしない

- **決定**: squash 検出（検証 A/B/C）と AskUserQuestion 別ターン実行の絶対禁則は SKILL.md のみに存在させ、command には要約すらコピーしない
- **理由**: command に要約でも置くと「要約が本文とドリフトする」二重管理が再発する。command は「SKILL.md を読んでその通りに実行せよ」とだけ指示し、安全性の根拠はすべて Read された SKILL.md 本文から供給する。受け入れ条件 10（command に診断分類表・手順本文の重複コピーが無い）を構造的に満たす
- **検証**: `grep -n '🟢 Safe' plugins/worktree/commands/wt-clean.md` などで分類表・squash 手順・禁則本文が command から消えていること、かつ SKILL.md 側では検証 A/B/C・絶対禁則が一言一句残っていることを両面で確認する

### D4: wt-setup.sh の find -path グロブと settings.local.json symlink は「実挙動確認 → 問題なければ現状維持 + コメント」（付録 D-3）

- **対象 1（find -path グロブ, :35 付近）**: `find . -path "./$pattern" -type f` は `$pattern` を **1 個のパス glob** として扱う。`.env.*` のように 1 階層のパターンは直下のみ一致し、サブディレクトリ配下（例: `config/foo.env.local`）には一致しない。`.worktreeinclude` の既定パターン（`.env` / `.env.*` / `*.local.json` / `*.local.md`）はいずれもリポジトリ直下想定のため、現状の挙動で意図通り。**実挙動を確認し、直下想定である旨のコメントを追記して現状維持** に倒す（config.yaml rule・意思決定ガイドラインの「曖昧なら現状維持 + 文書化」に準拠）。もし実挙動確認でサブディレクトリを取りこぼす具体的な既定パターンが見つかった場合のみ、`-path "./**/$pattern"` 追加等の修正を検討する
- **対象 2（settings.local.json symlink, :62-67 付近）**: `settings.local.json` はマシンローカルの権限許可（`permissions.allow` 等）を含みうる。worktree にこれを symlink すると、メインリポの許可設定が worktree にも効く。同一マシン・同一ユーザーの worktree では**むしろ望ましい**（毎回許可し直さずに済む）ため、現状の symlink 挙動は妥当と判断する。**symlink する理由（同一マシン・同一ユーザー内での権限設定共有）を説明するコメントを追記して現状維持** に倒す。実挙動確認で「worktree 固有の設定が上書きされて壊れる」等の問題が確認された場合のみ、`settings.local.json` を symlink 対象から外す修正を検討する
- **共通制約**: どちらの結論でも `bash -n` 構文検証を通す。修正時は既存のセットアップ挙動（`.claude/skills` / `commands` / `rules` の subdir symlink など）を壊さない

### D5: バージョン bump は plugin.json のみ、marketplace 同期は change-7

- **決定**: 本 change は `plugins/worktree/.claude-plugin/plugin.json` の version を 2.1.1 → 2.2.0 に bump する。marketplace.json の version・description 同期は行わない
- **理由**: 付録 F-6・change-7 の依存関係に従い、marketplace.json の最終同期は全編集プラグイン完了後に change-7 が直列で行う（並列 change 間の同一ファイル競合回避）。plugin.json の bump 自体は各 change の責務（plugin-editing.md 準拠）

## Risks

- **リスク**: ラッパー化で SKILL.md 特定に失敗し command が起動しない（`CLAUDE_PLUGIN_ROOT` 未設定 + 探索フォールバック不備）
  - **緩和**: e.md と同じ多段フォールバック（`${CLAUDE_PLUGIN_ROOT}/skills/...` → `~/.claude/plugins/marketplaces/*/plugins/worktree/skills/...` → `~/.claude/plugins/installed/*/worktree/skills/...`）を実装し、特定した絶対パスを Read する
- **リスク**: command から手順を消す際、frontmatter の `allowed-tools` から必要ツール（特に `AskUserQuestion`）を誤って落とし、破壊操作前の確認質問が出せなくなる
  - **緩和**: frontmatter は既存値を維持する方針を明記し、`allowed-tools` に `AskUserQuestion` が残っていることをテストで検証する
- **リスク**: SKILL.md 本文を「保全」するつもりで誤って触り、squash 検出や絶対禁則の文言を欠落させる
  - **緩和**: 本 change の変更対象から SKILL.md を除外し、テストで検証 A/B/C・絶対禁則の文言が残存することを grep 検証する
