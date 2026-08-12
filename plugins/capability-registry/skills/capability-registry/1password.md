# 1Password (op)

- **verify**: `op whoami`（SA トークン経由なら Service Account 情報が返る）
- **トークンの構造**: エージェントは read-only Service Account（SA）で agents 保管庫だけを読む。SA トークン自体の在処は env `OP_SERVICE_ACCOUNT_TOKEN` → `~/.config/op-sa/claude-agents-ro.token`（600 権限）→ Keychain `op-sa-claude-agents-ro` の順（無人経路優先）
- **アイテム命名規約**: `<project>--<service>` / フィールド `credential`。project は origin remote のリポ名（末尾 `.git` 除去 → 最終パス要素 → 小文字化。例: `genetta-inc/suimei` → `suimei`）。dir 名からは導出しない（origin が無い場所では fmtoken は exit 45 で止まる）

## 運用知見

- SA の権限は発行後に変更不可（Individual プラン）。間違えたら取り消して再発行
- op をデスクトップアプリ連携で叩くと macOS がターミナル名義の「他アプリのデータへのアクセス」確認を op プロセスごとに出す。**フックやスクリプトは必ず SA 経由で叩く**（SA トークン経由なら無音）
- Keychain 保管の SA トークンも ACL 次第で**読み出しごとに生体認証**が出る。生体認証が繰り返し出る = SA の無音経路（env / 600 ファイル）に乗れていないサイン。そのマシンに 600 ファイルを配布して解消する:
  `security find-generic-password -a "$USER" -s op-sa-claude-agents-ro -w > ~/.config/op-sa/claude-agents-ro.token && chmod 600 ~/.config/op-sa/claude-agents-ro.token`（生体認証はこの 1 回だけ）
- アイテム登録は人間が 1Password アプリで行う（ブラウザ・CLI とも不可の運用）
