## 決定

- 実行側の原因は常に `request --phase implement --failure executor`。ゲートは 1 回目の failed から原因側を上げる設計（2 周キャップ内で収束させるため）で、これは変えない
- 判断側の原因は、そのゲートの 1 回目の failed なら `--failure first`（決める役が上位の格）、決める役を立てたあとも failed が続く 2 回目以降なら `--failure judgment`（最上位の格）。旧文の「決める役は `opus` から始めて `fable` に上げる」と同じ段の踏み方になる。`judgment` から入ると 1 回目から最上位の格になり、旧文より強くなるので採らない
- 返った model を使い、独自の model を指定しない。model が変わるなら新しい thread に手渡す（develop SKILL.md「モデル」節と同じ）
- Claude での値は括弧書きの例に留める（本文の規則にしない）
- `--failure` の値の意味（`codex-develop.py` と `templates/escalation-tripwires.md`）は変えない
