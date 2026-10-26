## Context

背景は proposal.md の Why。直す対象は、`dev-workflow-develop` の spec の本文ではなく、シナリオの題名の表記（SKILL.md から epic.md）と、テストのコメントに書かれた旧要件名。要件の規範は変わらない。

## Goals / Non-Goals

- Goals: epic.md へ移った節を指すシナリオ題名 7 件を epic.md を指す題名にする。bats 2 本のコメントの旧要件名 2 件を改名後の名前にする。`openspec validate --specs --strict` の failed 件数を増やさない（変更前 86）。
- Non-Goals: WHEN/THEN の本文の変更、要件名の変更、SKILL.md に中身が残る節を指す題名の変更、plugins/ の手順書の変更。

## Decisions

- **題名は archive 後の spec を直接直す。** openspec の MODIFIED はシナリオを題名で突き合わせ、題名だけを変えた差分を「現行のシナリオを落としている」として拒否する（検証用 repo で再現済み。#1337 の design.md も同じ制約で題名を据え置いた）。RENAMED は要件名にしか使えない。
- **REMOVED と別名の ADDED にはしない。** 対象は 7 つの要件で、どれも長い（守備範囲の段落を含む）。全文を写すと写し間違いの危険が、題名 7 行の直しという目的に見合わない。要件名も変わり、要件名を参照する他の記述まで直す必要が出る。
- **delta spec を持たない change にする。** `.openspec.yaml` に `skip_specs: true` を足すと、`openspec validate develop-spec-scenario-titles-epic-md --type change --strict` が「valid」で終了コード 0 になる（「skip_specs is set」の INFO が出る）。足さないと「Change must have at least one delta」で失敗する。archive は `openspec archive develop-spec-scenario-titles-epic-md --yes --skip-specs` で行え、`openspec/changes/archive/` に移ることを検証用の複製で確かめた。spec は archive では更新されないので、題名の直しはこの change の実装として spec.md に直接入れる。
- **直す 7 件**（#1241 の delta spec の 89・133・645・667・759・980・1187 行に当たる）: 217・691・1925・1947・2206・2783・3248 行。新しい題名は先頭の「SKILL.md」を「epic.md」にしただけ。
- **直さない 9 件**: 256（モードは SKILL.md の決め方で決まる）・383（SKILL.md が (3a) と (3b) のあいだの計測を指示している）・737（SKILL.md 全体を読む指示が無い）・1341（(3) を細かく切らない理由は SKILL.md にある）・1368（SKILL.md が段の値を書く）・1751（SKILL.md にループの終わりの節がある）・2450（SKILL.md のループの終わりに完了報告の 1 行目が書かれている）・3026（SKILL.md の文面）・3528（SKILL.md を Read で読んだだけの会話は数えない）。どれも中身が今も SKILL.md にある節、または SKILL.md 自体を指す。
- **bats のコメント 2 件**は #1241 で改名した要件名に合わせる（`epic-dispatch.bats:5096`・`develop-skill.bats:1159`）。コメントだけでテスト本体は変えない。

## Risks / Trade-offs

- 今後この 7 要件を MODIFIED で書く change は新しい題名を写す必要がある。題名が違えば validate が拒否するので気づける。
- bats 2 本は手元に bats が無く未実行。変更はコメントだけで、CI で確かめる。
- spec の直接編集は change の delta を経ないので、差分の確認は PR の diff（題名 7 行）で行う。
