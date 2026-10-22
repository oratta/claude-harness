## Why

オーナーの環境では公開版の Harness（このリポジトリ）に加えて、個人版の Harness（private の別リポジトリ）も読ませたい。plugin は marketplace を 2 つ入れれば両方効くが、rules と output style は `scripts/sync.sh` が公開版の分だけを `~/.claude/rules/` と `~/.claude/output-styles/` に symlink しているので、個人版の分が届かない。flatmate の住人は起動のたびに公開版の `scripts/sync.sh` を呼ぶので、そこで個人版も張れれば、オーナーの対話セッションと住人の両方に同じ形で届く。

いま `~/.claude/rules/` は `*.md` が 1 階層に並ぶだけで、どの Harness が置いたファイルか見て分からない。同名のルールがあると片方がもう片方を上書きしてしまう（#1129 で個人版のルールを `harness-dev.md` に名前を変えたのはこのため）。

## What Changes

- `scripts/sync.sh` が rules の symlink を出どころごとのサブディレクトリに張る。公開版は `~/.claude/rules/claude-harness/`、個人版は `~/.claude/rules/claude-harness/<個人版が自分で名乗る名前>/`
- `scripts/sync.sh` が「重ねる Harness（overlay）」を、利用者が許可したものだけ重ねる。許可は `~/.claude/harness-overlays`（1 行に 1 つ、`~/.claude/plugins/marketplaces/` 直下のディレクトリ名）。許可した marketplace の直下の印のファイル `.harness-overlay` の 1 行目がサブディレクトリ名になる。許可に無い marketplace は印があっても張らず pull もしない（入れただけの第三者の marketplace に常時読まれる指示を張らせないため）。公開版は個人版の名前を知らなくてよい
- 旧位置（`~/.claude/rules/*.md` に直接張った、公開版を指す symlink）を、新位置に張ったあとで片付ける
- output style は 1 階層のまま（`~/.claude/output-styles/`）。overlay の output style が公開版と同名なら公開版を優先し、警告して非 0 で終わる
- 規則の名前がぶつかったときの扱い、テスト、README の更新

個人版リポジトリ側の変更（印のファイルを置く、README の symlink の手順を sync.sh に任せる形に直す）は別リポジトリの別 PR で行う。

## Capabilities

### New Capabilities
- `harness-overlay-sync`: `scripts/sync.sh` が rules を出どころごとのサブディレクトリに張り、overlay を見つけて重ねる振る舞い

### Modified Capabilities
なし（`always-on-injection-scope` と `harness-public-private-split` の古くなる説明文の扱いは design.md に書く）

## Impact

- `scripts/sync.sh`、`tests/rules-sync.bats`、`rules/README.md`、`docs/worktree-recovery.md`
- flatmate 側の `scripts/agent-status.sh` の `read_harness_rules_state` は `~/.claude/rules` 直下の symlink を数えているので、張り先の移動後は「未配線」と誤表示する。直しは flatmate 側の別 issue（この change の範囲外）
- #1226（marketplace 名の付け直し）とは独立。サブディレクトリ名 `claude-harness` は marketplace 名から作らない固定の名前なので、改名の影響を受けない
