## Why

「委任レベル 0/1/2」のようなプリセットは便利だがプリミティブではない（2026-08-28 主整理、oratta/claude-harness#207）。エージェントが主に問いかける前に見るべきホワイトリストは 2 つしかない — **許可されたツール集合**（Claude Code の permission）と**判断を任された観点集合**（casting の配役表）。casting の返信前チェック 5 手順は観点側の確認を担っているが、ツール側と束ねて「委任」として見せる文書が無く、観点の判断基準（`policies/<slug>.md`）を主とやり取りしながら作る手段も無い（persona-interview の観点版が無い）。#125（PR 時レンズ）・#126（アクション直前ゲート）と flatmate の新住人立ち上げ（flatmate#450）がこの定義を前提にするので、先に 1 ファイルで固める。

## What Changes

- **委任の定義文書を新設**: `plugins/casting/catalog/delegation.md`。委任＝「許可ツール × 任された観点」の 2 プリミティブで定義し、ロール（プリセット）はその上に乗る組み合わせ名と位置づける。「論点＝別の観点を入れると結論が変わるもの。LLM 側が情報を持つものは論点ではなく自分で決める」を明文化する
- **委任宣言の書式を 1 か所に固定**: `## 委任` 見出しの下に「許可ツール」「任された観点」の 2 表を並べる書式を定義し、repo ファイル `.claude/casting/delegation.md`（git 追跡・`/casting:init` が雛形から生成）と起動プロンプトのセッション宣言（第 3 層）の両方で同じ書式を使う。正本はツール側＝Claude Code の permission 設定、観点側＝配役表の 3 層解決であり、宣言ファイルは「両正本の要約を 1 か所に見せる宣言」で、食い違ったら正本が勝つ
- **`/casting:policy-interview <観点>` コマンドを新設**: 1 問ずつ自由回答で聞き、`templates/policy.md` から `.claude/casting/policies/<slug>.md` を生成・更新する。「X の規約を守る」のように主が全文を把握していない前提を書ける節を policy 雛形に追加する
- **返信前チェック手順③の追記**: `rules/perspective-casting.md` の「担い手は主か」に、ツール側の permission も委任宣言の同じ表で確認する旨を 1 文足す（rule は 30 行以内を維持）
- casting プラグインの plugin.json（0.3.0 → 0.4.0）・README・SKILL.md・marketplace.json の説明を更新する

## Capabilities

### New Capabilities
- `casting-delegation`: 委任の定義（許可ツール × 任された観点）、委任宣言の書式と置き場、`/casting:policy-interview` による policy 文書の対話生成

### Modified Capabilities
- `casting-project-files`: `/casting:init` の生成物に `delegation.md` を加える（既存ファイル非上書き・冪等の規則は同じ）
- `casting-injection-map`: 注入文書の雛形に「前提とする外部規約（全文未把握）」の節を加え、policy-interview が生成の入口であることを規約に足す

## Impact

- 追加: `plugins/casting/catalog/delegation.md`、`plugins/casting/commands/policy-interview.md`、`plugins/casting/templates/delegation.md`、`plugins/casting/tests/casting-delegation.bats`
- 変更: `plugins/casting/commands/init.md`（生成スクリプトに delegation.md を追加）、`plugins/casting/templates/policy.md`、`plugins/casting/skills/casting/SKILL.md`、`plugins/casting/catalog/injection.md`、`plugins/casting/README.md`、`plugins/casting/.claude-plugin/plugin.json`、`.claude-plugin/marketplace.json`、`rules/perspective-casting.md`
- 既存の `casting-check.sh` の検査対象（project.md / local.md / precedents.md）は変えない。delegation.md は列構成が違うため別ファイルにし、check の 5 列検査に巻き込まない
- #125 / #126 はこの定義を前提に別 PR で進める（本 change では触らない）
