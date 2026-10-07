行番号は仕様づくりの時点（HEAD 383d033b）の値。前のタスクの編集でずれるので、編集前に該当範囲を読んで確かめる。

## 1. lint.sh のテストを先に書く

- [ ] 1.1 `tests/lint-plugin-validate.bats` を新しく作る。一時ディレクトリに git リポジトリを作り、`scripts/lint.sh` の複製・指摘の出ない `*.sh` 1 本・`plugins/alpha/.claude-plugin/plugin.json`・`plugins/beta/.claude-plugin/plugin.json` を置いて `git add` し、PATH の先頭に偽の `claude`（受け取った引数を 1 行ずつファイルに記録し、環境変数で指定された対象のときだけ 1 を返す）を置く。shellcheck が無い環境では `skip` する。テスト名は ASCII のみ。書く前に `tests/bats-assertion-guard.bats` を読み、アサーションの書き方の制約に合わせる。触る範囲: tests/lint-plugin-validate.bats（新規）
- [ ] 1.2 次の場合を 1 件ずつテストにする: すべて通れば exit 0 で、直下と 2 プラグインに 1 回ずつ `plugin validate <対象>` が呼ばれ `--strict` が付かない／1 つ目のプラグインが 1 を返すと 2 つ目も呼ばれ、終了コードが 0 以外で、偽の `claude` の出力が表示される／PATH に `claude` が無いと exit 0 で、飛ばしたことと理由が出力にある（PATH は shellcheck と git へのリンクを置いたディレクトリと `/usr/bin:/bin` で組む）／`lint.sh alpha` で `plugins/alpha` だけが呼ばれる／どのプラグインにも一致しないフィルタで 1 回も呼ばれず exit 0／shellcheck が指摘を出しても検証は呼ばれ、終了コードが 0 以外。触る範囲: tests/lint-plugin-validate.bats（新規）
- [ ] 1.3 `bats tests/lint-plugin-validate.bats` を走らせ、検証を足す前なので落ちることを確かめる。触る範囲: なし（実行のみ）

## 2. lint.sh に検証を足す

- [ ] 2.1 `scripts/lint.sh` の末尾を、shellcheck の終了コードを控えてから検証へ進む形に変える。対象は `git -C "$ROOT" ls-files -- 'plugins/*/.claude-plugin/plugin.json'` から `plugins/<name>` を取り出し、フィルタ引数があれば `plugins/<name>/` への部分一致（OR）で絞る。フィルタ無しのときだけリポジトリ直下（`.`）を先頭に加える。`command -v claude` が失敗したら飛ばしたことと理由を標準エラーに出す。各対象は `( cd "$ROOT" && claude plugin validate <対象> )` の出力を控え、0 なら対象名を 1 行、非 0 なら控えた出力を出す。最後に shellcheck と検証のどちらかが非 0 なら 1 で終わる。POSIX sh のまま書く（配列を使わない）。触る範囲: scripts/lint.sh:76-88（shellcheck の実行と終了処理）
- [ ] 2.2 冒頭の説明コメントを合わせる（1 行目の説明、使い方、設計の箇条書きに、公式の検証・`--strict` を付けない理由・`claude` が無いときの扱い・フィルタの効き方を足す）。触る範囲: scripts/lint.sh:1-26（冒頭コメント）
- [ ] 2.3 `bats tests/lint-plugin-validate.bats` が通り、`shellcheck --severity=warning scripts/lint.sh` に指摘が無いことを確かめる。触る範囲: なし（実行のみ）

## 3. hooks.json の command を引用符で囲む

- [ ] 3.1 4 本の hooks.json の command を `"${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh"` から `"\"${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh\""` に変える（13 箇所）。変えるのは引用符だけで、インデント・キーの並び・末尾のカンマ・他の値に触らない。変えたあと `git diff --stat` で 4 ファイル・13 行の追加と 13 行の削除であることを確かめる。触る範囲: plugins/capability-registry/hooks/hooks.json:9、plugins/cost-ledger/hooks/hooks.json:9,20、plugins/dev-workflow/hooks/hooks.json:9,19,30,39,49,59、plugins/worktree/hooks/hooks.json:8,20,25,36
- [ ] 3.2 command を完全一致で検査している既存テストの期待値を、引用符付きの値に合わせる。Python の文字列の中なので、引用符のエスケープを各テストの書き方（heredoc か `python3 -c "..."` か）に合わせる。触る範囲: plugins/dev-workflow/tests/subagent-stop-guard.bats:461、plugins/worktree/tests/session-proc-cleanup.bats:603-604、plugins/cost-ledger/tests/gate-report.bats:347、plugins/cost-ledger/tests/ledger.bats:199
- [ ] 3.3 `tests/lint-plugin-validate.bats` に、追跡されているすべての `plugins/*/hooks/hooks.json` について「`${CLAUDE_PLUGIN_ROOT}` を含む command の値が `"${CLAUDE_PLUGIN_ROOT}/` で始まり `"` で終わる」ことを確かめるテストを足す（`claude` を使わないので CI でも走る）。触る範囲: tests/lint-plugin-validate.bats（新規）

## 4. 変更の記録

- [ ] 4.1 hooks.json を変えた 4 プラグインに変更の記録を置く（何を変えたか、なぜか、issue 番号）。書式は同じディレクトリの既存の記録に合わせる。`version` は足さない。触る範囲: plugins/capability-registry/changes/716.md（新規）、plugins/cost-ledger/changes/716.md（新規）、plugins/dev-workflow/changes/716.md（新規）、plugins/worktree/changes/716.md（新規）

## 5. 確認

- [ ] 5.1 `scripts/lint.sh` が exit 0 であること。触る範囲: なし（実行のみ）
- [ ] 5.2 どれか 1 つのプラグイン（例: `plugins/casting/.claude-plugin/plugin.json`）の `name` を手で `claude-x` に変えて `scripts/lint.sh casting` が 0 以外で終わり、手で元の値に書き戻して exit 0 になること。書き戻しは編集で行い、`git checkout --` / `git restore` を使わない（破壊的操作にあたる）。書き戻したあと `git diff --stat plugins/casting` が空であることを確かめる。触る範囲: plugins/casting/.claude-plugin/plugin.json（一時的。差分を残さない）
- [ ] 5.3 4 プラグイン（capability-registry / cost-ledger / dev-workflow / worktree）で `claude plugin validate plugins/<name> 2>&1 | grep -c 'without quotes'` が 0 であること。触る範囲: なし（実行のみ）
- [ ] 5.4 引用符付きの hooks.json で hook が実際に起動することを、`claude -p --plugin-dir plugins/dev-workflow` で確かめる（SessionStart の `session-tripwires.sh` の注入が出ること）。起動しなければ引用符の変更を取り下げず、そのままの状態で本体に return する。触る範囲: なし（実行のみ）
- [ ] 5.5 `scripts/test.sh` が exit 0 であること（statusline のテストが 1 件だけ落ちたら単独で走らせ直して判定する）。触る範囲: なし（実行のみ）
- [ ] 5.6 `openspec validate lint-plugin-validate --strict` が通ること。触る範囲: なし（実行のみ）
