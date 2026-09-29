行番号は 2850fe32（仕様づくりの時点）の値。前のタスクの編集でずれうるので、編集する前に該当範囲を読む。パスは `plugins/dev-workflow/` からの相対（リポジトリ直下のものは `./` で始める）。

## 1. 検査を先に書く（Red）

- [ ] 1.1 `tests/develop-worker-stages.bats` を作る: 索引にコードブロックが無い／段の表の `spec`・`implement`・`finish` の各行がちょうど 1 つの段のファイルを指し実在する／`worker/common.md` が実在する／段ごとに `common.md`＋段のファイルの文字数（`python3` で数える Unicode の文字数）が 7,000 以下／`worker/` の 4 本・索引・`pre-classification.md` の `## ` 見出しが 1 ファイルにだけある／事前分類表の 4 行が `pre-classification.md` にだけある／`agents/worker.md` の本文が `worker/common.md` と `段:` を含む／SKILL.md に `段: spec`・`段: implement`・`段: finish` がある／事前分類の参照元 6 ファイルが `pre-classification.md` を指し、事前分類について `roles/worker.md` を指さない。触る範囲: tests/develop-worker-stages.bats（新規）
- [ ] 1.2 `tests/test_codex_develop.py` の W の phase の期待値を design「Codex に渡す正本の一覧」に合わせて先に直す（spec / implement / finish は `worker/common.md` と段のファイル、explore / summarize は `worker/common.md`、`roles/worker.md` は付かない）。触る範囲: tests/test_codex_develop.py:738-766
- [ ] 1.3 1.1 と 1.2 を走らせて落ちることを確かめる。触る範囲: なし（確認だけ）

## 2. 段のファイルへ移す（節ごとに「移し先に足す」と「worker.md から消す」を同じ commit にする）

- [ ] 2.1 `skills/develop/references/pre-classification.md` を作り、「重要実装の事前分類」節をそのまま移す。触る範囲: skills/develop/references/roles/worker.md:138-157、skills/develop/references/pre-classification.md（新規）
- [ ] 2.2 `worker/common.md` を作り、冒頭の「本体が渡すもの」（`段:` の行を足し、「このファイルだけを読んで動く」を「このファイルと `段:` が指す段のファイルを読んで動く」に直す）・「W がしないこと」・「コンテキスト上限と手渡し」（「(3) をこれより細かく切らない」の箇条を除く）を移す。触る範囲: skills/develop/references/roles/worker.md:1-11、skills/develop/references/roles/worker.md:168-179、skills/develop/references/roles/worker/common.md（新規）
- [ ] 2.3 「(3) をこれより細かく切らない」の箇条を develop の SKILL.md の (3) に移し、いまの短い理由と「理由の正本は references/roles/worker.md」の 2 行をその本文で置き換える。触る範囲: skills/develop/references/roles/worker.md:178、skills/develop/SKILL.md:106-108
- [ ] 2.4 `worker/spec.md` を作り、記録先の用意（Draft PR）・仕様化判断と記録・分割判定・仕様化する場合を移す。仕様化しない場合の段落に「本体が同じコンテキストで (3a) へ進むよう指示したら `worker/implement.md` を読んでから進む」を足す。触る範囲: skills/develop/references/roles/worker.md:13-91、skills/develop/references/roles/worker/spec.md（新規）
- [ ] 2.5 `worker/implement.md` を作り、(3a) 実装＋verify と昇格トリップワイヤーを移す。(3a) の return の「書式は下の『コンテキスト上限と手渡し』」は `common.md`「コンテキスト上限と手渡し」に直す。触る範囲: skills/develop/references/roles/worker.md:93-126、skills/develop/references/roles/worker.md:159-166、skills/develop/references/roles/worker/implement.md（新規）
- [ ] 2.6 `worker/finish.md` を作り、(3b) を移す。触る範囲: skills/develop/references/roles/worker.md:128-136、skills/develop/references/roles/worker/finish.md（新規）
- [ ] 2.7 `worker.md` を索引に書き直す（段の表・旧節から移し先への対応表・本体が `段:` を書くことの案内。本文とコードブロックは持たない）。移した節の中の位置の参照（「下の」「上の」）で、別ファイルに分かれたものをファイル名と節名に直す。触る範囲: skills/develop/references/roles/worker.md（全体）、skills/develop/references/roles/worker/*.md（2.2〜2.6 で作ったもの）
- [ ] 2.8 4 本の文字数を数え、段ごとの合計が 7,000 以下であることを確かめる。超えたら中身を削らず、ここで止めて本体に return する。触る範囲: なし（確認だけ）

## 3. 読み手側の付け替え

- [ ] 3.1 `agents/worker.md` の本文を、`skills/develop/references/roles/worker/common.md` と起動指示の `段:` が指す `worker/<段>.md` を読むこと、`段:` が無ければ読まずに本体へ聞き返すことに直す（description は変えない）。触る範囲: agents/worker.md:8
- [ ] 3.2 develop の SKILL.md に `段:` の行を書く: (1) の spawn と (2) の REQUEST_CHANGES の再開は `段: spec`、(3a) の再開・(4) の failed のあとの再開・CI の見張りの `fix` の再開は `段: implement`、(3b) の再開は `段: finish`、手渡しは前任の段。触る範囲: skills/develop/SKILL.md:86-101、skills/develop/SKILL.md:126、skills/develop/SKILL.md:143-145、skills/develop/SKILL.md:159（SendMessage と手渡しの説明の節）
- [ ] 3.3 事前分類の参照元を `references/pre-classification.md` に直す。触る範囲: skills/develop/SKILL.md:86、skills/develop/SKILL.md:199、skills/develop/references/roles/spec-reviewer.md:30、skills/develop/references/decision-criteria.md:82、skills/pr-review-gate/stages/triage.md:103、references/model-tiers.md:69、README.md:14
- [ ] 3.4 worker.md の節を指すその他の参照を移し先に直す。触る範囲: skills/develop/SKILL.md:13（役割表の指示書の列）、skills/develop/SKILL.md:218（「分割判定」→ `worker/spec.md`）、skills/develop/SKILL.md:281（役割の指示書の一覧）、skills/develop/references/decision-criteria.md:3、skills/develop/references/decision-criteria.md:122、skills/develop/references/decision-criteria.md:136（読んだコードの要点の書式 → `worker/common.md`）、skills/pr-review-gate/declarations.md:14（仕様化判断 → `worker/spec.md`）、templates/escalation-tripwires.md:19（→ `worker/implement.md`）
- [ ] 3.5 `scripts/codex-develop.py` の `PHASES` と `prompt()` を、design「Codex に渡す正本の一覧」どおりに付け替える。触る範囲: scripts/codex-develop.py:24-34、scripts/codex-develop.py:459-465
- [ ] 3.6 `git grep -n 'roles/worker\.md\|worker\.md' -- plugins ./tests ':!plugins/dev-workflow/CHANGELOG.md' ':!plugins/dev-workflow/changes'` を実行し、3.1〜3.5 で直していない行が、W という役割の名前やエージェント定義 `agents/worker.md` への言及、索引そのものを指す行だけであることを確かめる。触る範囲: なし（確認だけ）

## 4. 既存検査の付け替えと確認

- [ ] 4.1 worker.md の文言を検査している bats の各アサーションを、その文言が移ったファイルに 1 つずつ付け替える（連結して検査しない。否定の検査は索引・`worker/` の 4 本・`pre-classification.md` の全部で見る）。触る範囲: tests/develop-roles.bats:5-200、tests/develop-roles.bats:258-262、tests/develop-roles.bats:440-470、tests/spec-decision-and-review.bats:5-60、tests/model-escalation-policy.bats:7-60、tests/model-escalation-policy.bats:150-170、tests/subagent-waiting.bats:22、tests/subagent-stop-guard.bats:486-495（差し込み先を複製の `worker/implement.md` に）、tests/handoff-declaration.bats:132-145（書式の正本を `worker/common.md` に）、tests/retirement.bats:74-76（`worker/finish.md`）、tests/develop-skill.bats:118、./tests/develop-worker-ci-checks.bats:6（`worker/implement.md`）
- [ ] 4.2 `plugins/dev-workflow/changes/556.md` に変更の記録を書く（移したもの・issue の当たりから変えた置き場所 2 点とその理由・中身を変えていないこと）。触る範囲: changes/556.md（新規）
- [ ] 4.3 `./scripts/test.sh` と `./scripts/lint.sh` が exit 0 であることを確かめる（CI の workflow の `run:` から集めた検査も実行する）。触る範囲: なし（確認だけ）
- [ ] 4.4 `openspec validate worker-stage-files --strict` が通ることを確かめる。触る範囲: なし（確認だけ）
- [ ] 4.5 段ごとの文字数（`common.md`＋段のファイル）の実測値を (3a) の return に書く。`scripts/subagent-context-audit.sh --by-role` による W の `docs_median` の実測とファイルごとの内訳は、develop を通したあと PR 本文に記録する。触る範囲: なし（記録だけ）
