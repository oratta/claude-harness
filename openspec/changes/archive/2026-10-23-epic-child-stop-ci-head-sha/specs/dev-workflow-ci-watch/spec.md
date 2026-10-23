## MODIFIED Requirements

### Requirement: CI の見張りの手順は共有 reference に 1 本置く
`plugins/dev-workflow/references/ci-watch.md` は、合格後（と #523 の入口から呼ばれたとき）の CI の見張りの手順の正本として、次を書かなければならない（MUST）。pr-review-gate と develop の SKILL.md はこの手順を言い換えて再掲せず、この reference を参照する（MUST）。reference の中でゲートを前提にする手順（直し方の ③ と ⑥）は、③ を「`agent-review:passed` が付いていた PR のとき」、⑥ を「`agent-review:passed` を外した PR（`agent-review:pending` が付いている PR）」に限って行うと書き、`ready` を受けたあとの扱いは呼び出し側が決める差し込み口として書く（MUST。#523 の入口がゲートを通していない PR についてそのまま呼べるようにするため）。

1. **待つのは本体（メインセッション）だけ**: サブエージェントは見張りを始めない。理由として `references/subagent-waiting.md` の「背景タスクの完了では起こされない」を参照する
2. **1 つの PR を見張るのは 1 セッションだけ**: 見張りを始めるとき、PR に 1 行目が `CI 見張り開始:` のコメント（何を待っているか＝PR の CI の決着を本体が待っていること、を添える）を投稿し、見張りを終えるときに 1 行目が `CI 見張り終了:` のコメントを投稿する。始める前に PR のコメントを見て、`CI 見張り開始:` のあとに `CI 見張り終了:` が無ければ、ほかのセッションが見張り中として始めず、PR の URL を添えてオーナーに伝える。オーナーの指示で見張りを再開するとき（前のセッションが閉じた・オーナーに上げたあと続けるよう言われた）は、状態ファイルの `raised` を消すだけで済ませず、状態ファイル（`state`・`head`・`fixes`・`reran_head`）と PR の記録（直しの依頼・push・`gh run rerun`・ラベル）から中断した一手が済んでいるかを確かめる。状態ファイルの `head` が PR の今の HEAD と同じで、`fix` の判定のあと直しの push が無いときは、`next` を呼ばずに（`decide` が同じ状態・同じ HEAD の決着を `none` にするため）直し方の実装者への修正依頼から再開する。`rerun` の判定のあとその HEAD で `gh run rerun` が実行されていなければ、`gh run rerun` から再開する。`escalate` のあとに続けるよう言われたときは、オーナーの具体的な指示（直す・やり直す・関係ない失敗として扱うなど）を先に実行してから、`raised` を消して `wait` から見張りに戻る。同じセッションが `fix` の直しのあとに `wait` から始め直すときは、開始の判定も開始のコメントもしない。直しの担い手に渡すときも、終了のコメントは投稿しない
3. **待ち方**: `ci-watch.sh wait` を Bash ツールの `run_in_background` で起動し、完了通知で起こされてから出力を 1 回読む。前景のループで待たない・途中で出力を覗かない
4. **`wait` の結果ごとの動き**: `settled` → 下の 5 で `--unrelated` を決めてから `next` を実行する（`--until-merged` の `wait` が `ci-fail`・`conflict` で返した `settled` も同じ）／`merged` → 見張りを終えてマージを報告する／`closed` → 見張りを終える／`timeout` → `--until-merged` を付けずに起動した `wait` なら、PR の URL を添えて CI が上限時間内に決着しなかったことをオーナーに 1 アクションで伝える。`--until-merged` を付けて起動した `wait` なら、マージされなかったとして PR の URL を添えてオーナーにマージを頼む／`error` → `gh` の認証・ネットワークを確かめて 1 回だけ起動し直し、もう一度 `error` ならオーナーに伝える
5. **`--unrelated` を渡す基準**: `wait` の `obs.state` が `ci-fail` で `obs.retry` が `false` のとき、`cause` が `real` のチェックごとに、`gh run view <run> --log-failed` の末尾（範囲を切って読む）と `gh pr diff --name-only` を見て、「落ちたテスト・手順が PR の変えたファイルとそれを直接読み込むテストに当たらない」と「失敗の内容が PR の差分と因果を持たない（タイムアウト・ネットワーク・外部サービス・実行マシンの資源不足など）」の両方を満たすものだけを渡す。どちらかが判断できなければ渡さない
6. **`next` の一手ごとの動き**: `rerun` → `obs.runs` の各 run に `gh run rerun <run> --failed` を実行してから `wait` を起動し直す（やり直しに失敗したら、その旨を PR にコメントして `wait` を起動し直す。次の観測で `decide` が直しに回す）／`fix` → 下の 7 の直し方で直す。push したら、`agent-review:passed` を外したまま同じ状態ファイルで `wait` から始め直し（同じ見張りの続きなので、上の 2 の開始の判定・開始と終了のコメントはしない）、そのあとの `rerun`・`fix` もこの一手どおりに処理する。ゲートの取り直しは `ready` になってから行う／`escalate` → `needs-approval` を付け、落ちたチェック名と PR の URL を添えてオーナーに 1 アクションで頼み、見張りを終える。エピックの子のセッション（`scripts/epic-dispatch.sh route`（子の番号なし）が `nested` を返す）は、止まる前に `skills/develop/references/epic-child-stop.md` の手順どおり記録を残して `mark stopped` で止まる（CI の見張りで止まったときの `再開に要る途中経過:` の書き方もそこが正本で、HEAD の短い SHA の桁数や取り方をこの reference に写さない）／`ready` → 扱いは呼び出し側が決める。ゲートの合格後に呼んだとき（pr-review-gate・develop）の扱いは次のとおり: 直しで `agent-review:passed` を外した PR（`agent-review:pending` が付いている）は、先にゲートを取り直し、取り直したゲートに合格するまでマージ待ち・マージ依頼に進まない（failed なら指摘を直して push し、`wait` から続けて `ready` になってから再び取り直す。保留になるか 2 周で合格が確定しなければオーナーに上げる。合格したら同じ見張りの続きとして次のラベルの確認に進む）。そのうえで PR のラベルを見て、`human-merge` / `needs-human-merge` / `human-only` / `needs-approval`（`.github/workflows/auto-merge.yml` がマージを止めるラベル）のどれかが付いていれば、待たずに PR の URL を添えてオーナーにマージを頼み、見張りを終える。どれも付いておらず、自動マージの workflow（`.github/workflows/auto-merge.yml`）が対象リポにあれば `wait --until-merged` を `run_in_background` で起動して見届け、無ければ PR の URL を添えてオーナーにマージを頼む。どの呼び出し側でも、LLM が `gh pr merge` や merge API を叩いてはならない／`none` → `obs.state` が `wait` のときだけ `wait` を起動し直す。それ以外の `none`（前回と同じ状態・同じ HEAD の決着、オーナーに上げ済み）は見張りを終え、PR の URL を添えてオーナーに状況（`obs.state` と、上げ済みならその旨）を伝える。エピックの子のセッションは、この `none` で見張りを終えるときも、止まる前に `skills/develop/references/epic-child-stop.md` の手順どおり記録を残して `mark stopped` で止まる（`escalate` と同じ。親が追加のやり直しを許したあと同じ HEAD でまた落ちたときはこの `none` になる）
7. **直し方**（flatmate の `docs/project-modes.md`「止まった人間マージ待ち PR の見張り」の修正手順を移したもの）: 担い手は PR の実装者で、ゲートを回した側ではない（develop では W。develop を使わずメインセッションで pr-review-gate を回したときは、メインセッションが実装者のサブエージェント（model は sonnet）を起こして直させる）。① `git fetch origin` し、PR ブランチの worktree で作業する（残っていればそれを使い、無ければ対象リポの clone から切る。harness では開発用の clone から切り、marketplace dir では作業しない）② `conflict` は `git merge origin/main` で解く。版番号だけの競合は main の値に PR の上げ幅を積んだ値にする（main が 1.4.0・PR が 1.3.0 → 1.3.1 なら 1.4.1）。`ci-fail` は `gh run view <run> --log-failed` を読んで直す。実装者がログを読んで PR の差分と関係ない失敗だと判断したら、直さず push もせずに本体へ返し、本体は `next --unrelated <チェック名> --after-fix` を 1 回だけ実行してその一手に従う（同じ HEAD でのやり直しは 1 回までなので、失うのは CI 1 周分で止まる）③ `agent-review:passed` が付いていた PR のとき、push の前に `gh api -X DELETE repos/<owner/repo>/issues/<PR番号>/labels/agent-review:passed` で外し、`gh pr view <PR番号> --json labels` で外れたことを確かめ、PR が Draft でなければ `gh pr ready --undo` で Draft に戻し、`agent-review:pending` を付ける ④ オーナーにマージを頼んだ未解決の依頼があれば、差分が変わったので取り下げると PR にコメントする ⑤ commit して push する ⑥ `agent-review:passed` を外した PR（この直しで外したか、前の直しで外したまま `agent-review:pending` が付いている PR）は、push のあとすぐにはゲートを取り直さない。呼び出し側が `fix` の一手どおり `wait` → `next` を続けて CI のやり直し・再度の直しを済ませ、`ready` になってからゲートを取り直す。合格するまで `agent-review:passed` を付け直さない ⑦ push の前に直せないと判断したときは、push せずに `escalate` と同じ手順でオーナーに上げる
8. **状態ファイル**: 置き場所と、`fix` のあとも消さずに使い続けること（修正回数が PR ごとに累計され、3 回目の失敗で `escalate` になる）。状態ファイルは同じ PC のローカルにあり、1 つの PR を 1 セッションだけが見張る前提（上の 2）で読み書きする

#### Scenario: reference が見張りの手順を持つ
- **WHEN** `plugins/dev-workflow/references/ci-watch.md` を読む
- **THEN** `run_in_background`・`ci-watch.sh wait`・`ci-watch.sh next`・`--unrelated`・`--after-fix`・`gh run rerun`・`--log-failed`・`agent-review:passed`・`gh pr ready --undo`・`--until-merged` の各語が現れる

#### Scenario: サブエージェントに待たせない
- **WHEN** reference の待つ担い手の節を読む
- **THEN** 見張りを始めるのは本体（メインセッション）だけで、サブエージェントは始めないことと、`subagent-waiting.md` への参照が書かれている

#### Scenario: LLM はマージしない
- **WHEN** reference の `ready` の動きを読む
- **THEN** `gh pr merge` や merge API を叩かないことが書かれている

#### Scenario: マージを止めるラベルが付いた ready は待たずに頼む
- **WHEN** reference の `ready` の動きを読む
- **THEN** `human-merge`・`needs-human-merge`・`human-only`・`needs-approval` の 4 つのラベル名と、どれかが付いていれば `--until-merged` で待たずにオーナーへマージを頼むことが書かれ、`--until-merged` で起動した `wait` の `timeout` はマージを頼む扱いと書き分けられている

#### Scenario: none で起動し直すのは wait のときだけ
- **WHEN** reference の `none` の動きを読む
- **THEN** `wait` を起動し直すのは `obs.state` が `wait` のときだけで、それ以外の `none` は見張りを終えて PR の URL を添えてオーナーに伝えることが書かれている

#### Scenario: 1 つの PR を見張るのは 1 セッションだけ
- **WHEN** reference の見張りの開始の節を読む
- **THEN** `CI 見張り開始:` と `CI 見張り終了:` のコメントで見張り中かを判定し、見張り中なら始めないことと、同じセッションが直したあとに始め直すときは開始の判定もコメントもしないことが書かれている

#### Scenario: 再開では中断した一手を確かめる
- **WHEN** reference のオーナーの指示で再開するときの記述を読む
- **THEN** `raised` を消すだけで済ませず中断した一手が済んでいるかを確かめること、同じ HEAD の未実行の `fix` は `next` を呼ばずに実装者への修正依頼から再開すること、`escalate` のあとはオーナーの具体的な指示を先に実行してから見張りに戻ることが書かれている

#### Scenario: 直しの push のあとは ready まで見張ってからゲートを取り直す
- **WHEN** reference の `fix` の動きと `ready` を受けたあとの動きを読む
- **THEN** push のあと `agent-review:passed` を外したまま同じ状態ファイルで `wait` から始め直すこと、ゲートの取り直しは `ready` になってから行うこと、取り直したゲートに合格するまでマージ待ち・マージ依頼に進まないことが書かれている

#### Scenario: ゲート前提の手順は passed が付いていた PR に限る
- **WHEN** reference の直し方を読む
- **THEN** passed を外して Draft に戻す手順は `agent-review:passed` が付いていた PR に、ゲートの取り直しは passed を外した PR に限ると書かれ、`ready` のあとの扱いは呼び出し側が決めると書かれている

#### Scenario: エピックの子の escalate は停止の記録の規定を指す
- **WHEN** reference の `escalate` の動きを読む
- **THEN** エピックの子のセッションは止まる前に `skills/develop/references/epic-child-stop.md` の手順どおり記録を残して `mark stopped` で止まることが書かれ、HEAD の短い SHA の桁数や取り方（`先頭 7 文字`・`obs.head`・`headRefOid`）は書かれていない

#### Scenario: エピックの子の wait でない none も停止の記録の規定を指す
- **WHEN** reference の `none` の動きを読む
- **THEN** `obs.state` が `wait` でない `none` で見張りを終えるとき、エピックの子のセッションは止まる前に `skills/develop/references/epic-child-stop.md` の手順どおり記録を残して `mark stopped` で止まることが書かれ、HEAD の短い SHA の桁数や取り方（`先頭 7 文字`・`obs.head`・`headRefOid`）は書かれていない
