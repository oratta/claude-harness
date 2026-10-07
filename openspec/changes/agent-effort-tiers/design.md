## Context

effort は frontmatter の `effort:` で定義側の既定を持てる。Agent ツールの `effort` 引数（Claude Code 2.1.292）は呼び出し単位でそれを上書きする。`model` は `rules/subagent-model-selection.md` で「呼び出しごとに必ず明示」だが、effort は未指定でも親の値を継ぐだけで、モデルの段を無言で上げる事故（最上位枠の消費）とは性質が違う。

## Goals / Non-Goals

**Goals**
- 4 つの agent 定義に effort の既定を持たせる
- 初期値と上書き方法を `model-tiers.md` 1 箇所に集約する

**Non-Goals**
- profile（`codex-role-profiles.json`）の effort を Agent 引数へ変換すること。`manual-codex-develop` が「監査情報として保持するだけ」と定めており、そのまま
- Workflow スクリプトの `opts` に effort を渡す仕組み（別の子 issue の範囲）
- effort の値を測って合否にすること。受け入れ条件の `/cost` 記録は合否に使わない

## Decisions

1. **既定は frontmatter、上書きは Agent の `effort` 引数。** `model` と違い呼び出しごとの明示は義務にしない。理由: 未指定でも定義側の値が効くため、無言の最上位枠消費は起きない。代案（呼び出しごとに必須にする）は、呼び出し箇所が多く強制層も要るのに得るものが無いので採らない。
2. **初期値: worker / gate-runner = `medium`、reviewer / decider = `high`。** worker は答えの型が決まった実装、gate-runner は決まった手順の実行で、浅く速く考えてよい。reviewer と decider は判断が集中する。記事は「実装 low・レビュー low・最終検証 high」を勧めるが、`codex-role-profiles.json` の Claude 側（W=medium、レビュー・決める役=high）と揃え、2 つの正本が食い違わないことを優先した。これは初期値で、`/cost` の前後記録を見て主が調整する。
3. **`model-tiers.md` には既存の「ティア → model」表の下に独立した節「役ごとの effort」を足す。** 既存の表を書き換えない（#614 との衝突を避ける）。節には 4 役の値の表・frontmatter が既定で Agent の `effort` 引数が上書きであること・上書きの優先順位（公式文書に書かれている範囲は「環境変数 `CLAUDE_CODE_EFFORT_LEVEL` > frontmatter の `effort` > セッションの effort」。Agent の `effort` 引数が frontmatter や環境変数とどう競合するかは公式文書（https://code.claude.com/docs/en/sub-agents ）に記載なし。引数が frontmatter より優先されることは issue #711 の記述に依る）・profile の effort は監査値のままであることを書く。
4. **`dev-workflow-decider-agent` は MODIFIED。** 「frontmatter は name・description・model・tools」に `effort: high` を足す。decider の bats は `model` / `tools` だけを見るので壊れない。

## Risks / Trade-offs

- effort を下げると W の出力が浅くなり、失敗ループ（2 連続失敗）に入りやすくなる可能性がある。根拠は記事の一般論で、このリポジトリでの実測は無い。→ 前後の `/cost` を PR に記録し、失敗ループの昇格が増えたら medium を上げる。戻し方は frontmatter 1 行の修正。
- 公式文書（sub-agents の frontmatter 節）は、frontmatter の `effort` がセッションの effort を上書きするが環境変数 `CLAUDE_CODE_EFFORT_LEVEL` は上書きしないと書いている。環境変数が設定された環境では、4 役の frontmatter の値は効かず、環境変数の値が全役に効く（効果を測る前に `echo $CLAUDE_CODE_EFFORT_LEVEL` で確認する）。Agent の `effort` 引数と環境変数の関係は文書に記載なし。2.1.292 より古い版では `effort` frontmatter が無視されるだけで害はない。
