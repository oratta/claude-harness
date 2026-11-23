# Proposal

## Why

PR #1703 は補足後も照合表の書式違反と新規ファイルのハンク被覆漏れが残り、review-incomplete になった。厳密な全ヒット照合の保証を維持しながら、投稿前に書式を直せる手順と、補足前に全ハンクの残差を明示する手順が必要である（#1765、親 #1474）。

## What Changes

- レビュアーが投稿する最終の照合表を語ごとに review-hit-set.py へ渡し、exit 0 を確認してから投稿する。抜粋・列名変更・ヒットなしの行・パスのバッククォートを具体的な自己検査対象として示す。
- G は固定 PR diff の全ハンクと被覆行を集合比較し、補足を頼む前に未被覆のファイルと正確なヘッダーを一覧にする。新規ファイルも含め、他区画で被覆したという文章だけでは被覆済みにしない。
- PR #1703 の指定 HEAD と元の表＋補足の表を使い、不正形の検出と、同じ検索・判定を保った書式修正後の再照合を記録する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 投稿前の照合表の自己検査と、補足前の未被覆ハンク一覧を必須にする。

## Impact

- 変更対象: reviewer-brief.md、gate-triage.md、既存の review-hit-set.bats と pr-review-gate-skill.bats、および変更記録。仕様の差分は既存 capability 1 つに閉じる。
- review-hit-set.py の許容形式・照合ロジックと、triage.md は変更しない。#1410 とコードの衝突を避け、#1285 と重なる reviewer-brief.md は自己検査の段落だけを変更する。
- 区画レビュアーの読む範囲・トークン消費（#1692）、補足回数、terminal Status、マージ権限は変更しない。
- 分割判定: 単一 change。受け入れ条件は 3 件で同じ照合契約に閉じ、独立した設計判断は厳密な契約を維持して投稿前に修正する選択 1 つ。被覆の残差一覧は既存の機械照合・補足手順の具体化であり独立した capability ではない。
