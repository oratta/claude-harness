# dev-workflow-pr-review-gate

## ADDED Requirements

### Requirement: レビュー実行者を変更内容から事前判定する（light / full）

pr-review-gate スキルは手順2（レビュー）の冒頭で、レビューの重量を light / full のいずれかに判定しなければならない（MUST）。判定材料は機械的に取得できるもの——変更ファイル一覧（`gh pr diff <N> --name-only`）と diff の変更行数——に限る（MUST）。既定は full とし、light の条件をすべて満たすことを確認できたときだけ light に落とす（MUST）。判定が付かない場合は full に倒す（MUST）。

light と判定してよいのは次の (a)(b) のいずれか一方をすべて満たす場合に限る（MUST）:

- (a) 変更ファイルがすべて `*.md` であり、かつエージェントの行動を定義するファイル（`CLAUDE.md` / `AGENTS.md`、`.claude/` 配下、`.github/workflows/`、スキル・コマンド・エージェント定義、憲法 doc）を1つも含まない
- (b) 合計変更が 30 行以下であり、かつ diff を読んだ結果「挙動を変えない変更」（コメント・typo・文言修正・テストデータのみ）と判断できる

#### Scenario: 既定は full で Codex から試す

- **WHEN** light の条件を満たさない PR、または判定が付かない PR のレビューを開始する
- **THEN** スキルは full として扱い、Codex CLI をレビュー実行者の第一選択として使う（Codex が使えないときのみ Task サブエージェントへフォールバックする）

#### Scenario: docs のみの変更は light になる

- **WHEN** 変更ファイルがすべて `*.md` で、`CLAUDE.md` / `.claude/` 配下 / `.github/workflows/` / スキル・コマンド・エージェント定義を含まない PR をレビューする
- **THEN** スキルは light と判定し、Codex 呼び出しを省いて最初から Task サブエージェント（実装と別コンテキスト）にレビューさせる

#### Scenario: エージェントの行動を定義する md は light にならない

- **WHEN** 変更が md だけであっても `CLAUDE.md` や `.claude/` 配下のスキル定義を含む
- **THEN** スキルは light の条件 (a) を満たさないと判定し、full として扱う

### Requirement: light はレビュー実行者だけを変え、通過条件を免除しない

light と判定した場合に省略してよいのは Codex CLI の呼び出しだけであり（MUST）、それ以外の工程——実装と別コンテキストでレビューすること、手順3 のリスク宣言、手順4 の動作確認証拠、手順5 の HEAD SHA 照合と合格前の API 実測、収束ルール（2周キャップ・差分限定再レビュー・blocking 定義の限定）——は一切免除されない（MUST NOT 免除）。

#### Scenario: light でも合格処理の条件は同じ

- **WHEN** light と判定した PR が手順5（合格処理）に到達する
- **THEN** 現在の HEAD SHA を含むリスク宣言コメントと動作確認証拠コメントの実在を API で実測してからでなければ `agent-review:passed` を付けない（full の場合と同一）

#### Scenario: light でも自己レビューは禁止

- **WHEN** light と判定する
- **THEN** レビューは実装したコンテキストではなく Task サブエージェント（別コンテキスト）が実行する

### Requirement: 判定結果と理由を PR コメントに記録する

スキルは light / full の判定結果と、その根拠（対象ファイルの種別と変更行数）を PR コメントに1行残さなければならない（MUST）。事後に判定の妥当性をサンプリング監査できるようにするためである。

#### Scenario: 判定の1行記録

- **WHEN** レビュー重量を判定した
- **THEN** `レビュー重量: light — docs のみ 12 行（挙動定義ファイルなし）` のような判定結果と根拠を含むコメントが PR に投稿されている

### Requirement: 事前判定と障害時フォールバックを区別する

スキルは、変更内容に基づく事前判定（light）と、Codex CLI が使えないときの障害時フォールバックを、役割の異なるものとして書き分けなければならない（MUST）。既存のフォールバック記述は削除してはならない（MUST NOT）。同じ「Task サブエージェントがレビューした」でも、どちらの経路によるものかが PR コメントから判別できること（MUST）。

#### Scenario: フォールバック経路が残っている

- **WHEN** full と判定した PR で Codex CLI が未導入・サブスク切れ・タイムアウトになる
- **THEN** スキルは Task サブエージェントへフォールバックし、その旨（フォールバックであること）を PR コメントに1行残す

#### Scenario: 経路の書き分け

- **WHEN** レビュー実行者が Task サブエージェントになった
- **THEN** PR コメントから「light と判定したため最初から Task サブエージェント」なのか「full だが Codex が使えずフォールバック」なのかが読み取れる
