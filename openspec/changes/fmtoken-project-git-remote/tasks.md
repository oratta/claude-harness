# Tasks: fmtoken-project-git-remote

## 1. テスト先行（Red）

- [ ] 1.1 fmtoken.bats の make_repo を origin remote 付きに拡張し、既存テストを remote 導出前提（`repo--*` でなく remote 名）に更新する
- [ ] 1.2 新規テスト追加: `workspace/<住人>/repo` 構造（HTTPS remote）で remote 名に解決される
- [ ] 1.3 新規テスト追加: SSH scp 形式 remote（`git@github.com:org/name.git`）で同じ名前に解決される
- [ ] 1.4 新規テスト追加: worktree 配下でメイン repo と同じ project 名に解決される
- [ ] 1.5 新規テスト追加: origin remote 無し → exit 45・登録依頼メッセージを出さない / git リポ外 → exit 45
- [ ] 1.6 bats 実行で新規テストが失敗することを確認（Red）

## 2. 実装（Green）

- [ ] 2.1 fmtoken.sh の project 導出を `git remote get-url origin` ベースに変更（`.git` 除去 → 最終パス要素 → 小文字化）。normalize 関数・親 dir フォールバック・pwd フォールバックを削除
- [ ] 2.2 remote 取得不能時の exit 45 と専用 stderr メッセージを実装
- [ ] 2.3 bats 全件パスを確認（Green）、ヘッダコメントの導出説明も更新

## 3. vault リネーム（実装と同一 PR・分割不可）

- [ ] 3.1 rw SA（Keychain `op-sa-claude-agents-rw`）で vault `agents` の現在の title 一覧を取得（前状態の記録）
- [ ] 3.2 `uranai--*` 13件 → `suimei--*` にリネーム（`op item edit`・タイムアウト長め・分割実行）
- [ ] 3.3 `traoremvp--*` 4件 → `traore--*` にリネーム
- [ ] 3.4 後状態の title 一覧で `buffon`(2)/`flatmate`(2)/`shukan`(7)/`suimei`(14)/`traore`(4)=29件 を確認

## 4. 実機確認・仕上げ

- [ ] 4.1 `~/Dropbox/WorkSpace/00_IndieDev/flatmate/workspace/uranai-market/repo` から fmtoken.sh --list が suimei の一覧を返すことを確認
- [ ] 4.2 worktree 配下（本 worktree 等）で同じ project 名に解決されることを実機確認
- [ ] 4.3 PR 本文を5節フォーマットで確定し、検証ログ（bats 出力・リネーム前後一覧）を添付
