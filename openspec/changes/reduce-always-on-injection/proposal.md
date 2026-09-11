## Why

全セッション・全サブエージェントの起動直後に常時載る固定分が 51,993 バイトあり、作業者サブエージェントの中央値（開始 58,000 → 終了 168,000 トークン）ではそのうち harness 側が減らせる分だけで総消費の約 16% を占める。ツールを絞っても効かないことは実測済みで（Read/Grep/Glob だけの decider でも初回 47,731 トークン）、効くのは文書側だけである。

いまの rules/*.md は「常時載る場所に、その作業のときにしか要らない詳細まで書く」形になっている（たとえば harness の開発手順 5,376 バイトは harness を触らないセッションでも毎回載る）。ルールを消すのではなく、**載る量と載るタイミングを分ける**。

親: エピック #257。着手条件の #258（予算テスト）はマージ済みで、削減量を同じ物差しで測れる状態にある。

## What Changes

- **rules/*.md 9 本を「発火条件と要点 1〜3 行」に縮める。** 各ルールの詳細は削除せず、既存の skill か references へ移す。移設先は 1 対 1 の対応表として残す
- **常時見えていないと事故る種類は縮約の対象から外す。** 破壊的 git 操作の禁止と他プロジェクトの dev server kill 禁止は、読むタイミングが「やろうと思った瞬間」であって、そのときに skill を呼ぶ判断ができるとは限らない
- **path スコープ（rules frontmatter の `paths:`）の採否を実機確認で決める。** 公式仕様では一致するファイルを読んだときだけ載るが、ユーザーレベル `~/.claude/rules/` で効かない不具合報告がある（anthropics/claude-code#22170、#17204）。採用可否を先に 1 件で確かめ、効かなければ縮約と移設だけで目標に届かせる
- **`output-styles/readable.md` は据え置く。** 書き方の正本そのもので、要点への縮約は正本の欠落になる（移設先を持たない）。メインセッションにしか載らずサブエージェントには載らない
- **SKILL.md / agent / command の `description` を発火条件だけに削る。** 手順・背景・経緯は本文へ移す。長いものから順に wt-clean（1,297）、experience-to-skill（1,022）、pr-review-gate（756）、daily-report（756）、develop（712）
- **`tests/injection-budget.txt` を削減後の実測に合わせて引き下げる。** 予算は上下両方向のラチェットなので、減らしただけでは逆にテストが落ちる
- openspec スキルの二重掲載（`openspec-*` と `opsx:*` で同じ 10 スキルが載る）は本 change では**対象外**とし、その判断を記録に残す。どちらも `openspec init` がこの repo に生成した commit 済みのファイル（`.claude/skills/openspec-*/SKILL.md` と `.claude/commands/opsx/*.md`、内訳では 1,510 + 640 バイト）で harness 側にあるが、手で削っても `openspec update` の再生成で戻る。加えて develop の作業者指示書が `/opsx:ff` 等のコマンド名に依存し、`opsx:archive` と `opsx:bulk-archive` はスキル本文を参照していて片方だけ消せない。削るなら `openspec update` の生成対象を絞る別 issue になる

**BREAKING なし**（ルールの内容は保存され、読み込まれるタイミングだけが変わる）。

## Capabilities

### New Capabilities
- `always-on-injection-scope`: 常時注入される文書（rules / CLAUDE.md / 各 description）に何を置いてよいか、置けないものをどこへ移すかの方針。縮約時に内容を失わせないための移設対応表の義務と、常時性を手放してはいけないルールの判定条件を定める

### Modified Capabilities
- `injection-budget-gate`: path スコープを採用した場合、常時注入されないルールを合計から外す（いまの集計は `rules/*.md` 全ファイルを常時注入として数えるため、条件付きのルールを足すと実態より多く見える）。path スコープを採用しない場合はこの capability に変更は入らない

## Impact

- `rules/*.md` 9 本（README は集計対象外）、移設先となる既存 skill / references
- `plugins/*/skills/*/SKILL.md`・`plugins/*/agents/*.md`・`plugins/*/commands/*.md`・`.claude/skills/`・`.claude/commands/` の frontmatter `description`
- `CLAUDE.md`（および同期複製の `AGENTS.md`。`tests/agents-md-sync.bats` が同一性を強制する）
- `tests/injection-budget.txt`（聖域。値を動かす PR は本文に理由を書く）、path スコープ採用時は `tests/injection-budget.bats`
- `rules/README.md` のファイル一覧表（移設で内容が変わる行）
- 配布は `scripts/sync.sh` の symlink 形のままで、ファイルが減っても増えても再実行で追随する（変更不要）
