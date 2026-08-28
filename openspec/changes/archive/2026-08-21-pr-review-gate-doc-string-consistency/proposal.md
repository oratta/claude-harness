## Why

`pr-review-gate` の合格判定は「別コンテキストのレビュー ＋ リスク宣言 ＋ 動作確認の証拠」で成立するため、**同一 PR 内で実装とドキュメント文字列（JSDoc・`--help` の usage・README・エラーメッセージ）が矛盾していても `agent-review:passed` が付く**。auto-merge 配備リポではラベル付与の直後に機械マージが走るので、矛盾に気づいた時点では既に main に入っており、同じ issue に対する 2 本目の PR が必要になる。

実測（genetta-inc/suimei issue #306）: 同一ブランチから PR #308 → #309 が 13 分差で続けて auto-merge された。`git diff 7530e46 9773c05` の実体は **2 行のドキュメント文字列だけ**で、振る舞いの修正は含まない。#308 は「既定を JST の前日に変える」修正でありながら、既定を「JST の今日」と説明する JSDoc と USAGE を 2 か所に残したまま合格・マージされている。コードの正しさは #308 の時点で担保されており、問題は**合格判定が実装と説明文の矛盾を通したこと**にある。

auto-merge 配備リポでは「合格 ＝ 即マージ」なので「あとで直す」が成立しない。合格の時点で完成している必要がある。

## What Changes

- **手順4（動作確認）を 4-1 / 4-2 の2つの確認に分ける**: 4-1 は既存の振る舞いの確認（本文は変更しない）、4-2 に「ドキュメント文字列の整合確認」を新設する
- **4-2 を合格の必須条件にする**: 確認対象を4種（API ドキュメント文字列 / CLI の使い方 / 利用者向け文書 / 実行時に人が読む文字列）に具体化し、変更したシンボル名で当該リポを `git grep` する具体的なコマンド例を置く。「ドキュメントも見る」のような検証不能な書き方にしない
- **証拠を HEAD SHA 付き PR コメントとして残す**: 見出しは `## ドキュメント文字列の整合確認`。既存の fail-closed 実測（HEAD SHA を含むコメントの実在を API で確認する）の対象に、リスク宣言・動作確認と並べて3つ目として加える
- **合格処理（手順5）の前提を更新**: 実測で確認する見出しを2つ（リスク宣言・動作確認）から3つに増やす。1つでも欠けていれば合格処理をしない
- **先送りの禁止を明文化**: 実装と説明文の食い違いは follow-up issue に回さず同じ PR で直す（既存の「マージ後に issue で直せるものは blocking にしない」の例外として位置づける）
- **既存の合格条件は1つも緩めない・削らない**: 6手順の骨格・ラベル体系・別コンテキストレビュー・リスク宣言・fail-closed・収束ルールはすべてそのまま

## Capabilities

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 合格の必須条件にドキュメント文字列の整合確認を追加する（要件の追加のみ。既存要件の変更・削除はしない）

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` — 手順4 の分割と 4-2 の新設、手順5 の実測見出し3点化、「やらないこと」に1行追加、frontmatter version 1.2.0 → 1.3.0
- `plugins/dev-workflow/tests/pr-review-gate-skill.bats` — 4-2 の存在・具体性・既存手順の非削除を検証するテストを追加
- `plugins/dev-workflow/.claude-plugin/plugin.json` — version 1.10.1 → 1.11.0
- `.claude-plugin/marketplace.json` — dev-workflow の version を同期
- **聖域接触**: `plugins/dev-workflow/skills/pr-review-gate/` は auto-merge workflow の SACRED パスに含まれるため、この PR は機械マージされず `human-merge` が付いて主のマージ判断になる
