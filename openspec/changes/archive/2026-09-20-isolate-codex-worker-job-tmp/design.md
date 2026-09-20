## Context

Dispatch HEAD: `4ee15b5fa61495a4eb9d358f53139e85c8f5ebc5`。worker は implement/spec-write に workspace-write、他の role に read-only を使う。turn の writableRoots は cwd のみで、excludeSlashTmp/excludeTmpdirEnvVar は true。Rpc は clean_env の TMPDIR を継承する。runtime CODEX_HOME はジョブ専用だが、認証・設定を含むのでその全体を writable にしてはいけない。

`add-codex-worker` の proposal/design/tasks/specs と `codex-develop-continuation` を参照した。前者は未 archive であり、今回の ADDED 要件を基盤要件に重複させない。run は複数の fresh job を束ねる概念で、job_id と同一ではない。

## Goals / Non-Goals

**Goals:** Git 管理外の専用 TMPDIR でテストを完走し、許可範囲・寿命を実測する。

**Non-Goals:** ps/pgrep の許可、残留プロセス検出、unknown の自動復旧、network/approval 緩和、read-only の書き込み許可、品質工程の変更。

## Decisions

以下の四点の採用案と却下理由は R1 で妥当と判定された。修正仕様の R1 承認前の実装許可ではない。

| 論点 | 採用案 | 却下案 | 理由 |
| --- | --- | --- | --- |
| ジョブごとに一つか | workspace-write の job_id ごとに新規の一時領域を一つ所有し、ジョブ内の全コマンドで使う | コマンドごとの複数 root、全ジョブ共通 root | 許可の単位を既存 job 所有・終了契約に合わせ、root の増殖と共有を防ぐ |
| run ごとか | 同一 run 内でも fresh job 間では共有しない | run の寿命まで同じ TMPDIR を保持 | role・account・工程を跨いだ残留データへの依存を作らない |
| 作業場所の外か | 実パスが worktree およびあらゆる Git 管理領域の外にある専用ディレクトリ | cwd/.tmp-bats、runtime CODEX_HOME 全体、/tmp 全体の許可 | outside-a-git-repo テストの前提を保ち、認証・設定や他の一時領域を開放しない |
| 終了時に消すか | 実行終了が確認されたジョブの専用領域を削除し、ack 待ちの保存領域にしない | 恒久保持、ack 時だけ削除、run 終了まで保持 | テスト副産物を結果保管と混同せず、後続ジョブへ残さない |

### 許可と環境の結び付け

worker が信頼できる親領域に原子的に作る、所有者一致・0700 の実ディレクトリを使う。配置先の親は、worker 起動時の環境変数 `TMPDIR` が非空ならその値を優先し、未設定または空なら `/tmp` を使う。`TEMP` / `TMP` や request フィールドは配置先の入力にしない。選択した親を正規化済み絶対パスへ解決し、その配下にジョブ専用領域を新規作成する。個人パスを固定せず、親全体を writableRoot に追加しない。選択した親が存在しない・ディレクトリでない・作成できない場合、または専用領域が cwd/Git 管理内となるか所有者一致・0700 を満たせない場合は、別の候補へフォールバックせず開始を拒否する。入力 prompt や任意の request フィールドから追加 root を受け取らない。

Rpc 起動より前に専用領域を用意し、App Server およびそこから起動するツールの TMPDIR を同じ正規化済み絶対パスにする。workspace-write の writableRoots は cwd とその領域のみ。excludeSlashTmp/excludeTmpdirEnvVar=true は維持し、TMPDIR の暗黙許可に頼らない。元の TMPDIR は子へ渡さない。read-only role には本変更による writableRoot を足さない。

### 寿命と安全な削除

正常終了、確認済み失敗・取消、turn 開始前の失敗で片付ける。削除対象は作成時に所有を確認した専用領域だけで、symlink の参照先や親へ再帰しない。cleanup 失敗は成功扱いにせず残留の事実を返す。turn 状態不明や worker 強制終了を「終了済み」と推測して削除・再利用しない。R1 は unknown 時の削除延期を認めた。停止未確認は終了ではなく、既存の所有保持・再投入禁止と整合する。停止証拠に基づく運用回復は未実装であるため、最終的な自動削除までは保証しない。

## Risks / Trade-offs

- **停止未確認の残留:** unknown/worker 強制終了では領域の所有を保持し、削除・再利用しない。運用回復が未実装のため、最終的な自動削除までは保証しない。
- **フルテストの別要因:** #315 の Killed:9 が TMPDIR だけで解消するとは断定しない。対象 HEAD で全件数・成功数・終了コードを採り直す。fake transport の合格は砂場の実効性を証明しない。
- **終了直後の観測競合:** terminal の記録だけでは cleanup 完了の証拠にならない。完了した worker の後で存在確認し、結果に cleanup 失敗を残せる順序をテストする。

## Migration Plan

R1 承認後に TDD で worker と回帰テストを変更し、実 Codex implement role で検証する。CODEX-WORKER.md を更新し dev-workflow/plugin.json のバージョンを上げる。常時注入予算は据え置く。既存ジョブの領域を後付けで変更せず、新規 job から適用する。問題があればこの変更を戻し、新規 job を従来 cwd のみへ戻す。未知の実行の領域を自動削除しない。

## Open Questions

未解決事項なし。オーナーが非再利用と確認済み終了後の削除を確定し、R1 が unknown 時の削除延期を認めた。修正仕様の再レビュー後に実装へ進む。
