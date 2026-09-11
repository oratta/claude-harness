## Context

着手前の実測（`tests/injection-budget.bats` の `breakdown()`、バイト）:

| 項目 | 現在値 |
|---|---|
| rules/*.md（README 除く 9 本） | 23,274 |
| CLAUDE.md | 5,732 |
| output-styles/*.md（メインのみ） | 6,863 |
| description 合計（plugins skills/agents/commands + .claude/skills + .claude/commands） | 16,124 |
| **合計** | **51,993** |
| 予算 `tests/injection-budget.txt` | 54,500 |
| 「30% 以上減」の到達線 | **36,395 以下** |

必要な削減は **15,598 バイト以上**。

制約:

- 予算は上下両方向のラチェットで、実測が予算の 1/1.1 を下回っても fail する。削減後は `tests/injection-budget.txt` の引き下げが必須
- 集計は `rules/*.md` を**全ファイル常時注入として**数える（`list_synced_md` は README だけを除く）。path スコープを採用すると、実態は常時載らないのに合計には載り続ける
- frontmatter 書式検査（`injection-budget-gate`）の対象は skill / agent / command の frontmatter であって `rules/*.md` ではない。rules に `paths:` を足しても既存の書式検査には当たらない
- 配布は `scripts/sync.sh` が `rules/*.md` を 1 ファイルずつ `~/.claude/rules/<name>.md` に symlink する形。ファイルの増減・rename は再実行で追随する

## Goals / Non-Goals

**Goals:**

- 常時注入の合計を 36,395 バイト以下にする
- ルールの内容を失わせない。縮約した分は必ず移設し、移設先を対応表で辿れるようにする
- path スコープが実際に効くかを、採用の前に手元で確かめる

**Non-Goals:**

- openspec スキルの二重掲載（`openspec-*` と `opsx:*` で同じ 10 スキルが載る）の解消。外部プラグイン側の構成で harness からは直せない
- 接続コネクタ 108 個の名前一覧（9,163 バイト）。アカウント側の設定
- `openspec/specs/` の肥大（1 件 45KB 級）。これは該当 capability を触る工程だけが払う変動費で、起動時固定分には 1 バイトも乗っていない。エピック #257 の別の子

## Decisions

### 決定 1: ルールごとの扱いを「残す / 縮約 + 移設 / path スコープ」の 3 通りで決める

判定条件は **「読むべき瞬間に、skill を呼ぶ判断ができるか」**。

やろうと思った瞬間が読むべき瞬間であるルール（破壊的操作の禁止など）は、そのとき「先にルールを読もう」と思えないからこそルールになっている。これは常時性を手放せない。一方、特定の作業に入ったことが自分で分かるルール（harness を編集する、ダッシュボードを触る）は、作業の入口で読めば足りる。

| ルール | 現在 | 扱い | 移設先 / 理由 |
|---|---|---|---|
| `destructive-git-guard.md` | 1,199 | **残す**（微縮約のみ） | 破壊的操作を思いついた瞬間が読むべき瞬間で、その時点で skill を呼ぶ判断ができない |
| `dev-server.md` | 625 | **残す** | 他プロジェクトのプロセスを kill する判断も同じ。すでに 625 バイトで削る余地が小さい |
| `plugin-editing.md` | 5,376 | **縮約 + 移設**、path スコープ第一候補 | harness を編集するときだけ要る。詳細は `CLAUDE.md` の「開発場所」節と `docs/worktree-recovery.md` に既にあり、rules 側は重複。path スコープは `rules/**`・`plugins/**`・`scripts/sync.sh` に当てる |
| `communication-style.md` | 4,833 | **縮約** | 全文の正本は `output-styles/readable.md`（6,863、メインのみ）。rules 側はサブエージェント向けの短い版という位置づけなのに、実際は全文に近い。要点だけ残す |
| `subagent-model-selection.md` | 3,219 | **縮約 + 移設** | ティア対応表と「`model` 必須」は残す。経緯・適用範囲・強制層の説明は `plugins/dev-workflow/references/model-tiers.md` へ |
| `perspective-casting.md` | 2,710 | **縮約 + 移設** | 5 手順の見出しだけ残し、各手順の説明は `plugins/casting/skills/casting/SKILL.md`（既に正本）へ |
| `git-commit-policy.md` | 2,383 | **縮約 + 移設** | 「承認なしに実行しない操作の一覧」は残す。PR 運用 / ローカル main 運用の判定手順と pr-review-gate 連携は `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` へ |
| `browser-infra-env-capture.md` | 2,070 | **縮約 + 移設**、path スコープ候補 | 1Password への昇格手順は `capability-registry` スキルが正本。rules 側は「表示された次のアクションで保存」の 1 点だけ |
| `link-when-requesting-review.md` | 859 | **縮約** | 書式の注意（裸 URL を括弧で囲まない）は残し、理由の説明を削る |

削減見込み: rules 23,274 → 約 7,000（-16,000 前後）。description 16,124 → 約 10,000（-6,000 前後）。CLAUDE.md 5,732 → 約 4,500（-1,200 前後）。合計で到達線に届く。

**代替案（採らない）**: ルールを丸ごと削除する。内容が失われて事故が再発する（各ルールは実事故から生まれている）。

### 決定 2: path スコープは「実機で効くと確認できたときだけ」採用する

公式仕様では rules frontmatter の `paths:`（glob のリスト）に一致するファイルを読んだときだけ載る。ただしユーザーレベル `~/.claude/rules/` で効かない不具合報告がある（anthropics/claude-code#22170、#17204。手元は 2.1.268）。

手順は「先に 1 件で確かめ、結果によって残りの設計が変わる」。確認は実装タスクの**最初**に置く。

- **効いた場合**: `plugin-editing.md` と `browser-infra-env-capture.md` に `paths:` を付ける。あわせて `injection-budget-gate` を変更し、`paths:` を持つルールを合計から外す（外さないと、実態は載らないのに合計に載り続け、予算が実態とずれる）
- **効かなかった場合**: `paths:` を使わず、縮約と移設だけで到達線を目指す。決定 1 の見込みは path スコープ無しでも到達する数字なので、この分岐で受け入れ条件は変わらない

**代替案（採らない）**: 確認せずに `paths:` を付ける。効かなければ、ルールが常時載ったまま合計からだけ消えて、予算が実態より小さく見える状態になる（削減を偽装したのと同じ結果になる）。

### 決定 3: 移設は「削除ではない」ことを対応表で機械的に確認できる形にする

縮約後の各ルールに、移設先へのパスを 1 行で書く。これで rules を読んだ Claude が詳細の在処を辿れる。PR 本文の対応表は `rules/README.md` のファイル一覧表と同じ内容を持たせ、README 側を正本にする（README は集計対象外なので、ここに書いても固定分は増えない）。

**代替案（採らない）**: 対応表を PR 本文にだけ書く。PR はマージ後に読まれないので、半年後に「この詳細はどこへ行ったか」を追えない。

### 決定 4: description は「いつ起動するか」だけを残す

description は全スキル分が起動時に載り、本文は起動時にだけ読まれる。だから description に手順・背景・禁止事項を書くと、そのスキルを一度も使わないセッションにも全部載る。残すのは発火条件（どんな依頼・どんな語で起動するか）だけで、それ以外は SKILL.md 本文の冒頭へ移す。

## Risks / Trade-offs

- **縮約しすぎてルールが効かなくなる** → 各ルールに「発火条件」を必ず 1 行目に残す。何をしてはいけないかが 1 行で分かる状態を最低ラインにする。特に `destructive-git-guard.md` と `dev-server.md` は削減対象から外す
- **path スコープが一見効いたように見えて実は効いていない** → 確認は「対象パスを触ると載る」だけでなく「対象パスを触らないと載らない」の両方向を見る。片方向だけだと、常に載っている状態を「効いた」と誤認する
- **予算の引き下げ幅を欲張ると、次に 1 行足しただけで fail する** → 予算は実測に対してラチェットの余裕（1.1 倍）を持つ値に置く。削減後の実測 × 1.05 前後を目安にする
- **description を削って skill が起動しなくなる** → 削るのは手順と背景で、起動語（ユーザーが使う言い回し）は残す。削った skill を 1 件、実際の依頼文で起動できるか確かめる
- **`CLAUDE.md` と `AGENTS.md` の同期が崩れる** → `tests/agents-md-sync.bats` が同一性を強制するので、片方だけ編集すると test.sh が落ちる。編集は両方に同じ内容を入れる

## Migration Plan

1. path スコープの実機確認（両方向）。結果を記録先に残す
2. rules 9 本を縮約し、詳細を移設先へ移す。移設のたびに `rules/README.md` の表を更新する
3. description を縮約する（長いものから）
4. `CLAUDE.md` / `AGENTS.md` を縮約する
5. 実測を取り、`tests/injection-budget.txt` を引き下げる
6. `scripts/test.sh` 全件

ロールバックは通常の revert で足りる（配布は symlink なので、revert 後に `scripts/sync.sh` を回せば元に戻る）。

## Open Questions

- path スコープの実機確認の結果（採用可否）。実装タスク 1 で解消する
