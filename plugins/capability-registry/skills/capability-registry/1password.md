# 1Password (op)

- **verify**: `op whoami`（SA トークン経由なら Service Account 情報が返る）
- **トークンの構造**: エージェントは read-only Service Account（SA）で vault `agents` だけを読む。SA トークン自体の在処は Keychain `op-sa-claude-agents-ro` → `~/.config/op-sa/claude-agents-ro.token`（600 権限）の順
- **アイテム命名規約**: `<project>--<service>` / フィールド `credential`。project は cwd の git root 名を正規化（小文字化・先頭 `_` 除去・`_ver.X.Y` 接尾辞除去）したもの

## 運用知見

- SA の権限は発行後に変更不可（Individual プラン）。間違えたら取り消して再発行
- op をデスクトップアプリ連携で叩くと macOS がターミナル名義の「他アプリのデータへのアクセス」確認を op プロセスごとに出す。**フックやスクリプトは必ず SA 経由で叩く**（SA トークン経由なら無音）
- アイテム登録は人間が 1Password アプリで行う（ブラウザ・CLI とも不可の運用）
