## 1. worker.md の (3a) 手順 5 を書き換える

- [ ] 1.1 `plugins/dev-workflow/skills/develop/references/roles/worker.md` の (3a) 手順 5（125 行目付近、「テスト・lint・ビルドを実行し」の行）を、`.github/workflows/*.yml` の `run:` から検査コマンドを拾い（環境セットアップを除く）、すべて実行する指示に書き換える。コマンド名をこのリポジトリ固有の値に固定しない
- [ ] 1.2 workflow ファイルが存在しない、または検査コマンドを判別できないときの慣例コマンド（`scripts/test.sh` 等）へのフォールバックを明記する

## 2. worker.md の (3a) の return 項目を書き換える

- [ ] 2.1 `plugins/dev-workflow/skills/develop/references/roles/worker.md` の「(3a) の return に書くこと」（137 行目付近）に、収集した検査コマンドの一覧を含める義務を追加する（既存の「実行したテストコマンドと exit code」の記述と整合させる）

## 3. 実機確認

- [ ] 3.1 shellcheck に違反する変更を仕込んだ状態で W の (3a) 手順を 1 回動かし、return に `scripts/lint.sh`（または CI 由来の shellcheck 相当コマンド）の非 0 exit code が載ることを確認する
- [ ] 3.2 確認結果を PR 本文に記録する（issue #508 受け入れ条件 2）

## 4. 検証

- [ ] 4.1 `git grep -n 'workflows' origin/main -- plugins/dev-workflow/skills/develop/references/roles/worker.md` を新しい HEAD に対して実行し、1 件以上ヒットすることを確認する
- [ ] 4.2 `scripts/test.sh` と `scripts/lint.sh` を実行し、exit code 0 を確認する
- [ ] 4.3 `openspec validate worker-return-ci-checks --strict`（または `/opsx:verify`）を実行する
