## Why

ステータスラインの左端の名前は、Claude のアカウントが `A` `B`、Codex が `Codex` と出ていて付け方が揃っていない。`A` だけでは Claude のアカウントだと分からず、Claude の行と Codex の行を見分けにくい。名前を `Claude A` `Claude B` `Codex A` のように「どのサービスの・どのアカウントか」で揃える。親エピック genetta-inc/flatmate#1656 の子で、ダッシュボード側の同じ名前への変更は別 issue（このリポジトリの範囲外）。

## What Changes

- Claude のスロットの行頭の名前を `Claude <登録簿の label>` にする
- Codex の行頭の名前を `Codex <label>` にする。`<label>` は `accounts.json` のトップレベル `codex.label`（無い・不正なら `A`）
- 長い名前はアカウント名の部分だけを表示幅 8 で切り、サービス名は残す。名前の列の幅は表示される名前の最大幅で揃える
- スロットが 1 つ以下で Codex の行が無いときの出力は 1 バイトも変えない
- 範囲外: Codex オフの行を消す（#1112）、リセット権（#1115）。Codex の行の有無・取得・オフの扱いは変えない
- 既存テストのうち `  Codex  off` のように Codex の名前を直接書いているもの（`statusline.bats`、`test_codex.py`）は、新しい名前に合わせて期待値を直す（オフの行そのものの扱いは変えない）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `statusline-multi-account-usage`: 行頭の名前を「サービス名 + アカウント名」にする。切り詰めはアカウント名の部分だけ。Codex の行の名前の要件を足す
- `usage-account-registry`: トップレベル `codex.label`（Codex の表示名）の読み方を足す

## Impact

- `plugins/statusline/scripts/statusline.sh`（登録簿を読む Python 片、label 列の幅、Codex の行の組み立て）
- `plugins/statusline/README.md`（表示例とフィールド表に `codex.label`）
- `plugins/statusline/tests/`（bats と pytest）
- 登録簿の `schema` は `1` のまま（未知のキーは古い読み手が読み飛ばす）
