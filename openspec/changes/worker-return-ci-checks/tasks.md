## 1. worker.md の「全経路共通の大原則」に検査実行の指示を足す

- [x] 1.1 `plugins/dev-workflow/skills/develop/references/roles/worker.md` の「全経路共通の大原則」節に、対象リポジトリの PR・push で起動する `.github/workflows/*.yml` / `*.yaml` のジョブの `run:` ステップを読み、検査コマンド（lint・test・ビルド等）と環境セットアップ（依存インストール等。除外例として `sudo apt-get install` を明示）を判別し、検査コマンドをすべて実行する指示を追加する。コマンド名をこのリポジトリ固有の値に固定しない。`auto-merge.yml` 等 `pull_request` / `push` 以外で起動する運用系ワークフローは対象外と明記する。守備範囲の段落（入力の出どころ・拾いたい誤り・通ってよい入力・取りこぼしを塞ぎ切ることを完了条件にしない）を worker.md に書く
- [x] 1.2 workflow ファイルが存在しない、または検査コマンドを判別できないときの慣例コマンド（`scripts/test.sh` 等）へのフォールバックを明記する
- [x] 1.3 手元にツールが無く実行できない検査は「未導入」として実行結果と区別し、未導入を合格扱いにしないことを明記する
- [x] 1.4 (3a)「コード直行する場合」手順 5 の「テスト・lint・ビルドを実行し」は 1.1 の指示への参照に整理し、内容を重複させない

## 2. worker.md の (3a) の return 項目を書き換える

- [x] 2.1 `plugins/dev-workflow/skills/develop/references/roles/worker.md` の「(3a) の return に書くこと」に、収集した検査コマンドの一覧と各 exit code（未導入があれば未導入と明記）を含める義務を追加する（既存の「実行したテストコマンドと exit code」の記述と整合させる）

## 3. 変更記録

- [x] 3.1 `plugins/dev-workflow/changes/508.md` を作成し、この change の内容（触ったファイル・要旨）を記録する

## 4. 実機確認

- [ ] 4.1 shellcheck に違反する変更を仕込んだ状態で W の (3a) 手順を 1 回動かし、return に `scripts/lint.sh`（または CI 由来の shellcheck 相当コマンド）の非 0 exit code が載ることを確認する
- [ ] 4.2 確認結果を PR 本文に記録する（issue #508 受け入れ条件 2）

## 5. 検証

- [x] 5.1 `git grep -n 'workflows' origin/main -- plugins/dev-workflow/skills/develop/references/roles/worker.md` を新しい HEAD に対して実行し、1 件以上ヒットすることを確認する
- [ ] 5.2 `scripts/test.sh` と `scripts/lint.sh` を実行し、exit code 0 を確認する
- [x] 5.3 `openspec validate worker-return-ci-checks --strict`（または `/opsx:verify`）を実行する
