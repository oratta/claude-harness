## Context

実機確認（2026-10-07、Claude Code 2.1.292、scratchpad の使い捨てリポジトリ。wt-setup と同じ構成の probe プラグイン: `commands/foo.md` と `skills/foo/SKILL.md`（`context: fork` / `background: false`）、対照として同名ラッパーの無い `skills/bar/SKILL.md`）:

| 呼び方 | 同名ラッパーあり（foo） | ラッパー無し（bar） |
| --- | --- | --- |
| `/probe:foo`、`/foo` | commands 側の本文が実行された | （bar）スキル本文が実行された |
| Skill ツール `probe:foo` / `probe:bar` | commands 側の本文が返った。fork の表示なし | `completed (forked execution)` と出て fork で実行された |

公式ドキュメント（https://code.claude.com/docs/en/skills）の「Resolve skills that share a name」表は「skill と `.claude/commands/` のファイルでは skill が勝つ」とするが、プラグインの `commands/` と `skills/` が同名の場合は実機では commands が勝った。ドキュメントはこの組み合わせを明示していない。

## Decisions

### D1: frontmatter は残す（外さない）

- 残す理由: (a) 既存要件（`skill-execution-isolation`）が `context: fork` を SHALL にしており、外すと要件と bats（#707）を同時に変える必要がある (b) ラッパーを将来外す・名前を変える・別経路（`claude -p` 以外の呼び出し）が生じたとき、fork と完了待ちの指定が最初から効く (c) 残すコストは frontmatter 3 行とコメントのみ
- 外す案: 効かない設定の保守が無くなるが、要件・テスト・設計履歴（`archive/2026-04-10-wt-setup-model-and-fork`）の改訂が要り、ラッパーを外したときに隔離を失う
- 受け入れるもの: 現行経路で `background: false` の効果は実機で確かめられない。静的な保険である旨をコメントに明記して扱う

### D2: 理由の置き場

frontmatter 内の YAML コメント（`sed -n '1,12p'` に収まる）。bats は `^context: fork$` / `^background: false$` の行 grep なので、コメント行を足しても通る。

## Risks / Trade-offs

- Claude Code の将来版でラッパーとスキルの解決順が変わると、いま効かない fork が突然効く。その場合 `$ARGUMENTS` の後続作業が fork 内で実行される（Step 6）。ただし `background: false` により完了は待つ。
