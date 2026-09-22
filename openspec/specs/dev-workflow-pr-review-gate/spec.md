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

移植版 SKILL.md は次の収束ルールを含む（SHALL）: ①レビューは既定 2 周（初回 + 再レビュー 1 回）で確定し、3 周目は自動では開けない（3 周目以降が開くのは、主が順 5 で「この PR で直す」と答えたときと、決める役が順 6 で「全部列挙してから直す」と裁定したとき（PR ごとに 1 回まで）だけ。2 周目終了時の扱いは「2 周目終了時に残った指摘を違反文の引用で仕分ける」Requirement と「引用できる指摘が残ったら 3 周目に入らず主に上げる」Requirement に従う） ②再レビューは前回指摘が閉じたかの差分確認に限定し、新規の気づきは follow-up issue に回す（例外は「方式の書き換え後の再レビューは全体レビューにし、周回は数え続ける」Requirement と、例外 3 種に当たる新規の指摘） ③マージ後に issue で直せるものは blocking にしない ④リスク許容リンク経由の合格では、リンク先を実際に確認し、GitHub リンクなら `gh api` で author を実測して確認記録（確認者・確認日時）を宣言コメントに追記する ⑤リスク承認を待つ間に動作確認（手順 4）を並行して進めてよいことを明記する。

#### Scenario: 2 周キャップの規定が存在する

- **WHEN** 移植版 SKILL.md のレビュー手順を読む
- **THEN** 既定 2 周キャップ・3 周目を自動で開けないこと・再レビューの差分限定とその例外（方式の書き換え後の全体レビュー）・blocking 定義の限定（マージ後に直せるものは follow-up issue 化）が規定されている

#### Scenario: 高深刻度だけを理由に 3 周目へ入る規定が残っていない

- **WHEN** 移植版 SKILL.md の収束ルールを読む
- **THEN** 「新規の高深刻度 blocking なら 3 周目に入ってよい」という許可条件は無く、レビュアーの深刻度ラベルは参考情報である旨が書かれている

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
- **THEN** スキルは full として扱い、従来モードでは Codex CLI（companion または exec）を第一選択とし、後述の実測条件で不可を確認したときのみ Task サブエージェントへフォールバックする。新 Codex モードは App Server 固定で、この exec / Claude fallback を適用しない

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

スキルは、変更内容に基づく事前判定（light）と、従来モードの full における Codex CLI 障害時フォールバックを書き分けなければならない（MUST）。従来モードのフォールバックは残すが、Codex 不可と判定してよいのは、実際のコマンドで確認したバイナリ無し・認証切れ・待ち方の正本の総待ち上限到達だけとする（MUST）。companion / slash command の不在、未試行、auth.json の有無だけで不可と判定してはならない（MUST NOT）。他のエラーを三条件に読み替えて暗黙に Claude へ切り替えてはならない（MUST NOT）。#707 の新 Codex モードの App Server 固定・暗黙 exec / Claude fallback 禁止を維持する（MUST）。

PR コメントから light と full 障害時を判別できなければならない（MUST）。従来モードの full では対象 HEAD・選んだ経路・実際に叩いたコマンド・結果（取得できた終了コードと出力の要点、タイムアウト時は実待ち時間と完了未確認）を記録する（MUST）。G が full の Codex 不可により `needs-reviewer` を返す場合も同じ証拠を含める（MUST）。

#### Scenario: バイナリ無しを確認した
- **WHEN** 従来モードの full で `command -v codex` 等を実行しバイナリ不在を確認した
- **THEN** コマンドと終了コード・結果を記録して障害時フォールバックに進める。G は証拠付き needs-reviewer を返す

#### Scenario: 認証切れを確認した
- **WHEN** 従来モードの full で実際の Codex 呼び出しが認証切れの応答を返した
- **THEN** 実行コマンド・終了コードと応答の要点を記録して障害時フォールバックに進める

#### Scenario: 総待ち上限に達した
- **WHEN** 従来モードで起動した Codex が待ち方の正本の総待ち上限まで完了しない
- **THEN** 起動・待機コマンド、実待ち時間、完了未確認を記録して障害時フォールバックに進める。単一回の待ち終了を総待ち上限と扱わない

#### Scenario: 未試行や対象外エラーは不可の証拠にならない
- **WHEN** companion が無いだけ、Codex 未試行、または実行結果が引数誤り・権限拒否・通信障害など三条件以外だった
- **THEN** Codex 未導入・認証切れ・総待ち上限到達と推測せず、Claude へ暗黙にフォールバックしない

#### Scenario: 経路の書き分け
- **WHEN** レビュー実行者が Task サブエージェントになった
- **THEN** PR コメントから「light 判定で最初から Task」か「従来モードの full で実測した Codex 不可による fallback」かが分かり、後者にはコマンドと結果がある

#### Scenario: 新 Codex モードには互換経路を適用しない
- **WHEN** #707 の新 Codex モードを実行する
- **THEN** この不可判定を exec / Claude fallback の許可に使わず、App Server 固定の制約を維持する

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

### Requirement: Codex の待ち方を読み手別に書き分ける
`skills/pr-review-gate/SKILL.md` の Codex 呼び出し規約は、このスキルをメインセッションとサブエージェント G の両方が読むことを前提に、待ち方を読み手別に書き分けなければならない（MUST）。メインセッションは背景タスクの完了で再起動されるため `--background` 起動 ＋ 完了通知で続行してよい（SHALL）。サブエージェントは再起動されないため、完了確認を同一ターン内の前景ポーリングで行わなければならず（MUST）、完了通知を待つ目的でターンを終えてはならない（MUST NOT）。詳細の正本は `plugins/dev-workflow/references/subagent-waiting.md` を参照する（SHALL）。

既存の「フォアグラウンドで完了を待つ呼び方を禁止する」の見出し文は、**前景 1 回で起動から完了まで待ち切ろうとする呼び方の禁止**と、**前景ポーリングでの完了確認の必須**が区別できる形に書き直さなければならない（MUST）。新方針と字面で衝突したまま残してはならない（MUST NOT）。

#### Scenario: サブエージェントとして読む
- **WHEN** G が pr-review-gate の Codex 呼び出し規約を読む
- **THEN** 完了通知に頼らず同一ターン内で前景ポーリングして待つこと、待ちでターンを終えないことが読み取れる

#### Scenario: メインセッションとして読む
- **WHEN** 本体が pr-review-gate の Codex 呼び出し規約を読む
- **THEN** `--background` 起動と完了通知での続行が引き続き許可されていることが読み取れる

#### Scenario: 禁止文が新方針と衝突しない
- **WHEN** Codex 呼び出し規約の冒頭の禁止文を読む
- **THEN** 禁止されているのが「前景 1 回で完走させようとすること」だと分かり、「前景で待つこと自体が禁止」とは読めない

### Requirement: 待ち値は正本に従い SKILL.md には再掲しない
`skills/pr-review-gate/SKILL.md` は、`codex-companion.mjs status --wait` の `--timeout-ms` を必ず明示すること（既定は 4 分しかない）と、値が Bash 前景の上限（600000 ms）未満でなければならないことを書かなければならない（MUST）。従来の 900000 は前景上限を超えるため 1 回の呼び出しで完走せず、これが待ちの構造を壊す原因になっていた。

**具体の待ち値・1 回で終わらなかったときの繰り返し・総待ちの上限は正本 `plugins/dev-workflow/references/subagent-waiting.md` に従うものとし、SKILL.md に数値を再掲してはならない（MUST NOT）。** 同じ手順を 2 か所に置くと片方だけ古くなるため。レビュー実行者の表にある「タイムアウト」が正本の定める総待ちの上限に達したことを指す、という定義だけは SKILL.md に残す（SHALL）。「1 回の呼び出しで最長 15 分待てる」のような、数値ガードに掛からない散文で前景上限を超える待ちを示唆する記述を残してはならない（MUST NOT）。

#### Scenario: 待ち値の指定
- **WHEN** SKILL.md の Codex 呼び出し規約を読む
- **THEN** `--timeout-ms` を必ず明示すること・値が 600000 ms 未満であることが書かれ、具体の数値は正本に委ねられており、「最長 15 分待てる」の記述も残っていない

#### Scenario: 1 回で終わらない Codex レビュー
- **WHEN** 1 回の待ちで Codex が完了しない
- **THEN** 繰り返しと上限の扱いは正本に従う旨が書かれており、待ちのためにターンを終える指示は無い

#### Scenario: フォールバック条件のタイムアウトが定義されている
- **WHEN** レビュー実行者の表にある「従来モードの full だが Codex CLI が使えないとき（実測したバイナリ無し・認証切れ・タイムアウト）」の「タイムアウト」が何を指すかを調べる
- **THEN** 正本が定める総待ちの上限に達したことだと読み取れる

### Requirement: ゲート合格まで PR を Draft のまま扱い、合格処理で Ready にする
手順 5（合格処理）は、`needs-approval` が付いていないことを Ready 化より前に確認しなければならない（MUST。付いたまま Ready 化だけ済ませると、保留中の PR が Draft でなくなる）。そのうえで、PR が Draft（`gh api repos/$R/pulls/$N --jq .draft` が `true`）なら `gh pr ready` を実行してから `agent-review:passed` を付けなければならない（MUST）。順序は Ready 化 → passed 付与でなければならない（MUST）。passed を先に付けると、その labeled イベントは PR が draft のため auto-merge にスキップされ、Ready 化で CI が走らないリポでは次の判定が日次 schedule まで来ないためである。PR が Draft でなければ `gh pr ready` を実行してはならない（MUST NOT。人間が作った非 Draft の PR をそのまま通す）。Ready 化に失敗したとき、または `draft` を取得できなかったときは、`agent-review:passed` を付けずに合格処理を中断しなければならない（MUST。draft のまま passed を付けるとその labeled イベントはスキップされて消費され、あとで Ready 化をやり直しても新しい labeled は起きないため）。合格処理の最後の実測確認には、ラベル 3 点に加えて PR の `draft` が `false` であることを含めなければならない（MUST）。

手順 1 で stale な `agent-review:passed` を外したとき、PR が Draft でなければ `gh pr ready --undo` で Draft に戻さなければならない（MUST）。passed が付いていなかった場合（初回のゲート・failed からの再レビュー・保留からの再開）は Draft に戻してはならない（MUST NOT）。

#### Scenario: Draft の PR は Ready にしてから passed を付ける
- **WHEN** SKILL.md の手順 5 を読む
- **THEN** PR の `draft` を取得し、`true` のときだけ `gh pr ready` を実行する手順が `agent-review:passed` を付ける API 呼び出しより前に書かれている

#### Scenario: 順序の理由が書かれている
- **WHEN** SKILL.md の手順 5 の Ready 化の記述を読む
- **THEN** passed を先に付けると labeled イベントが draft でスキップされ、Ready 化で CI が走らないリポでは日次の判定まで拾われないことが理由として書かれている

#### Scenario: 実測確認に draft が含まれる
- **WHEN** SKILL.md の手順 5 の最後の実測確認の表を読む
- **THEN** `agent-review:passed` がある・`agent-review:pending` がない・`needs-approval` がない、に加えて PR の `draft` が `false` である行がある

#### Scenario: Ready 化に失敗したら passed を付けない
- **WHEN** Draft の PR で手順 5 の断片を実行し、`gh pr ready` が失敗する
- **THEN** `agent-review:passed` を付ける API は呼ばれず、断片は非 0 で終わり、SKILL.md には passed の有無で分けた復旧手順が書かれている

#### Scenario: 人間が作った非 Draft の PR では Ready 化を行わない
- **WHEN** Draft でない PR がゲートの手順 5 に来る
- **THEN** SKILL.md は Ready 化を「Draft なら」の条件付きで書いており、非 Draft の PR には `gh pr ready` を実行しない

#### Scenario: 取り直しで stale passed を外すと Draft に戻す
- **WHEN** SKILL.md の手順 1 の stale passed を外す記述を読む
- **THEN** passed を外したときに PR が Draft でなければ `gh pr ready --undo` を実行する手順があり、passed が付いていなかった場合は Draft に戻さないと書かれている

#### Scenario: G の指示書が Ready 化を含む
- **WHEN** `skills/develop/references/roles/gate-runner.md` のやることと passed の return 書式を読む
- **THEN** 手順 5 の要約に Ready 化（Draft なら）が入っており、passed の return に Ready 化の結果（実施した／対象外）を書く欄がある

### Requirement: 従来モードの正式な Codex レビュー経路に exec を含める

SKILL.md のレビュー実行者表は、従来モードの full の正式な Codex 経路として companion 経由と `codex exec` 直叩きを明記しなければならない（MUST）。companion / slash command の不在だけで Codex を飛ばさず、バイナリがあれば exec を試す（MUST）。exec は既存の `-c approval_policy=never -c model_reasoning_effort=medium -`、ファイルからの標準入力、待ち方の正本に従う（MUST）。G の表は Bash からの exec / companion task を示し、G が使えない Agent / slash command を要求しない（MUST）。この経路は従来モードだけに適用する（MUST）。

#### Scenario: companion 無しで exec が成功する
- **WHEN** 従来モードの full で companion / slash command が無く、バイナリと有効な認証で exec レビューが完了する
- **THEN** Codex のレビュー結果を使い、Claude へフォールバックしない。PR コメントには exec のコマンドと完了結果を記録する

#### Scenario: G が正式経路を使う
- **WHEN** G が従来モードの full レビューを起動する
- **THEN** Bash から exec または companion task を呼び、既存正本の同一ターン内の完了確認に従う。companion 導入は必須にしない

### Requirement: 各稼働 PC の確認手順と証拠記録を文書化する

スキルは従来モードの PC ごとの確認手順と記録テンプレートを提供しなければならない（MUST）。バイナリのパス・バージョン確認、companion 有無の記録、実レビューと既存正本による完了確認、対象 issue への記録を含める（MUST）。記録には PC 識別子・日時・対象 HEAD と範囲・経路・コマンド・結果・可否または未確認・残課題を含め、認証情報そのものは転載しない（MUST）。companion 導入は任意とする（SHALL）。

#### Scenario: レビューできた PC の記録
- **WHEN** ある稼働 PC で確認手順を実行して Codex レビューが完了した
- **THEN** その PC と対象を識別できるコマンド・完了結果を対象 issue に記録し、その PC のレビュー可否を示す

#### Scenario: 文書化と実測を区別する
- **WHEN** 手順は文書化できたが実機レビューを確認していない
- **THEN** 未確認と扱い、バイナリや auth.json の存在だけでレビュー可能と宣言しない。各 PC 実測は別運用として対象 issue に残し、結果が揃うまで対象 issue を完了扱いにしない

### Requirement: 2 周目終了時に残った指摘を違反文の引用で仕分ける

SKILL.md は、2 周目のレビュー結果を受け取った直後に、ゲート実行者（G。G を使わない運用ではゲートを回す側）が残った指摘ごとに「受け入れ条件または仕様の守備範囲のどの文に違反するか」を原文の引用で示す手順を規定しなければならない（MUST）。実行者（誰が）と時点（2 周目の結果を受け取った直後）を明記する（MUST）。指摘がマージを止めるかどうかは「マージを止めるかの判定は全周共通にする」Requirement の判定で決め、仕分けの手順は判定の文を言い換えて再掲せず参照する（MUST）。レビュアー（Codex・Task サブエージェント）が付けた深刻度ラベルは参考にとどめ、判定の根拠にしてはならない（MUST NOT）。引用元は記録先（issue または Draft PR 本文）の受け入れ条件と、この PR が触れる openspec の spec（change の delta spec を含む）に限る（MUST）。仕分けの結果（指摘ごとの引用・例外 3 種のどれか、または「引用なし」）は PR コメントに記録する（MUST）。PR が openspec に触れず記録先にも受け入れ条件の文が無いなど引用元が無いときは、G は引用元を広げず、残った指摘を全件「引用なし」として扱う（MUST）。

#### Scenario: 引用の実行者と時点が書かれている

- **WHEN** SKILL.md の収束ルールを読む
- **THEN** 2 周目の結果を受け取った直後に G が指摘ごとに違反文を引用すること、深刻度ラベルは参考にとどめること、止めるかどうかは全周共通の判定を参照することが書かれている

#### Scenario: 深刻度が高くても引用できなければ blocking にしない

- **WHEN** 2 周目に「高」の深刻度ラベルが付いた指摘が残り、受け入れ条件と spec のどの文にも違反を引用できず、例外 3 種にも当たらない
- **THEN** その指摘はマージを止める指摘として扱われず、follow-up issue 化に回る

### Requirement: 引用できない指摘は follow-up issue に切って passed の判定へ進む

SKILL.md は、2 周目終了時に全周共通の判定でマージを止めない指摘（違反文を引用できず例外 3 種にも当たらないもの、`plausible` のもの、`should`・`nit`）を follow-up issue に切り出し、その issue の URL を仕分けの PR コメントに記録したうえで、手順 3 以降（`passed` の判定）へ進むことを規定しなければならない（MUST）。止めない指摘を理由に 3 周目を開けてはならない（MUST NOT）。

#### Scenario: 残った指摘がすべて引用できない

- **WHEN** 2 周目終了時に残った指摘のどれにも違反文を引用できず、例外 3 種にも当たらない
- **THEN** G は各指摘を follow-up issue に切り、URL を PR コメントに記録し、3 周目に入らず手順 3 以降へ進む

### Requirement: 引用できる指摘が残ったら 3 周目に入らず主に上げる

SKILL.md は、2 周目終了時に全周共通の判定でマージを止める指摘が 1 件でも残った場合、3 周目に入らず、仕分け表の順 5（主に切り出すかを聞く）または順 6（同じ型の再発は決める役が方式を裁定する）に当てることを規定しなければならない（MUST）。主に「続けるか、範囲外として閉じるか」の 1 択を判断材料なしで出してはならない（MUST NOT）。主への質問は順 5 の 4 点（何が起きるか・見積もり・固定費・推奨）を含める（MUST）。G や本体が、主の回答または決める役の裁定なしに 3 周目を開けてはならない（MUST NOT）。この停止は無人運用（loop-dev-agent）でも同じく適用する（MUST）。主の回答または決める役の裁定で開いた周の終了時にも同じ仕分けを適用し、止める指摘が残れば再び順 5・6 に当てる（MUST。主の回答なしに次の周へ進まない。決める役の裁定で周を開けるのは PR ごとに 1 回まで）。

#### Scenario: 引用できる指摘が 1 件残る

- **WHEN** 2 周目終了時に、受け入れ条件の 1 文に違反すると引用できる `confirmed` の `blocking` 指摘が 1 件残り、前の周と同じ型ではない
- **THEN** G は 3 周目に入らず `needs-approval` を付け、順 5 の 4 点を書いて主に切り出すかを聞き、Status を保留として return する

#### Scenario: 主がこの PR で直すと答えた

- **WHEN** 切り出しの確認で保留中の PR に、主が「この PR で直す」と回答する
- **THEN** G は回答リンクを PR コメントに記録し、`needs-approval` を外して `agent-review:failed` に付け替え、次の周として修正サイクルに戻す

#### Scenario: 続行した周の終わりにも止まる

- **WHEN** 主の回答で開いた 3 周目が終わり、止める指摘が残る
- **THEN** G は同じ仕分けを適用して順 5 または順 6 に当て、主の回答なしに 4 周目へ進まない

#### Scenario: 無人運用でも止まる

- **WHEN** loop-dev-agent の無人運用中に、2 周目終了時に止める指摘が残る
- **THEN** 対話運用と同じく順 5・6 に当て、3 周目を自動で開けない

### Requirement: 方式の書き換え後の再レビューは全体レビューにし、周回は数え続ける

SKILL.md は、前周の指摘に対する W の修正が方式の書き換え（修正の差分行数が前周の指摘の対象行数を大きく超える）だった場合、次の再レビューを差分限定ではなく PR 全体のレビューにすることを規定しなければならない（MUST）。その判定は G が再レビューを始める前に行い、判定に使った 2 つの行数（修正の差分行数と前周の指摘の対象行数）を PR コメントに記録する（MUST）。全体レビューにした場合も周回は 1 周目に戻さず数え続け（MUST）、2 周目が全体レビューになった場合はその結果に対して 2 周目終了時の仕分け（違反文の引用）をそのまま適用する（MUST）。

#### Scenario: 2 周目の前に方式が書き換えられた

- **WHEN** 1 周目の指摘が 20 行分だったのに対し、W の修正差分が数百行に及ぶ
- **THEN** G は 2 周目を全体レビューとして行い、2 つの行数を PR コメントに記録し、周回は 2 として数え、その結果に 2 周目終了時の仕分けを適用する

#### Scenario: 通常の修正は差分限定のまま

- **WHEN** W の修正差分が前周の指摘の対象行数と同程度である
- **THEN** 再レビューは前回指摘が閉じたかの差分確認に限定される

### Requirement: G の指示書の failed 節と周回欄が収束ルールに揃っている

`skills/develop/references/roles/gate-runner.md` は、failed 節と return の書式を SKILL.md の収束ルールと仕分け表に揃えなければならない（MUST）: 仕分け欄には、指摘を受け取ったすべての周で、指摘ごとに当てた仕分け表の順（順 4 なら「受け入れ条件の外・その場で直した・直し方 N 行」）と PR コメント URL を含めること。Status に `needs-decider`（順 6）を持つこと。保留欄の切り出しの確認は、順 5 の 4 点（何が起きるか・見積もり・固定費・推奨）を含めること。`周回:` 欄は主の回答または決める役の裁定で開いた 3 周目以降も表せること。全体レビューにした周はその旨と判定に使った 2 つの行数を書くこと。あわせて再開節を揃えなければならない（MUST）: 「W の修正後の再レビュー」の記述は、再レビューの範囲に全体レビューの例外を含め、3 周目の条件を主の回答または決める役の裁定に置き換え（「3 周目に入れるのは新規の高深刻度 blocking のみ」の許可条件を残さない）、「保留の解除」は切り出しの確認への主の回答（切り出す／この PR で直す）を含めること。gate-runner.md は「続けるか、範囲外として閉じるか」の 1 択を持ってはならない（MUST NOT）。

#### Scenario: 2 周目で止める指摘が残ったときの return

- **WHEN** G が 2 周目を終え、全周共通の判定で止める指摘が残り、前の周と同じ型ではない
- **THEN** return は Status: 保留で、指摘ごとに当てた順と、順 5 の 4 点（何が起きるか・見積もり・固定費・推奨）を含み、「続けるか、範囲外として閉じるか」の 1 択を含まない

#### Scenario: 再開節に旧ルールが残っていない

- **WHEN** gate-runner.md の再開節を読む
- **THEN** 「新規の高深刻度 blocking のみ」の 3 周目許可条件は無く、再レビューの範囲に全体レビューの例外があり、3 周目は主の回答か決める役の裁定があるときだけで、保留の解除に切り出しの確認への回答が含まれている

#### Scenario: 周回欄が全体レビューを表す

- **WHEN** 方式の書き換えにより 2 周目を全体レビューにした
- **THEN** return の `周回:` 欄は 2 で、全体レビューにしたことと 2 つの行数が書かれている

### Requirement: レビュアーの指摘に固定書式を課す

SKILL.md 手順 2-1 は、レビュアー（Codex CLI・Task サブエージェント）が書く指摘 1 件ごとの固定書式を規定しなければならない（MUST）。各指摘は次のフィールドを持つ（MUST）: 見出し（命令形 1 行・80 字以内）、深刻度（`blocking` / `should` / `nit`）、検証（`confirmed`＝実行・テストで裏取り済み / `plausible`＝推測・未検証）、根拠（深刻度が `blocking` のとき必須。記録先の受け入れ条件または PR が触れる openspec spec の原文の引用、または例外 3 種＝安全機構の穴・データ破壊・無言の機能不全のどれに当たるか）、場所（`file:line-range`、diff と重なる範囲で 10 行以内）、何が起きるか（入力・状態と誤動作、発生条件）、直し方（行レベルの置換コードか 3 行以内の手順で、そのとおりに直せば指摘が閉じるもの）。再レビューでは各指摘に状態（`fixed` / `unresolved` / `wontfix`）を足す（MUST）。

SKILL.md は深刻度 3 値の定義表を持たなければならない（MUST）: `blocking` は受け入れ条件または仕様の文に違反しマージすると壊れるもの、`should` は直すべきだがマージ後に issue で直せるもの、`nit` は好み・スタイル。

書式と深刻度の定義表は SKILL.md 手順 2-1 に 1 か所だけ置き（MUST）、レビュアーへの指示文に貼り付けられるブロックの形にする（MUST）。他のファイルは書式を再掲せず、このブロックを参照する（MUST NOT 再掲）。

#### Scenario: 書式の見出し語と深刻度 3 値がある

- **WHEN** SKILL.md 手順 2-1 を読む
- **THEN** 深刻度・検証・根拠・場所・何が起きるか・直し方の各欄と、`blocking` / `should` / `nit` の定義表がある

#### Scenario: 再レビューの状態欄がある

- **WHEN** SKILL.md の固定書式を読む
- **THEN** 再レビュー時に各指摘へ `fixed` / `unresolved` / `wontfix` の状態を足すことが書かれている

### Requirement: マージを止めるかの判定は全周共通にする

SKILL.md は、指摘がマージを止めるかどうかの判定を 1 か所に書かなければならない（MUST）。判定は全周（1 周目・2 周目・主の回答または決める役の裁定で開いた周）で同じでなければならない（MUST）: マージを止めるのは、深刻度が `blocking` で、根拠の引用を G が記録先の受け入れ条件または PR が触れる openspec spec（delta spec を含む）の原文と照合できた（または根拠が例外 3 種＝安全機構の穴・データ破壊・無言の機能不全に当たる）、かつ検証が `confirmed` の指摘だけとする。それ以外の指摘（`should`・`nit`・`plausible`・照合できない `blocking`）はマージを止めず、follow-up issue に回す（MUST）。レビュアーが付けた深刻度ラベルは参考にとどめ、G の照合を判定の根拠とする（MUST）。

止める指摘が残ったときの動き方は、仕分け表（「指摘を受け取った G は仕分け表の順に当てる」Requirement）で決めなければならない（MUST）。SKILL.md は「一般則は 1 周目に適用し、2 周目からは収束ルールが優先する」のような、周によって判定を分ける記述を持ってはならない（MUST NOT）。

1 周目で failed にするとき、止めない指摘は failed の PR コメントに一覧で残し、follow-up issue はまだ切らない（SHALL）。follow-up issue は G が手順 3 へ進む時点で、未解決の止めない指摘について切り、URL を PR コメントに記録する（MUST）。

#### Scenario: 1 周目に should と plausible だけが残る

- **WHEN** 1 周目のレビューが `should` の指摘と `plausible` の `blocking` 指摘だけを返す
- **THEN** G は failed にせず、各指摘を follow-up issue に切って URL を PR コメントに記録し、手順 3 以降へ進む

#### Scenario: 1 周目に止める指摘がある

- **WHEN** 1 周目のレビューが、受け入れ条件の文を引用した `confirmed` の `blocking` 指摘を 1 件返す
- **THEN** G は仕分け表の順 2 に当て、`agent-review:failed` に付け替えて修正サイクルへ戻す

#### Scenario: 引用できない安全機構の穴

- **WHEN** 受け入れ条件と spec のどの文も引用できないが、根拠が安全機構の穴に当たり検証が `confirmed` の `blocking` 指摘が残る
- **THEN** その指摘はマージを止める指摘として扱われる

#### Scenario: 周ごとに判定を分ける文が残っていない

- **WHEN** SKILL.md を読む
- **THEN** 「この一般則は1周目に適用する」の文は無く、判定は 1 か所に書かれ、収束ルールの仕分けはその判定を参照している

### Requirement: レビュアーへの指示に全件列挙と再レビューの制限を含める

SKILL.md 手順 2-1 のレビュアー向け指示ブロックは、次を含まなければならない（MUST）: 1 周目は対象範囲に該当する指摘を全部列挙するまで止まらないこと。差分限定の再レビューは前回指摘の閉鎖確認（状態欄の付与）に限り、新規の指摘を出さないこと。ただし例外 3 種（安全機構の穴・データ破壊・無言の機能不全）に当たる新規の指摘は、差分限定の周でも出してよいこと。方式の書き換え後の全体レビューでも、新規に出してよい深刻度は `blocking` だけであること。前回の「直し方」どおりに直した箇所を再指摘しないこと（直し方自体が誤っていた場合はレビュアー側の誤りとして `wontfix` 相当の記録にする）。差分限定の周に出た例外 3 種の新規指摘は、仕分け表の順 1 から通す（MUST）。

#### Scenario: 全件列挙の 1 文がある

- **WHEN** SKILL.md のレビュアー向け指示ブロックを読む
- **THEN** 「該当する指摘を全部列挙するまで止まらない」旨の 1 文がある

#### Scenario: 再レビューで新規 nit を出さない

- **WHEN** SKILL.md のレビュアー向け指示ブロックを読む
- **THEN** 再レビューでは新規の `nit` を出さず、全体レビューに戻っても新規に出してよいのは `blocking` だけと書かれている

#### Scenario: 差分限定の周でも例外 3 種は出せる

- **WHEN** SKILL.md のレビュアー向け指示ブロックの、新規の指摘を出さない文を読む
- **THEN** 例外 3 種（安全機構の穴・データ破壊・無言の機能不全）に当たる新規の指摘は出してよいという但し書きがある

### Requirement: Codex 経路と Task サブエージェント経路で同じ書式を渡す

`references/subagent-waiting.md` の Codex 指示文の雛形は、SKILL.md 手順 2-1 のレビュアー向け指示ブロックを貼ることの指示と、「該当する指摘を全部列挙するまで止まらない」の 1 文を含まなければならない（MUST）。`skills/develop/references/roles/gate-runner.md` の needs-reviewer の return payload は、レビュアーに渡す指示として同じブロックを指定する行を持たなければならない（MUST）。どちらも書式の欄や深刻度の定義を再掲してはならない（MUST NOT）。

#### Scenario: Codex の雛形が書式を要求する

- **WHEN** `subagent-waiting.md` の指示文雛形を読む
- **THEN** SKILL.md 手順 2-1 のブロックを貼る指示と全件列挙の 1 文がある

#### Scenario: needs-reviewer が書式を渡す

- **WHEN** gate-runner.md の needs-reviewer の payload を読む
- **THEN** レビュアーに渡す指示として SKILL.md 手順 2-1 のブロックを指定する行がある

### Requirement: codex exec でのルーブリック適用を実測して分岐する

この change の実装は、`codex exec` 直叩き（書式を指定しない指示文）で Codex 公式レビュールーブリック（`[P0]`〜`[P3]` の見出し・`priority`・`confidence_score`）が出力に適用されるかを実測し、結果を PR コメントに残さなければならない（MUST）。適用されない場合は、指示文に固定書式を書く経路（前の Requirement）だけで足りる。適用される場合は、SKILL.md に Codex の JSON（`priority` / `confidence_score` / `code_location`）から固定書式への対応表を置かなければならない（MUST）。Codex が使えず実測できないとき（バイナリ無し・認証切れ・総待ちの上限）は、実測した不可条件を PR コメントに記録し、適用されない場合と同じ扱いにする（MUST）。どちらの場合も `confidence_score` を `confirmed` の代わりにしてはならない（MUST NOT）。

#### Scenario: 適用されない

- **WHEN** 実測で、出力に `[P0]`〜`[P3]`・`priority`・`confidence_score` のどれも現れない
- **THEN** 実測結果が PR コメントにあり、SKILL.md に対応表は無く、指示文の雛形が書式ブロックを要求している

#### Scenario: 実測できない

- **WHEN** Codex がバイナリ無し・認証切れ・総待ちの上限のどれかで使えない
- **THEN** 実測した不可条件が PR コメントにあり、適用されない場合と同じく SKILL.md に対応表は無い

#### Scenario: 適用される

- **WHEN** 実測で、出力にルーブリックの優先度または確信度が現れる
- **THEN** 実測結果が PR コメントにあり、SKILL.md に Codex の JSON から固定書式への対応表がある

### Requirement: 合格条件に判定を明記する

SKILL.md 手順 5 は、合格処理の前提として、最後のレビュー結果に全周共通の判定で止まる指摘（`blocking` かつ `confirmed` で、G が引用を照合済みまたは例外 3 種に当たるもの）のうち、主が切り出すと答えて follow-up issue に切ったものと、G が順 3 の集合一致で閉じたもの以外が 0 件であることを書かなければならない（MUST）。切り出しの確認で主が「切り出す」と答え、follow-up issue に切った指摘と、順 3 の集合一致で閉じた指摘（閉じた PR コメントの URL を仕分け欄に残す）は、この 0 件の数に含めない（MUST。順 3 の指摘だけで戻した周は再レビューを行わないので、最後のレビュー結果には閉じた印が付かないため）。

#### Scenario: 手順 5 の合格条件

- **WHEN** SKILL.md 手順 5 を読む
- **THEN** 全周共通の判定で止まる指摘（`blocking` かつ `confirmed`、G が引用を照合済み）のうち、主が切り出すと答えて follow-up issue に切ったものと、順 3 の集合一致で閉じたもの以外が 0 件であることが合格処理の条件として書かれている

### Requirement: レビュアーの要約受領の分岐を 1 か所に置く

`skills/develop/references/roles/gate-runner.md` は、レビュアーの要約を受け取ったときの分岐を再開節の「レビュアーの要約受領」の 1 か所に書かなければならない（MUST）。needs-reviewer 節は「レビュー実行者:」コメントの投稿を規定したうえで、以降の分岐はその再開節の記述に従うと参照し、無条件に「手順 3 以降を続ける」と指示してはならない（MUST NOT）。再開節の分岐は、指摘が無ければ手順 3 以降、指摘が残れば全周共通の判定を通し、止める指摘が無ければ follow-up issue に切って手順 3 以降、止める指摘があれば周の数に関係なく仕分け表の順に当て、順 2〜4 は `agent-review:failed`、順 5 は保留、順 6 は `needs-decider` で return する、とする（MUST）。同じ周に順 5 と順 2〜4 が混ざったときは保留を先にする（「指摘を受け取った G は仕分け表の順に当てる」Requirement）。

#### Scenario: needs-reviewer 節に無条件の継続指示が無い

- **WHEN** `grep -n "手順 3 以降を続ける" gate-runner.md` を実行する
- **THEN** 無条件の継続指示が返らない

#### Scenario: 2 周目に止める指摘が needs-reviewer 経路で残る

- **WHEN** 本体が spawn したレビュアーの 2 周目の要約に、前の周と同じ型ではない止める指摘が 1 件残る
- **THEN** G は再開節の分岐に従って順 5 に当て、仕分けと順 5 の 4 点を PR コメントに記録し、Status を保留として return する

#### Scenario: 1 周目に受け入れ条件の外の大きな指摘が needs-reviewer 経路で届く

- **WHEN** 本体が spawn したレビュアーの 1 周目の要約に、受け入れ条件の外で今直す 3 条件を満たさない止める指摘が 1 件ある
- **THEN** G は failed にせず順 5 に当て、Status を保留として return する

#### Scenario: 2 周目に同じ型が needs-reviewer 経路で再発する

- **WHEN** 本体が spawn したレビュアーの 2 周目の要約に、1 周目と同じ型の止める指摘が別の場所で残る
- **THEN** G は順 6 に当て、Status `needs-decider` で return する

### Requirement: 指摘を受け取った G は仕分け表の順に当てる

SKILL.md は、手順 2-1「マージを止めるかの判定（全周共通）」の直後に、指摘を受け取った G の仕分け表を 1 か所だけ置かなければならない（MUST）。表は次の 6 つの順をこの順番で持ち、G は周回の数に関係なく、指摘が届くたびに上から当てる（MUST）:

1. 止める判定に達するか（全周共通の判定）。達しない指摘は follow-up issue に回し、主に聞かない
2. 受け入れ条件の中か。根拠の引用元が記録先の受け入れ条件、またはこの PR の change の delta spec なら「中」とし、W が直す。主に聞かない
3. 「同じ文が別の場所に残っている」「N 件のうち k 件しか直っていない」型か。W に一覧を作らせ、G は検索結果の集合一致で閉じる。主に聞かない
4. 今直す 3 条件を満たすか。W が直し、仕分け欄に記録する。主に聞かない
5. それ以外。主に「この欠陥を残して切り出すか」を聞く
6. 次のどちらか。決める役が方式を裁定する
   - 2 周目以降の周の終わりに止める指摘が残り、前の周と同じ型が別の場所・別の場合で再発している
   - 順 3 の照合が差し戻し後の 2 回目も一致しない、または順 4 で直した指摘が 1 回で閉じない（順 3・順 4 からの落とし込み。周の終わりを待たずにその時点で順 6 に当てる）

2 周目の終わり（と、主の回答または決める役の裁定で開いた周の終わり）に止める指摘が残っていれば、G は順 2〜4 を使ってはならない（MUST NOT）。同じ型の再発に当たる指摘は順 6、それ以外は順 5 に当てる（MUST）。仕分けの結果（指摘ごとに当てた順と、その根拠）は PR コメントに記録する（MUST）。収束ルール節・手順 6・gate-runner.md・worker.md は表を順番号と見出しで参照し、表の中身を言い換えて再掲してはならない（MUST NOT）。

G が順 2〜4 に当てた指摘を W に戻すときのラベルは、どれも `agent-review:failed` とする（MUST。順 3 も同じ）。

同じ周に順 5 の指摘と順 2〜4 の指摘が混ざったときは、G は全件の仕分けを PR コメントに記録して保留で return し、主の回答後に、切り出さない指摘をまとめて 1 回の `agent-review:failed` で W に戻す（MUST）。主の回答が来るまで、W は順 2〜4 の指摘の修正にも着手しない（MUST）。`needs-approval` と `agent-review:failed` を同時に付けてはならない（MUST NOT）。

#### Scenario: 仕分け表の 6 順が順番どおりにある

- **WHEN** SKILL.md 手順 2-1 の「マージを止めるかの判定（全周共通）」の直後を読む
- **THEN** 止める判定・受け入れ条件の中・一覧の一致・今直す 3 条件・主に聞く・決める役の裁定の 6 順が、この順番で 1 つの表にある

#### Scenario: 1 周目の受け入れ条件内の指摘は聞かずに直す

- **WHEN** 1 周目に、記録先の受け入れ条件を引用した `confirmed` の `blocking` 指摘が届く
- **THEN** G は順 2 に当て、主に聞かずに `agent-review:failed` で W に戻す

#### Scenario: 2 周目の終わりには聞かずに直す経路を使わない

- **WHEN** 2 周目の終わりに、受け入れ条件を引用した止める指摘が残り、前の周と同じ型ではない
- **THEN** G は順 2〜4 を使わず、順 5 で主に聞く

### Requirement: 一覧の一致で閉じる（順 3）

SKILL.md は、順 3 の閉じ方を次のとおり規定しなければならない（MUST）。W は、検索コマンド（grep の語、または場合分けの軸とその全域。例: 先頭バイトなら 0x00〜0xFF）と、全ヒットに「直した／該当しない理由」を付けた表を PR コメントに投稿してから push する。G はレビューをせず、同じ検索コマンドを自分で実行して、ヒットの集合が W の表と一致するかだけを見る。表に無いヒットがあれば、その差分だけを W に返す。差し戻しは 1 回までとし、2 回目も一致しなければ順 6 の型に落とす（MUST）。検索コマンドや軸の全域を W が書けない指摘は、順 3 に当ててはならない（MUST NOT）。

順 3 の照合はレビューの周に数えない（MUST）。G はレビューをしないため、周回キャップとは別に差し戻し 1 回の上限で止める。同じ failed で W に戻した指摘が順 3 だけなら、集合が一致して閉じたあとに差分限定の再レビューは行わず、周を消費しない（MUST）。順 2・順 4 の指摘が同じ failed に含まれていれば、それらの指摘の差分限定の再レビューは通常どおり行い、周を 1 つ消費する（MUST）。G は順 3 の表の「該当しない理由」の正否を判定しない（集合の一致だけを見る）。

#### Scenario: 順 3 だけで戻した周は周を消費しない

- **WHEN** 1 周目に順 3 の指摘だけで `agent-review:failed` にし、W の表と G の検索結果の集合が一致する
- **THEN** G は差分限定の再レビューを行わず、周回は 1 のまま手順 3 以降へ進む

#### Scenario: 集合が一致して閉じる

- **WHEN** W が検索コマンドと全ヒットの表を PR コメントに投稿し、G が同じコマンドを実行してヒットの集合が表と一致する
- **THEN** G はその指摘を閉じ、レビューをし直さない

#### Scenario: 2 回目も一致しない

- **WHEN** 差し戻し後の 2 回目の照合でも、表に無いヒットが残る
- **THEN** G はその指摘を順 6 の型として扱う

### Requirement: 今直す 3 条件（順 4）

SKILL.md は、順 4 の「今直す 3 条件」を次のとおり規定しなければならない（MUST）: 直し方が行レベルで 30 行以内であること、spec を変えないこと、この PR でその場で直した累計が 30 行以内であること。閾値は手順 2-0 と同じ 30 行を使い、別の数字を足してはならない（MUST NOT）。W は直したら、仕分け欄に「受け入れ条件の外・その場で直した・直し方 N 行」と記録する（MUST）。順 4 で直した指摘が 1 回で閉じなかったら、2 回目は順 6 の型に落とす（MUST）。

#### Scenario: 30 行の閾値が手順 2-0 と同じ

- **WHEN** `grep -n '30 行' SKILL.md` を実行する
- **THEN** 手順 2-0 の light 判定と、順 4 の直し方の上限と累計の上限が、どれも 30 行を使っている

### Requirement: 主への質問は推奨と見積もり付きで、その周で聞く（順 5）

SKILL.md は、順 5 で主に聞く文面に次の 4 点を必ず含めることを規定しなければならない（MUST）: 欠陥がマージ後に何を起こすか、直す見積もり（行数・触るファイル・spec を変えるか）、別 issue にする固定費、推奨。G は 2 周目の終わりまで待たず、指摘を受け取ったその周で聞く（MUST）。G は PR に `needs-approval` を付けて保留で return する（MUST）。この保留は無人運用（loop-dev-agent）でも同じく適用する（MUST）。

SKILL.md 手順 6 の復帰表は、保留の種類として「切り出しの確認」の行を持たなければならない（MUST）。その行は主の回答ごとに次を規定し、どちらの回答でも `needs-approval` を外すことを明示する（MUST）: 主が「切り出す」と答えたら、その指摘を follow-up issue に切って URL を PR コメントに記録し、`needs-approval` を外して、ほかに止める指摘が無ければ手順 3 以降へ進む。主が「この PR で直す」と答えたら、主の回答リンクを PR コメントに記録し、`needs-approval` を外して `agent-review:failed` に付け替え、修正サイクルに戻す（2 周目以降なら次の周に入る）。

#### Scenario: 1 周目に受け入れ条件の外の大きな欠陥が届く

- **WHEN** 1 周目に、受け入れ条件の外で、今直す 3 条件を満たさない止める指摘が届く
- **THEN** G はその周で `needs-approval` を付け、何が起きるか・見積もり・固定費・推奨の 4 点を書いて主に切り出すかを聞き、Status を保留として return する

#### Scenario: 主が切り出すと答えた

- **WHEN** 切り出しの確認で保留中の PR に、主が「切り出す」と回答する
- **THEN** G は指摘を follow-up issue に切って URL を PR コメントに記録し、`needs-approval` を外す

### Requirement: 同じ型の再発は決める役が方式を裁定する（順 6）

SKILL.md は、順 6 に当たった指摘について、決める役（`dev-workflow:decider`）が方式（全部列挙してから直す／切り出す）を裁定することを規定しなければならない（MUST）。決める役が裁定するのは方式だけで、止めるかどうかの判定は G が行う（MUST）。G は孫を持てないので、Status `needs-decider` で return し、本体が決める役を起こして裁定を受け取り、裁定を渡して G を再開する（MUST。本体の動きは `dev-workflow-develop` の「G の needs-decider を受けた本体の動き」Requirement）。決める役のモデルは既存の残量モードの規定に従う。

G は裁定を受け取ったら、裁定の内容を 1 行目 `決める役の裁定: 全部列挙してから直す` または `決める役の裁定: 切り出す` の PR コメントとして記録し、仕分け欄にも同じ内容を書く（MUST）。「PR ごとに 1 回まで」の回数は、G が再 spawn・再開されたときに、1 行目が正規表現 `^決める役の裁定: (全部列挙してから直す|切り出す)$` に完全一致する PR コメントの件数を、`gh api --paginate --slurp` で全ページから数える（MUST。G のコンテキストに回数を持たせない）。1 回目の裁定が「切り出す」だった場合もこの 1 回に数え、2 回目の順 6 は決める役を起こさず「切り出す」として扱う（MUST。厳しい側に倒す意図）。

裁定が「全部列挙してから直す」なら、G は `agent-review:failed` に付け替え、W に順 3 と同じ形の一覧を作らせて次の周に入る（MUST）。この裁定で周を開けるのは PR ごとに 1 回までとし、2 回目の順 6 は「切り出す」として扱う（MUST）。裁定が「切り出す」なら、順 5 と同じ経路で主に聞く（MUST）。決める役の裁定で開いた周は、主の回答で開いた周と同じに扱い、その周の終わりにも仕分け表を適用する（MUST）。

#### Scenario: 同じ型が 2 周続けて出る

- **WHEN** 2 周目の終わりに、1 周目と同じ型の止める指摘が別のファイルで残る
- **THEN** G は Status `needs-decider` で return し、本体が起こした決める役の裁定に従う

#### Scenario: 順 3 から落とし込む

- **WHEN** 1 周目に順 3 に当てた指摘が、差し戻し後の 2 回目の照合でも一致しない
- **THEN** G は周の終わりを待たずにその指摘を順 6 に当て、Status `needs-decider` で return する

#### Scenario: 再 spawn された G が裁定の回数を数える

- **WHEN** 1 行目が `決める役の裁定: 全部列挙してから直す` の PR コメントが 1 件ある PR で、再 spawn された G が再び順 6 に当たる指摘を受け取る
- **THEN** G は PR コメントからその 1 件を数え、決める役を起こさず「切り出す」として順 5 の経路で主に聞く

#### Scenario: 2 回目の順 6

- **WHEN** 決める役の「全部列挙してから直す」裁定で開いた周の終わりに、再び順 6 に当たる指摘が残る
- **THEN** G は決める役を起こさず「切り出す」として扱い、順 5 と同じ経路で主に聞く

### Requirement: W の指示書が一覧の表と今直す記録を持つ

`skills/develop/references/roles/worker.md` は、順 3 で W が PR コメントに投稿する表の書式（検索コマンド、全ヒットごとの「直した／該当しない理由」）と、投稿してから push する順序を書かなければならない（MUST）。あわせて、順 4 で直したときに (3a) の return と仕分け欄へ「受け入れ条件の外・その場で直した・直し方 N 行」を記録することを書かなければならない（MUST）。表の書式の正本は SKILL.md の順 3 とし、worker.md は参照する（MUST）。

#### Scenario: worker.md に検索コマンドの表がある

- **WHEN** `grep -c '検索コマンド' worker.md` を実行する
- **THEN** 1 以上

