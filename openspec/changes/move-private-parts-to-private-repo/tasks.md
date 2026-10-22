行番号は仕様づくりの時点（前半のブランチ 9897e5ba の上）の値。1.1 で origin/main を取り込むと `tests/public-private-split.bats` と `openspec/specs/harness-public-private-split/spec.md` は大きく変わるので、編集の前に該当範囲を読み直す。「個人版:」で始まるパスは個人版のリポジトリ `oratta/claude-harness-oratta` の中のパス。

## 1. 前提をそろえる

- [x] 1.1 前半の PR #1213 が main にマージされたことを確かめ、このブランチに origin/main を取り込む（merge。衝突は #1213 側で解いた結果に合わせる）。触る範囲: ブランチ全体（編集なし）
- [x] 1.2 `harness-public-private-split` の delta の 2 つの MODIFIED（「dev-workflow 以外の公開版の部品は…」「dev-workflow の公開版の部品は Orca 経路を除いて…」）を、取り込んだ後の正本と突き合わせ、個人版のファイルと節を除く決まりを外した点以外が正本と同じになるよう直す。`openspec validate move-private-parts-to-private-repo --type change --strict` が通る。触る範囲: openspec/changes/move-private-parts-to-private-repo/specs/harness-public-private-split/spec.md、openspec/specs/harness-public-private-split/spec.md（読むだけ）
- [x] 1.3 写し元の commit SHA を決める（1.1 の後の origin/main の HEAD）。移す部品のパスについて `git log <写し元SHA>..origin/main -- <パス>` が空であることを、以後のマージ前の確認の基準にする。触る範囲: なし（SHA を作業メモと PR 本文に書く）

## 2. 個人版のリポジトリの中身を作る（push は本体）

- [x] 2.1 公開版の開発用 clone の外に、個人版の作業ディレクトリを作り `git init -b main` する。場所は本体が指定する。触る範囲: 個人版: リポジトリ全体（新規）
- [x] 2.2 `plugins/weekly-report/`・`plugins/daily-report/` を写し元の SHA から丸ごと写す（`git archive <SHA> plugins/weekly-report plugins/daily-report | tar -x -C <作業ディレクトリ>`）。触る範囲: 個人版: plugins/weekly-report/（新規）、個人版: plugins/daily-report/（新規）
- [x] 2.3 `rules/plugin-editing.md` を `rules/` に、`plugins/dev-workflow/docs/auto-merge-deployments.md` を `docs/auto-merge-deployments.md` に写す。触る範囲: 個人版: rules/plugin-editing.md（新規）、個人版: docs/auto-merge-deployments.md（新規）
- [x] 2.4 プラグイン `capability-registry-oratta` を作る: `.claude-plugin/plugin.json`（name・description・skills。`version` を書かない）、`skills/capability-registry-oratta/SKILL.md`（新しい frontmatter の description と、写し元の capability-registry の SKILL.md の「表記規約（生成文にも適用すること）」「資格情報の階層（どこに置くかはプロジェクトごとに決めない）」の 2 節をそのまま）、`skills/capability-registry-oratta/1password.md`・`scripts/fmtoken.sh`・`tests/fmtoken.bats`（写し元から）。`tests/fmtoken.bats` のスクリプトの相対パスが新しい置き場で解けることを確かめる。触る範囲: 個人版: plugins/capability-registry-oratta/（新規）、plugins/capability-registry/skills/capability-registry/SKILL.md:9-12・19-47（写し元。読むだけ）
- [x] 2.5 `openspec/specs/` の 4 本（`capability-registry-fmtoken`・`weekly-report-jsonl-direct`・`report-command-hygiene`・`report-noninteractive-mode`）を写す。触る範囲: 個人版: openspec/specs/（新規）
- [x] 2.6 写したものに 2 点だけ手を入れる: install ID の `@oratta-claude-harness` を `@claude-harness-oratta` に、`plugins/dev-workflow/references/self-verification.md` への参照を「公開版の dev-workflow の `references/self-verification.md`」に。`grep -rnF -e '@oratta-claude-harness' -e 'plugins/dev-workflow/references/self-verification.md' <作業ディレクトリ>` が 0 件であることで古い書き方が残っていないことを確かめ（`plugins/dev-workflow/` の付いた旧パスの全体で探す。置き換えた後の文は `plugins/dev-workflow/` を含まないので当たらない）、`grep -rnF -e '@claude-harness-oratta' -e '公開版の dev-workflow の `references/self-verification.md`' <作業ディレクトリ>` で置き換えた箇所の数が置き換える前の当たりの数と同じであることを別に確かめる。それ以外の差分が無いことを `diff -r` で写し元と比べて確かめる。触る範囲: 個人版: plugins/weekly-report/、plugins/daily-report/、plugins/capability-registry-oratta/、rules/plugin-editing.md
- [x] 2.7 `.claude-plugin/marketplace.json` を書く（name `claude-harness-oratta`、plugins は `weekly-report`・`daily-report`・`capability-registry-oratta`。`version` を書かない。`weekly-report`・`daily-report` の項目は公開版の marketplace.json の同名の項目をそのまま写す。`capability-registry-oratta` の項目は公開版の `capability-registry` の項目（欄は name・description・source・category・author・keywords）を元にし、name を `capability-registry-oratta`、source を `./plugins/capability-registry-oratta`、description を 2.4 で書いたスキルの description に合わせた文、keywords を保管庫とトークンの取り出しの語（例: `1password`・`token`）に変え、category と author はそのまま写す）。触る範囲: 個人版: .claude-plugin/marketplace.json（新規）、.claude-plugin/marketplace.json:27-55・111-125（写し元。読むだけ）
- [x] 2.8 公開版の作業ツリーに個人版の固有名が残っていないかを調べる `scripts/check-public-leak.sh <公開版の作業ツリー>` と辞書 `tests/private-names/dict/private-parts.txt`（`fmtoken`・`weekly-report`・`daily-report`・`auto-merge-deployments`・`1password.md`・`Fieldy`）を書く。検索の範囲は design の決定 4 のとおり（公開版の `git ls-files` のうち `rules/`・`output-styles/`・`scripts/`・`plugins/` とルート直下の `README.md`・`CLAUDE.md`・`AGENTS.md`・`CONTRIBUTING.md`。`openspec/`・`docs/public-private-split.md`・`_longruns/`・`changes/`・`CHANGELOG.md`・`tests/`・`evals/` を除く）。辞書は絶対パスで `forbidden-words-check.sh --dict` に渡し、`FORBIDDEN_WORDS_NO_GH=1` で呼ぶ。今の公開版（消す前）に対して実行すると当たりが出て終了コード 1 になることを確かめる。触る範囲: 個人版: scripts/check-public-leak.sh（新規）、個人版: tests/private-names/dict/private-parts.txt（新規）、plugins/dev-workflow/scripts/forbidden-words-check.sh:1-30（読むだけ）
- [x] 2.9 `README.md` を書く: 位置づけ（公開版 `oratta/claude-harness` の上に載せる追加分）、入れ方（`/plugin marketplace add oratta/claude-harness-oratta` と各プラグインの install、`~/.claude/rules/plugin-editing.md` の symlink の張り方）、確かめ方（`bats plugins/*/tests`、`scripts/check-public-leak.sh`）、写し元の SHA。CI は置かない。触る範囲: 個人版: README.md（新規）
- [x] 2.10 `bats plugins/*/tests` が個人版の作業ディレクトリで通る。触る範囲: なし（実行だけ）
- [x] 2.11 最初の commit を作る（メッセージに写し元の公開版の commit SHA と https://github.com/oratta/claude-harness/issues/1129 を書く）。`gh repo create oratta/claude-harness-oratta --private` と `git push -u origin main` は本体に頼む（サブエージェントからの main への push は hook に拒否されるので打たない）。触る範囲: 個人版: リポジトリ全体

## 3. 公開版の検査を先に直す（TDD）

- [x] 3.1 移した部品が公開版に無いことの検査を足す: 節「個人版に移した部品」の表からパスと SKILL.md の見出しを読み、`git ls-files` が 0 件・`marketplace.json` の `plugins[]` と bundle に `weekly-report`・`daily-report` が無い・SKILL.md に 2 節の見出しが無い、を確かめる。節の表の行が移した先と写し元の SHA を持つことも確かめる。`rules/plugin-editing.md` を作業コピーに置き直すとそのパスを挙げて落ちる検査と、仕分けの表に `fmtoken.sh` の行を残すと落ちる検査を足す。触る範囲: tests/public-private-split.bats（新規の @test。`check_split` の近く 26-140）
- [x] 3.2 仕分けの表の移した行を前提にした既存の検査を、移した後の形に直す（`fmtoken.sh` の行を落とす検査・分類を書き換える検査・個人版のファイルと節を検索の範囲から除く処理）。除く処理は外し、capability-registry の SKILL.md の「原則」の節に `moko` を書き足すと落ちる検査を足す。触る範囲: tests/public-private-split.bats:340-350、tests/public-private-split.bats:410-416、tests/public-private-split.bats:500-515、tests/public-private-split.bats:570-580（1.1 の後の位置で読み直す）
- [x] 3.3 移した部品を前提にした他の検査を直す: 自己検証の対象と参照元から daily-report・weekly-report を外す、常時注入の目印と対象から plugin-editing.md を外す、版上げの規約文書の対象から plugin-editing.md を外す、capability-registry の SKILL.md の公開版の部分の切り出し（`public_part`）を外して全体を見る。触る範囲: plugins/dev-workflow/tests/shared-references.bats:20-30・70-76、plugins/dev-workflow/tests/self-verification-sections.bats:15-42、tests/always-on-injection-scope.bats:51-55・121-126、tests/plugin-release-convention.bats:23、plugins/capability-registry/tests/skill-registry.bats:37-40・65-66
- [x] 3.4 `bash scripts/test.sh` を回し、3.1 の検査が公開版から消す前の状態で期待どおり落ちることを確かめる。触る範囲: なし（確認だけ）

## 4. 公開版から部品を消し、参照を直す

- [x] 4.1 `git rm -r` で消す: `plugins/weekly-report/`・`plugins/daily-report/`・`rules/plugin-editing.md`・`plugins/dev-workflow/docs/auto-merge-deployments.md`・`plugins/capability-registry/scripts/fmtoken.sh`・`plugins/capability-registry/skills/capability-registry/1password.md`・`plugins/capability-registry/tests/fmtoken.bats`。触る範囲: 左のパス
- [x] 4.2 capability-registry の SKILL.md から「表記規約」「資格情報の階層」の 2 節を消し、残る節から 2 節への参照があれば「個人版が入っていれば」の書き方に直す。触る範囲: plugins/capability-registry/skills/capability-registry/SKILL.md:9-47
- [x] 4.3 `marketplace.json` から `weekly-report`・`daily-report` の項目と bundle `all` の 2 行を消す。触る範囲: .claude-plugin/marketplace.json:26-55、.claude-plugin/marketplace.json:181-190
- [x] 4.4 自己検証の対象スキル一覧から 2 行を消し、dev-workflow の README の説明から daily-report・weekly-report を外す。触る範囲: plugins/dev-workflow/references/self-verification.md:30-60、plugins/dev-workflow/README.md:116
- [x] 4.5 auto-merge テンプレの README の展開の記録への参照を「展開の記録は個人版を使うときはそちら」の書き方に直す。触る範囲: plugins/dev-workflow/templates/auto-merge/README.md:125-132
- [x] 4.6 ルート直下の文書を直す: README のプラグイン一覧から 2 行を消す、CONTRIBUTING の Skill の例から `weekly-report` を別の公開版のスキルに替える、CLAUDE.md・AGENTS.md の LLM ログの節の skill の例を公開版に残るものか一般的な書き方に直し、関連の行の plugin-editing を「個人版が入っていれば」の書き方にする、`docs/worktree-recovery.md` の冒頭の plugin-editing への言及を同じ書き方にする。CLAUDE.md・AGENTS.md は聖域なので PR 本文に理由を書く。触る範囲: README.md:60-66、CONTRIBUTING.md:60、CLAUDE.md:29・41、AGENTS.md:31・43、docs/worktree-recovery.md:1-5
- [x] 4.7 仕分けの文書を直す: 仕分けの表から移した行を外し、新しい節「個人版に移した部品」（列は 部品・移した先・写し元の commit）を足す。付属のファイルの扱いの「#1129 で書き分ける」を書き分けた結果に、capability-registry の扱いの節を移した後の状態に、載せない行の基準の「個人版の部品の中の行」の例を移した部品の記録への参照に直す。触る範囲: docs/public-private-split.md:30-36、docs/public-private-split.md:51-103、docs/public-private-split.md:104-144、docs/public-private-split.md:165-172
- [x] 4.8 `rules/README.md` の plugin-editing の行が「個人版が入っていれば」のままで、個人版のリポジトリ名を書いていないことを確かめる（必要なら直す）。触る範囲: rules/README.md:42
- [x] 4.9 常時注入の実測を取り、`tests/injection-budget.txt` を実測に合わせて下げる（聖域。PR 本文に何を消して値をいくつにしたかを書く）。触る範囲: tests/injection-budget.txt:1
- [x] 4.10 変更の記録を書く（移した部品と移した先・写し元の SHA・公開版で消したもの・オーナーの切り替えの手順）。触る範囲: plugins/dev-workflow/changes/1218.md（dev-workflow の 1129.md は前半の PR で main に入っているので PR 番号で書く）、plugins/capability-registry/changes/1129.md（新規）

## 5. 検証

- [x] 5.1 `bash scripts/test.sh` と `bash scripts/lint.sh` が通る。触る範囲: なし（実行だけ）
- [x] 5.2 個人版の作業ディレクトリで `scripts/check-public-leak.sh <公開版の作業ツリー>` を実行し、終了コード 0 を確かめる。当たりが出たら、公開版の文を直すか、経緯としてだけ名前を挙げる行なら個人版の allow に載せる。結果を PR 本文に載せる。触る範囲: なし（実行と PR 本文）
- [x] 5.3 個人版の作業ディレクトリと各プラグインで `claude plugin validate` が通る。触る範囲: なし（実行だけ）
- [x] 5.4 `openspec validate move-private-parts-to-private-repo --type change --strict` が通る。触る範囲: なし（確認だけ）

## 6. 切り替えとマージ（オーナーと本体）

- [ ] 6.1 公開版の PR を Draft のまま本文にオーナーの切り替えの手順（design の決定 6 の 3）を書き、本体に渡す。触る範囲: なし（PR 本文）
- [ ] 6.2 オーナーが全 PC で切り替えを終えたことを記録先で確かめる。触る範囲: なし（確認だけ）
- [ ] 6.3 `git log <写し元SHA>..origin/main -- <移した部品のパス>` が空であることを確かめる（空でなければ個人版に写してから進む）。触る範囲: なし（確認だけ）
- [ ] 6.4 archive の直前に `git rm -r openspec/specs/capability-registry-fmtoken openspec/specs/weekly-report-jsonl-direct openspec/specs/report-command-hygiene openspec/specs/report-noninteractive-mode` を行う。触る範囲: 左のパス
