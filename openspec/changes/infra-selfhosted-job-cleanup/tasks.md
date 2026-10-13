## 1. 雛形

- [x] 1.1 `ci.yml.template` の `test` ジョブの最後に、セルフホスト限定の掃除の手順（`if: always() && runner.environment == 'self-hosted'`、`$GITHUB_WORKSPACE` 配下の cwd を持つプロセスを、自分と祖先を除いて TERM → 5 秒待ち → 残りを KILL）とコメントを足す 触る範囲: plugins/infra/templates/workflows/ci.yml.template:92-93（`Run unit tests` の手順の直後。ファイル末尾）
- [x] 1.2 `weekly-full.yml.template` の `full` ジョブの最後（`report-failure` ジョブの前）に、1.1 と同じ文面の手順を足す 触る範囲: plugins/infra/templates/workflows/weekly-full.yml.template:82-88（`npm audit` の手順と E2E のコメントの後、`report-failure` の前）

## 2. SKILL.md

- [x] 2.1 「CI/CD 構成の 2 軸」節に、ジョブ終了時の掃除の意味（セルフホスト限定・作業ディレクトリ配下だけ・ほかのジョブは止めない・cwd を外へ移したものは止まらない）と、既存リポジトリへの反映のしかた（両ジョブの最後の手順に手で書き足す。再実行は勧めない理由は上限時間と同じ）を足す 触る範囲: plugins/infra/skills/infra-setup/SKILL.md:267-282（`runs-on` の項から「既に雛形から CI を入れたリポジトリへの反映」の項まで）

## 3. テスト

- [x] 3.1 両雛形の最後の手順の `if` / `run` / `continue-on-error` の静的検査、2 つの `run` の一致、`run` を取り出して偽のプロセスで走らせる範囲検査（作業ディレクトリ配下は止まり、外・前方一致する隣は生きる）、TERM を無視するプロセスが KILL で止まる検査、`kill` を差し替えて止められない対象があるとき非 0 になり PID が出る検査、待つ間に消えた PID（`ps -p` が失敗）が正常になる検査、`kill` が権限拒否で失敗し `ps -p` は成功する対象が消滅とみなされず PID を出して非 0 になる検査（`kill -0` の失敗と消滅を区別する検査）、SKILL.md の節の検査を足す 触る範囲: plugins/infra/tests/infra-fixes.bats:879-891（末尾に追記）
- [x] 3.2 変更の記録を書く 触る範囲: plugins/infra/changes/994.md（新規）
- [x] 3.3 `scripts/test.sh infra` が exit 0 になることを確かめる
