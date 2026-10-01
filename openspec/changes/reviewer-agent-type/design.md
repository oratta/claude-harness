## Context

エピック #511 の #330 で、W（作業者）と G（ゲート実行者）を frontmatter の `tools:` で道具を絞った種別（`dev-workflow:worker` / `dev-workflow:gate-runner`）に移した。道具の定義はサブエージェントの起動時に毎回読み込まれるので、道具を絞ると起動直後のコンテキストが減る。pr-review-gate のレビュアーはこの範囲に入っておらず、今も `general-purpose` で起こされ、起動直後の中央値が 57,964 トークンある。

レビュアーを起こす指示は次の 5 か所にある。

- `skills/pr-review-gate/stages/prepare.md` の「needs-reviewer の return」（本体が読む payload と既定の種別）
- `skills/pr-review-gate/stages/review-run.md` 2-1 の優先順の表（フォールバックの Task サブエージェント）とモデルの節
- `skills/develop/SKILL.md` の Agent ツールの行・(4) の needs-reviewer ③・モデル表の「G が要求するレビュアー」の行
- `references/codex-develop.md` の Claude role の起動（「R1 とレビュアーは `general-purpose`」）
- `plugins/dev-workflow/README.md` の役割とモデルの説明（レビュアーの種別が書かれていれば）

レビュアーの作業の正本は `skills/pr-review-gate/stages/reviewer-brief.md`。差分を読み（`git diff` / `gh pr diff`）、`git grep` で照合表を作り、テスト・lint を自分で再実行し、三表と指摘を起こした側に返す。PR へのコメント投稿は起こした側（G）が行う。

## Goals / Non-Goals

**Goals:**

- レビュアー用の種別を足し、本体がレビュアーを起こす既定の種別をそれに替える
- 新種別が Edit / Write / NotebookEdit を持たない
- 監査スクリプトが新種別を `Reviewer` に数える
- 起動直後の usage が `general-purpose` より 20,000 以上少ないことを、同じ指示文で並べて示す

**Non-Goals:**

- 仕様レビュー R1 の種別を替えること（R1 は `gh issue comment` で自分で記録を投稿するので、道具の要件が違う。今回の計測の対象でもない）
- 画面確認役 V の種別を替えること（ブラウザの道具が要る）
- 事前分類に当たるときに `dev-workflow:decider` で起こす扱い、および `agent-model-guard.sh` の判定規則を変えること
- Codex のレビュアー（従来モードの Codex CLI、adapter 経路の executor=codex）の扱いを変えること
- 上限超えの割合の事後計測（エピック #511 の完了計測でまとめて測る）

## Decisions

### 種別名は `dev-workflow:reviewer`

ファイル `agents/reviewer.md`、`name: reviewer`。監査の分類名（`Reviewer`）・Agent の description の慣例（`Reviewer: ...`）と揃う。代案の `pr-reviewer` は R1（仕様レビュアー）と区別しやすいが、既存の文書がこの役を一貫して「レビュアー」と呼んでいるので短い方を採る。

### 道具は `Read, Bash, Grep, Glob, TaskStop`

- `Bash`: `git diff` / `gh pr diff` / `git grep`（照合表の検索コマンドは `git grep` 固定）と、テスト・lint の再実行に要る
- `TaskStop`: テストを背景で起こしたときに、総待ちの上限で止めてから return するための道具。`plugins/dev-workflow/references/subagent-waiting.md` が正当な出口として定め、`scripts/subagent-stop-guard.sh` が種別を問わず検査するので、G と同じく持たせる。issue の当たり（Read / Grep / Glob / Bash）に 1 つ足した
- `Edit`・`Write`・`NotebookEdit`・`mcp__*`・`WebFetch`・`WebSearch`・`Skill`・`Agent` は持たせない。名前付き spawn で `SendMessage` が要ると実機で確かめた場合だけ `SendMessage` を足してよい（W / G と同じ扱い）

代案の「`Read, Grep, Glob` だけ（decider と同じ）」は、テストの再実行と `git grep` ができず reviewer-brief の手順を満たせないので採らない。

### 定義の `model` は `opus`

レビュアーの既定は `opus`（develop のモデル表・review-run.md のモデル節）。spawn のたびに `model` を明示する規則は変えないが、書き忘れたときに親セッションのモデル（Fable のことがある）を継承しないよう、定義に既定値を書く。`inherit` や省略にはしない。

### 本文は指示書を指すだけにする

worker.md / gate-runner.md と同じく、手順を写さず「起動指示に貼られたレビュアー向け指示ブロックと `skills/pr-review-gate/stages/reviewer-brief.md` に従う」「ファイルを編集しない」「サブエージェントを起こさない」「PR / issue にコメントを投稿せず、三表と指摘を起こした側に返す」だけを書く。

### Fable は種別で上げる規則のまま

`agent-model-guard.sh` の `DECIDER_TYPES` には足さない。`dev-workflow:reviewer` に `model: fable` を渡せば今の判定で拒否される。Fable に上げたいときは従来どおり `dev-workflow:decider`。スクリプトの変更はヘッダーのコメント（worker / gate-runner と並べて reviewer も DECIDER_TYPES に入れない旨）だけで、判定コードは変えない。

### 監査は `agentType` を description より先に見る

`classify_role` は今、`agentType == dev-workflow:decider` を最優先にし、次に description の先頭トークンを見る。`agentType == dev-workflow:reviewer` を decider の次に `Reviewer` へ分類する規則を足す。description が `Reviewer:` で始まっていない個体（description の書き忘れ・別の書き方）も数えられるようにするため。`dev-workflow:worker` / `gate-runner` を agentType で分類することは今回の範囲に入れない（issue の受け入れ条件にない）。

### 計測（受け入れ条件 1・2）はマージ前の版を `--plugin-dir` で読み込んで行う

マージ前は配布版のキャッシュ（`~/.claude/plugins/cache/`）に新種別が無いので、本体のセッションからは `dev-workflow:reviewer` を起こせない。計測は worktree の `plugins/dev-workflow` を `claude --plugin-dir` で読み込んだセッションで行う。

- 受け入れ条件 1: 同じ Claude Code の版・`model: opus`・同じ指示文（このPRの reviewer-brief のレビュアー向け指示ブロックと固定した差分範囲）で、`general-purpose` と `dev-workflow:reviewer` を 1 体ずつ起こし、各 `subagents/agent-*.jsonl` の最初の assistant 行の `message.usage` を読む。`input_tokens`・`cache_creation_input_tokens`・`cache_read_input_tokens` を分けて書き、合計の差を出し、版の番号と一緒に PR 本文の `## 新種別の計測` に書く
- 受け入れ条件 2: この PR 自身のゲートの Claude レビュアーを、次の手順で `dev-workflow:reviewer` として起こす（本体の決定）

#### この PR のゲートでレビュアーを起こす手順（受け入れ条件 2）

マージ前の版でしか新種別を起こせないので、この change の PR のゲートに限り、レビュアーは本体の Agent ツールではなく次の手順で起こす。この手順で起こしたレビュアーは、develop の「本体が `dev-workflow:reviewer` で spawn する」規定を満たしたものとして扱う。

1. 本体は worktree を cwd にして `claude -p --model sonnet --plugin-dir <worktree>/plugins/dev-workflow` を起動する。`-p` セッションのメインは中継だけを担うので `sonnet` で足りる
2. そのセッションの中で、Agent ツールを `subagent_type: dev-workflow:reviewer`・`model: opus`・description `Reviewer: ... for PR #<N> (#650)` で呼び、G の `needs-reviewer` の payload（固定 HEAD・受け入れ条件・diff の範囲・reviewer-brief.md のレビュアー向け指示ブロック）をそのまま渡す。区画があれば区画ごとに 1 体ずつ（description は `Reviewer: 区画 <k>/<n> for PR #<N> (#650)`）、補足の回も同じ方法で起こす
3. `-p` のプロンプトで、レビュアーの return を要約・加工せずにそのまま出力するよう指示する
4. 本体は `-p` の出力を正にしない。そのセッションの `subagents/agent-*.jsonl` の最後の assistant の return を三表と指摘の原文とし、隣の `meta.json` の `agentType`（`dev-workflow:reviewer` であること）と description を添えて、照合と振り分けの G に渡す
5. adapter 経路の G は full でも light でも `needs-reviewer` を返すので、G が Codex を自分で走らせる経路はこの PR では起きない。review phase の自動選択が codex を選んだ場合は、Codex のレビューに加えて 1〜4 の方法で Claude レビュアーを 1 体起こし、その結果も G に渡す。それができなければ、PR 本文の `## 新種別の計測` に「受け入れ条件 2 は満たせなかった」と理由とともに書く

## Risks / Trade-offs

- [`--plugin-dir` で読み込んだ版と、インストール済みの同名プラグインのどちらの定義が使われるかが曖昧] → 計測の記録に、起こしたエージェントの `meta.json` の `agentType` と、起動直後の system prompt に新種別の道具だけが並んでいること（`tools` の一覧）を添えて、どちらが使われたかを示す
- [レビュアーが `Bash` を持つので、原理上はシェル経由でファイルを書き換えられる] → 種別の保証は「編集の道具を持たない」までで、`Bash` 経由の書き換えは本文の指示（ファイルを編集しない）と、G の HEAD 固定による差分の検出に任せる。G と同じ扱い
- [起動直後の削減が 20,000 に届かない] → 受け入れ条件 1 に当たらないので、道具をさらに削れるか（`TaskStop` を外す等）を検討して return する。値はどちらでも記録する
- [description の追加で常時注入の予算に当たる] → description を 1 文にし、それでも足りないぶんだけ `tests/injection-budget.txt` を動かし、PR 本文に理由を書く（role-agent-types の既存要件どおり）

## Migration Plan

マージ後、各 PC で marketplace を更新すれば新種別が使える。戻すときは prepare.md / review-run.md / SKILL.md / codex-develop.md の既定の種別を `general-purpose` に戻せば、定義ファイルが残っていても使われない。

## Open Questions

（なし。受け入れ条件 2 でレビュアーを起こす経路は、本体の決定として「計測」の節の手順に書いた）
