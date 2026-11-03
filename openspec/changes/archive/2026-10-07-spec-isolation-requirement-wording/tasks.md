## 1. 要件の最初の文を直す

- [x] 1.1 `openspec/specs/skill-execution-isolation/spec.md` の要件「スキルは隔離されたコンテキストで実行する」の最初の文を、proposal の文に置き換える。触る範囲: openspec/specs/skill-execution-isolation/spec.md:16-16
- [x] 1.2 archive 側 delta spec の同じ文を同じ文にする。触る範囲: openspec/changes/archive/2026-10-07-wt-setup-fork-frontmatter-decision/specs/skill-execution-isolation/spec.md:5-5

## 2. 検証

- [x] 2.1 `openspec validate --specs --strict` と `bats tests/openspec-specs-format.bats` が exit 0 で、2 ファイルの該当文が一致する。触る範囲: openspec/specs/skill-execution-isolation/spec.md:16-16
