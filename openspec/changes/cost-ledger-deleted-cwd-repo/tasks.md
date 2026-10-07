行番号は仕様づくりの時点（HEAD 8269ab8d）の値。前のタスクの編集でずれるので、編集前に該当範囲を読んで確かめる。同時に進んでいる #691（PR #744）と #697 が変える箇所（`cmd_timeline`・`build_parser`・`timeline_has_trigger_near`・`gate_report.py`・`gate-report.sh`・`hooks.json`・README の 147〜216 行付近）には触らない。

## 1. 変更前の実測（コードを変える前に取る）

- [ ] 1.1 実機の台帳を写しに取り（`cp -p "$COST_LEDGER_PATH" <scratchpad>/ledger-before.jsonl`）、以後の実測と実機の確認は `COST_LEDGER_PATH` を写しに向けて行う。実機の台帳には `--rescan` を流さない。触る範囲: なし（リポジトリの外の作業用ディレクトリ）
- [ ] 1.2 変更前のコードで、写しに対して次を測って控える: `cost 272` の合計・「リポジトリ不明」の件数と額／`cost 272` の所要時間／hook 1 回（`ledger-hook.sh` に Stop の入力を渡す）の所要時間／`ledger-sync --rescan` の所要時間（写しのさらに写しに対して）／`cost 272` 1 回で台帳のファイルを開いた回数（`builtins.open` を包んで台帳のパスを数える）／`cost 272` 1 回の `gh` の呼び出し回数（`PATH` の先頭に置いた包みで数える）。触る範囲: なし

## 2. テストを先に書く

- [ ] 2.1 `deleted-cwd.bats` を作り、推定の規則のテストを書く（実装前は失敗する）: 同じ名前の置き場に残った作業ツリーから推定して `repo_inferred: true` が付く／置き場の名前が origin のリポジトリ名と一致する場合／置き場の名前が一致しなければ不明／置き場に 2 リポジトリの作業ツリーがあれば不明／置き場が git リポジトリの中なら不明／`.claude/worktrees/` の手前が残っている場合と、手前も削除済みの場合／`git rev-parse` で決まる行と不明の行は `repo_inferred` の欄を持たない。置き場と作業ツリーを作る補助関数はこのファイルの中に置く（`helper.bash` は変えない）。触る範囲: `plugins/cost-ledger/tests/deleted-cwd.bats`（新規）、読むだけ: `plugins/cost-ledger/tests/helper.bash:8-50`
- [ ] 2.2 同じファイルに issue の受け入れ条件のテストを書く: 台帳へ追記する前に `cwd` が消えていた行が `issue <番号>` の合計に入り、`推定で数えた行:` と `--json` の `inferred_repo_*` に出る（直す対象）／台帳へ追記したあとで `cwd` を消した行が合計に入り、`推定で数えた行:` が出ない（回帰。現状でも通る見込み）／別のリポジトリの置き場の削除済み `cwd` で同じ番号を触った行を、合計にも不明にも数えない。触る範囲: `plugins/cost-ledger/tests/deleted-cwd.bats`（新規）
- [ ] 2.3 同じファイルに補正行のテストを書く: 「不明」の行が書かれた台帳（置き場を後から作って再現する）に `ledger-sync --rescan` を流すと、既存の行は 1 バイトも変わらず補正行が組ごとに 1 行だけ追記される／2 回目と、控えを消したあとの `--rescan` は 0 行／推定できない `cwd` が混ざる組には書かない／通常の `ledger-sync` と hook は補正行を書かない／補正後は `issue <番号>` の合計に入る／別のリポジトリへの補正は数えない／同じ組に 2 リポジトリの補正行があれば不明のまま／`facts` の出力に `repo_fix` の行が出ない／補正行を特別扱いしない合計でも金額と件数が変わらない。触る範囲: `plugins/cost-ledger/tests/deleted-cwd.bats`（新規）
- [ ] 2.4 同じファイルにエピックと番号なしのテストを書く: エピックで推定の行が子 issue の `own_usd` と `total_usd` に入り `inferred_repo_*` に出る／別のリポジトリに推定された同じ番号の行を数えない／番号なしの `cost` で `推定で数えた行:` が出る。`gh` の包みは `epic.bats` の書き方に合わせる。触る範囲: `plugins/cost-ledger/tests/deleted-cwd.bats`（新規）、読むだけ: `plugins/cost-ledger/tests/epic.bats` の `gh` の包みの部分

## 3. 削除済みの cwd からの推定

- [ ] 3.1 `RepoResolver.repo_id` に、`cwd` がディレクトリとして存在しないときの推定（`.claude/worktrees/` の規則と置き場の規則）を足し、置き場ごとの判定結果を覚える。推定で決めた `cwd` かどうかを返す口を足す。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:142-165`（`RepoResolver`）
- [ ] 3.2 `build_fact` が、推定で決めたときだけ `repo_inferred: true` を事実に入れる。`_NoRepo` に常に偽を返す同じ口を足す。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:489-517`（`build_fact`）、`plugins/cost-ledger/scripts/cost_ledger.py:1244-1248`（`_NoRepo`）
- [ ] 3.3 2.1 のテストと既存の bats 全部が通ることを確かめる（既存の fixture の削除済み `cwd` は置き場の名前が一致せず、不明のままになる見込み。変わるテストがあれば原因を調べ、fixture を合わせる前に本体へ報告する）。触る範囲: なし

## 4. 補正行の追記（`ledger-sync --rescan`）

- [ ] 4.1 `--rescan` のときだけ、読み込んだ会話ログのバイト列から（`session_id`, `gitBranch`）ごとの `cwd` を集める（ファイルを開く回数を増やさない。`facts_from_lines` は変えない）。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:990-1052`（`_ledger_sync_locked`）
- [ ] 4.2 台帳の「不明」の行の組（この回に追記する行の分を含む）を集め、全 `cwd` が同じ 1 リポジトリに決まる組の補正行を、索引に無いものだけ追記する新しい関数を足して `_ledger_sync_locked` から呼ぶ。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:990-1052`（`_ledger_sync_locked` と、その直前か直後に置く新しい関数）
- [ ] 4.3 2.3 のうち追記のテストが通ることを確かめる。触る範囲: なし

## 5. 読むときの補正の適用

- [ ] 5.1 台帳から補正行を集める関数（`"repo_fix": true` を含む行だけを JSON として読む 1 回の走査）と、事実の列から補正行を取り除いて「不明」の事実を置き換える包みを足し、`load_facts` の台帳の経路 2 つ（issue で絞る経路とそれ以外）に当てる。`iter_ledger_issue_facts`・`iter_ledger_facts`・`load_branches_facts` は変えない。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:1165-1183`（`load_facts` と、その直前に置く新しい関数）
- [ ] 5.2 2.2 と 2.3 の読む側のテストが通ることを確かめる。触る範囲: なし

## 6. 表示と `--json`

- [ ] 6.1 `cmd_issue` に、数えた区間の行のうち `repo_inferred` が真の行の件数と額を足す（`--json` の `inferred_repo_usd`・`inferred_repo_messages` と、「リポジトリ不明」の行の直後の `推定で数えた行:`）。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:2336-2407`（`cmd_issue`）
- [ ] 6.2 `assign_epic_rows` が、ヘッドブランチの一致でなく区間で割り当てた行のうち `repo_inferred` が真の行の件数と額を返し、`cmd_epic` が表示と `--json` に出す。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:2188-2255`（`assign_epic_rows`）、`plugins/cost-ledger/scripts/cost_ledger.py:2446-2513`（`cmd_epic`）
- [ ] 6.3 `cmd_branch` の番号なしの経路（`scope_repo_id` があるとき）に `推定で数えた行:` を足す。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:1928-1965`（`cmd_branch`）
- [ ] 6.4 2.2 と 2.4 のテストと、既存の bats 全部（`bats plugins/cost-ledger/tests`）が通ることを確かめる。触る範囲: なし

## 7. 文書

- [ ] 7.1 README の台帳の節に次を足す: 削除済みの `cwd` はパスからリポジトリを推定すること／過去の「不明」の行は `ledger-sync --rescan` を手で 1 回流すと補正行が追記されること（hook からは走らない）／実行前に台帳を `cp -p` で控えること、控えへ戻す手順（控えを戻し、`<台帳>.state.sqlite` を消して `ledger-sync` を 1 回）／誤った補正は、同じ組に別の `repo_id` の補正行を 1 行足すと不明に戻ること／出力の `推定で数えた行:` の意味。#744 が変える 147〜216 行付近には触らない。触る範囲: `plugins/cost-ledger/README.md:262-276`（「台帳（会話ログが消えたあとも残す）」の節の末尾）
- [ ] 7.2 変更の記録を書く。触る範囲: `plugins/cost-ledger/changes/750.md`（新規）

## 8. 変更後の実測と実機の確認

- [ ] 8.1 変更後のコードで、1.1 の写しに対して 1.2 と同じ項目を測る（`--rescan` は写しに流す。流す前の `cost 272` と、流したあとの `cost 272` の両方を取る）。hook 1 回の所要時間が 1 秒を超えたら、実装を止めて本体に報告する（design の決定 4 の別案に切り替えるかの判断）。触る範囲: なし
- [ ] 8.2 PR に書く内容を return にまとめる: `cost 272` の「リポジトリ不明」の件数と額・合計の変更前後（見込みは 4,042 件 $329.59 → 0 件、$373.09 → $432.15）／`推定で数えた行` の件数と額／hook・`cost 272`・`--rescan` の所要時間、台帳を開いた回数、`gh` の呼び出し回数の変更前後／LLM のトークンを使わないこと（スキル本文に手順を足していない・hook は出力を出さない）／マージ後に主が実機で行う手順（台帳の控え → `ledger-sync --rescan` を 1 回 → `cost 272` の確認）と、design の「Risks」の 3 件（別のリポジトリの行を数える恐れ・補正行は消せない・直らない分が残る）。触る範囲: なし
- [ ] 8.3 `openspec validate cost-ledger-deleted-cwd-repo --strict` と、リポジトリの lint（`scripts/lint.sh`）が通ることを確かめる。触る範囲: なし
