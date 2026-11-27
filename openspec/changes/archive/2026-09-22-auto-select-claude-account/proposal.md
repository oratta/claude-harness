## Why

Claude の複数アカウントについて使用量は既に観測できるが、起動時にどのアカウントを使うかは人が statusline を見て選んでいる。週の進行に対して枠が最も余っている利用可能なアカウントを決定論的に選び、`cld` から使えるようにして、この手作業をなくす。

## What Changes

- `accounts.json` と usage snapshot から、週経過率と週次消化率の差が最大のスロットを選ぶ起動時セレクタを追加する。
- 古い・欠測した値と 5 時間枠が逼迫したスロットを候補から除外し、候補が無いときは既定アカウントへ縮退する。
- 明示したスロット id を snapshot に依存せず選べるようにする。
- shell が取り込む `securestorage` 値と、人が読む選択理由の出力契約を定める。
- 自動選択を使う `cld` と明示選択を使う shell function の設定例を README に追加する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `usage-account-registry`: レジストリに登録されたスロットから起動アカウントを選ぶ規則、縮退、明示指定、出力契約を追加する。

## Impact

- `plugins/dev-workflow/scripts/` に選択スクリプトを追加する。
- `plugins/dev-workflow/tests/` に選択規則と出力契約の bats テストを追加する。
- `plugins/dev-workflow/README.md` に shell function の設定例と運用手順を追加する。
- `openspec/specs/usage-account-registry/spec.md` の要件を拡張する。
- 外部依存は追加せず、既存の `accounts.json` と `~/.claude/.usage-snapshot` を利用する。
