## MODIFIED Requirements

### Requirement: エピックの入口は読み手と場面ごとに読むものを案内する

エピックの手順書は入口 `references/epic.md` に読み手・読む場面・参照先の表を置き、nested の子には親の起動・片付け・見張りの本文を読ませず、親の開始時には停止・マージ待ち・別 repo・サブエージェント方式の操作本文を読ませてはならない（MUST NOT）。各場面へ入る前にその文書を読む指示を置く（MUST）。

分割後の別ファイルにある規則は、実在するファイル名と節名または段落名で案内しなければならない（MUST）。時間分類はその正本を参照し、案内元で閾値を重複して定めてはならない（MUST NOT）。指定されたテストの所在説明コメントと公開版分類 docs の現行参照も、同じ配置を指す（MUST）。サブエージェント方式の利用条件・本体 worktree の片付けの説明は、分割前の意味を維持する（MUST）。

#### Scenario: nested の子が開始して止まる
- **WHEN** nested の子が注意書きを受け、後で主の返事待ちになる
- **THEN** 入口で注意書きの信頼条件を確認し、停止前に epic-child-stop.md と epic-keepalive.md と共有 JSON を読み、`主に聞く理由:` を書く前に parent-pass-criteria.md の「例」を読む（読込量は同ファイル全文を数える）。W の並列枠が必要なら epic-worker-slots.md だけを追加し、親の起動・片付け・見張りの手順は読まない

#### Scenario: 親が開始し停止した子を扱う
- **WHEN** 別セッション方式の親が開始し、後で stopped または pending-owner の子を処理する
- **THEN** 開始時は epic.md と epic-loop.md、停止解決に入る前は epic-stop.md と関連する子の記録契約・判断基準・時間分類、および親の送信判定の正本 epic-keepalive-watch.md を読む。マージ待ち・委任・別 repo は該当時だけ追加する

#### Scenario: 移した規則はその場面で読める
- **WHEN** 親が委任を受ける、または子が委任の添え書きのある返事を受ける
- **THEN** 親子とも epic-delegation.md の同じ有効性・種類別条件を読み、親の投稿・送信の操作は epic-stop.md、子の受信・真正性確認の操作は epic-child-stop.md にある

#### Scenario: 親の時間分類と報告とマージ待ちの参照が正本に届く
- **WHEN** 親が epic-loop.md の「主への報告」または手順9、epic-stop.md の手順8、epic-loop.md のマージ権限の説明を読む
- **THEN** 時間分類は reply-after-idle.md「親への適用」、報告形式は epic-loop.md「主への報告」、マージ待ちは epic-merge-wait.md「マージ待ちの子」への参照から確認できる。時間分類の値と分岐、報告・承認・マージの条件は変わらない

#### Scenario: 入口とサブエージェント方式の説明が単独で読める
- **WHEN** epic.md の共通規則と epic-subagent.md を読む
- **THEN** 共通規則は別セッション方式とサブエージェント方式の両方に適用すると分かる。サブエージェント方式がいつでも使えること、同方式に別セッション方式の kept 後の本体 worktree を消す操作は無いことが分かる。別リポジトリの子を起こさない制約と W ごとの隔離 worktree の規定は維持される

#### Scenario: 声かけの後の通常の再開判定を確認できる
- **WHEN** 親が epic-keepalive-watch.md の停止中の子へのキャッシュ維持の説明を読む
- **THEN** 実際の返事が来たときの再開判定は reply-after-idle.md「そのまま送るか、起動し直すか（子）」への参照から確認できる。声かけの送信条件と子の再開判定は変わらない

#### Scenario: 指定されたテストと公開版分類の説明が現在の配置を指す
- **WHEN** epic-dispatch.bats・parent-merge.bats の回し方の所在を説明するコメントと、docs/public-private-split.md の「差し替え可能な起動部品の1つとして Orca を並べた行」の説明を読む
- **THEN** epic-dispatch.bats のコメントは epic-loop.md の通常進行・同時に動く子の上限と epic-subagent.md の該当段落を指す。parent-merge.bats の「マージ待ちの子」の所在説明コメントは epic-merge-wait.md「マージ待ちの子」を指す。docs の現行説明は epic-loop.md「部品ごとの欄」を指し、過去の行番号を保存した履歴表は現行参照と区別される。公開版分類の値は変わらない
