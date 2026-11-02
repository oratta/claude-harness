## Why

pr-review-gate 手順 3-c（前の HEAD の許容の引き継ぎ）は、main の取り込みで衝突を解いたファイルが許可リスト（`marketplace.json` / `plugin.json` の版の行・`CHANGELOG.md`）の外にあると、リスク宣言の本文も根拠ファイルも変わっていなくても引き継げない。genetta-inc/flatmate PR #1388 では衝突解消が `openspec/specs/client-package/spec.md` に及んだだけで `risk-carryover-check.sh` が exit 1 を返し、主は同じリスクに 3 回「許容」と答えることになった（issue #694）。合格処理の G が 3-c を試す時点では新しい HEAD で取り直しのレビューが行われているので、そのレビューが衝突解消の中身を見ていれば、許可リストによる制限は二重になっている。エピック #725（許容の確認で主の手が止まる回数を減らす）の一部。

## What Changes

- `risk-carryover-check.sh` は、許可リストの条件（ファイル名と中身の条件）を満たさない衝突解消を `NG:` にせず、ファイルごとに `RESOLVED_OUTSIDE_ALLOWLIST=<ファイル>` の行で出す。終了コードを 0 = 無条件で引き継げる / 3 = 新しい HEAD を取り直しのレビューが全体で見ていれば引き継げる / 1 = 引き継げない / 2 = 引数・環境の不備、に分ける。`CARRYOVER=` の値に `if-rereviewed` を足す。`NG:` が 1 行でもあれば従来どおり 1（根拠ファイルの diff・main 以外の commit・履歴の書き換えなど）
- **BREAKING**（G の読み方）: 許可リスト外の衝突解消は終了コード 1 ではなく 3 になる。終了コード 3 を「引き継げない」と読む古い 3-c の文面とは組み合わせない（同じ PR で 3-c も直す）
- `risk-carryover-check.sh` は、根拠ファイルが前後どちらの HEAD にも無いと終了コード 2 を返し（#478）、pathspec をリポジトリのルート相対に固定する（#478）。衝突解消ファイルの列挙は `git diff --no-renames` で行う（#480）
- `pr-review-gate/stages/hold.md` 3-c の条件 1 を「終了コード 0、または終了コード 3 で、新しい HEAD を固定 HEAD にした取り直しのレビューが PR 全体を見た周である」に直し、引き継ぎの根拠行の書式に終了コードと取り直しのレビューの固定 HEAD・その `レビュー重量:` コメントのリンクを書く欄を足す。3-c 以外の節は変えない（兄弟 #721 が hold.md の別の節を触るため）

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-review-gate`: Requirement「前の HEAD の許容を新しい HEAD に引き継いでよい条件」（条件①と守備範囲）、「risk-carryover-check.sh が差分の範囲と根拠ファイルの無変更を判定する」（終了コード・出力・列挙・根拠ファイルの存在確認）、引き継いだ宣言の書式を定める Requirement（引き継ぎの根拠行）を変える

## Impact

- `plugins/dev-workflow/scripts/risk-carryover-check.sh`
- `plugins/dev-workflow/tests/risk-carryover-check.bats`（既存の「許可リスト外 → exit 1」系 5 件を exit 3 に直し、新しいケースを足す）
- `plugins/dev-workflow/skills/pr-review-gate/stages/hold.md`（3-c だけ）
- `plugins/dev-workflow/tests/pr-review-gate-skill.bats`（3-c の追記 4 行の書式検査が `終了コード 0 — ` 固定で書かれている）
- `plugins/dev-workflow/changes/694.md`（変更の記録）
- `develop/references/roles/gate-runner.md` は 3-c を正本として参照するだけなので変えない見込み（実装時に確認）
- 引き継ぎの行を機械で読むワークフロー・スクリプトは無い（auto-merge が照合するのは `対象 HEAD:` と `主のリスク許容が必要。` の行で、引き継ぎの 4 行は G と pass.md の表が読む）
- 関連 issue: #694（本体）、#478・#480（同じスクリプトの follow-up。同じ PR で閉じる）
