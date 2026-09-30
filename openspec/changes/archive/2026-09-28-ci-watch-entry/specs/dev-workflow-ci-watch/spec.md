## ADDED Requirements

### Requirement: ゲート未通過 PR の CI を見張る入口がある

dev-workflow は `/ci-watch <PR> [--merge]` の入口を持ち、対象 PR の URL または番号と、マージ依頼を表す任意の `--merge` 引数を受け取らなければならない（MUST）。番号は現在のリポジトリの PR、URL は URL が示すリポジトリの PR として扱い、対象を解決できなければ見張りを始めてはならない（MUST NOT）。メインセッションは `plugins/dev-workflow/references/ci-watch.md` の開始判定と開始・終了コメント、`scripts/ci-watch.sh wait` / `next`、各 `act` の手順を再利用しなければならない（MUST）。独立した待機・仕分け規則を入口に持ってはならない（MUST NOT）。

`wait` が `ci-fail` を返し `obs.retry=false` なら、入口の呼び出し側は共有 reference のログと PR 差分の 2 条件を確認し、両方を満たすチェック名だけを `ci-watch.sh next --unrelated <チェック名>` に渡さなければならない（MUST）。一時的に落ちるテストもこの経路で扱い、手がかりが足りなければ `--unrelated` を渡さず `fix` に回す（MUST）。やり直しの回数は `pr-state.sh` の同一 HEAD で 1 回という既存の判定に従う（MUST）。`next` が `fix` を返したら、メインセッションは自分で直さず、実装者のサブエージェント（model は sonnet）を起こして共有 reference「7. 直し方」で直させなければならない（MUST）。実装者が PR の差分と関係ない失敗だと返したら、メインセッションは `ci-watch.sh next --unrelated <チェック名> --after-fix` を 1 回だけ実行し、その一手に従わなければならない（MUST）。実行の一手と結果は対象 PR にコメントとして記録しなければならない（MUST）。

守備範囲: 入口が受け取る対象はオーナーの依頼に含まれる PR URL または番号、対象 PR と CI の観測は GitHub CLI、関係ない失敗の判断材料は共有 reference が定める落ちた run のログ末尾と PR の変更ファイル一覧に限る。拾いたい誤りは、別 PR を見張ること、ゲート未通過 PR の失敗を放置すること、理由のない CI 失敗を一時的な失敗として再実行することである。ログ末尾に原因が出ない失敗や、変更ファイルを間接的に読むテストの失敗を取り違える入力は、そのまま `fix` または同一 HEAD で 1 回の誤った再実行へ進むことを許す。GitHub の観測遅延やログから因果関係を完全に判定する穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: URL または番号を受け取る
- **WHEN** オーナーが `/ci-watch <PR URL>` または `/ci-watch <PR番号>` で対象 PR を指定する
- **THEN** 入口は対象 PR を解決し、共有 reference の開始判定と `ci-watch.sh wait` に接続する

#### Scenario: ゲート未通過 PR の CI 失敗から一手へ進む
- **WHEN** ゲート未通過 PR の CI が落ち、`wait` が `ci-fail` を返す
- **THEN** 呼び出し側は共有 reference の基準で `--unrelated` の有無を決めて `next` を呼び、`rerun` または `fix` の一手と結果を PR に記録する

#### Scenario: PR の対象を解決できない
- **WHEN** URL または番号から対象 PR を解決できない
- **THEN** 入口は `ci-watch.sh wait` を開始せず、対象を確認するよう呼び出し元に伝える

#### Scenario: 実装者が関係ない失敗と返す
- **WHEN** `fix` の直しを頼んだ実装者が、ログを読んで PR の差分と関係ない失敗だと返す
- **THEN** メインセッションは push せずに `ci-watch.sh next --unrelated <チェック名> --after-fix` を 1 回だけ実行し、その一手に従う

### Requirement: マージ依頼の無い見張りは `ready` で終える

入口は、マージ依頼の有無を `--merge` 引数の有無だけで決めなければならない（MUST）。依頼文の自由文からマージ依頼を推定してはならない（MUST NOT）。`--merge` が無い見張りで `ready` を受けたら、`pr-review-gate` を実施してはならず、ラベルを付け外ししてはならない（MUST NOT）。1 行目が `CI 見張り終了:` のコメントを PR に投稿し、CI が通ったことを PR の URL を添えてオーナーに伝えて見張りを終えなければならない（MUST）。

守備範囲: 判定の入力は `/ci-watch` の呼び出しに `--merge` が含まれるかどうかだけである。拾いたい誤りは、見張りだけを頼まれた PR でゲートを回し、`agent-review:passed` を付けて auto-merge.yml による承認の無いマージを起こすことである。オーナーが自由文でマージを頼みながら `--merge` を付け忘れた入力は、見張りが `ready` で終わってマージが 1 往復遅れることを許す。PR に既に `agent-review:passed` が付いていて、見張りと無関係に自動マージが進むことを止めることは、この要件の完了条件にしない。

#### Scenario: マージ依頼なしで CI が通る
- **WHEN** オーナーが `--merge` を付けずに `/ci-watch <PR>` で見張りを始め、`next` が `ready` を返す
- **THEN** 入口はゲートを実施せず、ラベルを付け外しせずに `CI 見張り終了:` を PR に投稿し、PR の URL を添えて CI が通ったことをオーナーに伝える

#### Scenario: 自由文のマージ依頼は `--merge` として扱わない
- **WHEN** オーナーの依頼文に「マージして」とあるが、`/ci-watch` の呼び出しに `--merge` が無い
- **THEN** 入口はマージ依頼が無いものとして見張り、`ready` でゲートとマージに進まずに見張りを終える

### Requirement: 条件付きのマージ依頼は既存のゲートと権限の範囲で扱う

オーナー本人が当該 PR について `/ci-watch <PR> --merge` で「CI が通ったらマージして」と直接依頼した場合、その依頼は当該 PR が CI 成功と既存ゲート・リポジトリ運用の条件を満たした後にマージへ進める意思として扱わなければならない（MUST）。入口からの `ready` はゲート合格と同一視せず、`pr-review-gate` の合格が確定するまで、マージ待ち・マージ依頼へ進んではならない（MUST NOT）。合格後の扱いは `references/ci-watch.md` の「`ready` を受けたあと」に従う（MUST）。

この依頼を、ゲート省略、別 PR のマージ、別 HEAD のリスク許容、main への直接 push、rebase・force-push、LLM による `gh pr merge` または merge API の承認として扱ってはならない（MUST NOT）。自動マージが使えないか、マージを止めるラベルがあるときは、PR URL を添えて人間にマージを依頼しなければならない（MUST）。

守備範囲: 承認判断の入力は、オーナー本人が当該 PR を指定して付けた `--merge` と、共有 reference が取得する CI・ラベル・ゲート結果である。拾いたい誤りは、CI green だけでゲートを飛ばすことと、依頼の対象や権限を広げて直接マージすることである。オーナーが曖昧な表現で別の PR を意図していた場合や、GitHub が直後に古い CI 状態を返す場合は、依頼の再確認または共有 reference の観測結果に従うことで進行が遅れることを許す。自然言語の意図や GitHub の状態遅延を完全に解消することは、この要件の完了条件にしない。

#### Scenario: CI は通ったがゲート未通過
- **WHEN** オーナーが `/ci-watch <PR> --merge` で当該 PR のマージを依頼しており、見張った PR が `ready` になり、ゲートの合格記録がまだない
- **THEN** 入口はゲートを実施し、合格が確定するまでマージ待ち・依頼に進まない

#### Scenario: 自動マージできない
- **WHEN** オーナーが `/ci-watch <PR> --merge` で当該 PR のマージを依頼しており、ゲート合格後の PR にマージを止めるラベルがある、または自動マージ workflow がない
- **THEN** 入口は直接 merge API を呼ばず、PR URL を添えて人間にマージを依頼する
