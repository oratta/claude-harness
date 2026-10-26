## Context

背景は proposal.md の Why。spec の文は移設先の実物（`plugins/dev-workflow/skills/develop/references/` 配下）に合わせて直す。差分は `## MODIFIED Requirements` に、直す文を含む要件の全文を置く。

## Goals / Non-Goals

- Goals: 移した節を SKILL.md の節として名指しする記述を無くす。`grep -n "SKILL.md.\{0,4\}「エピックの扱い」\|SKILL.md.\{0,4\}『エピックの扱い』" openspec/specs/` が 0 件になる。
- Non-Goals: 要件の意味の変更、要件名の変更、plugins/ 配下の変更。

## Decisions

- 直す基準は「その節の中身が今どのファイルにあるか」。移設先に中身がある節（エピックの扱い・エピックの子の停止・保留の引き継ぎ・直し方の判定・channel の 3 小節）を名指す記述を直し、SKILL.md に中身が残る節を名指す記述は直さない。見出しだけが SKILL.md に案内として残る「エピックの扱い」「エピックの子が主の返事を待って止まるとき」「保留で止まるときの引き継ぎ」も、規定の置き場所としては移設先を指す。
- 「SKILL.md の手順 N」「SKILL.md の Orca 経路」など、エピックの回し方の手順を指す言い方も同じ理由で `references/epic.md` に直す（手順の番号は epic.md でも同じ）。
- 複数の場所が分担する規定（リスク許容を親経由で受ける 3 か所、W の `段:` の対応）は「SKILL.md と移設先」の形で書く。
- 要件名は変えない（RENAMED にすると要件名で参照している他の記述にも波及するため）。名前に SKILL.md を含む 2 件は残るので、別の変更に回す。
- channel の網羅検査の要件は、列挙の置き場所を channel.md にし、検査が除く対象に channel.md を足し、列挙に epic-child-stop.md と fix-check.md を足す（channel.md の現状の列挙は 10 個で、spec の列挙は 8 個だった）。

## Risks / Trade-offs

- 要件の全文を差分に置くため差分が大きい。直した文以外を変えないことは、実装後レビューが PR の diff（archive 後の spec）で確かめる。
- 要件名に SKILL.md を含む 2 件が残る → 別の変更として扱い、return で報告する。
