# 破壊的 git 操作の禁止

実事故から生まれたルール。「元に戻すだけ」という自己正当化が再犯パターン（詳細な経緯はローカルの `~/.claude/rules-archive/` に保存、repo には含めない）。

## ルール

1. 破壊的操作は**例外なく事前承認**。「元に戻すだけ」も破壊的操作。
2. interrupt 直後は原状回復に走らず**現状報告が先**（`git status` / `git diff` を見せてから聞く）。
3. 承認は可否だけでなく**タイミングと方法まで**確認して完了。「消していい」と言われても、いつ・どうやって消すかまで確認する。

## 頭に浮かんだ瞬間、実行ではなく質問に変換するコマンド

- `git checkout -- <path>` / `git restore <path>`（作業破棄）
- `git reset --hard` / `git clean -f`
- `git commit --amend`（push 済み）/ `git rebase -i`
- `git push origin main|master` / `git push --force[-with-lease]`
- `git branch -D`
- `--no-verify` / `--no-gpg-sign`

「戻すだけ」「消すだけ」「一瞬で終わる」と思ったら、それは承認を飛ばそうとしているサイン。手を止めて聞く。
