# openspec-dedup-resolution Specification

## Purpose
TBD - created by archiving change repo-cleanup-final. Update Purpose after archive.
## Requirements
### Requirement: OpenSpec 4 系統重複の生成元を調査し結論を decisions.md に記録する

本 change は、リポジトリ内に存在する OpenSpec スキル 4 系統（`.claude/skills/openspec-*` ×10 / `.claude/commands/opsx/*.md` ×10 / `.agents/skills/openspec-*` ×10 / `.agents/skills/source-command-opsx-*` ×10、計 40 ファイル）が openspec CLI（`openspec init --tools claude`）の生成物か手動管理かを調査し、その結論・根拠・採用した解決分岐を `openspec/changes/repo-cleanup-final/decisions.md` に記録しなければならない（MUST）。調査は削除等の破壊的操作より先に行う（MUST）。

#### Scenario: 生成元調査の実施と根拠の記録

- **WHEN** builder が OpenSpec 4 系統の生成元調査を行う
- **THEN** `.claude/skills/openspec-*/SKILL.md` の frontmatter に `author: openspec` / `generatedBy` / `compatibility: Requires openspec CLI` の CLI 生成マーカーが存在するか、`.agents/skills/source-command-opsx-*` に「migrated source command」表記が存在するか、`openspec` CLI（`which openspec` / `openspec --version`）が解決可能か、を確認し、確認結果を `decisions.md` に file 単位の根拠付きで記録しなければならない

#### Scenario: 調査結論が decisions.md に文書化される

- **WHEN** 調査が完了する
- **THEN** `openspec/changes/repo-cleanup-final/decisions.md` が存在し、(a) 4 系統が「CLI 管理 / 手動管理 / 判断不能」のいずれと結論づけられたか、(b) 採用した解決分岐（CLI 抑制 / `.claude/` 側残置削除 / 現状維持縮退）とその理由、の両方が記載されていなければならない

### Requirement: 調査結論に応じた三分岐で重複を解決する

調査結論に応じて、次のいずれか 1 つの分岐で重複を解決しなければならない（MUST）。(A) CLI 管理かつ CLI 設定で出力系統を抑制できると確認できた場合は、設定変更で 1 系統に抑制し抑制手順を `decisions.md` に記録する。(B) 手動管理と確認できた場合は `.claude/` 側 1 系統（`.claude/skills/openspec-*` と `.claude/commands/opsx/`）を残して `.agents/skills/openspec-*` と `.agents/skills/source-command-opsx-*` を削除する。(C) CLI 管理の疑いが残り削除しても `openspec update` で再生成されうる等で判断がつかない場合は、削除せず現状維持とし、調査結果と抑制手順を `decisions.md` に記録する縮退に倒す。いずれの削除も git tracked の状態で行い履歴から復元可能でなければならない（MUST）。

#### Scenario: 分岐 A — CLI 抑制が可能な場合

- **WHEN** 調査で 4 系統が CLI 生成物であり、かつ CLI 設定で出力系統を単一化できると確認された
- **THEN** 設定変更により重複が 1 系統に抑制され、その設定変更内容と再現手順が `decisions.md` に記録される

#### Scenario: 分岐 B — 手動管理と確認された場合

- **WHEN** 調査で 4 系統が手動管理（CLI 再生成の対象でない）と確認された
- **THEN** `.claude/skills/openspec-*` と `.claude/commands/opsx/` の 2 系統は残り、`.agents/skills/openspec-*/` と `.agents/skills/source-command-opsx-*/` は git rm により削除され、削除は commit 履歴から復元可能な状態である

#### Scenario: 分岐 C — 判断不能時の現状維持縮退

- **WHEN** CLI 管理の疑いが残り、削除が `openspec update` 等で再生成されて無効化される恐れがある
- **THEN** 4 系統は削除されず現状のまま維持され、`decisions.md` に「現状維持を選んだ理由」と「将来 CLI 設定で抑制するための手順」が記録される

#### Scenario: 削除は常に git tracked で可逆

- **WHEN** いずれかの系統を削除する分岐（A の設定変更に伴う削除を含む）を採る
- **THEN** 削除対象は削除前に git tracked であり、`git rm` 相当で削除され、commit 履歴から復元可能である（untracked ファイルの物理削除は行わない）

