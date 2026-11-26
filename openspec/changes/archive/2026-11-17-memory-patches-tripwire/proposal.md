# Proposal

## Why

ハーネスの動きへの指摘をメモリにその場しのぎで書くと、ハーネス側が直ったあともメモリが毎セッション読み込まれ、新しい規則を上書きし続ける（#1654。flatmate のエピックの親が、develop の規則より古いメモリに従って見張りを止めた）。メモリと直し先の issue が結び付いていないので、issue が閉じても誰も気づかない。

## What Changes

- プラグインの動きへの指摘をメモリにその場しのぎで書くときは、同じターンでその部品を持つリポジトリに issue を立て、メモリの frontmatter に `patches: <issue の URL>` を書く規則を `rules/plugin-editing.md` に足す（全プロジェクトのセッションに常時読み込まれる）
- `plugins/dev-workflow/scripts/memory-tripwire.sh` が、メモリの frontmatter の `patches:`（`metadata:` の下とトップレベル）を読み、その issue の状態をセッションの開始時に裏のプロセスで `gh` に確かめて控え、閉じていればその次のセッションで既存の `[memory]` の 1 行で消す候補として知らせる（開始の処理は控えだけを読み、照会を待たない）。控えはメモリディレクトリの外の共通の 1 ファイルに置く。確かめる処理は時間で打ち切り、`gh` が無い・認証切れ・オフラインでも何も出さずに続ける
- 時間の要件を「1 回 100ms 未満」から「裏の確認を除いた開始の処理が 0.5 秒未満」に改める
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
- SessionStart の待ち時間: 照会は裏で走るので、いつも 0.5 秒未満。閉じたことの知らせは 1 セッション遅れる（閉じたあと 2 回目のセッションになることがある）
- 常時読み込まれる rules が 1 行ぶん増える（`tests/injection-budget.bats` の予算の中に収める）
- `patches:` を持たないメモリには何も変わらない
