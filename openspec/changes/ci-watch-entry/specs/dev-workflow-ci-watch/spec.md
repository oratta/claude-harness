## ADDED Requirements

### Requirement: ゲート未通過 PR の CI を見張る入口がある

dev-workflow は `/ci-watch <PR>` の入口を持ち、対象 PR の URL または番号を受け取らなければならない（MUST）。番号は現在のリポジトリの PR、URL は URL が示すリポジトリの PR として扱い、対象を解決できなければ見張りを始めてはならない（MUST NOT）。メインセッションは `plugins/dev-workflow/references/ci-watch.md` の開始判定と開始・終了コメント、`scripts/ci-watch.sh wait` / `next`、各 `act` の手順を再利用しなければならない（MUST）。独立した待機・仕分け規則を入口に持ってはならない（MUST NOT）。

`wait` が `ci-fail` を返し `obs.retry=false` なら、入口の呼び出し側は共有 reference のログと PR 差分の 2 条件を確認し、両方を満たすチェック名だけを `ci-watch.sh next --unrelated <チェック名>` に渡さなければならない（MUST）。一時的に落ちるテストもこの経路で扱い、手がかりが足りなければ `--unrelated` を渡さず `fix` に回す（MUST）。やり直しの回数は `pr-state.sh` の同一 HEAD で 1 回という既存の判定に従う（MUST）。実行の一手と結果は対象 PR にコメントとして記録しなければならない（MUST）。

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

### Requirement: 条件付きのマージ依頼は既存のゲートと権限の範囲で扱う

オーナー本人から当該 PR について「CI が通ったらマージして」と直接依頼された場合、その依頼は当該 PR が CI 成功と既存ゲート・リポジトリ運用の条件を満たした後にマージへ進める意思として扱わなければならない（MUST）。入口からの `ready` はゲート合格と同一視せず、`pr-review-gate` の合格が確定するまで、マージ待ち・マージ依頼へ進んではならない（MUST NOT）。合格後の扱いは `references/ci-watch.md` の「`ready` を受けたあと」に従う（MUST）。

この依頼を、ゲート省略、別 PR のマージ、別 HEAD のリスク許容、main への直接 push、rebase・force-push、LLM による `gh pr merge` または merge API の承認として扱ってはならない（MUST NOT）。自動マージが使えないか、マージを止めるラベルがあるときは、PR URL を添えて人間にマージを依頼しなければならない（MUST）。

守備範囲: 承認判断の入力は、オーナー本人からの当該 PR を指定した依頼と、共有 reference が取得する CI・ラベル・ゲート結果である。拾いたい誤りは、CI green だけでゲートを飛ばすことと、依頼の対象や権限を広げて直接マージすることである。オーナーが曖昧な表現で別の PR を意図していた場合や、GitHub が直後に古い CI 状態を返す場合は、依頼の再確認または共有 reference の観測結果に従うことで進行が遅れることを許す。自然言語の意図や GitHub の状態遅延を完全に解消することは、この要件の完了条件にしない。

#### Scenario: CI は通ったがゲート未通過
- **WHEN** 入口から見張った PR が `ready` になり、ゲートの合格記録がまだない
- **THEN** 入口はゲートを実施し、合格が確定するまでマージ待ち・依頼に進まない

#### Scenario: 自動マージできない
- **WHEN** ゲート合格後の PR にマージを止めるラベルがある、または自動マージ workflow がない
- **THEN** 入口は直接 merge API を呼ばず、PR URL を添えて人間にマージを依頼する
