## Context

背景は proposal.md の Why。spec の文は移設先の実物（`plugins/dev-workflow/skills/develop/references/` 配下）に合わせて直す。差分は `## MODIFIED Requirements` に、直す文を含む要件の全文を置く。

## Goals / Non-Goals

- Goals: 移した節を SKILL.md の節として名指しする記述を無くす。tasks.md 2.1 の `grep -rnE` が一致ゼロ（exit 1）になる。移した内容（条件・サブエージェント方式・枠の数え方・マージ待ちの子・`nested` を受けたセッション）を SKILL.md に置く書き方も、`references/epic.md` に置く書き方に直す。
- Non-Goals: 要件の意味の変更、plugins/ 配下の変更。要件名は、名前に SKILL.md を含む 2 件だけを変える（下の Decisions）。

## Decisions

- 直す基準は「その節の中身が今どのファイルにあるか」。移設先に中身がある節（エピックの扱い・エピックの子の停止・保留の引き継ぎ・直し方の判定・channel の 3 小節）を名指す記述を直し、SKILL.md に中身が残る節を名指す記述は直さない。見出しだけが SKILL.md に案内として残る「エピックの扱い」「エピックの子が主の返事を待って止まるとき」「保留で止まるときの引き継ぎ」も、規定の置き場所としては移設先を指す。
- 「SKILL.md の手順 N」「SKILL.md の Orca 経路」など、エピックの回し方の手順を指す言い方も同じ理由で `references/epic.md` に直す（手順の番号は epic.md でも同じ）。
- 複数の場所が分担する規定（リスク許容を親経由で受ける 3 か所、W の `段:` の対応）は「SKILL.md と移設先」の形で書く。
- 要件名は、名前に SKILL.md を含む 2 件（「SKILL.md の回し方は再開時に adopt を呼び、待ちを終えるときに clear を呼ぶ」「別のリポジトリの子を含むエピックの回し方を SKILL.md に書く」）だけ、`## RENAMED Requirements`（FROM/TO）で「epic.md の…」「…を epic.md に書く」に変える。回し方の中身が epic.md にある以上、名前だけ SKILL.md を指すと issue の受け入れ条件（移設先の節を SKILL.md の節として名指す記述が無い）に反する。RENAMED した要件を MODIFIED で書くときの見出しは新しい名前にする。要件名を参照する他の記述は `grep -rn` で確かめ、`openspec/specs/` と delta には無かった（`plugins/dev-workflow/tests/epic-dispatch.bats:5096`・`plugins/dev-workflow/tests/develop-skill.bats:1159` のコメントが旧名を書いているが、plugins/ 配下はこの change で変えないので申し送る）。
- `dev-workflow-epic-state` の spec.md の 109・242・580 行付近は、develop の手順書を総称して「SKILL.md の手順」と書いている（節名では名指していない）。別の capability の守備範囲の段落と WHEN にあり、この change の対象（移した節を名指す記述）に当たらないので見送る。直すなら別の change で扱う。
- シナリオの題に SKILL.md を含むものが 7 件（「SKILL.md の回し方が起動部品の差し替えとして書かれている」「SKILL.md に子エピックの扱いと完了報告が書かれている」「SKILL.md に端末を作れなかった子の再開手順が書かれている」「SKILL.md の回し方が規則のファイルを指す」「SKILL.md に既定値と根拠の実測値が書かれている」「SKILL.md の経路の決め方に orca になる条件としての件数の下限が書かれていない」「SKILL.md に注意書きのコメントと起動し直したセッションの扱いが書かれている」）残る。`openspec validate --strict` は、MODIFIED の要件が現行 spec のシナリオを題で照合し、題が違うと「現行のシナリオを落としている」として拒否する（題を epic.md に変えて試して確かめた）。シナリオの題だけを変える手段が RENAMED（要件名にしか使えない）にも無いので、題は据え置き、WHEN・THEN の本文を実物に揃える。題の変更は openspec 側の対応（シナリオの改名）を待つか、要件ごと REMOVED と ADDED にする別の change で扱う。
- 入力を分類して続行／停止する要件（エピックの条件・作り方・回し方・完了条件、adopt と clear の呼び方、推定した done の片付け、保留の許容の受け方）には、`references/roles/spec-reviewer.md` の観点 6 の 4 要素（入力の出どころ・拾いたい誤り・通してよい入力の具体例・穴を塞ぎ切ることを完了条件にしない旨）を備えた短い守備範囲の段落を足す。中身は `references/epic.md` と各要件の既存の本文から導き、新しい振る舞いは足さない。
- channel の網羅検査の要件は、列挙の置き場所を channel.md にし、検査が除く対象に channel.md を足し、列挙に epic-child-stop.md と fix-check.md を足す（channel.md の現状の列挙は 10 個で、spec の列挙は 8 個だった）。

## Risks / Trade-offs

- 要件の全文を差分に置くため差分が大きい。直した文以外を変えないことは、実装後レビューが PR の diff（archive 後の spec）で確かめる。
- シナリオの題に SKILL.md を含む 7 件が残る → 上の Decisions のとおり openspec の制約で据え置き、return で報告する。
