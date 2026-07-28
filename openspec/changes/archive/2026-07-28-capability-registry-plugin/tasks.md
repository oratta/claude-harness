# Tasks: capability-registry-plugin

## 1. テスト先行（Red）

- [x] 1.1 `plugins/capability-registry/tests/fmtoken.bats` を作成（op スタブで正規化・SA フォールバック順・exit 43/44・--check/--list を検証）
- [x] 1.2 `plugins/capability-registry/tests/browser-guard.bats` を作成（hooks.json の PreToolUse matcher、hook スクリプトの additionalContext 出力・allow 判定・セッション初回のみ注入・fail-soft を検証）
- [x] 1.3 `plugins/capability-registry/tests/skill-registry.bats` を作成（SKILL.md の description トリガー文言・索引 50 行以内・初期 5 サービス行・ネガティブエントリ・サービス別ファイル存在・plugin.json / marketplace.json 登録を検証）

## 2. プラグイン骨格と fmtoken 移設（Green）

- [x] 2.1 `plugins/capability-registry/.claude-plugin/plugin.json` を作成（skills 登録、description に配置意図を記載）
- [x] 2.2 flatmate の `scripts/fmtoken.sh`（fb21df1 時点）を `plugins/capability-registry/scripts/fmtoken.sh` に無改変で移設し実行権限を付与

## 3. 発見層スキル（Green）

- [x] 3.1 `skills/capability-registry/SKILL.md` を作成（description = 「外部サービスを操作する前に」トリガー文、1 サービス 1 行索引: op/gh/supabase/vercel/stripe、認証 verify コマンド、fmtoken 参照、ブラウザ必須例外、ネガティブエントリ節）
- [x] 3.2 サービス別詳細ファイル `1password.md` / `github.md` / `supabase.md` / `vercel.md` / `stripe.md` を作成（遅延ロード対象。運用知見: SA 権限は発行後変更不可、op はデスクトップアプリ連携でなく SA 経由で叩く等）

## 4. 強制層 hook（Green）

- [x] 4.1 `plugins/capability-registry/hooks/hooks.json` を作成（PreToolUse、matcher: `mcp__claude-in-chrome__.*|mcp__playwright__.*`、`${CLAUDE_PLUGIN_ROOT}/scripts/browser-guard.sh`）
- [x] 4.2 `plugins/capability-registry/scripts/browser-guard.sh` を作成（stdin JSON から session_id を読み、初回のみ additionalContext で注意喚起、マーカーで重複抑止、全経路 fail-soft exit 0）

## 5. マーケットプレイス登録と検証

- [x] 5.1 `.claude-plugin/marketplace.json` に capability-registry を登録し marketplace version を bump
- [x] 5.2 bats テスト全件実行し exit 0 を確認（既存プラグインのテストにも回帰がないこと）
- [x] 5.3 flatmate 側 fmtoken.sh の扱い（削除 + プラグイン参照への置換）を flatmate リポの issue として起票し、本 change の記録に issue URL を残す → https://github.com/genetta-inc/flatmate/issues/126
