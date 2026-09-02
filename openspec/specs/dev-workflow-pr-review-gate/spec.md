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

### Requirement: 仕様宣言を通過の必須点に加える
pr-review-gate スキルは、手順 3 に「仕様宣言」を positive affirmation として追加しなければならない（MUST）。仕様宣言は `## 仕様宣言` 見出しと 1 行目 `対象 HEAD: <40 桁フル SHA>` を持つ PR コメントで、本文は「仕様を更新した（change 名・archive 済み・`仕様レビュー: APPROVE` の所在）」か「仕様変更なし＋理由」のどちらかちょうどとする（MUST）。「書かない」を選んではならず（MUST NOT）、スキル冒頭の必須点の列挙に仕様宣言を含めなければならない（MUST）。

#### Scenario: 手順 3 に仕様宣言の 2 形がある
- **WHEN** SKILL.md の手順 3 を読む
- **THEN** `## 仕様宣言` 見出し・`対象 HEAD:` 1 行目・「更新した」形と「変更なし＋理由」形の両テンプレートが書かれている

#### Scenario: 冒頭の必須点に仕様宣言が入っている
- **WHEN** SKILL.md 冒頭の「通過の必須」の列挙を読む
- **THEN** リスク宣言・動作確認の証拠・`agent-review:passed` に加えて仕様宣言が挙がっている

### Requirement: 合格処理は仕様宣言の実在と issue 記録との整合を実測する
手順 5 は、現在の HEAD SHA を含むコメントの 1 行目一覧に「リスク宣言」「動作確認」「仕様宣言」の 3 見出しがすべて現れることを確認してからでなければ `agent-review:passed` を付けてはならない（MUST NOT）。さらに、PR 本文で最初に現れる `Closes` / `Fixes` / `Refs #N` から元 issue を解決し、その最新の `^仕様化判断: (する|しない)$` コメントと照合しなければならない（MUST）: 「する」なら、PR の変更ファイルに `openspec/` が含まれる**または**仕様宣言の「更新した」形が指す change が base ブランチで archive 済み（`openspec/changes/archive/*-<name>/` の実在を実測。スタック PR で仕様が先行 PR に入っている場合）であり、かつ issue に `^仕様レビュー: APPROVE$` で始まるコメントがあること（MUST）。「しない」なら仕様宣言が「変更なし＋理由」形であり、PR に `openspec/` 差分が**無い**こと（差分があれば「しない」と矛盾するので合格しない。判断を「する」に取り直すか差分を外す）（MUST）。記録が無い場合は合格処理をせず、判断を記録してからやり直す（MUST）。PR コメントへの記録は PR 本文に issue 参照が無い場合に限り（MUST）、issue 参照があれば issue 側が正で、issue 側に記録が無ければ issue に投稿する（MUST）。

#### Scenario: 3 見出しの実測が規定されている
- **WHEN** SKILL.md の手順 5 を読む
- **THEN** SHA 照合の出力に仕様宣言の見出しも現れることを要求し、欠けていれば合格処理をしない旨が書かれている

#### Scenario: 記録との整合表がある
- **WHEN** SKILL.md の手順 5 を読む
- **THEN** 「する → openspec 差分（または archive 済み change の実測）と `仕様レビュー: APPROVE`」「しない → 変更なし＋理由、かつ openspec 差分なし」「記録なし → 合格しない・記録してからやり直す」の 3 行を含む表が書かれている

#### Scenario: issue の無い PR の逃げ道がある
- **WHEN** SKILL.md の手順 5 を読む
- **THEN** PR コメントへの記録は PR 本文に issue 参照が無い場合に限り、issue 参照があれば issue 側が正である旨が書かれている

### Requirement: spec-touch-check スクリプトが規範パス接触と openspec 差分を報告する
dev-workflow プラグインは `scripts/spec-touch-check.sh <owner/repo> <PR番号>` を含まなければならない（MUST）。スクリプトは PR の変更ファイル一覧を取得し（環境変数 `SPEC_TOUCH_FILES` があればそれを使う）、規範を持ちうるパスへの接触（`SPEC_TOUCH=yes|no`）・`openspec/` 配下の差分の有無（`OPENSPEC_DIFF=yes|no`）・触れた規範パスの一覧を標準出力に出す（MUST）。規範パスの既定は `docs/` `.claude/` `templates/` `scripts/` `CLAUDE.md` `AGENTS.md` とし、リポ直下に `.spec-touch-paths` があればその内容で置き換える（MUST）。終了コードは、規範パスに触れて `openspec/` 差分が無いとき 2、それ以外の正常時 0、取得失敗時 1 とする（MUST）。手順 5 は「しない」判定の PR でこのスクリプトが 2 を返したとき、仕様宣言の理由に規範パス接触への言及を要求する（MUST）。

#### Scenario: 規範パスに触れて openspec 差分が無い
- **WHEN** `SPEC_TOUCH_FILES` に `docs/foo.md` と `lib/a.ts` を渡して実行する
- **THEN** `SPEC_TOUCH=yes` `OPENSPEC_DIFF=no` と `docs/foo.md` が出力され、終了コード 2 で終わる

#### Scenario: openspec 差分がある
- **WHEN** `SPEC_TOUCH_FILES` に `docs/foo.md` と `openspec/specs/x/spec.md` を渡して実行する
- **THEN** `SPEC_TOUCH=yes` `OPENSPEC_DIFF=yes` が出力され、終了コード 0 で終わる

#### Scenario: 規範パスに触れていない
- **WHEN** `SPEC_TOUCH_FILES` に `lib/a.ts` だけを渡して実行する
- **THEN** `SPEC_TOUCH=no` `OPENSPEC_DIFF=no` が出力され、終了コード 0 で終わる

#### Scenario: .spec-touch-paths で既定を置き換える
- **WHEN** カレントディレクトリの `.spec-touch-paths` に `handbook/` だけを書き、`SPEC_TOUCH_FILES` に `docs/foo.md` と `handbook/a.md` を渡す
- **THEN** `SPEC_TOUCH=yes` で一覧には `handbook/a.md` だけが出て `docs/foo.md` は出ない

#### Scenario: 手順 5 がスクリプトを参照する
- **WHEN** SKILL.md の手順 5 を読む
- **THEN** `spec-touch-check.sh` を実行し、終了コード 2 のときは「変更なし」宣言の理由に規範パス接触への言及を要求する旨が書かれている

### Requirement: auto-merge への組み込みは範囲外と明記する
SKILL.md は、仕様宣言が `対象 HEAD:` 規約に乗っているため auto-merge workflow に組み込めるが、配備済みリポへの伝播を伴うため本 change では組み込まない（別 issue）ことを明記しなければならない（MUST）。

#### Scenario: 範囲外の明記
- **WHEN** SKILL.md の仕様宣言に関する記述を読む
- **THEN** auto-merge への組み込みは別 issue である旨が書かれている

