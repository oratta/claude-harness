## Why

CI のジョブがキャンセルや上限時間で打ち切られると、ジョブが起こしたプロセスがセルフホストランナーの Mac に残ることがある。flatmate では 2026-10-10 に、打ち切られた `scripts/test.sh` が親を失ったまま次のスイートを起動し続け、スイートと `wrangler dev` が 2 日以上 CPU を使い続けて後続の CI が上限を超えた（genetta-inc/flatmate#1563）。infra-setup の雛形から CI を入れたリポジトリ（suimei など）は同じ Mac のランナーを共有しており、同じ事故が起こりうる。GitHub のランナーはジョブごとにマシンが捨てられるので、掃除が要るのはセルフホストのときだけ。

## What Changes

- `ci.yml.template` の `test` ジョブの最後に、ジョブの作業ディレクトリ（`$GITHUB_WORKSPACE`）の下に cwd を持つプロセスを止める手順を置く。条件は `always() && runner.environment == 'self-hosted'`
- `weekly-full.yml.template` の `full` ジョブにも同じ手順を置く
- 手順は雛形の中に直書きする（flatmate の `scripts/stop-tests.sh` と `.test-run/` の記録は雛形利用先に無いため、移さない）。自分自身とその祖先は止めない。TERM のあと残ったものだけ KILL する。ほかのジョブのプロセスは cwd がこの作業ディレクトリの外なので止めない
- `infra-setup` の `SKILL.md` に、掃除の手順の意味と、既に雛形から CI を入れたリポジトリへの反映のしかたを書く
- `plugins/infra/tests/infra-fixes.bats` に、手順の有無・条件・位置の検査と、実際にプロセスを止める範囲の検査を足す

範囲外: 既存リポジトリ（suimei など）への反映そのもの、flatmate 側の変更、ランナーの Mac を定期的に見る見張り（genetta-inc/flatmate#1567）。

## Capabilities

### New Capabilities
- `infra-ci-selfhosted-cleanup`: infra の CI 雛形が、セルフホストのときだけ、ジョブ終了時に作業ディレクトリ配下のプロセスを止め、その意味と既存リポジトリへの反映のしかたを案内する要件

### Modified Capabilities

なし

## Impact

- `plugins/infra/templates/workflows/ci.yml.template`
- `plugins/infra/templates/workflows/weekly-full.yml.template`
- `plugins/infra/skills/infra-setup/SKILL.md`
- `plugins/infra/tests/infra-fixes.bats`
- `plugins/infra/changes/994.md`（変更の記録）
- 常時注入の予算に効く `description` などの増減: なし
