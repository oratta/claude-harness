## MODIFIED Requirements

### Requirement: 事前判定と障害時フォールバックを区別する

スキルは、変更内容に基づく事前判定（light）と、従来モードの full における Codex CLI 障害時フォールバックを書き分けなければならない（MUST）。従来モードのフォールバックは残すが、Codex 不可と判定してよいのは、実際のコマンドで確認したバイナリ無し・認証切れ・待ち方の正本の総待ち上限到達だけとする（MUST）。companion / slash command の不在、未試行、auth.json の有無だけで不可と判定してはならない（MUST NOT）。他のエラーを三条件に読み替えて暗黙に Claude へ切り替えてはならない（MUST NOT）。#707 の新 Codex モードの App Server 固定・暗黙 exec / Claude fallback 禁止を維持する（MUST）。

Codex がオフ（`usage-account-registry` capability の要件「Codex を codex.enabled でオフにできる」。`usage_view.py --codex-enabled` が `off`）のときは、実測の三条件による不可判定とは別に、従来モードの full で Codex を試してはならない（MUST NOT）。バイナリ探索も Codex の呼び出しも行わない。オフは利用者が明示した設定であり、未試行や auth.json の有無からの推測ではない。したがって「未試行の Codex を不可と推測してはならない」という上の規則には当たらない。G は full と判定したあと Codex を試す前に `usage_view.py --codex-enabled` を実行し、`off` なら `needs-reviewer` を返す（根拠は `Codex オフ（設定）`）。オンのとき、およびこのコマンドが `on` を出すときの経路は変えない。この規則は従来モードの full にだけ適用し、develop の adapter 経路（本体が `codex-develop.py` で投げ先を選び直す経路）と新 Codex モードの経路は変えない。「従来モードでは Codex CLI を第一選択とする」と書く他の要件は、Codex がオフのとき適用しない。

PR コメントから light と full 障害時を判別できなければならない（MUST）。Codex オフが理由のときは、`レビュー実行者: Task サブエージェント（full・Codex オフ）` とし、証拠欄の `選んだ経路`・`終了コード`・`実待ち時間` は `未実行（Codex オフ）`、`実行コマンド` はオフの判定に使ったコマンドとその出力、`出力の要点` は Codex オフの設定により Codex を試していないこと、と書く（MUST）。実測した Codex 不可と区別できるよう、この書式には「実測した」を含めない（MUST NOT）。従来モードの full では対象 HEAD・選んだ経路・実際に叩いたコマンド・結果（取得できた終了コードと出力の要点、タイムアウト時は実待ち時間と完了未確認）を記録する（MUST）。G が full の Codex 不可により `needs-reviewer` を返す場合も同じ証拠を含める（MUST）。

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

#### Scenario: Codex がオフなら full でも Codex を試さない
- **WHEN** 従来モードで full と判定し、`usage_view.py --codex-enabled` が `off` を出す
- **THEN** G は `command -v codex` も Codex の呼び出しも実行せず、`needs-reviewer` を返し、根拠に `Codex オフ（設定）` と書く。本体が起こす Task サブエージェントのレビュー結果のあと、手順 3 以降は変わらない

#### Scenario: Codex オフの PR コメントは実測の不可と区別できる
- **WHEN** Codex オフが理由で Task サブエージェントがレビューした PR のコメントを読む
- **THEN** 1 行目が `レビュー実行者: Task サブエージェント（full・Codex オフ）` で、`選んだ経路` は `未実行（Codex オフ）`、`実行コマンド` にオフの判定コマンドとその出力 `off` がある。`実測した` の語は含まれない

#### Scenario: Codex がオンなら従来どおり
- **WHEN** `usage_view.py --codex-enabled` が `on` を出す（`codex` の設定が無い環境を含む）状態で従来モードの full を回す
- **THEN** Codex を第一選択とし、不可判定は実測の三条件だけで、オフの判定が経路を変えることはない

#### Scenario: 新 Codex モードには互換経路を適用しない
- **WHEN** #707 の新 Codex モードを実行する
- **THEN** この不可判定を exec / Claude fallback の許可に使わず、App Server 固定の制約を維持する
