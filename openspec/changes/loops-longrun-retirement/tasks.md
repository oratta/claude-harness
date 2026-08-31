## 1. テストを先に書く（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/retirement.bats` を新設: 3 ディレクトリ不在・marketplace の `plugins[]` と bundles から 3 名が消えている・`plugins/` と marketplace の登録が一致・38 spec ディレクトリ不在・許容リスト外の `loops:|/lr:|longrun` ヒット 0 件・旧 reference パスの参照 0 件・CHANGELOG に uninstall 3 行と `/reload-plugins`・新旧パス対応表・ルート README に解散記録
- [ ] 1.2 `plugins/dev-workflow/tests/shared-references.bats` を新設: 4 契約の実在・README の `references/` 節・self-verification の中核原則と 4 種別・対象一覧に longrun/loops 無し・参照元 7 か所が新パス・model-tiers の 4 行表とエイリアス規則と `LONGRUN`/resolver/plan.md 不在・rules が model-tiers を指し行数 43 のまま・workflow-execution の 3 フェーズ/Build Contract/しきい値/schema/workflow-authoring と `/lr:e`・`plan.md` 不在・tripwires と develop SKILL.md が workflow-execution を指す
- [ ] 1.3 `plugins/loops/tests/pr-body-format.bats` の reference 検査を `plugins/dev-workflow/tests/pr-body-format.bats` に移す（REF を新パスに、TEMPLATE/INSTALL/MANIFEST 系のテストは落とし、issueify の 2 節検査を `skills/issueify/SKILL.md` に向ける。正本パスが issueify の新パスであることも検査）
- [ ] 1.4 `plugins/dev-workflow/tests/issueify-skill.bats` を新設: plugin.json の `skills[]` 登録・frontmatter `name: issueify`・4 入力モード・6 節ドラフト・4 型の受け入れ条件・承認ゲート・ラベル 5 種・`dependencies/blocked_by`・`loops`/`goalify`/`agent-loop-template` 0 件・pr-body-format 新パス参照・develop.md が同プラグイン内 Read で `plugins/loops` を含まない
- [ ] 1.4b `tests/marketplace-sync.bats` を新設し、`plugins/loops/tests/integration.bats` の S130 / S130b / S131 / S132 / S133 / S139 を移す（loops の helper に依存しない自前 setup。S127/S128 は捨てる）
- [ ] 1.4c `plugins/dev-workflow/tests/self-verification-sections.bats` を新設し、`plugins/loops/tests/skill-verification-sections.bats`（S42〜S50）と `self-verification-reference.bats`（S36〜S41）を移す（対象 6 スキル・REF を新パス・S40 の実パス一覧から longrun-plan を外す）
- [ ] 1.5 既存テストを更新: `develop-skill.bats`（`longrun:plan` 見出し → 「上流の壁打ち」見出し、wire 1 の `/lr:e` → `workflow-execution`、`/lr:p` 不在）、`develop-command.bats`（`loops-issueify` → `skills/issueify`、`plugins/loops` 不在）、`push-guard-setup.bats`（`loops-dev-agent-install` → `loop-dev-agent`）
- [ ] 1.6 `bash scripts/test.sh dev-workflow` を実行し、新設・更新したテストが Red であることを確認する

## 2. 契約と issueify を dev-workflow に置く

- [ ] 2.1 `plugins/dev-workflow/references/self-verification.md` を作る（旧 loops 版から中核原則・4 種別・記載ルールを引き継ぎ、参照パスを新パスに、対象一覧から longrun/loops の行を除いて 6 スキルにする。冒頭の「公式記事 loops」の由来は「ターンベースの自己検証」として残す）
- [ ] 2.2 `plugins/dev-workflow/references/pr-body-format.md` を作る（旧 loops 版の内容を維持し、末尾の生成ロジック正本を `plugins/dev-workflow/skills/issueify/SKILL.md` に、issue テンプレは「リポの issue テンプレート（flatmate が配る）」に差し替える）
- [ ] 2.3 `plugins/dev-workflow/references/model-tiers.md` を作る（D2 のとおり。ティア表・エイリアス規則・inherit の意味・ロールの目安・残量モードによる降格。longrun 固有の機構は書かない）
- [ ] 2.4 `plugins/dev-workflow/references/workflow-execution.md` を作る（D3 の 6 点。`workflow-authoring` を正本として指す）
- [ ] 2.5 `plugins/dev-workflow/skills/issueify/SKILL.md` を作る（旧 loops-issueify を基に D7 の依存解消。frontmatter `name: issueify`、description に起動語）。`plugin.json` の `skills[]` に `./skills/issueify` を追加

## 3. 参照元を新パスに向ける

- [ ] 3.1 `commands/develop.md` の issueify フォールバックを同プラグイン内 Read に書き換える（`${CLAUDE_PLUGIN_ROOT}/skills/issueify/SKILL.md`、フォールバック探索は dev-workflow 配下のみ。fail-soft 縮退は維持）
- [ ] 3.2 `templates/escalation-tripwires.md`: 導入手順の unmanned の項を憲法（`docs/agent-loop.md`。flatmate 保守。harness にテンプレ無し）に、`/lr:e、/lr:p 等` の例示を `references/workflow-execution.md`・`/opsx:explore` に、wire 1 の乗り換え先を「ネイティブ Workflow 実行（`references/workflow-execution.md`）」に、wire 3 の構造的決定を `/opsx:explore` に書き換える
- [ ] 3.3 `skills/develop/SKILL.md`: 「longrun:plan を呼ばない理由」節を「上流の壁打ち（`/opsx:explore`）を呼ばない理由」に、参照節の「棲み分け相手」を「各リポの loop-dev-agent 憲法（`docs/agent-loop.md`。flatmate 保守）」に書き換える。実行モード表の loops 言及も同様
- [ ] 3.4 `skills/push-guard-setup/SKILL.md` の `loops-dev-agent-install`（3 か所）を「loop-dev-agent 導入済み repo（flatmate の `new-resident` が設置）」に書き換える
- [ ] 3.5 自己検証の参照パスを 7 か所で差し替える: infra-setup / weekly-report / daily-report / experience-to-skill / wt-setup / wt-clean の SKILL.md と `plugins/worktree/references/wt-clean-verification.md`（行数を変えない。節の 15 行制限を守る）
- [ ] 3.6 `rules/subagent-model-selection.md` の 40 行目を「ワークフロー実行のロール別ティアは dev-workflow の `plugins/dev-workflow/references/model-tiers.md`」に差し替える（43 行のまま）。`rules/git-commit-policy.md` の `/lr:a` を `/opsx:archive` に
- [ ] 3.7 `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md` と `README.md` の「`longrun:archive` / `openspec:archive` の完了通知」を「`openspec:archive`（`/opsx:archive`）の完了通知」に
- [ ] 3.8 `plugins/casting/catalog/injection.md` の設計時の配線先（3 か所）を longrun plan から「`/opsx:explore`・opsx proposal（develop の W が担う）」に書き換える
- [ ] 3.9 `plugins/skill-pack/skills/skill-pack/SKILL.md` の例示 `✅ longrun@oratta-claude-harness` を `✅ dev-workflow@oratta-claude-harness` に
- [ ] 3.10 `scripts/test-auto-merge-workflow.sh` の fixture パス `plugins/longrun/README.md` を `plugins/casting/README.md` に

## 4. 解散プラグインと spec を消す

- [ ] 4.1 `git rm -r plugins/loops plugins/longrun plugins/lr`
- [ ] 4.2 削除対象 38 spec について、他の生きている spec からの参照を `grep -rn "<spec名>" openspec/specs` で確認し（歴史記述以外があれば MODIFIED を追加）、`git rm -r` で削除する
- [ ] 4.3 `.claude-plugin/marketplace.json` から `loops`・`longrun`・`lr` のエントリと bundles の 3 名を外し、dev-workflow の description を更新（`loops-issueify で起票` → `issueify スキルで起票`、`longrun:plan は呼ばず` → `上流の壁打ち（/opsx:explore）は呼ばず`）
- [ ] 4.4 ルート `README.md`: クイックスタートの例を `dev-workflow` に、longrun / loops の節と「その他のプラグイン」の `lr` 行を削り、dev-workflow 節の loops / longrun 言及を直し、「解散済みプラグイン」の短い記録（3 名・2026-08・CHANGELOG リンク）を置く
- [ ] 4.5 `openspec/backlog.md` の loops / longrun 由来の項目（Phase 2 Codex Builder・`/longrun:feedback` Tier 3・loops 廃案分・proactive-routines 拡張候補）を「loops / longrun の解散（#205）により対象消失」の 1 行注記に畳む

## 5. CHANGELOG・README・version

- [ ] 5.1 `plugins/dev-workflow/CHANGELOG.md` を新設し 2.1.0 の項に: uninstall 3 行と `/reload-plugins`、`enabledPlugins` からの除去、契約の新旧パス対応表（self-verification / pr-body-format / model-tiers / issueify、廃止した review-queue・feature-list-format・`/lr:e`・`/lr:p` の後継と理由）、flatmate 側の追従項目と issue リンク（6.2 で起票後に追記）
- [ ] 5.2 `plugins/dev-workflow/README.md`: `references/` の節（規約と 4 本の一言説明）と issueify スキルの節を足し、「loop-dev-agent との関係」を憲法の正本宣言（flatmate 側）に書き換える
- [ ] 5.3 version bump: dev-workflow 2.0.0 → 2.1.0、casting 0.4.0 → 0.4.1、experience-to-skill 0.3.1 → 0.3.2、skill-pack 0.2.0 → 0.2.1、infra 0.5.6 → 0.5.7、weekly-report 1.1.2 → 1.1.3、daily-report 0.3.4 → 0.3.5、worktree 2.12.2 → 2.12.3。plugin.json の description（dev-workflow）と marketplace.json の各エントリを同期

## 6. 検証と PR

- [ ] 6.1 `bash scripts/lint.sh`、`bash scripts/test.sh dev-workflow casting worktree infra daily-report weekly-report experience-to-skill skill-pack product-handover tests` を実行して全件 pass・exit 0 を確認。`grep -rn "loops:\|/lr:\|longrun" plugins rules docs README.md .claude-plugin scripts` の許容リスト外ヒットが 0 件であることを目視でも確認
- [ ] 6.2 flatmate 側の参照更新 issue を `gh issue create -R genetta-inc/flatmate` で起票し（`docs/agent-loop.md` の正本宣言後の自立・`docs/burn-mode.md` の review-queue 参照・issue テンプレの参照パス。harness #205 / PR #216 へのリンク）、URL を CHANGELOG と issue #205 のコメントに残す
- [ ] 6.3 `/opsx:verify loops-longrun-retirement` → `/opsx:archive loops-longrun-retirement`、commit / push、PR #216 の本文を `references/pr-body-format.md` の型で書いて Ready for Review、pr-review-gate を通す
