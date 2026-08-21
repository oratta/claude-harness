# dev-workflow-pr-review-gate Specification

## Purpose
TBD - created by archiving change promote-pr-review-gate-to-dev-workflow. Update Purpose after archive.
## Requirements
### Requirement: pr-review-gate スキルがプラグインとして全リポに配布される

dev-workflow プラグインは `skills/pr-review-gate/SKILL.md` を含み、`plugin.json` の skills 配列に登録することで、プラグイン導入済みの任意のリポで「PR を作った / レビューして / マージまで進めて / 保留を再開する」の文脈で発火させられる状態にする（SHALL）。スキル名は flatmate 版と同じ `pr-review-gate` とする（SHALL）。

#### Scenario: プラグイン導入リポでスキルが読める

- **WHEN** dev-workflow プラグインを導入したリポのセッションで pr-review-gate スキルを参照する
- **THEN** `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` が frontmatter（name: pr-review-gate と発火条件を含む description）付きで存在し、plugin.json の skills 配列に `./skills/pr-review-gate` が含まれている

#### Scenario: flatmate 版と手順の骨格が同一

- **WHEN** 移植版 SKILL.md を flatmate 版（PR #232）と比較する
- **THEN** 6 手順（前提を揃える → 別コンテキストレビュー → リスク宣言 → 動作確認 → 合格処理 → 保留処理）、ラベル名（`agent-review:passed` / `agent-review:pending` / `agent-review:failed` / `needs-approval`）、fail-closed の原則（宣言・証拠の HEAD SHA 実測確認まで passed を付けない）がすべて維持されている

### Requirement: スキルはリポ非依存で、flatmate 固有の仕組みには条件分岐で対応する

移植版 SKILL.md は flatmate 固有のファイル・スクリプト・spec を無条件には参照しない（SHALL NOT）。flatmate にしか無い仕組み（pending ミラー等）は「リポに存在すれば従う・無ければ縮退手順」の条件分岐として記述する（SHALL）。auto-merge workflow が未配備のリポでは `agent-review:passed` 付与後のマージが人間操作になることを明記する（SHALL）。

#### Scenario: flatmate 固有参照の不在

- **WHEN** 移植版 SKILL.md を検査する
- **THEN** `genetta-inc/flatmate` の直書き URL が存在せず、`pending-mirror.sh` / `memory/pending-owner.md` / `channel-reply-policy` への参照はすべて「存在すれば」の条件付き記述の中にのみ現れる

#### Scenario: auto-merge 未配備リポでの縮退

- **WHEN** auto-merge workflow が配備されていないリポでスキルの手順 5（合格処理）まで到達する
- **THEN** スキルは「passed 付与後のマージは人間が行う（auto-merge 配備リポでは自動）」という縮退動作を案内しており、マージ API を LLM が直接叩くことは引き続き禁止されている

### Requirement: flatmate issue #240 の収束ルールが織り込まれている

移植版 SKILL.md は次の収束ルールを含む（SHALL）: ①レビューは既定 2 周（初回 + 差分再レビュー 1 回）で確定し、3 周目に入れるのは新規の高深刻度 blocking（安全機構の穴・データ破壊・無言の機能不全）のみ ②再レビューは前回指摘が閉じたかの差分確認に限定し、新規の気づきは follow-up issue に回す ③マージ後に issue で直せるものは blocking にしない ④リスク許容リンク経由の合格では、リンク先を実際に確認し、GitHub リンクなら `gh api` で author を実測して確認記録（確認者・確認日時）を宣言コメントに追記する ⑤リスク承認を待つ間に動作確認（手順 4）を並行して進めてよいことを明記する。

#### Scenario: 2 周キャップの規定が存在する

- **WHEN** 移植版 SKILL.md のレビュー手順を読む
- **THEN** 既定 2 周キャップ・3 周目の許可条件（新規の高深刻度 blocking のみ）・再レビューの差分限定・blocking 定義の限定（マージ後に直せるものは follow-up issue 化）が規定されている

#### Scenario: リスク許容リンクの真正性確認が存在する

- **WHEN** 主の許容回答リンク経由で合格処理（手順 5）を行う
- **THEN** スキルはリンク先を開いて主本人の発言と許容の意思を確認し、GitHub コメントの場合は `gh api` で author を実測する手順と、確認記録の書式（確認者・確認日時の追記）を規定している

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

light と判定した場合に省略してよいのは Codex CLI の呼び出しだけであり（MUST）、それ以外の工程——実装と別コンテキストでレビューすること、手順3 のリスク宣言、手順4-1 の動作確認証拠、手順4-2 のドキュメント文字列の整合確認、手順5 の HEAD SHA 照合と合格前の API 実測、収束ルール（2周キャップ・差分限定再レビュー・blocking 定義の限定）——は一切免除されない（MUST NOT 免除）。

#### Scenario: light でも合格処理の条件は同じ

- **WHEN** light と判定した PR が手順5（合格処理）に到達する
- **THEN** 現在の HEAD SHA を含むリスク宣言コメント・動作確認証拠コメント・ドキュメント文字列の整合確認コメントの3つすべての実在を API で実測してからでなければ `agent-review:passed` を付けない（full の場合と同一）

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

### Requirement: 実装とドキュメント文字列の整合を合格の必須条件にする

pr-review-gate スキルは、変更した振る舞いを説明しているドキュメント文字列が新しい振る舞いと一致していることの確認を、`agent-review:passed` 付与の必須条件として手順4に持たなければならない (MUST)。この確認は手順4-2 として、既存の振る舞いの確認（手順4-1）と並ぶ独立した確認として記述しなければならない (MUST)。6手順の骨格（前提を揃える → 別コンテキストレビュー → リスク宣言 → 動作確認 → 合格処理 → 保留処理）は変更してはならない (MUST NOT)。

確認対象は次の4種を名指しで列挙しなければならない (MUST): ①API ドキュメント文字列（JSDoc / docstring / 型定義のコメント）②CLI の使い方（`--help` の USAGE・引数やサブコマンドの説明）③利用者向け文書（README・docs・spec・スキル/コマンド定義の説明文）④実行時に人が読む文字列（エラーメッセージ・警告・ログ・UI の文言）。

#### Scenario: 4-2 が合格の必須条件として存在する

- **WHEN** `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` の手順4 を読む
- **THEN** 「ドキュメント文字列の整合確認」の節が存在し、`usage` / `JSDoc` / エラーメッセージを含む確認対象が列挙され、合格（手順5）の必須条件であることが明記されている

#### Scenario: 6手順の骨格が維持されている

- **WHEN** SKILL.md の見出し構成を検査する
- **THEN** `### 1. 前提を揃える` から `### 6. 保留処理` までの6手順がそのまま存在し、ドキュメント整合の確認は `### 4. 動作確認` の配下の小節として置かれている

### Requirement: 整合確認は grep の対象と実行コマンドまで具体化する

pr-review-gate スキルは、ドキュメント文字列の整合確認を「ドキュメントも見る」のような検証不能な指示で書いてはならない (MUST NOT)。この PR で振る舞いが変わったシンボル・フラグ・既定値を列挙し、その名前で当該リポを検索する具体的なコマンド例（`git grep -n '<シンボル>'` 形式）を含めなければならない (MUST)。ヒットが 0 件だった場合に「0 件」と記録することを求め、未確認を空欄にすることを禁じなければならない (MUST)。

#### Scenario: 具体的な grep コマンド例がある

- **WHEN** SKILL.md の手順4-2 を読む
- **THEN** 変更したシンボル名でリポを検索する `git grep -n` の実行例が複数（フラグ名・関数名・既定値を説明する語）含まれている

#### Scenario: 未確認を空欄にできない

- **WHEN** grep のヒットが 0 件だった
- **THEN** スキルは「0 件（説明文なし）」と記録することを求めており、確認していない項目を空欄のまま残すことを禁じている

### Requirement: 整合確認の証拠は HEAD SHA 付きコメントとして実測される

pr-review-gate スキルは、ドキュメント文字列の整合確認の結果を、対象 HEAD の 40 桁フル SHA を含む PR コメント（見出し `## ドキュメント文字列の整合確認`）として残すことを求めなければならない (MUST)。手順5 の合格前の API 実測は、リスク宣言・動作確認・ドキュメント文字列の整合確認の3つの見出しがすべて現在の HEAD SHA を含むコメントとして実在することを確認しなければならず (MUST)、1つでも欠けている場合は `agent-review:passed` を付けてはならない (MUST NOT)。

#### Scenario: 3見出しの実測に更新されている

- **WHEN** SKILL.md の手順5（合格処理）の実測手順を読む
- **THEN** 確認する見出しが3つ（リスク宣言・動作確認・ドキュメント文字列の整合確認）に増えており、1つでも欠けたら合格処理をしないと規定されている

#### Scenario: 既存の fail-closed 条件は緩んでいない

- **WHEN** 手順5 の合格条件を変更前と比較する
- **THEN** stale な `agent-review:passed` の除去、HEAD SHA 照合、リスク宣言の positive affirmation、許容リンクの真正性確認、`needs-approval` の3点実測はすべて残っている

### Requirement: 実装と説明文の食い違いは follow-up issue に先送りしない

pr-review-gate スキルは、実装と説明文の食い違いを follow-up issue へ回すことを禁じなければならない (MUST)。auto-merge 配備リポでは合格ラベルの付与が即マージを意味し「あとで直す」が成立しないため、この食い違いは既存の blocking 限定ルール（マージ後に issue で直せるものは blocking にしない）の適用対象外として、同じ PR の中で直さなければならない (MUST)。

#### Scenario: 先送り禁止が明文化されている

- **WHEN** SKILL.md の手順4-2 と「やらないこと」を読む
- **THEN** 実装と説明文の食い違いを follow-up issue に先送りせず同じ PR で直すことが明記されており、整合確認を飛ばして `agent-review:passed` を付けないことが「やらないこと」に含まれている


### Requirement: ゲートの必須条件を説明する文字列は全箇所そろって更新される

ゲートの合格必須条件を説明している利用者向け文字列は、必須条件をすべて列挙しなければならない (MUST)。対象は次の5か所である: pr-review-gate スキルの frontmatter `description`、`plugins/dev-workflow/.claude-plugin/plugin.json` の `description`、`.claude-plugin/marketplace.json` の dev-workflow エントリの `description`、`plugins/dev-workflow/README.md` の pr-review-gate 節、`plugins/dev-workflow/templates/auto-merge/README.md` のスキル連携の説明。ゲートに必須条件を追加したとき、この5か所の一部だけを更新して残りを旧条件のまま残してはならない (MUST NOT)。この同時更新は目視ではなく自動テストで機械的に検証しなければならない (MUST)。

#### Scenario: 説明文だけ旧条件のまま取り残されると落ちる

- **WHEN** ゲートの必須条件を追加し、5か所のうち一部の説明文を更新しないまま `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` を実行する
- **THEN** `gate-description` テストが失敗し、どの場所でどの条件が抜けているかを名指しで出力する

#### Scenario: 収束ルールの例外が説明文にも現れる

- **WHEN** `plugins/dev-workflow/README.md` の収束ルールの記述を読む
- **THEN** 「マージ後に直せるものは blocking にしない」に、実装とドキュメント文字列の食い違いは例外で同じ PR の中で直す旨が併記されている
