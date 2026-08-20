# 1Password (op)

- **verify**: `op whoami`（SA トークン経由なら Service Account 情報が返る）
- **トークンの構造**: エージェントの読み取りは read-only Service Account（SA）で agents 保管庫だけを読む。SA トークン自体の在処は env `OP_SERVICE_ACCOUNT_TOKEN` → `~/.config/op-sa/claude-agents-ro.token`（600 権限）→ Keychain `op-sa-claude-agents-ro` の順（無人経路優先）。登録には別の書き込み用 SA `op-sa-claude-agents-rw` を使う（下記「アイテム登録」）
- **保管庫は 2 つ**: `agents` 保管庫には dev / test / 読み取り系の資格情報が入り、SA から読める（`op item list --vault agents`）。`human-only` 保管庫には prod の書き込み可能キーの原本（`uranai--STRIPE_SECRET_KEY_PROD` / `shukan--SUPABASE_SERVICE_ROLE_KEY` 等）が入り、SA からは保管庫ごと見えない — 人間が 1Password アプリで扱い、CI へは Actions secrets の稼働コピーで渡る（階層の正本は SKILL.md の「資格情報の階層」）
- **アイテム命名規約**: フィールドは常に `credential`。接頭辞はカテゴリで使い分ける — プロダクトの秘密は `<project>--<service>`（project は origin remote のリポ名: 末尾 `.git` 除去 → 最終パス要素 → 小文字化。例: `genetta-inc/suimei` → `suimei`。dir 名からは導出しない。origin が無い場所では fmtoken は exit 45 で止まる）、エージェントの身元は `<agent>--<SERVICE>`（例: `moko--TRELLO_TOKEN`）。エージェント名接頭辞はプロジェクト導出では引けないので `fmtoken.sh --name <item>` で参照する

## 運用知見

- SA の権限は発行後に変更不可（Individual プラン）。間違えたら取り消して再発行
- op をデスクトップアプリ連携で叩くと macOS がターミナル名義の「他アプリのデータへのアクセス」確認を op プロセスごとに出す。**フックやスクリプトは必ず SA 経由で叩く**（SA トークン経由なら無音）
- Keychain 保管の SA トークンも ACL 次第で**読み出しごとに生体認証**が出る。生体認証が繰り返し出る = SA の無音経路（env / 600 ファイル）に乗れていないサイン。そのマシンに 600 ファイルを配布して解消する:
  `security find-generic-password -a "$USER" -s op-sa-claude-agents-ro -w > ~/.config/op-sa/claude-agents-ro.token && chmod 600 ~/.config/op-sa/claude-agents-ro.token`（生体認証はこの 1 回だけ）
- **アイテム登録（CLI 代行が正規手順）**: SA の役割分担は read = `op-sa-claude-agents-ro`（読み取り専用）/ register = `op-sa-claude-agents-rw`（書き込み用。解決順は env `OP_SERVICE_ACCOUNT_TOKEN_RW` → `~/.config/op-sa/claude-agents-rw.token`（600 権限）→ Keychain `op-sa-claude-agents-rw`）。エージェントが発行フローで秘密を手に入れたら、人間に依頼せず rw SA 経由の CLI で自分で登録する（2026-07-30 主判断。実績: #49 / #58、moko の `moko--TRELLO_TOKEN`）。手作業の GUI 登録は命名規約 `<project>--<service>` / `<agent>--<SERVICE>` の逸脱源になりやすく、機械的な CLI 登録の方が規約を守れる
- **登録には `fmtoken.sh --register` を使う**: `printf '%s' "$VALUE" | fmtoken.sh --register <名前>--<service>`（値は stdin 渡し — transcript / ps への露出防止）。命名規約の機械検証・既存アイテムの上書き拒否（exit 47）・rw トークン解決が自動で効くため、生の `op item create` より優先する。rw トークンが未配布のマシン（exit 43）でだけ主に配布を依頼する
- **SA の保管庫アクセス権限変更**は引き続き人間が 1Password アプリで行う（Individual プランでは CLI/API から不可）
