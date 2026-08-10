# loops-respond-mode Specification

## Purpose
配布テンプレート（loops プラグイン）が応答モード — 人間が issue / PR コメントの行頭にメンションを書いたら、ループが他のどの自動作業よりも先にそれへ応答する経路 — を含み、`/loops:dev-agent-install` がそれを配線することを保証する。

## Requirements

### Requirement: 配布テンプレートは応答モードの検出スクリプトを含む
`plugins/loops/templates/agent-loop-inbox.sh` が存在しなければならない (SHALL)。このスクリプトは、コメント本文の**行頭**にマーカー（既定は `{{AGENT_MENTION}}` プレースホルダ、実行時は `AGENT_INBOX_MARKER`）があり、かつ「対応済み」リアクション（既定 `rocket`、`AGENT_INBOX_DONE_REACTION` で上書き可）が付いていないコメントだけを未対応として stdout に JSON 1 オブジェクトで返す (SHALL)。判定に投稿者アカウントを使ってはならない (MUST NOT)。ローカル状態ファイルを作ってはならない (MUST NOT)。どんな失敗でも exit 0 で `{"pending":[]}` を返す fail-open でなければならない (SHALL)。行頭限定・投稿者非依存・状態ファイル非保持の設計判断は、根拠のコメントごとテンプレートに含めなければならない (SHALL)。

#### Scenario: 行頭のマーカーだけが発火する
- **WHEN** issue のコメントに引用行（`> @marker …`）や地の文での言及（`` `@marker` で判定する ``）が含まれる
- **THEN** それらは未対応として返らず、行頭に書かれた呼びかけだけが返る

#### Scenario: 対応済みは rocket リアクションだけで決まる
- **WHEN** 行頭マーカー付きのコメントに rocket リアクションが付いている
- **THEN** そのコメントは未対応に含まれない（ローカルの状態ファイルは参照も生成もされない）

#### Scenario: 投稿者を問わない
- **WHEN** 行頭マーカー付きのコメントが bot 名義のアカウントから投稿されている
- **THEN** 投稿者に関わらず未対応として返る

#### Scenario: API 障害でループを止めない
- **WHEN** `gh` が利用できない、または検索 API が失敗する
- **THEN** exit 0 で `{"pending":[]}` を返し、失敗の内訳は stderr に出力される

### Requirement: 配布テンプレートは応答の投稿スクリプトを含む
`plugins/loops/templates/agent-loop-reply.sh` が存在しなければならない (SHALL)。返信の投稿と対象コメントへの「対応済み」リアクション付与を 1 コマンドで行い (SHALL)、投稿前に返信本文の行頭にマーカーが混入していないかを機械検査して、混入していれば投稿せず非 0 で終了しなければならない (SHALL)。引用行（行頭が `>`）やバッククォートで囲まれた言及は通さなければならない (SHALL)。

#### Scenario: 自己発火する返信は投稿されない
- **WHEN** 返信本文の行頭にマーカーが書かれた状態でスクリプトを実行する
- **THEN** 投稿は行われず、非 0 で終了し、回避方法（行頭に `>` を付ける / バッククォートで囲む）が示される

### Requirement: 選定スクリプトは応答モードを最優先で判定する
`plugins/loops/templates/select-target.sh` は、他のどのモードの判定よりも前に `agent-loop-inbox.sh` を呼び、未対応コメントがあれば `mode: "respond"` を `target` / `target_kind` / `comment_id` / `candidates` とともに出力して即終了しなければならない (SHALL)。この判定より前に副作用を持つ処理（ラベル書き換え等の書き込み API 呼び出し）を置いてはならない (MUST NOT)。未対応が無い場合の既存モード（review / fix / implement / propose / skip / error）の挙動を変えてはならない (MUST NOT)。

#### Scenario: 印が付いた tick は respond になる
- **WHEN** 行頭マーカー付きで未リアクションのコメントが 1 件以上ある
- **THEN** `mode:"respond"` が返り、`comment_id` に対応済み化の宛先が入り、書き込み API は呼ばれない

#### Scenario: 印が無い tick は従来どおり
- **WHEN** 未対応コメントが 1 件も無い
- **THEN** 従来のモード判定（review → fix → implement → propose/skip）にそのまま落ちる

### Requirement: 憲法テンプレートは応答モードを定義する
`plugins/loops/templates/agent-loop-template.md` は、Step 0.9 の出力表に `respond` モードと `comment_id` フィールドを含み、`respond` を最優先とする優先順位を明記しなければならない (SHALL)。あわせて応答モードの手順（未対応・対応済みの定義、行頭限定の理由、返信は `scripts/agent-loop-reply.sh` 経由に限ること、除外ラベルは `human-only` / `agent-wip` のみで `agent-blocked` を除外しないこと）を含めなければならない (SHALL)。エージェント自身が返信本文の行頭にマーカーを書くことを禁止しなければならない (SHALL)。

#### Scenario: 憲法から応答モードの実行方法が分かる
- **WHEN** 導入先のエージェントが `mode:"respond"` を受け取って憲法を読む
- **THEN** 対象コメントの読み方・返信の作り方・`agent-loop-reply.sh` による投稿と rocket 付与の手順が書かれている

### Requirement: install スキルはループのスクリプトを 3 本とも配置する
`plugins/loops/skills/loops-dev-agent-install/SKILL.md` は、`scripts/agent-loop-select.sh` / `scripts/agent-loop-inbox.sh` / `scripts/agent-loop-reply.sh` の 3 本を配置し、実行権限を付け、`{{AGENT_MENTION}}` を含むプレースホルダの置換漏れと `bash -n` の構文を実測確認する手順を含めなければならない (SHALL)。マーカーはヒアリング項目として確定し (SHALL)、既に導入済みのリポジトリへ後から配線する手順を含めなければならない (SHALL)。

#### Scenario: 新規導入で応答モードが配線される
- **WHEN** `/loops:dev-agent-install` を実行する
- **THEN** 3 本のスクリプトが `scripts/` に置かれ、選定スクリプトの respond 分岐が検出スクリプトを解決できる状態になる

#### Scenario: 導入済みリポジトリを後から配線できる
- **WHEN** 応答モードより前に導入したリポジトリで未配線を検出する
- **THEN** スキルの後追い配線手順（3 本の配り直しと憲法ファイルの更新）で最新化できる
