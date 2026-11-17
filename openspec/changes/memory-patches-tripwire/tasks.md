# Tasks

## 1. memory-tripwire.sh の patches: の検知

- [x] 1.1 テストの切り離しを先に入れる: `memory-tripwire.bats` の `run_check` と `session-tripwires.sh` を呼ぶテストで、`DEV_WORKFLOW_MEMORY_PATCHES_CACHE` を一時ディレクトリに向け、呼ばれたら記録を残し決めた状態を返す偽の `gh` を `PATH` の先頭に置く。確かめ方: 既存の全テストがそのまま通る。触る範囲: plugins/dev-workflow/tests/memory-tripwire.bats:6-38（setup と run_check）
- [x] 1.2 frontmatter の `patches:` の読み取り（トップレベルと `metadata:` の下・issue の URL の形だけ・frontmatter の外は無視）を足す。確かめ方: 仕様の「2 つの置き場所のどちらも読む」「frontmatter の外と URL でない値は無視する」「守備範囲の外の書き方でもセッション開始を止めない」に当たるテストを足して通す。触る範囲: plugins/dev-workflow/scripts/memory-tripwire.sh:33-52（索引と本文を測る処理のあと）、plugins/dev-workflow/tests/memory-tripwire.bats:148-166（末尾に追加）
- [x] 1.3 控え（URL・日付・状態・閉じ方の 1 行。一時ファイルに書いて置き換え）と、その日の控えが無い URL だけを並べて `gh issue view --json state,stateReason` で確かめ、`DEV_WORKFLOW_MEMORY_PATCHES_TIMEOUT` で打ち切る処理を足す。失敗は「不明」で控え、`gh` が無いときは控えを書かない。bash 3.2 で動く書き方にし、止めるのは自分が起こした PID だけにする。確かめ方: 仕様の「その日の控えがあれば gh を呼ばず 0.5 秒未満で終わる」「前の日の控えは確かめ直す」「控えをメモリディレクトリに置かない」「gh が使えなくても止めない」「取得の失敗があっても閾値の超過と別の URL の閉鎖は知らせる」「打ち切りの時間を 0 にすると gh を呼ばない」に当たるテストを足して通す（時間は bash 3.2 でも測れる方法で測る）。触る範囲: plugins/dev-workflow/scripts/memory-tripwire.sh:1-31（冒頭の説明と環境変数）・:33-52、plugins/dev-workflow/tests/memory-tripwire.bats（末尾に追加）
- [x] 1.4 閉じた issue を持つメモリを既存の 1 行に条件として足す（件数と「ファイル名 ← URL」の組。閉じ方は分けない）。冒頭のコメントの「通知だけ」「無出力」の説明を新しい動きに合わせる。確かめ方: 仕様の「閾値の超過と閉じた issue が同時でも 1 行」「開いている issue だけなら何も出さない」「閉じた issue は閉じ方によらず知らせる」に当たるテストと、`session-tripwires.sh` を通すと additionalContext の先頭に載るテストを足して通す。触る範囲: plugins/dev-workflow/scripts/memory-tripwire.sh:54-68（msg の組み立てと printf）、plugins/dev-workflow/tests/memory-tripwire.bats:148-166

## 2. memory-refresh スキル

- [x] 2.1 SKILL.md に `patches:` の書き方の正本（置き場所・値・検知側が 1 日 1 回確かめて知らせること・控えの場所）を置き、分類の表の削除に「`patches:` の issue が完了で閉じた」を足し、完了以外で閉じたものの扱いを書く。冒頭の検知の説明も `patches:` を含めて直す。`commands/memory-refresh.md` は薄いラッパーのまま変えない。確かめ方: `grep -n 'patches:' plugins/dev-workflow/skills/memory-refresh/SKILL.md` で書き方と分類の行が出て、`COMPLETED` と `NOT_PLANNED` の扱いが書かれている。触る範囲: plugins/dev-workflow/skills/memory-refresh/SKILL.md:8-12（検知の説明）・:20-31（分類の表とその下）

## 3. メモリを書くときの規則

- [x] 3.1 `rules/plugin-editing.md` に、プラグインの動きへの指摘をメモリにその場しのぎで書くときは同じターンでその部品を持つリポジトリに issue を立て、frontmatter に `patches: <issue の URL>` を書く 1 行を足す（個人版の名前とパスは書かない。冒頭の発火条件にもメモリで補おうとしたときを足す）。`rules/README.md` の plugin-editing の行の「常時注入に残した要点」を合わせて直す。確かめ方: `tests/public-private-split.bats` に、公開版の plugin-editing に `patches:` の規則があることを確かめるテストを足し、`tests/public-private-split.bats`・`tests/always-on-injection-scope.bats`・`tests/plugin-release-convention.bats`・`tests/injection-budget.bats` が通る。触る範囲: rules/plugin-editing.md:1-8、rules/README.md:59、tests/public-private-split.bats:160-200（PE を検査する Python の近く）・:471-495

## 4. 記録と実機の確認

- [x] 4.1 `plugins/dev-workflow/changes/1654.md` にこの change の分（何が変わったか・控えの場所・待ち時間・止め方・戻し方）を足す。確かめ方: ファイルに `patches:` と `DEV_WORKFLOW_MEMORY_PATCHES_TIMEOUT` の説明がある。触る範囲: plugins/dev-workflow/changes/1654.md（owner-hands-only-ops で新規に作ったファイルに追記。先に無ければ新規）
- [ ] 4.2 実機で確かめる: 一時ディレクトリの `CLAUDE_CONFIG_DIR` と `DEV_WORKFLOW_MEMORY_DIR` に、実際に閉じた issue の URL を `metadata:` の下の `patches:` に書いたメモリと前の日の控えを置き、本物の `gh` で `session-tripwires.sh` を走らせて additionalContext の先頭に `[memory]` の候補が出ること、同じ日にもう一度走らせると `gh` を呼ばず 0.5 秒未満で終わることを確かめ、コマンドと出力を記録先に残す。実ホームには書かない
- [ ] 4.3 `bats plugins/dev-workflow/tests/memory-tripwire.bats` と `bats plugins/dev-workflow/tests/` の SessionStart 関係のテスト（`session-tripwires` を呼ぶもの）が通る
