## Why

#60 で入れたマージ済み PR ブランチ push 拒否は `loops-dev-agent-install` の中にあるため、自律開発ループを導入したリポジトリにしか届かない。しかし事故が実際に起きているのは**人間が PC の前にいる対話セッション**での push であり、そこは今も無防備なままである。push を止められる層は「誰が打ったか」を問わない git フックであり、これをグローバル `core.hooksPath` に置けば人間の手打ちと Claude の Bash 実行を同時に覆える。

同時に、全リポジトリ・全 push に効かせるなら現行実装の 2 つの無駄を先に潰す必要がある。実測で `gh pr list` は 1 回あたり約 0.5 秒かかり、現行は 2 回呼ぶ（+約 1.0 秒/push、素の小さい push が約 0.8 秒なので 2 倍強）。さらに fail-open は「最終的には通す」ことしか保証しておらず、回線が死んでいると `gh` の接続タイムアウトまでフックが固まる。遅いガードは外されるため、これはガードの寿命に直結する。

## What Changes

- **グローバル層の新設**: `~/.githooks/pre-push` を生成し `git config --global core.hooksPath` を設定する導入スキル `push-guard-setup` を `dev-workflow` プラグインに追加する。グローバル層は**マージ済み PR チェックのみ**を持つ。
- **main/master 直 push 拒否はグローバル層に入れない**。「ローカル main 運用」のリポジトリでは承認後の `git push origin main` が正常系であり、全リポジトリで拒否すると正当な操作を壊すため。従来どおりリポジトリローカル層（`loops-dev-agent-install`）だけが持つ。
- **`gh` 呼び出しの 1 回化**: `--state all` で 1 回だけ呼び、merged / open を jq で数える（両テンプレート共通）。
- **自前タイムアウトの追加**: `gh` が応答しない場合に数秒で諦めて fail-open する。`timeout` / `gtimeout` があれば使い、無ければバックグラウンド実行 + ポーリング + kill にフォールバックする（macOS には coreutils の `timeout` が無い）。
- **層の優先関係の明文化**: ローカル `core.hooksPath` がグローバルより優先されること、グローバル設定が `.git/hooks/` 直置きフックを無効化すること、その回避方法を SKILL.md に書く。

## Capabilities

### New Capabilities
- `global-push-guard`: 全リポジトリに効くグローバル pre-push ガードの内容・導入手順・層の優先関係を規定する capability

### Modified Capabilities
- `loops-pre-push-guard`: `gh` 呼び出しの 1 回化と自前タイムアウトを、リポジトリローカル層のテンプレートにも要求する（拒否条件そのものは変更しない）

## Impact

- `plugins/dev-workflow/skills/push-guard-setup/SKILL.md` — 新設（グローバル層の導入手順）
- `plugins/dev-workflow/.claude-plugin/plugin.json` — skills 登録とバージョン bump
- `plugins/dev-workflow/tests/push-guard-setup.bats` — 新設
- `plugins/loops/skills/loops-dev-agent-install/SKILL.md` — Step 6 テンプレートを 1 回化 + タイムアウト対応
- `plugins/loops/tests/pre-push-merged-pr-guard.bats` — テスト追加
- `.claude-plugin/marketplace.json` — 両プラグインのバージョン同期
- 既にグローバル `core.hooksPath` を使っているユーザーは、導入時に既存値の確認を求められる（無断上書きしない）
