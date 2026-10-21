## Why

harness の `skill-pack`・`telegram`・`experience-to-skill` の 3 プラグインは、Claude Code 本体や公式プラグインで代替できるか、使われていない。主が 2026-10-08 に削除を承認した。

- skill-pack: Claude Code 本体の `/skills` 画面・`skillOverrides`・`/plugin`（`claude plugin enable|disable --scope`）でプロジェクト単位の ON/OFF ができるようになり不要
- telegram: 公式 `telegram@claude-plugins-official` で代替できる。fork の目的だった「利用者のリアクションをセッションへ届ける」機能は不要と主が判断
- experience-to-skill: 公式の skill-creator スキルで足り、使われていない

前例は loops 系 3 プラグインの解散（#205）と Discord 改造版の解散（#314、capability `discord-plugin-retirement`）。同じ形で解散する。記録先は PR #841（issue は無い）。

## What Changes

- **BREAKING** `plugins/skill-pack/`・`plugins/telegram/`・`plugins/experience-to-skill/` を git 追跡の削除として取り除く（計 24 ファイル）。3 つとも `@oratta-claude-harness` からインストールできなくなる
- `.claude-plugin/marketplace.json` の `plugins[]` から 3 エントリを、`bundles[]` の `all` から `experience-to-skill`・`skill-pack` を外す（`telegram` は元から `all` に無い）。`bundles` の `all` に入っていないプラグインがある件（#708）はここでは扱わず、#708 自体は閉じない
- ルート `README.md` のプラグイン一覧から 3 行を外し、「解散済みプラグイン」節に解散の旨・`claude plugin uninstall <name>@oratta-claude-harness` の手順・代替（公式機能）を足す
- 解散対象だけを規定する living spec を整理する: `openspec/specs/experience-to-skill-jsonl-distillation/` を `git rm` し、`repo-root-cleanup` の 3 要件（skill-pack の cooking 言及掃除、skill-pack の注記、e2s の `$0` 解決）を外す。`dev-workflow-shared-references`・`skill-verification-sections` が数える「対象スキル 7 つ」を 6 つに直す。`marketplace-plugin-sync` の例示から `plugins/telegram/package.json` を外す
- dev-workflow の `references/self-verification.md`（対象表から experience-to-skill の行と補足、対象外表から skill-pack・telegram 計 3 行を外す）、`references/commit-and-pr-operations.md`（`/e2s:distill` の 1 行）、`tests/self-verification-sections.bats`・`tests/shared-references.bats`（対象一覧から experience-to-skill を外す）、`README.md`（self-verification の説明から experience-to-skill を外す）を直す
- `plugins/cost-ledger/tests/fixtures.bats` と `tests/injection-budget.bats` のコメントにある experience-to-skill への言及を、実在するものを指す表現に直す
- 解散の状態を検査する `tests/skill-pack-telegram-e2s-retirement.bats` を足す

## Capabilities

### New Capabilities

- `skill-pack-telegram-e2s-retirement`: 3 プラグインを harness から撤去した状態（ディレクトリ・marketplace 登録・bundles・参照の不在と、README の解散記録）を規定する

### Modified Capabilities

- `repo-root-cleanup`: skill-pack・experience-to-skill を対象にした 3 要件を REMOVED（対象が無くなる）。残る要件（`templates/rules/` の削除、cooking 残骸掃除のうち skill-pack 以外）は維持する
- `dev-workflow-shared-references`: 自己検証リファレンスの対象スキルを 7 つから 6 つに、参照元を 8 か所から 7 か所にする
- `skill-verification-sections`: 「## 自己検証」節を持つ対象スキルを 7 つから 6 つにする
- `marketplace-plugin-sync`: 守備範囲の例示から、削除するプラグインのパスを外す

`experience-to-skill-jsonl-distillation` は capability ごと廃止する。全要件 REMOVED の delta は archive が `Spec must have at least one requirement` で中断するため、delta では表現せず main spec を直接 `git rm` する（前例: `remove-discord-plugin` の design.md）。

## Impact

- 削除: 3 プラグインのディレクトリ、`openspec/specs/experience-to-skill-jsonl-distillation/`
- 編集: `.claude-plugin/marketplace.json`、`README.md`、`plugins/dev-workflow/` の references・README・tests、`plugins/cost-ledger/tests/fixtures.bats`、`tests/injection-budget.bats`（コメントのみ）、上記 4 つの living spec
- 追加: `tests/skill-pack-telegram-e2s-retirement.bats`、`plugins/dev-workflow/changes/841.md`
- 常時注入量: 3 プラグインの description 計 1,556 バイトが減る。`tests/injection-budget.bats` は予算が実測以上・実測の 1.1 倍以下を要求するので、実装時に実測を取り、下振れ側に掛かれば `tests/injection-budget.txt`（聖域）を理由付きで更新する
- 聖域パス: `plugins/*/hooks/` は 3 プラグインとも無く、触れない。`tests/injection-budget.txt` を動かす場合だけ聖域
