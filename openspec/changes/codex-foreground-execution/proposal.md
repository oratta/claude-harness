## Why

Codex に仕事を投げると、その仕事は呼んだセッションから切り離されて動く（`codex-worker.py` の `submit` が `start_new_session=True` で `_worker` を起こす）。ターンを待つループには全体の時間上限が無く、回収するセッションがいなくなった仕事は `running` のまま走り続けて利用枠を消費する。止める手段はあるが、止める人がいることを前提にしている。

そのうえ呼び出し側の手順書（`plugins/dev-workflow/references/codex-develop.md`）には Codex にしか無い操作（`init` / `dispatch` / `status` / `result` / `ack` / `retry`、継続記録の復元）が並び、Claude のサブエージェント（呼ぶ → 完了通知 → 結果を読む）と二重管理になっている。「投げ先が変わるだけで呼び出し側の作りは変わらない形にする」という方針（エピック #345 の子 #334 / #336 / #338 と同じ意図）に反している。

## What Changes

- `codex-worker.py` に**前景実行の入口**（サブコマンド `run`）を足す。1 回のターンを実行して結果を stdout の JSON で出し、終了する。台帳（`ledger.sqlite`）も所有権の記録（`ownership.sqlite`）も作らず、読まない
- `run` は**呼んだプロセスと一緒に終わる**。起動時に控えた祖先の連鎖（直接の親だけでなく PID 1 まで）を 1 秒ごとに辿り直し、連鎖が変わったら実行中のターンを中断して app-server の子プロセスごと終わる。あいだに shell の wrapper が挟まっても呼び出し元の消失を拾える。合図から 30 秒以内に、コマンド自身と app-server の両方が消える
- `run` は **SIGTERM / SIGINT で止まる**。`turn/interrupt` を送ってから終了し、app-server の子プロセスを残さない
- `run` の stdout は 1 行の JSON で、最終回答・`status`・`usage`・要求した model / effort・実際に観測した model / effort（と観測元）・`thread_id` / `turn_id` / `error_kind` を含む
- `worker()` のターン実行部分を、記録先（台帳 / メモリ）を差し替えられる形に分ける。前景経路と既存の台帳経路が同じターン実行を通る
- `codex-develop.py` の役割ごとの設定解決（`resolve_execution`）と指示文の組み立て（`prompt`）を、前景実行の依頼ファイルを組み立てるところから使えるようにする。account 名から CODEX_HOME への対応は台帳ではなく**呼び出し側の設定**（`--account-home NAME=PATH` か同じ対応の JSON ファイル）で与え、対応に無い名前は拒否する
- `references/codex-develop.md` の呼び出し手順を「指示をファイルに書く → 前景コマンドを背景実行で起動 → 完了通知で結果を読む」の 3 手順に書き換える。`ack` / `retry` / `run-dir` / `worker-state` と継続記録の節は消える
- **受け入れる違い**: Codex の仕事が走っている最中にセッションを再起動すると、その仕事は止まり、その工程はやり直しになる。Claude のサブエージェントでは今もそうで、worktree に書かれた途中のファイルはどちらの場合も残る
- **この change でやらないこと**: 古い経路（`submit` / `status` / `result` / `ack` / `cancel` / `retry` / `register` / `reap` と台帳・所有権の仕組み）は消さない。消すのはエピック #345 の後続の子

## Capabilities

### New Capabilities
<!-- 無し。前景実行は既存の codex-worker（Codex の job を走らせる実行基盤）の中の実行形態の追加であり、別の機能領域ではない。issue #340 も `openspec/specs/codex-worker/spec.md` への要件追加として書いている -->

### Modified Capabilities
- `codex-worker`: 台帳を使わない前景実行の要件を足す（stdout の結果契約・親と一緒に終わる・SIGTERM で止まる・台帳と所有権に触れない）。要求設定と実効設定の公開先を「台帳の status / result」から「実行経路ごとの公開先（台帳経路は status / result、前景経路は stdout）」に広げる
- `manual-codex-develop`: adapter の呼び出し手順を、`init` → `dispatch` → `status` / `result` → `ack` の 4 段から前景実行の 3 手順に変える。役割ごとの設定は run への snapshot ではなく呼び出しごとの解決になる。送信到達が不明な pending の復旧（`retry`）は台帳経路だけの要件になる
- `codex-worker-concurrency`: 同時実行数の上限・作業ディレクトリの排他・残枠判定の 3 要件を台帳経路限定にする（前景実行はどれも持たないため、無条件の MUST のままだと `codex-worker` 側の新要件と衝突する）
- `codex-develop-continuation`: 継続記録（`<!-- codex-develop-continuation:v1|v2 ... -->` の保存と復元）は台帳経路だけの要件になる。前景経路は run を持たないので記録を作らず、セッションをまたいだ継続の代わりにその工程をやり直す

## Impact

- `plugins/dev-workflow/scripts/codex-worker.py`: サブコマンド `run` の追加、`--state-dir` を台帳サブコマンド側へ移す、`worker()` のターン実行部分の分離、親の監視とシグナル処理、runtime CODEX_HOME を台帳の外に作る経路
- `plugins/dev-workflow/scripts/codex-develop.py`: 前景実行の依頼ファイルを組み立てる入口（`resolve_execution` / `prompt` の再利用）
- `plugins/dev-workflow/tests/test_codex_worker.py`: 偽 app-server（`FAKE`）を使う既存テストに前景実行の 3 種（台帳を作らない完走・親の終了・SIGTERM）を追加
- `plugins/dev-workflow/references/codex-develop.md`、`plugins/dev-workflow/docs/codex-develop.md`、`plugins/dev-workflow/scripts/CODEX-WORKER.md`: 呼び方の書き換え
- `plugins/dev-workflow/skills/develop/SKILL.md`、`plugins/dev-workflow/commands/develop.md`: Codex 経路の案内
- `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json`: dev-workflow のバージョンを 2.13.13 にする
- 影響しないもの: ステータスラインの Codex 行は自分で app-server の `account/rateLimits/read` を呼んでおり、worker の台帳を読んでいない（`openspec/specs/statusline-multi-account-usage/spec.md:155`）
