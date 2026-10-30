## 1. spec

- [x] 1.1 Purpose に、develop の本体も G に渡す前に先に回すことを足す
- [x] 1.2 守備範囲①の補足（呼び出し元）の段落を足す（既存の守備範囲の段落と Scenario は変えない）

## 2. 確認

- [x] 2.1 `openspec validate --specs --strict` と `tests/openspec-specs-format.bats` が通る
- [x] 2.2 `git diff origin/main -- openspec/specs` に MUST・SHALL・Scenario を含む行の増減が無い
