## 1. テストを先に書く（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/ci-watch.bats` を新設し、PATH 先頭の `gh` の偽物（呼び出しを記録し、呼ばれた回数ごとに用意した JSON を返す）で `wait` のケースを書く: 実行中のあいだは何も出さず落ちたら settled・決着した回だけ annotation を取る・通信切れの annotation が観測に入る・merged・closed・`--until-merged` は ready でも待つ・timeout・gh の 5 回連続失敗で error・状態ファイルに触れない・引数不足は非 0。間隔と上限は `DEV_WORKFLOW_CI_WATCH_INTERVAL=1` と小さい `DEV_WORKFLOW_CI_WATCH_TIMEOUT` で短くする
- [ ] 1.2 同じファイルに `next` のケースを書く: 初見で状態ファイルを作る・前回の状態を読んで escalate・`--unrelated` を observe に渡して rerun・状態 `{state:ci-fail, head:h1, fixes:1}` のとき `next --unrelated X --after-fix` は rerun で `fixes` は 1 のまま・gh の失敗で状態を書き換えない・読めない状態ファイルで非 0・`run rerun` を呼ばない。状態ディレクトリは `DEV_WORKFLOW_PR_STATE_DIR` で bats の一時ディレクトリに向ける
- [ ] 1.3 文書のケースを書く（既存の `plugins/dev-workflow/tests/pr-review-gate-skill.bats` の形に倣うか、`ci-watch.bats` に置く）: `references/ci-watch.md` に spec の語が現れる・待つのは本体だけと `subagent-waiting.md` への参照・`gh pr merge` を叩かない旨・`--unrelated` の守備範囲の段落（入力 3 つ・誤り 2 つ・許す例・完了条件にしない）・`ready` で 4 つのマージを止めるラベル（`human-merge` / `needs-human-merge` / `human-only` / `needs-approval`）を見て待たずに頼む旨と `--until-merged` の `timeout` はマージを頼む旨・`none` で `wait` を起動し直すのは `obs.state` が `wait` のときだけで、それ以外は見張りを終えてオーナーに伝える旨・`CI 見張り開始:` / `CI 見張り終了:` で 1 PR 1 セッションを判定する旨と再開時に `raised` を消す旨と同じセッションが直したあとに始め直すときは開始の判定もコメントもしない旨・直し方の passed の外しとゲートの取り直しが「`agent-review:passed` が付いていた PR のとき」に限られる旨・実装者が関係ない失敗と判断したら `next --unrelated <チェック名> --after-fix` を 1 回だけ使う旨・pr-review-gate SKILL.md の `run_in_background` が手順 5 の実測確認より後で手順 6 の見出しより前・`references/ci-watch.md` への参照とサブエージェントは passed を return する旨・develop SKILL.md の (4) に見張りと fix の流れ・gate-runner.md に G は見張りを始めない旨
- [ ] 1.4 `bats plugins/dev-workflow/tests/ci-watch.bats`（と追記した bats）で新しいテストが落ちることを確かめる

## 2. 実装（Green）

- [ ] 2.1 `plugins/dev-workflow/scripts/ci-watch.sh` を新設する（`wait` / `next`）。`pr-state.sh` は同じディレクトリのものを呼び、作り直さない。先頭コメントに呼び出し方・出力・環境変数・状態ファイルの場所・仕様の正本（openspec の `dev-workflow-ci-watch`）を書く
- [ ] 2.2 `plugins/dev-workflow/references/ci-watch.md` を新設する（spec の「CI の見張りの手順は共有 reference に 1 本置く」の 1〜8 と `--unrelated` の守備範囲）。直し方は genetta-inc/flatmate の main の `docs/project-modes.md`「止まった人間マージ待ち PR の見張り」の「修正依頼を受けたターンの手順」から移し、住人の依頼の列（`pr-watch tasks` / `done`）・あなた待ち（`pending-mirror.sh decide`）・`sync` / `render` の操作は持ち込まない。#523 の入口がこの reference をそのまま呼べるよう、ゲートや develop に依存する語（G・W）は「呼び出し側」「PR の実装者」と書き、develop での担い手は括弧で添える
- [ ] 2.3 `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` の手順 5 の末尾（実測確認と復旧の表・聖域パスの注記のあと、手順 6 の見出しの前）に「合格後の CI の見張り」を足す（メインセッションなら `run_in_background` で `ci-watch.sh wait` を起動、サブエージェントなら passed を return して呼び出し側に任せる、中身は `references/ci-watch.md`、直しで commit が積まれたら手順 1 から取り直す）
- [ ] 2.4 `plugins/dev-workflow/skills/develop/SKILL.md` の (4) の `passed` の扱いを足す（本体が `references/ci-watch.md` で見張る・`fix` なら W に直させて G を取り直し、passed で見張りを始め直す・unmanned は対象外）。`skills/develop/references/roles/gate-runner.md` の passed の return の箇所に、G は見張りを始めないことを 1 行足す
- [ ] 2.5 `bats plugins/dev-workflow/tests/ci-watch.bats`（と追記した bats）が全件通ることを確かめる

## 3. 記録と全体の確認

- [ ] 3.1 `plugins/dev-workflow/changes/522.md` に変更記録を書く（既存の changes/ の書式。待つのは本体だけ・状態ファイルの場所・`--unrelated` の基準・受け入れたリスクを含める）。版（version）は上げない
- [ ] 3.2 `scripts/test.sh` を全件フォアグラウンドで流して通ることを確かめる（終了コードはコマンド自身のもの。`statusline-multi-account.bats` の単発失敗は単独再実行で判定）
- [ ] 3.3 `scripts/lint.sh` が exit 0 になることを確かめる
- [ ] 3.4 `openspec validate ci-watch-after-gate --strict` が通ることを確かめる

## 4. 実機確認（受け入れ条件 3。本体が行い、記録を PR に貼る）

実行するのは develop の本体（メインセッション）。インストール済みのプラグインにはまだこの変更が入っていないので、reference と `ci-watch.sh` はこの PR の worktree のものを絶対パスで使う。捨て PR は oratta/claude-harness に切り、auto-merge に拾われないよう `human-merge` ラベルを付けておく（`needs-approval` は合格処理を止めるので使わない）。捨て PR の記録先は捨て PR 自身（本文に issue 参照を書かず、`仕様化判断: しない` を PR にコメントする）。

- [ ] 4.1 直す経路: main から捨てブランチを切り、`tests/` に必ず落ちる bats（`@test "ci-watch e2e" { false; }`）を 1 本足して Draft PR を作る。pr-review-gate を light で通して合格させる（CI の失敗はゲートの判定材料ではないので合格しうる。合格しなければ落ちるテストを合格処理の直後に push し直し、ゲートを取り直す形に替える）
- [ ] 4.2 合格処理のあと、本体が `ci-watch.sh wait` を `run_in_background` で起動し、オーナーが何もしないまま完了通知で起こされること、`next` が `fix` を返すことを確かめる。直し方の手順どおり（passed を外す・Draft に戻す・pending を付ける）に W がテストを直して push し、ゲートを取り直して合格したら `wait` から始め直し、`ready` まで進むことを確かめる。`ready` では捨て PR に `human-merge` が付いているので、`wait --until-merged` を起動せずに、PR の URL を添えてオーナーにマージを頼む文面がすぐ出ることを見る。続けて `--until-merged` の時間切れの扱いを確かめるため、本体が `DEV_WORKFLOW_CI_WATCH_TIMEOUT` を短くして `wait --until-merged` を手で起動し、`timeout` になったらマージを頼む文面が出ることを見る（ラベルの判定を飛ばして手で起動したことを記録に書く）
- [ ] 4.3 やり直す経路: 捨てブランチの bats を、1 回目の実行でだけ落ちるもの（`[ "${GITHUB_RUN_ATTEMPT:-1}" != 1 ]`）に差し替えてゲートを取り直し、見張りを始める。このテストは捨て PR の差分に入るので reference の 2 条件では `--unrelated` にならない。ここでは本体が `next --unrelated <落ちたチェック名>` を明示して渡し、`rerun` → `gh run rerun --failed` → `wait` → `ready` と進むことを確かめる（2 条件の判断そのものではなく、やり直しの配線を確かめる。design.md の Risks のとおり）
- [ ] 4.4 各経路の `wait` / `next` の出力・起こされた時刻・実行したコマンドを #522 の PR にコメントとして貼る。やり直す経路の記録には「`--unrelated` は手で渡した。理由は design.md の Risks『実機確認のやり直しの経路は判断の入力を人が与える』のとおり（捨て PR で足したテストは差分に入るので 2 条件では `--unrelated` にならない）」と明記する。捨て PR はクローズし、捨てブランチの削除と状態ファイル（`DEV_WORKFLOW_PR_STATE_DIR` の捨て PR の分）の扱いはオーナーに確かめてから行う
