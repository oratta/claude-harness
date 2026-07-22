## Context

issue #36。前提となる構造は issue #26 の実行戦略ハーネス:

- 4象限判定表（solo / delegate+verify / workflow 型 × 残量モード）は `github-issue` スキルの Step B/C でのみ発火する
- issue #26 の design は「自動で発火する入口分類（専用サブエージェント）」を逆相関・固定コストを理由に却下している
- 結果、issue を経由しないタスクは判定系に一度も乗らない配線ギャップが残っていた

`/work-issue` は人間が明示的に叩く command であり、これを入口ルーターに拡張しても「自動分類」には該当しない（ユーザー自身がルーティングの意思表示をしている）。

## Goals / Non-Goals

**Goals:**

- issue 未起票の依頼を `/work-issue` 一本で「起票 → 標準パイプライン」に乗せる（純粋拡張。既存分岐の挙動は不変）
- すべての `/work-issue` 経由タスクが Step B/C の実行戦略判定を必ず通過するようにする

**Non-Goals:**

- 自動の入口分類・UserPromptSubmit hook での毎依頼チェック（issue #34 の別アプローチ。競合しない）
- `loops-issueify` 本体の変更（読み込んで使うだけ）
- `github-issue` SKILL.md の変更（issue 番号確定後の挙動は従来どおり）

## Decisions

1. **issueify はクロスプラグイン path-discovery + インライン実行**。work-issue が github-issue/SKILL.md を解決するのと同一のパターン（CLAUDE_PLUGIN_ROOT → marketplaces → installed）で `loops-issueify/SKILL.md` を探して Read する。Skill tool は使わない（command 起動済みのコンテキストで二重にスキル化しない、という work-issue 既存方針の踏襲）。代替案「issueify の手順を work-issue に複製」は正本の二重管理になるため却下。

2. **loops 未導入時は fail-soft**。SKILL.md が見つからなければ、最小手順（概要・触るファイル・測定可能な受け入れ条件のドラフト → 承認 → `gh issue create`)にフォールバックし、コマンドを死なせない。dev-workflow → loops はソフト依存（実行時 Read のみ）に留める。

3. **番号不存在は typo 確認を先行**。番号を打った人の意図は高確率で既存 issue 参照であり、無言で新規起票すると意図しない issue が生える。近い番号の提示 → 明示的な希望があった場合のみ起票フローへ。

4. **複数分割時は「全起票 → 着手1件選択」**。issueify の原子化を尊重しつつ、interactive の「その場で1つずつ」と衝突しないよう、実行に渡すのは選択された1件だけにする。残りは通常の open issue として次回の `/work-issue` や loop-dev-agent が拾う。

5. **承認ゲートは維持**。loops-issueify の「ユーザーの確認なしに起票しない」不変条件を fail-soft 経路にも適用する。

## Risks / Trade-offs

- [コマンド定義（md）は実行コードではないため bats で挙動そのものは検証できない] → 受け入れ条件を「構造の存在検証」（5分岐・fail-soft・承認ゲートの記述が grep で確認できる）に置き、挙動の担保は本 change 自体のドッグフーディング（issue #36 を新フローで処理）で行う
- [loops-issueify の SKILL.md 改訂で前提が変わる] → ソフト依存（実行時 Read）なので work-issue 側の追随は不要。承認ゲート等の不変条件が消えた場合のみ見直す
- [work-issue.md の肥大化で command の可読性が落ちる] → フォールバック節は分岐表 + 手順数行に抑え、正本（issueify の詳細手順）は Read 先に残す

## Open Questions

（なし）
