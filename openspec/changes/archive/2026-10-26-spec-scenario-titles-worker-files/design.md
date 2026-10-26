## Context

背景は proposal.md の Why。直す対象は spec の本文ではなく、シナリオ題名の表記（索引 `worker.md` から移し先のファイル）。要件の規範は変わらない。

## Goals / Non-Goals

- Goals: 移し先へ移った内容を指すシナリオ題名 10 件を、移し先のファイル名にする。`openspec validate --specs --strict` の failed 件数を増やさない（変更前 86 failed / 7 passed）。
- Non-Goals: WHEN/THEN の本文の変更、要件名の変更、plugins/ の手順書とテストの変更。

## Decisions

- **題名は archive 後の spec を直接直す。** openspec の MODIFIED はシナリオを題名で突き合わせ、題名だけの変更を拒否する。RENAMED は要件名にしか使えない。別名 ADDED + 旧名 REMOVED は要件の全文を写す危険が、題名 10 行の直しに見合わない。#1335（PR #1365）と同じ型。
- **delta spec を持たない change にする。** `.openspec.yaml` に `skip_specs: true` を足し、`openspec archive spec-scenario-titles-worker-files --yes --skip-specs` で archive する。題名の直しはこの change の実装として spec.md に直接入れる。
- **直す 10 件と新しい題名**（行は変更前の値）:
  - develop 125: 「worker/ の 4 本と pre-classification.md に記録書式と事前分類表がある」（WHEN が `worker/` の 4 本と `references/pre-classification.md` を読む。事前分類表は後者にある）
  - develop 354: 「worker/implement.md と worker/finish.md が (3a) / (3b) の return 内容を列挙している」
  - develop 379: 「worker/common.md の工程名が 3 つになっている」
  - develop 1029: 「worker/ の 4 本が CLI の経路で書かれている」（WHEN は索引 worker.md も読むが、検査対象の中身は 4 本）
  - develop 1230: 「worker/common.md の手渡しの節に欄と書式がある」
  - pr-review-gate 755・760・765: 先頭の「worker.md」を「worker/implement.md」にする
  - spec-review 11: 「worker/spec.md に記録手順と正規表現がある」
  - spec-review 32: 「worker/spec.md の仕様化する場合の節と worker/common.md の実装に入る前の確認にレビューがある」
- **索引の worker.md を指す題名は残す方針だったが、該当は 0 件。** 10 件とも移し先の内容を指す。

## Risks / Trade-offs

- 今後この要件を MODIFIED で書く change は新しい題名を写す必要がある。題名が違えば validate が拒否するので気づける。
- spec の直接編集は delta を経ないので、差分の確認は PR の diff（題名 10 行）で行う。
