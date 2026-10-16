## 1. 手順書と仕様の文言を広げる

- [x] 1.1 SKILL.md 手順 6 末尾の「`--watch-done` 付きの `wait` が stdout に何も出さず exit 1 で終わった」を「`--watch-done` か `--watch-stopped` を付けた `wait` が…」に直す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:432-432（手順 6 の末尾 1 文）
- [x] 1.2 `openspec/specs/dev-workflow-develop/spec.md` の同じ文（要件「Orca 経路の本体は印が付いた子のワークスペースを片付ける」）を直し、シナリオを 1 件足す。触る範囲: openspec/specs/dev-workflow-develop/spec.md:1719-1719
- [x] 1.3 bats に、手順 6 の文が `--watch-done` と `--watch-stopped` の両方を挙げていることを確かめる検査を足す。既存の 2067 行目の検査（`--watch-done` を含む行に「親ワークツリーで開き直す」があるか）は、手順 6 に `--watch-done` が別の箇所にも出るため、新しい文言が無くても通る。足す検査は、`stdout に何も出さず exit 1` を含む行が `` `--watch-done` か `--watch-stopped` を付けた `wait` `` と「親ワークツリーで開き直す」を含むことを `grep -F` で確かめる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:2055-2068（テスト「skill: Orca route watches for done marks and reaps marked children」の末尾に1行足す。既存の行は残す）
- [x] 1.4 `bats plugins/dev-workflow/tests/epic-dispatch.bats` を通す（1.1 より前に1.3 の検査だけが落ちることも確かめる）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats（実行のみ）
