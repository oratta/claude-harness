## MODIFIED Requirements

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

## ADDED Requirements

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
