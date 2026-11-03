# Design

## Context

動機は proposal.md を参照。現行の名前探索は `agent-*<name>-*.jsonl` と `agent-*<name>.jsonl` の glob を結合し、重複を除き、ログの mtime 降順に並べる。その後、最初に見つかる cwd 一致のログを選び、一致が無ければ最新のログを選ぶ。`--file` の直接指定は別経路である。

## Goals / Non-Goals

**Goals:** metadata とファイル名の候補が混在しても、既存の選択規則を 1 回だけ適用する。metadata の欠落・不一致・破損によって従来の探索を妨げない。

**Non-Goals:** 計測式、usage のエラーレコード処理、上限判定、`--stop-since`、途中計測 hook、監査スクリプトは変更しない。version 更新は行わない。

## Decisions

### metadata とファイル名の候補を同じ選択処理へ渡す

既存の探索ディレクトリと同じ深さの `agent-*.meta.json` を読み、JSON オブジェクトの `name` と引数の名前を完全一致で比較する。一致する metadata の末尾 `.meta.json` を `.jsonl` に置き換え、実在するログだけを候補に加える。JSON が壊れている・オブジェクトでない・name が無い・name が違う場合や、metadata を読めない場合は、その metadata から候補を加えない。

従来の 2 つの名前 glob は残し、metadata からの候補と合わせて重複を除く。全候補をログ自体の mtime 降順に並べ、現行の cwd 一致優先処理で選ぶ。metadata の mtime は使わない。cwd 一致候補が無い場合は全体で最新のログを選ぶ。同時刻の候補間の順序は現行と同様に指定しない。

metadata の一致があればそこで探索を打ち切る案では、新しい別 cwd のログが既存の cwd 一致ログより優先されうる。候補を統合することで、issue 本文の条件 3「今までの選び方に合わせる」を探索元にかかわらず満たす。ファイル名からしか候補が得られない場合も同じ処理で選べるので、triage の条件 5 のフォールバックを保てる。

候補が無い場合は既存の `transcript not found` の JSON と exit 1 を維持する。`--file` は metadata 探索を通さず、そのまま直接測る。

## Risks / Trade-offs

- 全セッションの metadata を読む分だけ探索の I/O が増える → 既存と同じ深さの subagents 内に探索を限定し、JSONL 全文の読み取りを候補選択前に追加しない。
- 壊れた metadata や対応ログの無い metadata がある → 個別に読み飛ばし、従来のファイル名候補と他の正常な metadata を使えるようにする。
- 同名ログの誤選択 → bats ではログの `file` と `context_tokens` を検証し、cwd 優先・同じ cwd で最新・cwd 不一致時に最新の各ケースを作る。mtime は `os.utime` 等で明示してテストの待ち時間に依存させない。

## Migration Plan

既存ログの書き換えや設定変更は不要。R1 の APPROVE 後に対象スクリプトと bats を変更し、対象テストと `./scripts/test.sh` を実行する。取り消す場合はその変更を通常の PR で戻す。
