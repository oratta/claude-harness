# Design

## Context

動機は proposal.md を参照。基準 HEAD は `d188693f771cb72d149946b5ebce971e1b8769b5`。#1696 の調査・分割記録で、対象は `dev-workflow-memory-refresh/spec.md:87` の `patches:` による分類の守備範囲の 1 段落と確定している。現状は「控えが取れなければ適用しない」シナリオの `rawText` に入る。配置の回帰検査は #1695 の `tests/openspec-specs-format.bats:85-155` を使える。

## Goals / Non-Goals

**Goals:** 守備範囲の段落を同じ要件の `text` に 1 回だけ含め、全シナリオの `rawText` から除く。既存要件を全文保持して delta を適用できるようにする。

**Non-Goals:** 分類の基準、承認・控え・整理の実行手順、メモリやキャッシュ、hook、CLI は変えない。要件名・シナリオ・他の規則文・過去の archive delta も変更しない。

## Decisions

1. **段落全体を同じ要件の最初の Scenario の直前へ移す。** #1696 の判断記録どおり、`patches:` の守備範囲の全文と必要な段落区切りを保持する。規則の重複記載はシナリオへの混入を残し、新しい要件への分離は既存の要件名・構成を変えるため採らない。
2. **#1695 のケース表に 1 ケースを追加する。** Bats 内の Python が要件を切り出し、最初の `#### Scenario:` より前に対象段落の全文が 1 回、後ろには 0 回であることを検査する。前の change の 2 ケースを保持し、CLI の無い CI でも動く形にする。実装時は `openspec show dev-workflow-memory-refresh --type spec --json` の `text` / 全シナリオの `rawText` でも照合する。
3. **2 change が揃ったところで全 spec を再走査する。** 前任の機械的な調査と同じく、`openspec/specs/*/spec.md` の全 capability を CLI で読み、全シナリオの `rawText` を空行区切りで調べる。コードフェンス内と GIVEN / WHEN / THEN / AND / BUT 行およびその折り返しを除き、単語境界付き MUST / SHALL を持つ規則段落が 0 件であることを確かめる。説明段落や archive は対象にしない。新しい対象が見つかったら範囲を広げず本体へ報告する。

## Risks / Trade-offs

- [MODIFIED delta から既存シナリオが落ちる] → 元の要件全文をコピーし、対象段落を除けば同じ内容であることを照合する。
- [CLI に依存するテストは CI の環境で動かない] → Bats は #1695 の Markdown 境界検査を再利用し、CLI の実測は実装時の確認にする。
- [再走査の誤検出で対象外の文を動かす] → #1696 に記録済みの抽出条件を守り、対象が増えた場合は本体へ戻す。

## Migration Plan

本体が R1 の承認を確認した後、1 番目の change に続けて本 change のテストを追加し、移動前に失敗することを確かめてから段落を移す。全 spec 再走査と全体検証を実施する。戻す場合は本 change の段落移動とテストの 1 ケースを対で revert し、前の change の 2 ケースを残す。
