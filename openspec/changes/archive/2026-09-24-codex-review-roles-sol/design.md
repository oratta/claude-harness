## Context

組み込み role table（`plugins/dev-workflow/references/codex-role-profiles.json`）は、Codex がレビューする 3 つの profile でレビュー 3 役と decider をすべて `astra`/`high` にしている。model は系統名で書かれ、Codex worker が委譲の直前に model/list から最新版の ID（現在は `gpt-6-astra` / `gpt-6-sol`）に解決する。Codex の週次枠の消費が速く、自動選択が Codex を避ける（claude-default に倒れる）場面が増えている（issue #474 の develop 開始時点で Codex margin -11.57）。

## Goals / Non-Goals

**Goals:**
- 3 profile のレビュー 3 役の単価を下げ、Codex 枠の消費を減らす
- 変更後の解決結果を spec のシナリオとテストで固定する

**Non-Goals:**
- effort の変更（high のまま）
- `decider` のモデル変更（`astra` のまま）
- `hybrid-standard` の変更（レビュー役は Claude で、Astra を使っていない）
- 外部 profile-file・旧形式 `--model` の扱いの変更
- Sol と Astra のレビュー品質の比較計測（マージ後 1 週間の Codex 消費の変化だけを issue に 1 行残す）

## Decisions

### レビュー 3 役を `sol`、decider は `astra` に残す

案は 3 つあった。

| 案 | 内容 | 採否 |
|---|---|---|
| A | レビュー 3 役と decider をすべて `sol` にする | 不採用。decider は修正方針・マージ可否など判断が一点に集中する役で、呼ばれる回数が少ない。単価を下げても消費への効きが小さく、判断の質を落とす側だけが残る |
| B | レビュー 3 役を `sol`、decider を `astra` に残す | 採用 |
| C | レビュー 3 役を `sol` にし、effort を `xhigh` に上げて見落としを補う | 不採用。effort を上げる推奨は公式ではなく個人ブログ由来で、トークン消費が増えて単価差を打ち消す可能性がある |

レビューは 1 件の PR で複数回（仕様レビュー・実装レビュー・PR ゲート）呼ばれ、呼ばれる回数が最も多い高単価の役である。ここを Astra の 1/5 の単価の Sol に替えるのが消費への効きが最も大きい。Claude がオーケストレーターを担う構成では、Astra の強み（長い自律的な多段作業）はオーケストレーター側と重なり、単発のレビューには中位モデルで足りるとされる（2026-09-24 時点の OpenAI 公式の Model guidance）。

### 系統名のまま書く

`gpt-6-sol` のような完全 ID ではなく系統名 `sol` で書く。既存要件「組み込み profile の Codex entry の model は系統名で書く」に従い、世代が上がったときに自動で最新版へ解決させるため。

## Risks / Trade-offs

- [Sol のレビューが Astra より見落としを増やす可能性がある。比較データは無い] → issue #474 で受け入れ済みのリスク。Claude 側の R1（仕様レビュー）と pr-review-gate のレビュアーの二重レビューで補う。見落としが目立てば、この表の 3 役を `astra` に戻すだけで元に戻せる
- [消費削減の効果が想定より小さい] → マージ後 1 週間の Codex 消費の変化を issue #474 にコメントで 1 行残し、効果を確かめる（Codex 消費コメントの仕組みを使う）

## Migration Plan

1 PR で role table・テスト・変更記録・この change の archive（main spec への反映）をまとめて入れる。既存 run は init 時に解決済み設定と版を固定している（要件「解決済み設定と版を init で固定する」）ので、進行中の run のレビュー役は途中で変わらない。戻すときは PR を revert する。
