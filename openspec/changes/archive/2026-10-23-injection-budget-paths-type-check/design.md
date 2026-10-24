## Context

常時注入の予算テストは bash と awk だけで書かれており、YAML パーサへの依存を持たない。`paths:` を持つファイルは今 0 本で、path スコープの採用自体は同じ要件の「配布形での両方向の実機確認」を経るまで行わない。

## Goals / Non-Goals

**Goals:**

- 効かない `paths:`（`null`・空・リストでない値）を理由に常時注入の合計から外さない
- 行末コメントを glob の一部として読まない
- output-styles を `paths:` で外さない

**Non-Goals:**

- YAML の完全な解釈（引用符内の `#`・複数行のフロー表記・アンカー）。守備範囲の段落に通ることを許す入力として書く
- path スコープの採用そのもの

## Decisions

- YAML パーサ（yq・python）を足さず、awk のまま行末コメントの除去とリスト形の判定だけを足す。理由: CI とローカル（macOS の bash 3.2）で追加の依存を持たないため。代わりに対応しない構文を守備範囲に書く
- 判定を `has_valid_paths` に 1 本化し、`list_always_on_md` と `list_path_scoped_md` の両方から使う。除外と注記で判定がずれないようにするため
- output-styles は `list_always_on_md` を通さず `list_synced_md` で数える。`list_always_on_md` は rules 専用と注記する

## Risks / Trade-offs

- 引用符の中の ` #` を含む glob はコメントとして切られる → 現状そのような glob は無く、出たら glob の検査で違反として見える側に倒れる
