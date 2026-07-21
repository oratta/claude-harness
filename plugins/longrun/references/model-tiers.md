# モデルティア → opts.model 対応表（一元管理）

このファイルは longrun のモデル割り当て機構における **ティア名 → `opts.model` 渡し値の唯一の解決元**である。

<!-- DRIFT 防止: モデル ID / エイリアスを書いてよいのは本ファイルのみ。
     plan-template.md・longrun-plan SKILL.md・commands/exec.md・templates/workflow/*.js は
     ティア名（haiku / sonnet / fable / inherit）だけを扱い、解決はここを参照すること（change-4 / D3）。 -->

## なぜ 1 箇所に集約するか

モデル ID は世代交代で変わる。plan.md・workflow スクリプト・SKILL.md に ID を散在させると、
更新漏れで無言のドリフトが起きる。本ファイル 1 箇所に集約することで、新世代対応は
この対応表の 1 行変更だけで全経路に伝播する。

## ティア → `opts.model` 渡し値

`opts.model` は Workflow ツールの `agent(prompt, opts)` に渡すモデル指定で、
**agent 定義 frontmatter の `model:` 指定より優先される**
（一次ソース: `plugins/longrun/references/workflow-tool-reference.md` §3）。

渡し値は **エイリアス**を採用する（reference §3 で `model: 'haiku'` を実機検証済み、
`'sonnet' | 'opus'` も同一機構）。エイリアスはモデル世代交代に追従するため、
フル ID 直書きよりドリフトに強い。

| ティア | 用途の目安 | `opts.model` に渡す値 |
|--------|-----------|----------------------|
| `haiku`   | 定型的な検証・要約など軽量タスク | `'haiku'` |
| `sonnet`  | リサーチ・ブラウザ操作・中規模実装。builder の出発点 | `'sonnet'` |
| `fable`   | 判断が集中する場所（checkpoint 再ランク・verify の最終判定・アーキテクチャレビュー） | `'fable'` |
| `inherit` | 分類に迷うタスクの保守的デフォルト（高能力が必要） | （**渡さない**） |

## reserve 降格ルール（fable のみ対象）

環境変数 `FABLE_BUDGET_MODE` が `reserve` **かつ** `LONGRUN_AUTOMATED` が `1` のとき、
`fable` ティア（上書き欄経由を含む）は `'opus'` に降格して解決される（resolver が処理し、
降格した旨を `warnings` に含める。実行は中断しない）。

- 目的: 週次の全体枠は残っているが Fable 枠だけ枯渇しそうな時、残りの Fable を
  ユーザーの interactive 利用のために温存する（dev-workflow の残量モード定義を参照）。
- `LONGRUN_AUTOMATED=1` は**無人配線（cron / loop-dev-agent 等）側が設定する責務**。
  interactive セッションでは未設定のため降格は起きない。設定漏れ時は降格されない方向
  （品質は守られ、温存だけが効かない）に倒れる。
- haiku / sonnet / inherit の解決は reserve の影響を受けない。

> モデル ID 世代交代の参考対応（2026 時点。実際に渡すのは上表のエイリアス）:
> haiku エイリアスは `claude-haiku` 系、sonnet エイリアスは `claude-sonnet` 系の最新世代に解決される。
> エイリアス運用のため、世代交代時も本表のエイリアス値は通常変更不要。

## `inherit` のセマンティクス（重要）

`inherit` は **`opts.model` キー自体を出力しない**ことを意味する（値で `'inherit'` を渡すのではない）。

- `opts.model` を**渡さない／省略する**と、Workflow ツールの既定の解決順
  （agent 定義 frontmatter `model:` → 親セッションのモデル）がそのまま働く。
- longrun の 7 種 agent は現状すべて frontmatter で `model: opus` を持つため、
  `inherit` は現状 opus に解決される。
- 将来 agent 定義が `model:` を外した場合は、親セッション継承として自然に縮退する。

何らかの値（例 `'inherit'`）を渡すと agent frontmatter の `model: opus` を**意図せず上書きする**
リスクがあるため、`inherit` ティアでは `opts.model` キーを**必ず省略**する。

## fail-soft（未知ティア）

未知のティア値（表に無い文字列）・パース不能な行は **`inherit` として扱い、警告を表示して続行する**
（exec を中断しない／AskUserQuestion を出さない）。最適化機構の読み取り失敗は run を止める理由にならない。
