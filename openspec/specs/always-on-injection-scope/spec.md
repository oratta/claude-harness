# always-on-injection-scope Specification

## Purpose
全セッション・全サブエージェントに常時載る文書（`rules/` / `CLAUDE.md` / 各種 `description`）を発火条件と要点までに留め、詳細は削除せず任意の cwd から辿れる移設先へ移す規約。常時注入に残すべきルールの判定条件、path スコープ（`paths:`）の採用条件、削減後の予算ファイル引き下げを含む。
## Requirements
### Requirement: 常時注入の文書は発火条件と要点までに留める

`rules/*.md`（README を除く）・`CLAUDE.md`・skill / agent / command の frontmatter `description` は、**いつそれが必要になるか（発火条件）と、守るべき要点**だけを持たなければならない（MUST）。手順・経緯・理由の説明・具体例は、常時注入されない場所（skill 本文、`references/`、`docs/`）へ置かなければならない（MUST）。

`description` は全 skill 分が起動時に載り、本文はその skill を起動したときだけ読まれる。したがって `description` には起動語と発火条件だけを書き、手順・禁止事項・背景を書いてはならない（MUST NOT）。

**この要件の対象から外すもの**:

- `output-styles/*.md` は対象外とする。これは書き方の正本そのもので、要点への縮約は正本の欠落を意味する（参照先を持たない文書なので、移設先が存在しない）。メインセッションにしか載らず、サブエージェントには載らない点も、常時注入の削減対象としての優先度を下げる
- **ツールが生成し、再生成されうるファイル**は対象外とする（MUST NOT 違反としない）。`openspec init` / `openspec update` が生成する `.claude/skills/openspec-*/SKILL.md` と `.claude/commands/opsx/*.md` がこれに当たる。手で縮約しても次の再生成で戻るため、要件の対象に含めると再生成のたびに spec 違反になる。これらを減らす場合は生成側（生成対象を絞る設定）で行う

#### Scenario: 常時注入の合計が予算の引き下げとして現れる

- **WHEN** `tests/injection-budget.txt` を着手前実測の 70% 以下の値に引き下げた状態で `scripts/test.sh injection-budget` を実行する
- **THEN** exit code が 0 である（予算超過の側でも、予算過大の側でも落ちない）

#### Scenario: 縮約した skill が従来の依頼文で起動する

- **WHEN** `description` を縮約した skill のうち 1 件を、その skill が想定する実際の依頼文で呼ぶ
- **THEN** その skill が起動する（起動語が `description` に残っている）

#### Scenario: 生成物の description は違反にならない

- **WHEN** `.claude/skills/openspec-*/SKILL.md` と `.claude/commands/opsx/*.md` の `description` を、縮約されていない生成時のままの状態で検査する
- **THEN** この要件の違反として扱われない

### Requirement: 常時性を手放してはいけないルールを縮約対象から外す

**読むべき瞬間に、そのルールを読もうと判断できないルール**は、常時注入から外してはならない（MUST NOT）。判定条件は「そのルールが止めようとしている行動を思いついた時点で、先に skill や references を読む判断ができるか」であり、できないものは常時注入に残す。

この判定は path スコープの採否にも掛かる（MUST）。対象パスのファイルを読んで初めて載る形では、**そのファイルを読まないまま起きる事故**を防げない。読むべき瞬間にどのファイルも読んでいないルールに `paths:` を付けてはならない（MUST NOT）。

次のルールはこの条件に当たるため、常時注入に残さなければならない（MUST）。いずれも `paths:` を付けてはならない（MUST NOT）。

- 破壊的 git 操作の禁止（`rules/destructive-git-guard.md`）: 「戻すだけ」と思った瞬間が読むべき瞬間で、その時点で skill を呼ぶ判断ができない
- 他プロジェクトのプロセスを kill してポートを確保する禁止（`rules/dev-server.md`）: 同じ
- ダッシュボードで表示されたシークレットの即時保存（`rules/browser-infra-env-capture.md`）: 読むべき瞬間はシークレットが画面に表示された時で、そのときエディタではどのファイルも読んでいない。`.env*` を触って初めて載る形では「保存しようと思わなかった」事故を防げない

#### Scenario: 常時性を手放せないルールが常時注入に残っている

- **WHEN** `rules/` の一覧と各ファイルの frontmatter を見る
- **THEN** `destructive-git-guard.md`・`dev-server.md`・`browser-infra-env-capture.md` が実ファイルとして存在し、いずれも `paths:` を持たず、それぞれの禁止事項（承認なしに実行しない操作の一覧、他プロジェクトのプロセスを kill しない、表示された次のアクションで保存する）が本文に残っている

### Requirement: 縮約は削除ではなく移設で、移設先を任意の cwd から辿れる形にする

常時注入から削った記述は、削除してはならない（MUST NOT）。移設先のファイルに同じ内容を残さなければならない（MUST）。

`rules/*.md` は symlink で**全プロジェクト**のセッションに載るため、移設先は harness のリポジトリを cwd に持たないセッションからも解決できる形で書かなければならない（MUST）。リポジトリ相対パス（`plugins/casting/skills/casting/SKILL.md`・`docs/worktree-recovery.md` 等）で書いてはならない（MUST NOT）。他プロジェクトで作業中にそのルールが発火したとき、そのパスは Read できず、移設した内容に誰も届かなくなる。

解決できる形とは次の 2 つをいう。

- skill へ移す場合: **スキル名**で書く（`casting:casting`・`dev-workflow:pr-review-gate`）。スキルはどの cwd からでも起動できる
- `references/` / `docs/` へ移す場合: **`~/.claude/plugins/marketplaces/oratta-claude-harness/<path>`** の形で書く

加えて `rules/README.md` のファイル一覧表に、ルールごとの移設先を書かなければならない（MUST）。`rules/README.md` は集計対象外（`list_synced_md` が除外する）なので、ここに書いても常時注入の合計は増えない。

#### Scenario: 縮約したルールから移設先を辿れる

- **WHEN** 縮約した各ルールの本文を読む
- **THEN** 詳細の移設先がスキル名か `~/.claude/plugins/marketplaces/oratta-claude-harness/` から始まる絶対パスで書かれており、その解決先（該当スキル、または展開後のファイル）が実在する

#### Scenario: 移設先にリポジトリ相対パスが残っていない

- **WHEN** 縮約した各ルールの本文から、移設先として示されたパスを集める
- **THEN** `plugins/`・`docs/`・`scripts/` 等で始まるリポジトリ相対パスが 1 つも含まれていない

#### Scenario: README の一覧表が移設先を持つ

- **WHEN** `rules/README.md` のファイル一覧表を読む
- **THEN** 縮約した各ルールの行に、同じ解決できる形の移設先が書かれている

### Requirement: path スコープは配布形での両方向の実機確認を経てから採用する

rules frontmatter の `paths:`（glob のリスト）による条件付き注入は、**手元の Claude Code で実際に動くことを確認してからでなければ採用してはならない**（MUST NOT adopt without verification）。ユーザーレベル `~/.claude/rules/` で `paths:` が効かない不具合報告（anthropics/claude-code#22170、#17204）があるため、公式仕様だけを根拠に採用してはならない。

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

#### Scenario: path スコープが効かなかった場合は使わない

- **WHEN** 上のいずれかの確認で、一致しないセッションでもルールが載る（または一致するセッションで載らない）
- **THEN** `rules/*.md` のいずれにも `paths:` を追加せず、縮約と移設だけで予算の引き下げを達成する。効かなかった事実と判断が記録先に残っている

### Requirement: 削減後は予算ファイルを実測に合わせて引き下げる

`tests/injection-budget.txt` の予算は上下両方向のラチェットとして働き、実測が予算の 1/1.1 を下回っても fail する。したがって削減した場合は、同じ変更の中で予算値を引き下げなければならない（MUST）。

予算値は削減後の実測に対して、上下どちらのラチェットにも当たらない余裕を持つ値に置かなければならない（MUST）。

縮約後の `rules/*.md` に、予算ファイルの規約（`injection-budget` の語を含む記述）を書いてはならない（MUST NOT）。このリポジトリ固有の規約を全プロジェクトに載る場所へ置くと、この変更自身が減らそうとしている固定分を増やすことになる。予算ファイルの変更手続きは `CLAUDE.md` に残さなければならない（MUST。既存の要件「予算ファイルの変更手続きを CLAUDE.md に定める」がこれを要求している）。

#### Scenario: 削減後にテストが通る

- **WHEN** rules と description の縮約を終えたあと `scripts/test.sh injection-budget` を実行する
- **THEN** exit code が 0 である（予算超過でも予算過大でも落ちない）

#### Scenario: 予算の規約が rules に持ち込まれていない

- **WHEN** 縮約後の `rules/` 配下を `injection-budget` で検索する
- **THEN** 1 件も一致しない

#### Scenario: リポジトリ全体のテストが通る

- **WHEN** `scripts/test.sh` を実行する
- **THEN** exit code が 0 である（`rules-sync` と `agents-md-sync` を含む）

