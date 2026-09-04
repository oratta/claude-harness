# statusline-active-account-marker — active アカウントの行に目印を付ける

## Why

複数アカウントのレートリミット表示が動くようになった結果、statusline に 2 スロットが並ぶようになったが、**どちらが今のセッションのアカウントかを示す目印が無い**。

現在の描画:

```
A  5h      ▓▓▓▓░░░░░░░░░░░░  29%   ~2h 47m
A  7d All  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░  93%/90%   Fable ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░  94%/90%  ~15h 47m
B  5h      ░░░░░░░░░░░░░░░░   0%   ~3h 47m
B  7d All  ░░░░░░░░░░░░░░░░   0%/4%   ~6d 16h  0m前
```

区別できる材料は非 active 行の行末に付く経過時間（`0m前`）だけで、目印としては弱い。この表示はそもそも「snapshot の鮮度」を表すために置いたもので、「どちらが active か」を示す目的では設計されていない。両スロットの snapshot がほぼ同時刻に更新されると差がほとんど見えなくなるうえ、経過時間から active を推測させるのは読み手に余計な推論を強いる。

statusline は「今のペースでリセットまで持つか」を一目で判断するための表示であり、その判断は**どちらのアカウントの数字を見ているか**が分かって初めて成立する。

## What Changes

- **active スロットの行に目印を足す**: label の前に `▸ ` を置き、label を `DIM` ではなく通常の明るさで描く
- **非 active スロットの行**: label の前に半角スペース 2 つを置き、label は現行どおり `DIM`
- 目印の列は全行に等しく 2 桁足すので、バーの左端は揃ったまま

```
▸ A  5h      ▓▓▓▓░░░░░░░░░░░░  29%   ~2h 47m
▸ A  7d All  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░  93%/90%   Fable ...
  B  5h      ░░░░░░░░░░░░░░░░   0%   ~3h 47m
  B  7d All  ░░░░░░░░░░░░░░░░   0%/4%   ~6d 16h  0m前
```

- **スロットが 1 つ（レジストリ不在を含む）のときは目印を出さない**。出力は現行と 1 バイトも変わらない
- active スロットの判定は既存の規則（`usage-account-registry` の「active スロットの判定規則」: env → snapshot の `active` → 先頭）をそのまま使い、判定そのものは変えない

## Capabilities

### Modified Capabilities

- `statusline-multi-account-usage`: active スロットを視覚的に示す Requirement を追加し、行の左端の構成（目印の列 + label 列）と目標レイアウトを規定している既存 Requirement を改訂する。

## Impact

- **コード**: `plugins/statusline/scripts/statusline.sh` の `prefix` を組み立てている箇所のみ。バー描画（`bar_seg` / `bar2`）・active 判定（`active_idx`）・snapshot 読み取りには触れない。
- **テスト**: `plugins/statusline/tests/statusline-multi-account.bats` に目印のケースを追加。1 スロット時の退行ガード 2 本（`git show origin/main:...` との実出力 diff）は無改変で通り続ける必要がある。
- **docs**: `plugins/statusline/README.md` の複数アカウント表示のサンプルと読み方。
- **バージョン**: `plugins/statusline/.claude-plugin/plugin.json` とルートの `.claude-plugin/marketplace.json` を同時更新（`plugins/` 配下の変更はテストであってもバージョン同期ガード S131 の対象）。
- **対象外**: `usage-probe.sh` と snapshot のスキーマ。active 判定規則そのもの。
