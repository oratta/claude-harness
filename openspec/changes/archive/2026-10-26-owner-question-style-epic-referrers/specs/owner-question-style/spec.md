## MODIFIED Requirements

### Requirement: 主に問いを返す各所は正本を参照し、固有の事柄だけを残す

次のファイルは、問いの書く順やリスクの書き方を自前で決めた文を持ってはならない（MUST NOT）。正本（`output-styles/readable.md` の節 3。サブエージェント向けには `rules/communication-style.md` の 3 番目）を参照し、その場所に固有の事柄（記録の書式・投稿先・URL の添え方・返事の場所）だけを残す（MUST）。正本を指すパスは、リポジトリの外からも辿れる形 `~/.claude/output-styles/readable.md`（Output Style `readable`）で書かなければならない（MUST）。リポジトリ相対パス（`output-styles/readable.md` だけ）で指してはならない（MUST NOT。プラグインは他のリポジトリから読まれるので、リポジトリ相対パスは辿れない）。

- `plugins/dev-workflow/skills/develop/SKILL.md`（保留の依頼の出し直し・主への案内・channel の聞き方と主への発言・Orca 経路の親の発言の 1 行目・手順 8 の報告の順）
- `plugins/dev-workflow/skills/develop/references/epic.md`（#1219 で SKILL.md から移した「エピックの扱い」。別セッション方式の親の発言の 1 行目・手順 8 の止まった子の報告の順）
- `plugins/dev-workflow/skills/develop/references/epic-child-stop.md`（#1219 で SKILL.md から移した「エピックの子が主の返事を待って止まるとき」。子の停止の記録と主への問いの型）
- `plugins/dev-workflow/skills/pr-review-gate/stages/hold.md`（手順 6 の主への確認依頼・切り出しの確認・主に承認を求めてよい 4 分類）
- `plugins/dev-workflow/skills/pr-review-gate/stages/pass.md`（動作確認の依頼）
- `plugins/dev-workflow/references/ci-watch.md`（オーナーへのマージの依頼）
- `rules/one-off-no-script.md`・`plugins/dev-workflow/references/one-off-operations.md`（レビューの残りを主に聞く記述）
- `plugins/casting/skills/casting/SKILL.md`・`rules/perspective-casting.md`（主に上げるかの判定）

`stages/hold.md` の 4 分類と、casting の返信前チェックの判定は残してよい（MAY）。ただし、正本の主に聞く理由の 3 つのどれに当たるかを示し、3 つと食い違ってはならない（MUST NOT）。pr-review-gate の記録の書式（リスク宣言・動作確認の 3 点セット・切り出しの確認の 4 点）は記録の項目として残してよい（MAY）。主に出す文面は正本の型に従う（MUST）。

この要件の守備範囲は、上のファイルの文面である。上に無いファイルで見つかった自前の書き方は、見つかったときに足す。この要件の完了条件にはしない。

#### Scenario: 参照先に旧い型の写しが残っていない
- **WHEN** 上のファイルを `目的 → いま取り組んでいる場所`・`決めてほしいこと・推奨・受け入れるリスク`・`「飲めるか」を 1 問だけ` で検索する
- **THEN** どれも見つからず、各ファイルに `readable.md` か `communication-style` への参照があり、`readable.md` を指す箇所はどれも `~/.claude/output-styles/readable.md` の形である

#### Scenario: 4 分類と返信前チェックが 3 つの理由と対応する
- **WHEN** `stages/hold.md` の「主に承認を求めてよい」節と、casting の `SKILL.md` の返信前チェックを読む
- **THEN** どちらも、自分の判定が正本の主に聞く理由の 3 つのどれに当たるかを示している
