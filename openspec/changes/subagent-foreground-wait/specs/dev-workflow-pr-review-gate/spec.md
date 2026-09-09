## ADDED Requirements

### Requirement: Codex の待ち方を読み手別に書き分ける
`skills/pr-review-gate/SKILL.md` の Codex 呼び出し規約は、このスキルをメインセッションとサブエージェント G の両方が読むことを前提に、待ち方を読み手別に書き分けなければならない（MUST）。メインセッションは背景タスクの完了で再起動されるため `--background` 起動 ＋ 完了通知で続行してよい（SHALL）。サブエージェントは再起動されないため、完了確認を同一ターン内の前景ポーリングで行わなければならず（MUST）、完了通知を待つ目的でターンを終えてはならない（MUST NOT）。詳細の正本は `plugins/dev-workflow/references/subagent-waiting.md` を参照する（SHALL）。

#### Scenario: サブエージェントとして読む
- **WHEN** G が pr-review-gate の Codex 呼び出し規約を読む
- **THEN** 完了通知に頼らず同一ターン内で前景ポーリングして待つこと、待ちでターンを終えないことが読み取れる

#### Scenario: メインセッションとして読む
- **WHEN** 本体が pr-review-gate の Codex 呼び出し規約を読む
- **THEN** `--background` 起動と完了通知での続行が引き続き許可されていることが読み取れる

### Requirement: 待ち値は前景上限未満を指定する
`skills/pr-review-gate/SKILL.md` が示す `codex-companion.mjs status --wait --timeout-ms` の値は 600000 未満でなければならない（MUST）。従来の 900000 は Bash 前景の 600 秒上限を超えるため 1 回の呼び出しで完走せず、これが待ちの構造を壊す原因になっていた。既定値として 540000 を示し、1 回で終わらなければ同じ呼び出しを繰り返す旨を併記する（SHALL）。`--timeout-ms` の既定が 4 分しかないため必ず明示するという既存の注意は維持する（MUST）。

#### Scenario: 待ち値の指定
- **WHEN** SKILL.md の Codex 呼び出し規約を読む
- **THEN** `--timeout-ms` に 540000 を明示する例が示され、900000 のような 600000 以上の値は残っていない

#### Scenario: 1 回で終わらない Codex レビュー
- **WHEN** 540000 ms 待っても Codex が完了しない
- **THEN** 同じ `status --wait` をもう一度呼ぶ指示があり、待ちのためにターンを終える指示は無い
