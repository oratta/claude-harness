## Why

アカウントを増やす・止める・再開する操作に、コマンドが無い。追加は「認証情報の置き場所を作る → その環境変数を付けて起動してログインする → 同じシェルで `accounts-init.sh` を実行する」の 3 段階を README を見ながら手で行い、オン・オフは `accounts.json` を手で書き換える。壊れた JSON を書くと、登録簿が読めず既定アカウント 1 つに縮退して気づきにくい（`usage-account-registry` の「レジストリが壊れている」）。忙しい時期だけ 2 つ目の契約を足し、落ち着いたら止める、という使い方に手間がかかる。

## What Changes

- 新しいスクリプト `plugins/dev-workflow/scripts/accounts.sh` を足す。サブコマンドは 4 つ
  - `list`: 各スロットの id・ラベル・オン/オフ・`securestorage` を 1 行ずつ出す
  - `add <id> [--label <label>]`: 認証情報の置き場所（`~/.claude-accounts/<id>`）を作って登録簿に足し、ログインするためのコマンドを 1 行表示する
  - `off <id>` / `on <id>`: そのスロットの `enabled` を `false` / `true` に書き換える。認証情報と登録は消さない
- 書き換える前に、既存の登録簿を `<登録簿>.bak` に控える。壊れた JSON の登録簿は書き換えず exit 1
- 既にある id の `add`、登録簿に無い id の `on` / `off` は exit 2 で、登録簿を変えない
- 既存の `accounts-init.sh` は変えない（「いま居るシェルのアカウントを登録する」手段として残す）
- `plugins/dev-workflow/README.md` と `plugins/statusline/README.md` の「切り替えは当面 `accounts.json` を手で書き換える」を、このコマンドの案内に置き換える

Codex 側のオフ（#978）はこの change に含めない。`enabled` の読み方・自動選択・使用量の取得・描画は変えない（#976 で入った）。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `usage-account-registry`: 登録簿を一覧・追加・オン・オフするコマンドの要件を足す

## Impact

- 新規: `plugins/dev-workflow/scripts/accounts.sh`、`plugins/dev-workflow/tests/accounts-command.bats`
- 変更: `plugins/dev-workflow/tests/account-selector.bats`（このコマンドでオフにしたスロットが自動選択で選ばれないことのテストを 1 件）、`plugins/dev-workflow/README.md`、`plugins/statusline/README.md`、`plugins/dev-workflow/changes/977.md`（新規）
- 戻し方: スクリプトとテストを消し、README を戻す。登録簿の形は変わらない（`enabled` は #976 で入った）ので、このコマンドで書いた登録簿は戻した後もそのまま読める
