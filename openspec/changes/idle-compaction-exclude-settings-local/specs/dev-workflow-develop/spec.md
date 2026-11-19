## MODIFIED Requirements

### Requirement: idle compaction の設定操作は既存設定と承認規則を保つ
設定部品は check と apply を分け、idleCompaction 以外の値を保持し、false 済みは無変更としなければならない（MUST）。apply が設定ファイルを書くときは、書く前に、そのリポジトリの `git rev-parse --git-common-dir` が指すディレクトリの `info/exclude` に `.claude/settings.local.json` の行を足し、同じ行が既にあれば足さない（MUST）。`.gitignore` と追跡状態は変えてはならず（MUST NOT）、exclude を書けないときは設定ファイルを書かず失敗とする。check と、何も書かない apply は exclude に触れない。この exclude への追記は継続適用の範囲に含め（「別ファイル」への書き込みの例外にしない）、承認宣言の文面にも「共有 `info/exclude` への `.claude/settings.local.json` の 1 行の追記」を含める（MUST）。この要件の守備範囲で入力として扱うのは、利用者の設定ファイル、worktree のパス、既存の `info/exclude` の中身である。拾いたい誤りは、書いた設定ファイルが `git status --porcelain` に出ること、exclude に同じ行が重複すること、ファイルの追跡状態が変わることである。一方、`/.claude/settings.local.json` や glob のような表記違いの同義行は、完全一致ではないので 1 行足してよい（通してよい入力）。既存行の判定は完全一致だけで、symlink の拒否は従来どおり設定ファイルの経路に限る。表記違いや想定外の exclude の書き方まで穴を塞ぎ切ることは、この要件の完了条件にしない。PR 本文とリスク宣言に継続適用の範囲を明記し、主のマージ承認（リスク宣言の許容）をその範囲への一度の承認として記録する（MUST）。承認後の develop 開始では worktree ごとに操作承認を確認・質問してはならない（MUST NOT）。承認前の実設定変更や権限・hooks による迂回はせず、他キー・別ファイル・symlink 先は従来の聖域承認を要する（MUST）。他セッションへの持続・自動復元しないこと・戻し方も案内する。

#### Scenario: 他キーを保持し false 済みを変更しない
- **WHEN** permissions、hooks、任意の未知キーを持つ正常な設定に apply する
- **THEN** idleCompaction だけが false となり、他キーの値が保存される
- **AND** 再適用では内容と mtime が変わらず、ホームや共有設定に書き込みが無い

#### Scenario: apply のあと設定ファイルが dirty に出ない
- **WHEN** 設定ファイルが無い worktree に apply し、`git status --porcelain` を見る
- **THEN** `.claude/settings.local.json` は出ず、共有の `info/exclude` にその行が 1 行だけある
- **AND** 別の未コミットファイルがある worktree では、そのファイルだけが porcelain に出る

#### Scenario: 表記違いの同義行は完全一致でないので足す
- **WHEN** `info/exclude` に `/.claude/settings.local.json` や `.claude/*` だけがある状態で apply する
- **THEN** `.claude/settings.local.json` の行が 1 行足される

#### Scenario: exclude に同じ行があれば足さず、追跡済みなら追跡を変えない
- **WHEN** `info/exclude` に既に同じ行がある、または設定ファイルが既に追跡対象のリポジトリで apply する
- **THEN** 行は重複せず、追跡対象のファイルは追跡されたままである

#### Scenario: 一度承認した仕組みを新しい worktree でも質問せず適用する
- **WHEN** 主が上記の継続適用の範囲を記した PR のマージを承認し、リスク宣言を許容した仕組みで、新しい worktree の develop を開始する
- **THEN** check が exit 2 なら本体は当該キーだけの apply を行い、対象 worktree ごとの承認確認や追加質問を行わない
- **AND** PR 本文とリスク宣言の両方に「develop 開始時、現在の worktree の `.claude/settings.local.json` の idleCompaction だけを false にする。他の設定値は保持し、ホーム・共有設定には書かない」と記し、新しい worktree・新セッション・interactive / unmanned にも継続適用する範囲を含める
- **AND** 同じ文面に、共有 `info/exclude` への `.claude/settings.local.json` の 1 行の追記も継続適用の範囲として含める
- **AND** R1 の APPROVE やエージェントの投稿だけを主の承認と読み替えない

#### Scenario: 新規ファイルも一度の承認の範囲で作る
- **WHEN** 継続適用を承認された仕組みで develop を開始し、local 設定が無い
- **THEN** apply は idleCompaction false だけの JSON object を作り、共有設定やユーザー設定を複製しない

#### Scenario: 継続適用の範囲外には従来の承認を残す
- **WHEN** 他キー・別ファイル（共有 `info/exclude` への上記 1 行を除く）・symlink 先への書き込みが必要になる
- **THEN** この PR の承認を流用せず従来の聖域承認を求め、専用部品は symlink を追って書かない

#### Scenario: 仕組み自体の承認前は実設定を変えない
- **WHEN** PR は仕様・レビュー中で、主のマージ承認とリスク宣言の許容がまだ無い
- **THEN** 実 worktree の設定へ apply せず、仕様の作成や隔離した fixture の検証を承認済みと取り違えない
