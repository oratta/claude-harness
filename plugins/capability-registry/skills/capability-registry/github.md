# GitHub (gh)

- **verify**: `gh auth status`
- **トークン**: 通常は keyring 済みの gh をそのまま使う。別アカウント・別スコープが必要な時のみ `GITHUB_TOKEN`（env）に渡す。値の在処はオーナーの環境の索引があればそちら
- **できること**: PR・issue・API（`gh api`）・Actions（`gh run`）・リリース・secrets 投入（`gh secret set`）

## ブラウザ必須の例外

- OAuth アプリの初回承認（`gh auth login` のデバイスフロー確認）
- 組織の設定画面の一部（SSO 有効化、細粒度 PAT の承認ポリシー）
