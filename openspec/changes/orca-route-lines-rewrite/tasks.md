## 1. テストを先に書く（落ちることを確かめる）

- [ ] 1.1 `tests/public-private-split.bats` に、spec「固有記述の一覧に担い手なしの行を残さない」のテストを足す。(a) 実際の文書の一覧で「直す issue」が「担い手なし」の行が 0 件（既存の「no dev-workflow row in the listing is left without an owner」を、`plugins/dev-workflow/` の行に限らず一覧の全体に広げる）、(b) 一時の文書に「担い手なし」の行を足すと落ちる、(c) 一覧の行が 0 件でも形の検査（埋め込み Python の `if not listing` の「固有記述の一覧に行が無い」）が落ちない。(c) のために `if not listing` の検査を外し、見出しの行 `LIST_HEADER` があることだけを確かめる形にする。触る範囲: tests/public-private-split.bats:246-247、tests/public-private-split.bats:664-669、tests/public-private-split.bats:612-710（Orca 経路の節）
- [ ] 1.2 `bats tests/public-private-split.bats` で、足したテストのうち (c)（一覧が空でも通る）は一覧にまだ行があるうちは検査できないので、一時の文書で行を消して確かめる。(a)(b) は通る見込みで、(b) は担い手なしの行を足すと落ちることを確かめる。既存のテストが通ることを確かめる

## 2. 行ごとの判定（design D1）

- [ ] 2.1 一覧の担い手が #1177 の 25 件を、行番号でなく候補語 `git grep -n -i orca` と `git grep -n -w cld`（`changes/`・`CHANGELOG.md`・`tests/`・`evals/`・保留の部品を除く）で現在の本文に照合し直し、各行を読んで下の仮の判定を確かめる。違っていたら判定を変え、実施欄の表に最終の判定（直す／基準で外す）と理由を 1 行ずつ残す。あわせて、一覧に無い Orca の語の当たり（「部品ごとの欄」の表の 495〜502 行を含む）が基準に当たるか直すかも同じ表に残す

仮の判定:

| 場所（現在） | 仮の判定 | 理由 |
|---|---|---|
| `README.md:15` | 直す | 「Orca 経路の前提」と Orca を既定の経路として書く。起動部品の一覧として書き直す |
| develop `SKILL.md:46` | 基準で外す | `orca` と `tmux` を並べた判定の説明 |
| `SKILL.md:207` | 基準で外す | 「別セッション方式（Orca・tmux）」 |
| `SKILL.md:350` | 基準で外す | 同上 |
| `SKILL.md:353` | 基準で外す | 「Orca の部品の子では」と条件つきで書き、tmux の部品と並ぶ |
| `SKILL.md:483` | 基準で外す | 経路の決め方で `orca`・`tmux`・`subagent` を並べる |
| `SKILL.md:487` | 直す | 起動コマンドが `cld` の形で書かれている。`EPIC_DISPATCH_CLAUDE_CMD` で差し替える起動コマンドと書く |
| `SKILL.md:489` | 基準で外す | 「起動部品は Orca か tmux」 |
| `SKILL.md:491` | 基準で外す | 「Orca の部品の子では」と条件つきで、「tmux の部品に画面への写しは無い」と並べる。ただし「オーナーが Orca の画面で印を手で変えても」の文は Orca の部品の子と明記する直しを入れる |
| `SKILL.md:493` | 基準で外す | 「部品ごとの欄」の見出し（オーナーの指摘。design D2） |
| `SKILL.md:511` | 直す | 「Orca 側の失敗」の扱い。起動部品の側の失敗として書き、Orca の部品の場合を条件にする |
| `SKILL.md:512` | 基準で外す | 「`回し方: Orca` か `回し方: tmux`」 |
| `SKILL.md:517` | 確認 | Orca の語が無い。`epic-dispatch.sh reply` の手順で、別セッション方式の共通の手順なら一覧から外す（基準に当たらない理由は「Orca の語を含まない」で、候補語に当たらないので載せない行になる） |
| `SKILL.md:537` | 直す | 「無ければ Orca に登録済みのリポジトリ」。clone の探し方を起動部品ごとに書き、Orca の部品なら登録済みのリポジトリ、と条件にする |
| `SKILL.md:539` | 直す | `cld --model` の起動。起動コマンド（既定は `cld`）として書く |
| `SKILL.md:543` | 直す | `cld` が付ける `--dangerously-skip-permissions`。起動コマンドが付けるフラグとして書く |
| `references/reply-after-idle.md:3` | 直す | 「Orca 経路の子セッション」を「別セッション方式の子セッション」にする |
| `reply-after-idle.md:5` | 直す | 「回し方の Orca 経路の手順 8」を「別セッション方式の手順 8」にする |
| `reply-after-idle.md:64` | 直す | 「Orca 経路の子は `reap` で端末が閉じる」を、端末を閉じる起動部品（Orca・tmux）として書く |
| `scripts/owner-reply-check.sh:33` | 直す | コメントの「Orca で起動」を、起動部品に依らない書き方にする（bats の入力の文は `epic-dispatch.sh` の prompt の文のままで変えない） |
| `owner-reply-check.sh:52` | 直す | コメントの「Orca の親セッション」を「別セッション方式の親セッション」にする |
| `skills/pr-review-gate/declarations.md:83` | 直す | 「Orca の子のセッション」を「別セッション方式の子のセッション」にする |
| `declarations.md:91` | 直す | 「Orca の親が子のターミナルに打ち込んだもの」を「別セッション方式の親が…」にする |
| `declarations.md:103` | 直す | 「Orca の親」「Orca 以外の仕組み」を起動部品に依らない書き方にする |
| `skills/pr-review-gate/stages/pass.md:97` | 直す | 「Orca の親セッション」を「別セッション方式の親セッション」にする |

`parent-merge-criteria.md:3` の「Orca 経路のエピック」は保留の行（#1123 の後に決める）なので触らない。

## 3. 直す行を書き換える

各行は design D1 に従う。行番号は仕様づくりの時点の値で、ずれていたら候補語の `git grep` で探し直す。

- [ ] 3.1 `README.md` のエピックの説明を、起動部品（Orca・tmux）と、サブエージェント方式の並びで書き直す。触る範囲: plugins/dev-workflow/README.md:15
- [ ] 3.2 develop `SKILL.md` の 487・511・537・539・543（および判定で「直す」になった行）を書き直す。「部品ごとの欄」の表（493〜502 行）は変えない。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:487、plugins/dev-workflow/skills/develop/SKILL.md:511、plugins/dev-workflow/skills/develop/SKILL.md:537-543
- [ ] 3.3 `reply-after-idle.md` の 3・5・64 を書き直す。触る範囲: plugins/dev-workflow/skills/develop/references/reply-after-idle.md:3、plugins/dev-workflow/skills/develop/references/reply-after-idle.md:5、plugins/dev-workflow/skills/develop/references/reply-after-idle.md:64
- [ ] 3.4 `owner-reply-check.sh` の 33・52（コメントだけ。判定のコードと正規表現は触らない）、`declarations.md` の 83・91・103、`stages/pass.md` の 97 を書き直す。触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:33、plugins/dev-workflow/scripts/owner-reply-check.sh:52、plugins/dev-workflow/skills/pr-review-gate/declarations.md:83-103、plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:97
- [ ] 3.5 文面を固定している dev-workflow の bats（例: `plugins/dev-workflow/tests/epic-dispatch.bats` の develop `SKILL.md` を読むテスト、`owner-reply-check.sh` の bats）が直した文を求めて落ちるなら、新しい文に合わせる（期待する挙動は変えない）。`bats plugins/dev-workflow/tests/` が通る

## 4. 一覧と基準

- [ ] 4.1 `docs/public-private-split.md` の一覧から、2・3 で直した行と、基準で外すと判定した行をすべて消す（担い手が #1177 の行が 0 件になる）。一覧の説明文（「Orca 経路の行の担い手は #1177 にした」の段落）を、片付けた経緯に直し、一覧が空のとき見出しの行だけを残す。触る範囲: docs/public-private-split.md:142-175
- [ ] 4.2 同じ文書の「載せない行の基準」に「差し替え可能な起動部品の 1 つとして Orca を並べた行」の項目を足す（「Orca・tmux」「部品ごとの欄の表」の例を添え、Orca だけを前提にした行は当たらないと書く）。触る範囲: docs/public-private-split.md（節「載せない行の基準」）
- [ ] 4.3 `tests/public-private-split.bats` から `DEVWF_ORCA_ROWS`・`check_orca_owner` と、それを使う 4 つのテストを外す。`epic-launch-orca.sh is a pending part…` のテストは、担い手の欄を `#1177` から `#1123` に変えて残す。触る範囲: tests/public-private-split.bats:612-710
- [ ] 4.4 `bats tests/public-private-split.bats` が通り、`grep -c '#1177 |$' docs/public-private-split.md` が 0 で、一覧の担い手なしが 0 件である

## 5. 記録

- [ ] 5.1 変更の記録 `plugins/dev-workflow/changes/1177.md` に、直した行ごとに 1 行（元の場所・直し方）と、基準で外した行（部品ごとの欄の表を含む）の理由を書く。触る範囲: plugins/dev-workflow/changes/1177.md（新規）
- [ ] 5.2 `bash scripts/test.sh` と `scripts/lint.sh` が通る

## 実施欄

（実装の担い手が、2.1 の最終の判定の表と、実行したコマンドと結果をここに書く）
