## MODIFIED Requirements

### Requirement: path スコープは配布形での両方向の実機確認を経てから採用する

rules frontmatter の `paths:`（glob のリスト）による条件付き注入は、**手元の Claude Code で実際に動くことを確認してからでなければ採用してはならない**（MUST NOT adopt without verification）。ユーザーレベル `~/.claude/rules/` で `paths:` が効かない不具合報告（anthropics/claude-code#22170、#17204）があるため、公式仕様だけを根拠に採用してはならない。

常時注入の集計が `paths:` を理由に除外してよいのは、**rules の frontmatter にある非空の glob リスト**だけである（MUST）。コメント付きの glob（`- "**" # scope`）は行末コメントを除いて読み、`paths: null` や空のキーのようなリストでない値は、スコープにならず常時注入のままなので除外してはならない（MUST NOT）。output-styles には `paths:` フィールドが無く、選択中の本文は毎回載るので、`paths:` の有無にかかわらず全文を計上する（MUST）。

守備範囲: この集計が受け取る入力は、このリポジトリの `rules/*.md` と `output-styles/*.md` の frontmatter に限る。拾いたい誤りは、行末コメント付きの glob をコメントごと glob として読むことと、`paths: null` や空のキーのような効かない `paths:` を理由に常時注入の合計から外して過小計上すること、output-styles を `paths:` で外すことの 3 つ（issue #293）。次の入力は誤ったまま通ることを許す: 引用符の中の ` #`（`- "a #b"` も ` #` 以降をコメントとして落とすので、意図と違う glob として検査される）・複数行にまたがるフロー表記・アンカーやエイリアスなど YAML の他の構文・`paths:` を 2 回書いたファイル。これらは `tests/injection-budget.bats` を YAML パーサにしないための割り切りで、見つかるたびに塞ぎ切ることをこの要件の完了条件にしない。

確認は**配布形**で行わなければならない（MUST）。本番の `~/.claude/rules/<name>.md` は `scripts/sync.sh` が張る symlink であり、不具合報告は `~/.claude/rules/` の扱いに固有のものなので、実ファイルを置いて効いても symlink 形で効く証明にならない。確認用のファイルも `~/.claude/rules/<name>.md` から `paths:` を持つ実体への symlink として置かなければならない（MUST）。

確認は**両方向**でなければならない（MUST）。対象パスに一致するファイルを読んだセッションでそのルールが載ること、および対象パスに一致するファイルを読まないセッションでそのルールが載らないこと、の両方を確かめる。片方向（載ること）だけの確認では、常に載っている状態を「効いた」と誤認するため不十分とする。

確認には、**別のプロジェクトを cwd とするセッションから marketplace ディレクトリの絶対パス（`~/.claude/plugins/marketplaces/oratta-claude-harness/<path>`）のファイルを読んだ場合に glob が一致するか**を含めなければならない（MUST）。`paths:` を付ける候補である plugin-editing の主用途がこの場面だからである。

`paths:` を適用したあと、**本番のルール 1 本で両方向をもう一度確認**し、結果を記録先（GitHub issue #260 または PR）に証拠つきで残さなければならない（MUST）。検証用ファイルでの確認だけで適用を完了としてはならない（MUST NOT）。

#### Scenario: 配布形で両方向を確認する

- **WHEN** `paths:` を持つ実体への symlink を `~/.claude/rules/<name>.md` に置き、対象パスに一致するファイルを読むセッションと、読まないセッションの 2 つでそのルールが載るかを見る
- **THEN** 一致するセッションでは載り、一致しないセッションでは載らない。両方の結果が記録先に証拠つきで投稿されている

#### Scenario: 別プロジェクトの cwd から marketplace の絶対パスを読んだときに一致する

- **WHEN** harness 以外のリポジトリを cwd とするセッションから `~/.claude/plugins/marketplaces/oratta-claude-harness/` 配下のファイルを読む
- **THEN** その `paths:` を持つルールが載る（載らなければ、その glob は plugin-editing の主用途を満たさないので採用しない）

#### Scenario: 適用後に本番ルールで再確認する

- **WHEN** `rules/` の実ルールに `paths:` を付けて `scripts/sync.sh` を回したあと、そのルール 1 本について両方向を確認する
- **THEN** 一致するセッションでは載り、一致しないセッションでは載らない。その結果が記録先に証拠つきで投稿されている

#### Scenario: 効かない paths: は集計から外さない

- **WHEN** `rules/` に `paths: null` のファイルを置いて常時注入の合計を数える
- **THEN** そのファイルは常時注入として全文が計上され、glob 0 件の違反として検査が落ちる

#### Scenario: 行末コメント付きの glob はコメントを除いて検査する

- **WHEN** `paths:` の項目が `- "**" # scope/rules` のファイルを検査する
- **THEN** glob は `**` として読まれ、広すぎる glob の違反として検査が落ちる

#### Scenario: output-styles は paths: があっても全文を計上する

- **WHEN** `output-styles/` のファイルが frontmatter に `paths:` を持つ
- **THEN** 内訳の output-styles の行はそのファイルの全文を計上する

#### Scenario: path スコープが効かなかった場合は使わない

- **WHEN** 上のいずれかの確認で、一致しないセッションでもルールが載る（または一致するセッションで載らない）
- **THEN** `rules/*.md` のいずれにも `paths:` を追加せず、縮約と移設だけで予算の引き下げを達成する。効かなかった事実と判断が記録先に残っている
