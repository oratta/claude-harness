# context-audit-by-role — subagent-context-audit.sh に担当別の内訳を足す

## Why

develop ワークフローの担当（W / R1 / G / G のレビュアー / decider）は、起動直後の固定分・指示書の読み込み量・手渡しで再読みする量が担当ごとに大きく違う。2026-09-27 に手作業で集計した直近 10 日（flatmate / claude-harness）の中央値では、マージ前の検査担当（G）が上限 150K を 52%〜53% の頻度で超えていたのに対し、決める役（decider）は 0%〜30% だった。全担当をまとめて測る現行の `subagent-context-audit.sh` の `sources.isolated` / `sources.non_isolated` の内訳では、この担当差が見えない（隔離の有無は役割と相関するが役割そのものではない）。エピック [#511](https://github.com/oratta/claude-harness/issues/511) の後続の子は、この担当別の数字を使って施策の前後比較を行う。

親エピック: [#511](https://github.com/oratta/claude-harness/issues/511)。この change は [#552](https://github.com/oratta/claude-harness/issues/552) に対応する。

## What Changes

- **`--by-role` フラグを追加する**: 指定時のみ、出力に新しいトップレベルキー `by_role` を足す。既存キー（`count` / `first_median` / `sources` 等）の形は変えない。`--by-role` を付けない既定の呼び出しは現行と完全に同じ出力になる。
- **担当分類**: 隣の `agent-<id>.meta.json` から次の優先順位で分類する。① `agentType` が `dev-workflow:decider` なら `decider`（`description` の先頭が `R1:` であっても decider 扱いを優先する）。② それ以外は `description` の先頭コロン区切りトークンが `W` / `R1` / `G` / `Reviewer` のいずれかに完全一致すればそれを使う。③ どちらにも当たらない（`description` が無い・コロンが無い・未知のトークン・meta.json が無い/壊れている）場合は `unknown` に寄せる。分類できない件も `by_role` の合計から落とさない。
- **`docs_median`（指示書の読み込み量の中央値）**: `Read` ツール呼び出しで `file_path` が harness の指示書格納パス（`plugins/cache/oratta-claude-harness/` 配下の `.md`）に一致するもの、または `Skill` ツール呼び出しの直後に増えたコンテキストの合計を、担当ごとに中央値で出す。
- **`reread_pct`（作業担当の読み直し割合）**: 担当 `W` にだけ付く。`description` に含まれる `#N`（記録先番号）で同じ記録先の `W` をグループ化し、先行する `W` が読んだファイル（`Read` の `file_path` 全件、ファイル名一致・上限の見積もり）のうち、後続の `W` が読み直した割合を担当内の中央値として出す。先行が存在しない `W`（各グループの最初の 1 体）はこの中央値の母数から除く。
- **`docs/usage-audit.md` に読み方を追記する**: `--by-role` の使い方・出力キーの意味・分類規則・`reread_pct` の母数の注意を追加する。
- **強制はしない**: 既存同様、観測専用。閾値による停止・警告は加えない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-execution-strategy`: `subagent-context-audit.sh` の契約を持つ capability に、担当別集計（`--by-role`）の要件を追加する。既存の母集団集計（`count` / `sources` 等）・キャッシュ TTL・fail-open・`subagent-context.sh` 側の要件・残量モード導出は変更しない。

## Impact

- **コード**: `plugins/dev-workflow/scripts/subagent-context-audit.sh`（`--by-role` 追加。役割分類・`docs_median`・`reread_pct` の実装を追加するため、走査のフルスキャン化が `--by-role` 指定時にだけ発生する）。
- **文書**: `plugins/dev-workflow/docs/usage-audit.md`（追記）。
- **テスト**: `plugins/dev-workflow/tests/subagent-context-audit.bats`（`--by-role` の分類・`docs_median`・`reread_pct` の fixture とケースを追加）。
- **spec**: `openspec/changes/context-audit-by-role/specs/dev-workflow-execution-strategy/spec.md`（ADDED Requirements）。
- **性能**: `--by-role` を付けない既定呼び出しの走査コスト・出力は変えない。`--by-role` は担当分類とツール呼び出しの検出のためトランスクリプトの全文を前方から順に走査する（既定の先頭/末尾のみの部分読みより重い）。手動監査専用でセッション起動経路には載らないため許容する。既定と `--by-role` でキャッシュファイルが混ざらないよう、`--cache` 省略時は `--by-role` 指定時だけ既定パスに `.by-role` サフィックスを足す。
- **記録**: 実データで実行した結果を、着手前の基準値としてエピック #511 にコメントする（この change のタスク。恒久的な仕様ではない）。
- **やらないこと**: `SessionStart` hook への出力追加、閾値による強制停止、`subagent-context.sh`（1 体の実測）側の変更。
