## Context

#1269 の実測（openspec 1.14.1、テストと同じ構成: `openspec/specs/demo/spec.md` と、`.openspec.yaml` と `specs/demo/spec.md` だけの change `wording-demo`）。

| コマンド | 結果 |
|---|---|
| `openspec validate wording-demo --strict` | `Change 'wording-demo' is valid`・終了コード 0 |
| `openspec validate wording-demo --type change --strict` | 同上 |
| `openspec validate nosuch --strict` | `Unknown item 'nosuch'. Did you mean: ...`・終了コード 1 |
| `openspec validate --changes --strict` | `✓ change/wording-demo`・終了コード 0（検査している） |

古い版では最初の行が `Unknown item`・終了コード 1 だった（`spec-wording-sync-light-path` の実測。今の指示書とテストが前提にしている）。

## Decisions

### D1: `--type change` を付ける指示は残し、理由と結果の断定を直す

付けても付けなくても 1.14.1 では結果が同じだが、古い版では付けないと失敗し、spec と change が同名のときは名前だけでは曖昧になる。付ける指示は版を問わず害がないので MUST のまま残す（採用）。代案「指示を外す」は古い版で W が止まるので採らない。

### D2: 版で変わる挙動を、指示書では「版による」と書き、テストでは許容する

指示書に「1.14.1 では」と版番号を書くと次の版でまた古くなる。「付けない形の結果は版で変わる（`Unknown item` で終了コード 1 になる版も、change として検証して終了コード 0 になる版もある）」と書く（採用）。テストは必須の assertion を「付けた形が終了コード 0」に絞り、付けない形は 2 つの結果のどちらでも通す。実測テストが版の差で落ちる状態を、CLI のある環境で再発させないため。

### D3: `--changes --strict` は「使わない」の理由を版による、に変える

1.14.1 は検査するが、古い版は検査せずに 0 を返した（Requirement の旧文）。W には「使わず、名前を指定して `--type change` を付ける」と指示すれば足りるので、検査の有無は断定しない。
