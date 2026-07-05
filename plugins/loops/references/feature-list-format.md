# feature-list 形式（feature-list-format）

長期ビルドルーチン（`recipes/routine-long-build.md`）が使う外部状態の真のソースが `feature-list.json` である。
これは harnesses 論文（`research/claude-code-official.md` §7）の外部状態設計を、ネイティブ合成で実現するための
形式規約である。**JSON Schema による機械的強制は導入しない（MUST NOT）**。形式はこのリファレンスの記載のみとする
（schema 化・機械検証は必要になってから backlog で対応）。

## 配置

利用側の longrun ディレクトリ直下に置く: `{longrun-dir}/feature-list.json`。
進捗ノート `{longrun-dir}/claude-progress.md`（progress notes）と対で運用する。

## 形式

`feature-list.json` は項目（feature）の配列。各項目は以下の **4 キー**を持つ JSON オブジェクトとする:

```json
[
  {
    "id": "feat-1",
    "description": "何を実装するかの 1 行説明",
    "verification": "この項目が完了したことを判定する実在の検証コマンド（bats / grep / jq 等、exit code が本物のもの）",
    "passes": false
  }
]
```

| キー | 意味 |
|---|---|
| `id` | 項目の一意識別子。凍結や参照に使う。 |
| `description` | 実装対象の 1 行説明。 |
| `verification` | 完了判定に使う**実在の検証コマンド**（exit 0 で合格）。決定論的に判定できること。 |
| `passes` | 合格フラグ。**初期値は必ず `false`**。verification コマンドの exit 0 evidence がある場合のみ `true` に更新する。 |

## 不変条件（MUST）

- **`passes` の初期値は `false`**。全項目を `passes:false` で用意してから 1 サイクル 1 項目ずつ進める。
- **項目とその verification を削除してはならない（削除禁止）**。スコープ縮小の誘惑（達成できない項目を消して「完了」に見せる報酬ハッキング）を構造的に防ぐ。harnesses 論文「項目・テスト削除禁止」に対応する。
- 凍結（同一項目 2 連続 FAIL）した項目も**削除せず** `passes:false` のまま残し、凍結の事実と理由を progress notes に記録する。
- `passes:true` への更新は verification コマンドの **exit 0 の evidence（実行ログ）がある場合のみ**。自己申告での更新は禁止。

## progress notes（`claude-progress.md`）

各サイクルの記録（smoke check 結果・実装した項目・verification の exit code・passes 更新・凍結/エスカレーション）を
追記していく。エージェントのコンテキストは揮発するが、この 2 ファイルがリポジトリに残るため次サイクルが続きから再開できる
（「エージェントは忘れるが、リポジトリは記憶する」）。
