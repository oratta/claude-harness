# Tasks

行番号は仕様作成時点（219ccc5a）の案内。編集前に各範囲を読み直す。実装開始には記録先 #1233 の R1 APPROVE が必要。

## 1. hook の本体と配線

- [ ] 1.1 `plugins/capability-registry/tests/secret-guard.bats` を新設する。hooks.json の matcher と command の形、スクリプトの実行権限、止める入力の一覧、止めない入力の一覧、守備範囲の外の入力と止めすぎる向きの既知の挙動、`fmtoken.sh github` が通ること、壊れた入力、python3 が無い PATH、hook プロセスの環境変数の 3 通り（`off`・未設定・`on`）、コマンドの前置きでは無効化できないこと、スクリプトの本文と固定の案内文に `fmtoken` と `op-sa` が無いこと、`/x/op-sa/a.token` の Read の拒否の理由が入力のパスを引用し、それを除いた案内文に `op-sa` が無いこと、拒否の理由の案内の形を、spec のシナリオごとに書く。この時点で失敗することを確認する。テストの本文に個人の値を書かない。触る範囲: plugins/capability-registry/tests/secret-guard.bats（新規）、形の手本は plugins/capability-registry/tests/browser-guard.bats:1-50
- [ ] 1.2 `~/.claude/hooks/secret-guard.py` を元に `plugins/capability-registry/scripts/secret-guard.py` を作り、design の表の固有記述だけを除去する。無効化の説明を環境変数に置き換える。元のファイルは編集しない。`diff` で差分が design の表の範囲に収まることを確認する。触る範囲: plugins/capability-registry/scripts/secret-guard.py（新規）
- [ ] 1.3 `plugins/capability-registry/scripts/secret-guard.sh` を作り、無効化のスイッチ、python3 の有無、`python3 -I` の実行、`exit 0` の順に書き（`exec` にしない。本体の `.py` が無いときの exit 2 で全 Bash と Read を止めないため）、実行権限を付ける（`git ls-files -s` で 100755 を確認）。1.1 の bats が通ることを確認する。触る範囲: plugins/capability-registry/scripts/secret-guard.sh（新規）
- [ ] 1.4 `hooks.json` の `PreToolUse` の末尾に `matcher: "Bash|Read"`、`timeout: 10`、`"${CLAUDE_PLUGIN_ROOT}/scripts/secret-guard.sh"` のエントリを足し、`plugin.json` の keywords に `secret-guard` を足す。description は変えない。`bats plugins/capability-registry/tests/` と `bats tests/lint-plugin-validate.bats` が通ることを確認する。触る範囲: plugins/capability-registry/hooks/hooks.json:1-16、plugins/capability-registry/.claude-plugin/plugin.json:7-15
- [ ] 1.5 `tests/hook-python-isolation.bats` に secret-guard の偽のモジュールの検査を足す（browser-guard の検査と同じ形。-I を外した複製で対照も取る）。`bats tests/hook-python-isolation.bats` が通ることを確認する。触る範囲: tests/hook-python-isolation.bats:271-287

## 2. 文書と記録

- [ ] 2.1 `injection.md` の 2 か所の配線の記述を capability-registry の hook に更新する。`~/.claude/hooks/secret-guard.py` の記述が無くなることを grep で確認し、`plugins/casting/tests/` の injection の bats が通ることを確認する。触る範囲: plugins/casting/catalog/injection.md:38、plugins/casting/catalog/injection.md:74
- [ ] 2.2 `docs/public-private-split.md` に `secret-guard.sh` と `secret-guard.py` の部品の行（公開版）を足し、配線先が browser-guard だけという記述を直す。`bats tests/public-private-split.bats` が通ることを確認する。触る範囲: docs/public-private-split.md:35、docs/public-private-split.md:82
- [ ] 2.3 README の capability-registry の行と導入の案内に、入れると secret-guard が効くことを自分の子の分だけ書く。`bats tests/repo-hygiene.bats` が通ることを確認する。触る範囲: README.md:5-13、README.md:64
- [ ] 2.4 変更の記録を書く。`plugins/capability-registry/changes/1233.md` に、追加した hook、外した検査（fmtoken.sh）、無効化の環境変数、手の配線を外す手順と外してよい条件（design の移行の手順。公開の hook の動作確認のあと、個人版の代替の検査が有効になったことを確かめるか、保護を廃止する本人の判断が確定するまで手の配線を残す）を書き、`plugins/casting/changes/1233.md` に配線場所の更新を書く。版は上げない。`bats tests/plugin-release-convention.bats` が通ることを確認する。触る範囲: plugins/capability-registry/changes/1233.md（新規）、plugins/casting/changes/1233.md（新規）

## 3. 受け入れ条件の統合検証

- [ ] 3.1 `claude -p --setting-sources project --plugin-dir plugins/capability-registry` で、`GH_TOKEN` に偽の値を入れた環境から Bash ツールに `echo "$GH_TOKEN"` を打たせ、secret-guard の拒否の理由が返ることと、`GH_TOKEN="$(printf dummy)" gh --version` が止まらないことを確認する。手で配線した hook が読まれていない条件で確かめる。実機で確かめられなければ、その理由と代わりの確認を return に書く
- [ ] 3.2 `openspec validate secret-guard-plugin-hook --type change --strict` と `./scripts/test.sh` を実行し、exit 0 を確認する。`git add` はパスを名指しし、`.claude/settings.local.json` を含めない

## Workflow follow-up

- archive と PR は (3b) で行う
- 個人版に `fmtoken.sh` の代替の検査を足すか、保護を廃止するかは本体が主に確かめる（別リポジトリの作業）。どちらかが確定するまで、主の端末の手の配線は残す
