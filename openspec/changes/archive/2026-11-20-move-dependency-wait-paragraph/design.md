# Design

## Context

動機は proposal.md を参照。基準 HEAD は `f4ffa2591aacd02a92d66dc8c4fe64d3b02b6b1c`。対象段落はこの HEAD で直接移動済みだったが、「仕様化しない」と main spec の差分が併存しゲートで止まった。本工程では移動後の要件全文を delta に保存し、main spec を移動前へ戻す。方針は #1725 の本体の決定（issuecomment-7032399466）と同種の PR #1719 に従う。

## Goals / Non-Goals

**Goals:** archive 後、対象段落が同じ要件の `text` に1回現れ、全シナリオの `rawText` には現れないこと。規則やシナリオの脱落なしに change として記録すること。

**Non-Goals:** 依存待ちの分類、再起動、`clear` の優先規則の内容や実装、検査のアルゴリズム、他の要件、過去の archive は変更しない。

## Decisions

1. **段落全体を同じ要件の最初の Scenario の直前へ移す。** 本体が決めた位置と文言をそのまま使う。要件の分割やシナリオへの書き換えは行わず、要件名・他の本文・全5シナリオを保持した MODIFIED delta を archive する。
2. **直接編集を戻し、R1 承認後に archive で反映する。** 「仕様化しない」のまま直接編集を残す案はゲートの整合条件を満たさない。issue 本文には文言合わせに必要な直す文の指定が揃っていないため、artifact 一式と独立した R1 レビューを使う。本工程で archive は実行しない。
3. **既に追加された一般検査を回帰検査に使う。** `tests/openspec-specs-format.bats:18-61` は対象段落を特別扱いせず、最初の Scenario 後の MUST/SHALL を検出する。main spec を戻した時点の1件失敗を確認し、archive 後は全8テストの成功と CLI 上の帰属を確認する。検査の除外条件を緩めて通す案は issue の目的に反する。

## Risks / Trade-offs

- [MODIFIED delta の部分引用で既存の内容が消える] → 移動済み HEAD の対象要件全文を使い、archive 後の spec がその HEAD と同一であることを照合する。
- [仕様レビュー待ちの間は配置検査が失敗する] → 戻した段落1件による想定内の失敗として報告し、apply 段の archive 後に再実行する。成功済みとは記録しない。
- [archive の際に無関係な差分が入る] → main spec の差分が対象段落と空行の移動だけであることを確認する。

## Migration Plan

本工程は仕様作成と直接編集の取り消しまで。R1 の APPROVE 後、apply 段で delta を archive により反映し、配置検査・CLI の要件本文への帰属・lint・全体テストを検証する。戻す場合は本 change の段落移動を戻す。その場合は配置検査が再び失敗するため、テストを弱めず未解消として扱う。
