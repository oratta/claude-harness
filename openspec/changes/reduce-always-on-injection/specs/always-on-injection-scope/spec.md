## ADDED Requirements

### Requirement: 常時注入の文書は発火条件と要点までに留める

`rules/*.md`（README を除く）・`CLAUDE.md`・`output-styles/*.md`・skill / agent / command の frontmatter `description` は、**いつそれが必要になるか（発火条件）と、守るべき要点**だけを持たなければならない（MUST）。手順・経緯・理由の説明・具体例は、常時注入されない場所（skill 本文、`references/`、`docs/`）へ置かなければならない（MUST）。

`description` は全 skill 分が起動時に載り、本文はその skill を起動したときだけ読まれる。したがって `description` には起動語と発火条件だけを書き、手順・禁止事項・背景を書いてはならない（MUST NOT）。

#### Scenario: 常時注入の合計が着手前から 30% 以上減る

- **WHEN** `scripts/test.sh injection-budget` を実行し、内訳の合計を読む
- **THEN** 合計が 36,395 バイト以下である（着手前 51,993 バイトの 70%）

#### Scenario: 縮約した skill が従来の依頼文で起動する

- **WHEN** `description` を縮約した skill のうち 1 件を、その skill が想定する実際の依頼文で呼ぶ
- **THEN** その skill が起動する（起動語が `description` に残っている）

### Requirement: 常時性を手放してはいけないルールを縮約対象から外す

**読むべき瞬間に、そのルールを読もうと判断できないルール**は、常時注入から外してはならない（MUST NOT）。判定条件は「そのルールが止めようとしている行動を思いついた時点で、先に skill や references を読む判断ができるか」であり、できないものは常時注入に残す。

破壊的 git 操作の禁止（`rules/destructive-git-guard.md`）と、他プロジェクトのプロセスを kill してポートを確保する禁止（`rules/dev-server.md`）は、この条件に当たるため常時注入に残さなければならない（MUST）。

#### Scenario: 常時性を手放せないルールが常時注入に残っている

- **WHEN** `rules/` の一覧を見る
- **THEN** `destructive-git-guard.md` と `dev-server.md` が `paths:` を持たない実ファイルとして存在し、それぞれの禁止事項（承認なしに実行しない操作の一覧、他プロジェクトのプロセスを kill しない）が本文に残っている

### Requirement: 縮約は削除ではなく移設で、移設先を辿れる形にする

常時注入から削った記述は、削除してはならない（MUST NOT）。移設先のファイルに同じ内容を残さなければならない（MUST）。

縮約した各ルールは、詳細の移設先パスを本文に 1 行で示さなければならない（MUST）。加えて `rules/README.md` のファイル一覧表に、ルールごとの移設先を書かなければならない（MUST）。`rules/README.md` は集計対象外（`list_synced_md` が除外する）なので、ここに書いても常時注入の合計は増えない。

#### Scenario: 縮約したルールから移設先を辿れる

- **WHEN** 縮約した各ルールの本文を読む
- **THEN** 詳細の移設先がリポジトリ内のパスとして書かれており、そのパスが実在する

#### Scenario: README の一覧表が移設先を持つ

- **WHEN** `rules/README.md` のファイル一覧表を読む
- **THEN** 縮約した各ルールの行に移設先が書かれている

### Requirement: path スコープは両方向の実機確認を経てから採用する

rules frontmatter の `paths:`（glob のリスト）による条件付き注入は、**手元の Claude Code で実際に動くことを確認してからでなければ採用してはならない**（MUST NOT adopt without verification）。ユーザーレベル `~/.claude/rules/` で `paths:` が効かない不具合報告（anthropics/claude-code#22170、#17204）があるため、公式仕様だけを根拠に採用してはならない。

確認は**両方向**でなければならない（MUST）。対象パスに一致するファイルを読んだセッションでそのルールが載ること、および対象パスに一致するファイルを読まないセッションでそのルールが載らないこと、の両方を確かめる。片方向（載ること）だけの確認では、常に載っている状態を「効いた」と誤認するため不十分とする。

確認結果は記録先（GitHub issue #260 または PR）に証拠つきで残さなければならない（MUST）。

#### Scenario: path スコープが効くことを両方向で確認する

- **WHEN** `paths:` を付けた検証用ルールを 1 本置き、対象パスに一致するファイルを読むセッションと、読まないセッションの 2 つでそのルールが載るかを見る
- **THEN** 一致するセッションでは載り、一致しないセッションでは載らない。両方の結果が記録先に証拠つきで投稿されている

#### Scenario: path スコープが効かなかった場合は使わない

- **WHEN** 上の確認で、一致しないセッションでもルールが載る（または一致するセッションで載らない）
- **THEN** `rules/*.md` のいずれにも `paths:` を追加せず、縮約と移設だけで合計 36,395 バイト以下を達成する。効かなかった事実と判断が記録先に残っている

### Requirement: 削減後は予算ファイルを実測に合わせて引き下げる

`tests/injection-budget.txt` の予算は上下両方向のラチェットとして働き、実測が予算の 1/1.1 を下回っても fail する。したがって削減した場合は、同じ変更の中で予算値を引き下げなければならない（MUST）。

予算値は削減後の実測に対して、上下どちらのラチェットにも当たらない余裕を持つ値に置かなければならない（MUST）。

#### Scenario: 削減後にテストが通る

- **WHEN** rules と description の縮約を終えたあと `scripts/test.sh injection-budget` を実行する
- **THEN** exit code が 0 である（予算超過でも予算過大でも落ちない）

#### Scenario: リポジトリ全体のテストが通る

- **WHEN** `scripts/test.sh` を実行する
- **THEN** exit code が 0 である（`rules-sync` と `agents-md-sync` を含む）
