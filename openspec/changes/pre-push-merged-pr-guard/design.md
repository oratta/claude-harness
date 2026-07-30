## Context

`loops-dev-agent-install` は Step 6 で `.githooks/pre-push` を設置し、`core.hooksPath` を設定する。現行のフックは `remote_ref` が `refs/heads/main` / `refs/heads/master` のときだけ拒否する 14 行の POSIX sh スクリプトで、外部コマンドに依存しない。

事故の実体は「マージ済み PR のブランチへの push」であり、これは main 直 push ではないため現行フックをすり抜ける。発生経路はマージ後に残った worktree での作業再開が典型で、`core.hooksPath` は同一リポジトリの全 worktree で共有されるため、同じフックにチェックを足せば経路ごと塞げる。

制約:

- フックは開発者の日常 push の内側で毎回走る。誤検知で作業を止めた瞬間に `--no-verify` が常用され、ガード全体が形骸化する
- push 先が GitHub とは限らず、オフライン・`gh` 未認証もありうる
- POSIX sh で書く（bash 依存にしない）。git がフックに渡すのは stdin の `<local_ref> <local_sha> <remote_ref> <remote_sha>` 行のみ

## Goals / Non-Goals

**Goals:**

- マージ済み PR のブランチへの push を、コミットが宙に浮く前にその場で止める
- 正当な push（初回 push・PR 開き直し・ブランチ削除）を 1 件も止めない
- ガードが効かない環境（オフライン等）でも作業を止めない
- 導入済み repo に後から反映できる

**Non-Goals:**

- closed（マージされず閉じた）PR のブランチは対象外。意図的な開き直し・再利用がありうるため
- GitHub 以外のホスティング（GitLab 等）への対応
- push 後の事後検知・通知（このガードは push の瞬間のみを扱う）
- deny ルールや branch protection の置き換え（本フックは第 1 層であり、head branch 自動削除・`/wt-clean` と併用する多層防御の一部）

## Decisions

### D1: 「merged > 0 かつ open == 0」のときだけ拒否する

`gh pr list --head <branch> --state merged` と `--state open` の 2 回呼び出しで件数を取り、両条件が揃ったときだけ拒否する。

- 代案「merged > 0 なら常に拒否」→ 却下。同名ブランチで PR を開き直した正当なケース（マージ後に追加修正の PR を同じブランチで立てる）を止めてしまう
- 代案「closed も対象に含める」→ 却下。closed は「一旦引っ込めて作り直す」運用があり、誤検知率が高い
- 代案「`gh pr list --state all` 1 回で JSON を取り自前集計」→ 却下。`--jq 'length'` 2 回の方がフック内のパースが単純で、sh のまま読める

### D2: fail-open（`gh` が失敗したら通す）

`gh` の非 0 終了・空出力ではその ref のチェックをスキップして push を通す。

- ガードのために日常作業が止まると `--no-verify` が常用され、main 直 push 拒否まで含めてガード全体が無効化される。誤検知コスト > 見逃しコスト
- 見逃しは第 2 層（GitHub の head branch 自動削除）・第 3 層（マージ後の `/wt-clean`）で回収する

### D3: ブランチ削除 push は `local_sha` 全ゼロで判定して素通し

git は削除 push に対し `local_sha` を 40 桁の 0 で渡す。マージ済みブランチの削除はむしろ望ましい操作なので、チェック前に `continue` する。

### D4: バイパスは環境変数 `PREPUSH_ALLOW_MERGED=1`

- 代案「`--no-verify`」→ 却下。main 直 push 拒否まで一緒に無効化されるうえ、`--no-verify` はプロジェクトの deny ルール対象
- 拒否メッセージ内にそのまま実行できるコマンド例を出す。バイパス手段を隠すと `--no-verify` に逃げられるため、安全な逃げ道を明示する

### D5: ブランチ名は `remote_ref` から導出する

`refs/heads/<name>` の接頭辞を除いた値を `gh pr list --head` に渡す。ローカル名とリモート名が異なる push（`git push origin local:remote`）でも、PR が紐づくのはリモート側のブランチ名であるため。

### D6: 導入済み repo への反映は Step 6 の再実行

フックは生成物であり自動更新の仕組みを持たない。SKILL.md に「Step 6 のみ再実行」の手順を書き、`.githooks/pre-push` を上書き・`chmod +x`・`core.hooksPath` を確認する。

## Risks / Trade-offs

- **push が 1 秒弱遅くなる（`gh` 呼び出し 2 回）** → main/master 判定を先に済ませ、削除 push を早期 `continue` することで無駄な呼び出しを避ける。事故 1 件の調査コストに比べれば許容範囲
- **fail-open のため、オフライン時は事故を止められない** → 多層防御の第 2・第 3 層（head branch 自動削除、`/wt-clean`）で回収する前提とし、SKILL.md にその旨を書く
- **closed PR のブランチへの push は素通し** → 意図的な非対応（Non-Goals）。運用で問題が出たら別 issue で再検討する
- **導入済み repo でフックが古いまま残る** → 古いフックでも main 直 push 拒否は動作し続ける（後方互換）。再適用手順を SKILL.md に明記して差分を埋める
- **`gh` が別アカウントで認証されている場合に誤判定** → PR が見えなければ merged 0 件となり fail-open 側に倒れるため、push を誤って止めることはない
