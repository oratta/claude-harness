# 218-self-verification-audit-list — 自己検証の棚卸しリストを実在する全スキルに揃える

## Why

`plugins/dev-workflow/references/self-verification.md` の「対象スキル一覧」は「`plugins/*/skills/*/SKILL.md` を監査した結果」と書いているが、実在する 17 スキルのうち 6 件（`dev-workflow/push-guard-setup`・`capability-registry`・`discord/access`・`discord/configure`・`telegram/access`・`telegram/configure`）が対象表にも対象外表にも載っていない（oratta/claude-harness#218。#205 / PR #216 のレビューで判明した non-blocking 指摘で、main の旧 loops 版から同様）。「全件監査した」という文と実態が食い違ったままだと、次にスキルを足す人が「載っていない＝監査済みで対象外」と誤読する。

## What Changes

- 6 スキルを「成果物を出すか」「完了前の検証が本文に明示されているか」で監査し、結果を棚卸しリストに反映する
  - **対象に加える（1 件）**: `plugins/dev-workflow/skills/push-guard-setup/SKILL.md`。`~/.githooks/pre-push` と `core.hooksPath` という成果物を出し、#64 で独自の `## 自己検証` 節を既に持つが、共通原則への参照 1 行が無く bats の TARGETS にも入っていなかった。参照 1 行を追記し、対象表・TARGETS・consumers に加える（固有手順は書き換えない）
  - **対象外に載せる（5 件）**: `capability-registry`（索引スキルで成果物を出さない。原則 1 が verify 実行を本文に組み込む）、`discord`/`telegram` の `access`・`configure`（公式プラグインの fork で SKILL.md は upstream 本文のまま。成果物は設定ファイルで反映確認はチャンネルサーバーの再読込に委ねる＝skill-pack と同じ分類。`configure` は保存後の status 再表示が本文にある。allowed-tools が Read/Write/`ls`/`mkdir` に限られ `jq` 等の形式チェックを節に書けない）
- 棚卸しリストの網羅性を機械検査にする: `ls plugins/*/skills/*/SKILL.md` の全件が対象表か対象外表のどちらかに実パスで現れることを bats（`self-verification-sections.bats`）で検証する
- spec の「対象は 6 スキル」の数固定を 7 に更新し、網羅性の要件を追加する

## Capabilities

### Modified Capabilities

- `dev-workflow-shared-references`: 「自己検証の共通原則は解散プラグインの記述を除いて引き継ぐ」の対象スキルを 6 → 7（`push-guard-setup` 追加）。参照元も 7 → 8 か所
- `skill-verification-sections`: 「対象スキルの SKILL.md は『## 自己検証』節を持つ」の Scenario を 7 ファイルに更新。「棚卸しリストは実在する全スキルを網羅する」要件を追加

## Impact

- **docs**: `plugins/dev-workflow/references/self-verification.md`（対象表 +1 行・対象外表 +3 行・冒頭の件数と監査日）
- **スキル**: `plugins/dev-workflow/skills/push-guard-setup/SKILL.md`（`## 自己検証` 節に参照 1 行を追記。既存行の変更なし）
- **テスト**: `plugins/dev-workflow/tests/self-verification-sections.bats`（TARGETS +1・成果物キーワード +1・網羅性テスト S51 追加）、`plugins/dev-workflow/tests/shared-references.bats`（対象 7・consumers 8）
- **バージョン**: dev-workflow 2.1.1 → 2.1.2（plugin.json・marketplace.json・CHANGELOG）
- **ユーザー体験**: 利用者影響なし。スキルの発火条件・手順は変えない
