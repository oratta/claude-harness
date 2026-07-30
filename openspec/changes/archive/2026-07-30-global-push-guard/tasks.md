## 1. フック本体の改良（テスト先行）

- [x] 1.1 `plugins/loops/tests/pre-push-merged-pr-guard.bats` に「gh 呼び出しが 1 回」「gh がハングしたとき 3 秒以内に exit 0」「timeout に依存していない」「gh に stdin を渡していない」のテストを追加する（Red 確認）
- [x] 1.2 `plugins/loops/skills/loops-dev-agent-install/SKILL.md` Step 6 のテンプレートを `--state all` 1 回呼び出しに変更する
- [x] 1.3 同テンプレートに自前タイムアウト（バックグラウンド + 0.1 秒ポーリング + kill、外部コマンド非依存）を実装する
- [x] 1.4 Step 6 の説明にタイムアウト方針（3 秒・fail-open の格上げ）を追記する
- [x] 1.5 テストを実行して Green を確認する（exit code を表示）

## 2. グローバル層の新設

- [x] 2.1 `plugins/dev-workflow/tests/push-guard-setup.bats` を作成し、グローバルテンプレートの振る舞い（マージ済み拒否 / main は通す / バイパス / 削除 push / タイムアウト）と記述要件（優先関係・`.git/hooks` 無効化と回避方法・冪等性・既存設定の確認）のテストを書く（Red 確認）
- [x] 2.2 `plugins/dev-workflow/skills/push-guard-setup/SKILL.md` を新設し、グローバルフックのテンプレート（マージ済みチェックのみ）と導入手順を書く
- [x] 2.3 SKILL.md に層の優先関係・`.git/hooks/` 無効化の副作用と回避方法・冪等性・既存 `core.hooksPath` の確認手順を書く
- [x] 2.4 `plugins/dev-workflow/.claude-plugin/plugin.json` に skill を登録し、バージョンを上げる
- [x] 2.5 テストを実行して Green を確認する（exit code を表示）

## 3. 整合とバージョン

- [x] 3.1 `plugins/loops/.claude-plugin/plugin.json` のバージョンを上げる
- [x] 3.2 `.claude-plugin/marketplace.json` の dev-workflow / loops / トップレベルのバージョンを同期する
- [x] 3.3 `bats plugins/dev-workflow/tests/ plugins/loops/tests/` を実行し、新規テスト込みで green（既知の S124 / S23 を除く）を確認する

## 4. 実機導入と確認

- [x] 4.1 `~/.githooks/pre-push` を生成し `git config --global core.hooksPath ~/.githooks` を設定する（既存値が無いことを確認済み）
- [x] 4.2 マージ済みブランチ（`oratta/pre-push-pr-push`）への push が拒否されることを確認する
- [x] 4.3 現在の作業ブランチ（open PR あり）への push が通ることを確認する
- [x] 4.4 このリポジトリはローカル `core.hooksPath` を持たないため、グローバル層が実際に適用されていることを確認する

## 5. 仕上げ

- [x] 5.1 `/opsx:verify` で artifact と実装の整合を検証する
- [x] 5.2 change を archive し main specs へ sync する
- [ ] 5.3 PR 本文を 5 節構成で更新し、Ready for Review に切り替える
