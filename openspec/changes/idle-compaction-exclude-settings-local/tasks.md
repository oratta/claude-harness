## 1. exclude への追記

- [ ] 1.1 `develop-idle-compaction.py` に、`git -C <root> rev-parse --git-common-dir`（相対パスなら root 基準で解決）の `info/exclude` へ `.claude/settings.local.json` を足す関数を作る。同じ行（完全一致）があれば足さず、末尾改行が無ければ補い、`info` が無ければ作る。触る範囲: plugins/dev-workflow/scripts/develop-idle-compaction.py:24-107（`configure` の直列化のあと・`directory.mkdir` の前で呼ぶ）
- [ ] 1.2 exclude を書けない（OSError）ときは設定ファイルを書かず exit 1 にする（既存の except 経路を使う）。`--check` と false 済みの早期 return では呼ばない。触る範囲: plugins/dev-workflow/scripts/develop-idle-compaction.py:56-77

## 2. テスト

- [ ] 2.1 bats に追加: apply 後に `git status --porcelain` が空／再 apply と既存行で重複しない／追跡済みファイルは追跡のまま／別の未コミットファイルだけが porcelain に出る／linked worktree でも共有 exclude に書く／不正入力では exclude も作らない。触る範囲: plugins/dev-workflow/tests/develop-idle-compaction.bats:1-（末尾に追記）
