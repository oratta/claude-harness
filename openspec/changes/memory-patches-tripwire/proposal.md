# Proposal

## Why

ハーネスの動きへの指摘をメモリにその場しのぎで書くと、ハーネス側が直ったあともメモリが毎セッション読み込まれ、新しい規則を上書きし続ける（#1654。flatmate のエピックの親が、develop の規則より古いメモリに従って見張りを止めた）。メモリと直し先の issue が結び付いていないので、issue が閉じても誰も気づかない。

## What Changes

- プラグインの動きへの指摘をメモリにその場しのぎで書くときは、同じターンでその部品を持つリポジトリに issue を立て、メモリの frontmatter に `patches: <issue の URL>` を書く規則を `rules/plugin-editing.md` に足す（全プロジェクトのセッションに常時読み込まれる）
- `plugins/dev-workflow/scripts/memory-tripwire.sh` が、メモリの frontmatter の `patches:`（`metadata:` の下とトップレベル）を読み、その issue の状態を 1 日 1 回だけ `gh` で確かめて控え、閉じていれば既存の `[memory]` の 1 行で消す候補として知らせる。控えはメモリディレクトリの外の共通の 1 ファイルに置く。確かめる処理は時間で打ち切り、`gh` が無い・認証切れ・オフラインでも何も出さずに続ける
- 時間の要件を「1 回 100ms 未満」から「`patches:` が無いか、その日の控えがあるとき 0.5 秒未満」に改める
- `plugins/dev-workflow/skills/memory-refresh/SKILL.md` に `patches:` の書き方の正本を置き、分類に「`patches:` の issue が完了で閉じた」を削除の条件として足す（完了以外で閉じたものは、動きが直ったかを確かめてから分類する）
- `rules/README.md` の plugin-editing の行と `plugins/dev-workflow/changes/1654.md` を更新する（版は上げない）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-memory-refresh`: `patches:` の読み取り・控え・打ち切り・通知の要件を足し、既存の通知の要件（1 行の条件・書いてよいファイル・時間）と memory-refresh スキルの要件（分類と書き方の正本）を改める
- `harness-public-private-split`: 公開版の `rules/plugin-editing.md` が書く点を 5 点から 6 点にする（メモリの `patches:` の規則）

## Impact

- `memory-tripwire.sh` が初めてネットワーク（`gh`）を使い、メモリディレクトリの外に控えのファイル（既定 `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.memory-patches-cache.tsv`）を書く
- SessionStart の待ち時間: その日の最初のセッションで、控えの無い `patches:` があるときだけ最大で打ち切りの時間（既定 3 秒）増える。それ以外は 0.5 秒未満
- 常時読み込まれる rules が 1 行ぶん増える（`tests/injection-budget.bats` の予算の中に収める）
- `patches:` を持たないメモリには何も変わらない
