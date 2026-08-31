## Context

`loops`（レシピ集・loop-dev-agent 憲法テンプレ・issueify・review-queue・規約 reference）と `longrun`（plan.md → Workflow 実行の自律ハーネス。`lr` はその短縮コマンド）は、2026-08-29 時点で次の状態にある（issue #205 の調査表）:

| 部品 | 現況 |
|---|---|
| 憲法テンプレ `templates/agent-loop-template.md` | flatmate の `docs/agent-loop.md` が 449 行・差分 529 行で独自に育ち、「テンプレ側を直す」原則は破綻済み |
| `loops-issueify` | dev-workflow `commands/develop.md` の issueify フォールバックが path-discovery で読む。flatmate の burn-mode propose もこの形式に依存 |
| `references/pr-body-format.md` | dev-workflow の PR 手順・flatmate の issue テンプレが型として依存 |
| `references/self-verification.md` | infra / weekly-report / daily-report / e2s / worktree（wt-setup・wt-clean）の 7 スキルの `## 自己検証` 節が参照。spec `skill-verification-sections` が要求 |
| `loops-review-queue` | このリポ内に呼び出し元なし。flatmate `docs/burn-mode.md` が「残り PR を人が捌く経路」として参照 |
| レシピ 10 本・`loops-design`・`goalify`・`dev-agent-start`・`feature-list-format` 等 | 参照ゼロ |
| longrun `references/model-tiers.md` | `rules/subagent-model-selection.md` が「ロール別ティアの正本」として参照 |
| `/lr:e`（Workflow 実行） | `templates/escalation-tripwires.md` トリップワイヤー 1 と develop SKILL.md が昇格先として名指し。Workflow ツールと `workflow-authoring` スキルはネイティブにある |
| `/lr:p`（brain dump → plan） | develop が「呼ばない」と明記するのみ。最終コミット 2026-08-03 |
| `longrun-reviewer`（Build Contract）・`longrun-verifier`（定量 verify） | 前者は develop の R1（`spec-reviewer.md`）に置き直し済み。後者の姿勢は他に写しが無い |

制約: `rules/` は常時ロード層なので薄く保つ（今回は 1 行の参照差し替えのみ）。プラグインのファイルを変えたら version を上げないと `~/.claude/plugins/cache/` に反映されない（S131 が機械検査）。`plugins/` 配下の全ディレクトリが marketplace に登録されていることも S130b が検査する。ルートの `_longruns/` は過去の自律実行のアーカイブで、本 change の対象外（`scripts/test.sh`・`lint.sh`・`tests/shell-multibyte-expansion.bats` の除外指定はそのまま）。

## Goals / Non-Goals

**Goals:**
- `plugins/loops/`・`plugins/longrun/`・`plugins/lr/` を消し、`grep -rn "loops:\|/lr:\|longrun\|agent-owner" plugins rules docs` が移設先の説明文以外で 0 件になる（epic #208 の完了条件）
- 生きている契約 4 本（self-verification / pr-body-format / model-tiers / Workflow 実行の型）と issueify スキルを dev-workflow に移し、既存の参照元（7 スキル・rules・develop）をすべて新パスに向ける
- 解散した capability の spec を `openspec/specs/` から消し、正本の置き場に「存在しない機能の仕様」を残さない
- `/plugin uninstall` の手順と、flatmate 側で追従が必要な箇所を CHANGELOG に書く

**Non-Goals:**
- flatmate リポの編集（`docs/agent-loop.md`・`docs/burn-mode.md`・issue テンプレ）。別 issue を切って依頼する
- ルート `_longruns/` の整理
- `openspec/changes/archive/` 配下の歴史記録の書き換え
- develop の入口に brain-dump 壁打ち機能を新設すること（`/opsx:explore` で足りる）
- 移した契約の内容改訂（pr-body-format の型・自己検証原則の本文は変えない。パスと解散プラグイン由来の記述だけ直す）

## Decisions

### D1. 契約の置き場は `plugins/dev-workflow/references/`（プラグイン直下）

他プラグインから参照される契約をスキル配下（`skills/develop/references/`）に置くと、「develop スキルの内部資料」に見えて、worktree や infra のスキルがそこを参照する筋が通らない。プラグイン直下に `references/` を新設し「複数プラグインで共有する契約はここ」と README に書く。develop 固有の判定表（`decision-criteria.md`・`roles/`）は今の場所に残す。

代案: `rules/` 直下に置く。却下 — rules は毎セッション読み込まれる層で、150 行級の reference を置くと全セッションのコンテキストを食う。rules からは 1 行のポインタだけを張る。

### D2. model-tiers は longrun 固有の実装詳細を落として移す

残すもの: ロール → ティア → `opts.model` に渡すエイリアスの対応表、「エイリアスを渡す（フル ID 直書きしない）」規則、`inherit`＝`opts.model` を省略するの意味、残量モードによる降格（`reserve` は自動実行のみ・`exhausted` は全経路で `fable` → `opus`。正本は `decision-criteria.md` の残量モード表）。
落とすもの: resolver スクリプト（`resolve-model-allocation.mjs`）・plan.md の割り当てセクション・`LONGRUN_AUTOMATED` 環境変数（無人判定は憲法側が `--unmanned` として持つ）・fail-soft の未知ティア扱い。

`rules/subagent-model-selection.md` の該当 1 行は「ワークフロー実行のロール別ティアは dev-workflow の `references/model-tiers.md`」に差し替える。行数は変えない。

### D3. `/lr:e` の後継はネイティブ Workflow ツール直呼び、型は `workflow-execution.md` 1 ファイル

longrun の exec は「plan.md を読んで Workflow スクリプトを生成・起動する」薄い層だった。Workflow ツールと `workflow-authoring` スキル（スクリプト API・resume・品質パターン）がネイティブにあるので、経由する必然が無い。トリップワイヤー 1 と develop SKILL.md の乗り換え先は「ネイティブ Workflow 実行（`references/workflow-execution.md` の型で、`workflow-authoring` スキルを読んでスクリプトを書く）」にする。

`workflow-execution.md` に残す longrun の知見は 4 点に絞る: (1) Review → Build → Verify の 3 フェーズ構成と `meta.phases`、(2) Build Contract レビューは実装前に別コンテキストで行う（develop では R1 が担当済み。Workflow 内では reviewer agent を fable で）、(3) verifier の姿勢（自分が作っていないものを壊す立場・品質＝テスト/lint/型/ビルド 100% 必須・完成度 80%・疑わしければ FAIL・`schema` 付きレポートで自己申告を排除）、(4) ロール別ティア（builder は sonnet 出発、checkpoint/verify は fable。`model-tiers.md` を参照）。スクリプトの書き方そのものは書かない（`workflow-authoring` が正本）。

spec `dev-workflow-escalation-tripwires` の「2 段構えの配線」要件は「発火時のアクションはスキル呼び出しまたは本体への return で表現し、Workflow ツールの直接操作手順を含まない」と言っている。乗り換え先を「ネイティブ Workflow 実行」と書いても、テンプレートには**操作手順**を書かず `workflow-execution.md` への参照だけにするので要件の意図（テンプレは条件だけ）は保たれる。要件文の例示（`/lr:e、/lr:p 等の名前`）だけを差し替える。

### D4. `/lr:p` は廃止し、上流の壁打ちは `/opsx:explore` に委ねる

longrun-plan の価値は「形になっていない要望を対話で分解し、相互矛盾を確認して plan.md にする」ことだった。openspec ネイティブの `/opsx:explore`（思考のパートナーとして問題を調べ要件を明確にするモード）が同じ役割を持ち、その出口は `/opsx:new` / `/opsx:ff` → develop に自然につながる。plan.md という中間成果物を harness 独自に持つ理由が無くなった。

develop SKILL.md の「longrun:plan を呼ばない理由」節は「上流の壁打ち（`/opsx:explore`）を呼ばない理由」に書き換える（趣旨は同じ: develop が受け取るのは既にほぐれた依頼）。トリップワイヤー 3 の「構造に及ぶ決定 → `/lr:p` を起動して壁打ちに戻す」は「→ `/opsx:explore` で壁打ちに戻す」にする。`plan-interview-methodology.md`（1 問ずつ聞く方法論）は casting の policy-interview と communication-style の規則に同趣旨が既にあるので移さない。

### D5. `review-queue` は廃止（dev-workflow へ移さない）

判断材料: (a) このリポ内に呼び出し元が無い、(b) 読み取り専用のビューで、データ源の GitHub Project「Review Queue」は UI としてそのまま使える、(c) auto-merge が全面展開され、人が捌く PR は `human-merge` / `needs-approval` ラベルで `gh pr list --label human-merge --state open` の 1 行で出る、(d) dev-workflow に移すと「使われないスキル」を 1 つ増やすだけ。flatmate `docs/burn-mode.md` の「残り PR を人が捌く経路」の記述は flatmate 側 issue で `gh pr list` 系か Project URL に差し替えてもらう。

### D6. `feature-list-format.md` は廃止（dev-workflow へ移さない）

issue #205 の「やること」には移設と書かれているが、同 issue の調査表は「dev-workflow と flatmate の運用に吸収済み」としており、実際の利用者は `recipes/routine-long-build.md` の 1 本だけで、それは本 change で消える。配置規約 `{longrun-dir}/feature-list.json` の `{longrun-dir}` も消える。利用者の無い形式規約を移すのは「契約だけ残す」の趣旨に反するので廃止し、長期ビルドの外部状態が要る場合は Workflow の `args` / return 値と `resumeFromRunId` で持つ旨を `workflow-execution.md` に 1 行書く。主が移設を望むなら follow-up で git 履歴から戻せる（削除は git 追跡）。

### D7. issueify は dev-workflow の独立スキル、develop.md からは同プラグイン内 Read

`plugins/dev-workflow/skills/issueify/SKILL.md`（`name: issueify`）。`/develop` の issueify フォールバックは loops への 3 段 path-discovery をやめ、`${CLAUDE_PLUGIN_ROOT}/skills/issueify/SKILL.md` を Read してインライン実行する（Skill tool は使わない方針は維持）。fail-soft の縮退手順（最小ドラフト → 承認 → `gh issue create`）は「ファイルが読めない」場合の保険として残す。

本文の解散プラグイン依存を解く: (a) `loops-goalify` の方法論への参照 → 受け入れ条件の作り方（実行コマンド + 期待値。テスト / API / UI / 成果物の 4 型）を本文に書く（元から本文にあるので参照行だけ落とす）、(b) `recipes/loop-dev-agent.md` → 「無人ループ（loop-dev-agent。憲法は各リポの `docs/agent-loop.md`）」、(c) `.github/ISSUE_TEMPLATE/agent-task.md` → 「リポに issue テンプレートがあればその構造、無ければ以下の 6 節」、(d) 起票後のラベル体系（`agent-ready` / `needs-approval` / `human-only` / `size:large` / `agent-proposed`）は loop-dev-agent 運用の契約なので残す。

### D8. 解散 capability の spec は削除し、削除自体を新 spec の要件にする

openspec の delta で 38 spec 分の `## REMOVED Requirements` を書くのは冗長で、archive 後に「要件ゼロの spec ファイル」が残る（`tests/openspec-specs-format.bats` が退行として検出する形）。先例 `plugin-retirement-cleanup` に倣い、新 capability `loops-longrun-retirement` の要件に「対象 spec ディレクトリが存在しないこと」を書き、実装で git 追跡の削除を行う。生き残る契約の要件は新 spec（`dev-workflow-shared-references`・`dev-workflow-issueify`）に引き継いで書く。

削除対象: `loops-*`（19）・`longrun-*`（14）・`workflow-exec`・`workflow-tool-reference`・`workflow-run-control`・`legacy-command-removal`・`loop-dev-agent-tripwires`（計 38）。残すもの: 過去の一回性作業を記録した spec（`marketplace-final-sync`・`retirement-handoff-docs`・`llm-log-relocation`・`repo-root-cleanup`・`plugin-retirement-cleanup`）は `longrun` / `_longruns` を歴史記述として含むが、現在の振る舞いを規定していないので触らない。`skill-verification-sections`・`global-push-guard`・`dev-workflow-issue-entry`・`dev-workflow-escalation-tripwires`・`experience-to-skill-jsonl-distillation` は生きている要件なので MODIFIED で直す。

### D9. アンインストール手順は `plugins/dev-workflow/CHANGELOG.md`

リポ直下に CHANGELOG は無く、#206 の先例（`plugins/product-handover/CHANGELOG.md` に旧名からの移行手順）に合わせて、契約の受け皿である dev-workflow の CHANGELOG に「2.1.0: loops / longrun / lr の解散と契約の移設」として `/plugin uninstall loops@oratta-claude-harness` 等 3 行・`/reload-plugins`・`enabledPlugins` からの除去・契約の新旧パス対応表・flatmate 側の追従項目を書く。ルート README の loops / longrun / lr の節は削り、「解散済みプラグイン」の 3 行（名前・時期・CHANGELOG へのリンク）に置き換える。

### D10. テストは dev-workflow 側に移し、解散を機械検査する

- `plugins/loops/tests/pr-body-format.bats` の reference 検査部分を `plugins/dev-workflow/tests/pr-body-format.bats` に移す（憲法テンプレ・dev-agent-install・loops version の検査は削除対象なので落とす。issueify の 2 節検査は新パスに向ける）
- 新設 `plugins/dev-workflow/tests/shared-references.bats`: 4 契約の実在・self-verification の参照元 7 か所が新パスを指す・旧パス `loops/references/` の参照が 0 件・model-tiers に `LONGRUN` / resolver の記述が無い・workflow-execution が `workflow-authoring` を正本として指す
- 新設 `plugins/dev-workflow/tests/issueify-skill.bats`: frontmatter `name: issueify`・4 入力モード・承認ゲート・依存関係コマンド・解散プラグインへの参照 0 件・develop.md が同プラグイン内 Read に変わっている
- 新設 `plugins/dev-workflow/tests/retirement.bats`: 3 ディレクトリ不在・marketplace に 3 名が無い（`plugins[]` と bundles）・38 spec ディレクトリ不在・`grep -rn "loops:\|/lr:\|longrun" plugins rules docs README.md .claude-plugin` の許容リスト外ヒット 0 件・CHANGELOG に uninstall 3 行
- 既存テストの更新: `develop-skill.bats`（`longrun:plan` 見出し → 新見出し、wire 1 の `/lr:e` → `workflow-execution`）、`develop-command.bats`（`loops-issueify` → `skills/issueify`）、`push-guard-setup.bats`（`loops-dev-agent-install` → `loop-dev-agent`）

許容リストの考え方: 「移設先の説明文」＝ CHANGELOG（新旧対応表）・spec-reviewer.md の由来説明・product-handover CHANGELOG の「loops の解散は #205」・`_longruns/`（ルートのアーカイブ dir 名）に限る。テストはこの 4 種を正規表現で除外し、それ以外のヒットを違反とする。

## Risks / Trade-offs

- [install 済み環境で解散プラグインのキャッシュが残り、`/loops:*` `/lr:*` が見えたまま動かなくなる] → CHANGELOG に uninstall 手順を書き、README から誘導する。marketplace から消えるので次回の plugin update で新規 install はできなくなる
- [flatmate の憲法 `docs/agent-loop.md` が `/loops:issueify` や `pr-body-format.md` の旧パスを参照し続ける] → 憲法は flatmate 側で自立させる（正本宣言）。flatmate 側 issue で参照パスの更新を依頼し、PR 本文にリンクする。harness 側では新パスに旧パスを併記しない（二重管理を避ける）
- [`rules/subagent-model-selection.md` の変更は聖域パス接触で human-merge] → 想定どおり。1 行の差し替えに留め、レビュー負荷を上げない
- [38 spec の一括削除で、他の生きている spec が削除対象の要件名を参照しているかもしれない] → 実装前に `grep -rn "<削除 spec 名>" openspec/specs` で被参照を確認し、歴史記述以外の参照があれば MODIFIED で直す
- [self-verification の参照パスを 7 スキルで書き換えるため 5 プラグインの version bump が必要] → S131 の要求どおり patch bump。worktree の `unattended-mode.bats` 等が節の行数（15 行以内）を検査しているので、参照行の置換で行数を変えない
- [feature-list-format の廃止が issue の記述（移設）と食い違う] → D6 に理由を書き、PR 本文と issue コメントで明示する。git 履歴から復元可能

## Migration Plan

1. 契約 4 本と issueify を dev-workflow に**先に置く**（旧パスと新パスが一時的に併存）
2. 参照元（7 スキル・rules・develop・push-guard・casting・skill-pack・e2s）を新パスに向ける
3. `plugins/loops`・`longrun`・`lr` と 38 spec を git 追跡で削除、marketplace / README / backlog を更新
4. version bump（dev-workflow 2.1.0、参照を直した 7 プラグインは patch）と marketplace 同期
5. bats 全件 → PR → pr-review-gate（human-merge）→ マージ後に `/plugin uninstall` 3 行を各環境で実行、flatmate 側 issue を進める

ロールバック: 単一 PR なので revert で全体が戻る。部分的に戻すなら `git checkout <merge-base> -- plugins/loops` 等で復元できる（削除は git 追跡）。

## Open Questions

- なし（review-queue と feature-list-format の廃止は D5 / D6 で決め、PR で主に見えるようにする。異論があれば follow-up で git 履歴から戻す）
