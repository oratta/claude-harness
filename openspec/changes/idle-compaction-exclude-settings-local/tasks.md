## 1. exclude への追記

- [ ] 1.1 `develop-idle-compaction.py` に、`git -C <root> rev-parse --git-common-dir`（相対パスなら root 基準で解決）の `info/exclude` へ `.claude/settings.local.json` を足す関数を作る。同じ行（完全一致）があれば足さず、末尾改行が無ければ補い、`info` が無ければ作る。触る範囲: plugins/dev-workflow/scripts/develop-idle-compaction.py:24-107（`configure` の直列化のあと・`directory.mkdir` の前で呼ぶ）
- [ ] 1.2 exclude を書けない（OSError）ときは設定ファイルを書かず exit 1 にする（既存の except 経路を使う）。`--check` と false 済みの早期 return では呼ばない。触る範囲: plugins/dev-workflow/scripts/develop-idle-compaction.py:56-77

## 2. テスト

- [ ] 2.1 bats に追加: apply 後に `git status --porcelain` が空／再 apply と既存行で重複しない／追跡済みファイルは追跡のまま／別の未コミットファイルだけが porcelain に出る／linked worktree でも共有 exclude に書く／不正入力では exclude も作らない。触る範囲: plugins/dev-workflow/tests/develop-idle-compaction.bats:1-（末尾に追記）
- [ ] 2.2 bats に追加: exclude を書けない（`info/exclude` がディレクトリ等）とき exit 1 で設定ファイルが作られない・変わらない／`--check` と false 済みの apply が exclude の中身を変えない／`/.claude/settings.local.json` だけがある exclude には 1 行足す。触る範囲: plugins/dev-workflow/tests/develop-idle-compaction.bats（末尾に追記）

## 3. 手順書

- [ ] 3.1 `reply-after-idle.md` の「開始時の設定」を同じ範囲に直す。exit 2 の説明に apply が共有 `info/exclude` へ 1 行足すことを書き、承認範囲の段落の引用文面と「他キー・別ファイル・symlink 先は範囲外」に、共有 `info/exclude` への `.claude/settings.local.json` の 1 行の追記は範囲内と明記する。触る範囲: plugins/dev-workflow/skills/develop/references/reply-after-idle.md:8-18（「開始時の設定」。exit 2 の箇条書きと承認範囲の段落）
