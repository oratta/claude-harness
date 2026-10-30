# Design

## Context

動機は proposal.md の Why を見る。設計に効く事実は次の 3 つ。

- #1377 に足した親セッションは、別リポジトリ（oratta/mac-mini-migration）のエピックを回していた。編集の直前に読んだ手順書は `pr-review-gate/stages/pass.md` などで、受け入れ条件を足す文がある `triage.md` と `issueify/SKILL.md` は読んでいない。develop の手順書も約 1 時間半前に読んだきりである
- 親が実行した `gh issue view 1377 --json body` は本文しか取らないので、作業中かは分からない
- 常時注入の実測は 40,904 バイトで、予算 40,905 に対して余裕は 1 バイトである

## Goals / Non-Goals

**Goals:**

- 誰がどのリポジトリから足そうとしても、足す瞬間に決まりが目に入る
- 主が OK するときに、作業中かどうかを知っている

**Non-Goals:**

- G がレビュー指摘の振り分けで受け入れ条件に足す経路（`triage.md` の段 C）を変えること。#1377 の経路ではなく、#1390 の受け入れ条件の 2 つ目の「その経路」に当たらない。`triage.md` の段 C の子の行に作業中の確認が無い件は #1498 で扱う
- 自動検査や hook で足す操作を止めること
- 受け入れ条件を足す以外の本文の編集（誤字の修正やチェックボックスの更新）を縛ること
- Draft PR が記録先のときの PR 本文の受け入れ条件。Draft PR が記録先なら、作業中であることは PR を見れば分かる

## Decisions

### 書く場所は `rules/` にする

手順書（`issueify/SKILL.md`・`develop/SKILL.md`・`epic.md`）だけに書く案は取らない。足す瞬間に手順書を読む理由が無く、#1377 の親もどれも直前に読んでいなかった。`always-on-injection-scope` の判定条件「そのルールが止めようとしている行動を思いついた時点で、先に skill や references を読む判断ができるか」に当てると、できないので常時注入に残す側である。#1390 の受け入れ条件の「該当する手順書」は、経路に当たる手順書が無かったので、この rules の文で満たす。

### ファイルは `rules/git-commit-policy.md` にする

`rules/` の直下に新しいファイルを 1 本足す案もある。話題が分かれて見やすいが、次の 2 点で既存ファイルを取る。

- 新しいファイルは端末ごとに `scripts/sync.sh` が symlink を張るまで届かない。既存ファイルの追記は marketplace の更新だけで届く
- 見出しと表題のぶんバイトが増える

`perspective-casting.md` は判断の上げ方、`communication-style.md` は書き方の決まりで、作業の進め方を決める `git-commit-policy.md`（PR 運用の範囲とマージの承認）がいちばん近い。

### capability は新しく `in-progress-issue-scope` を作る

`dev-workflow-issueify` は issueify スキルの振る舞いの spec で、#1377 の経路（スキルを通らない編集）を覆わない。`dev-workflow-develop` は本体の手順の spec で、足す役が develop の中にいるとは限らない。`always-on-injection-scope` は縮約の規則の spec で、個々の決まりの中身は持たない。既存のどれにも属さないので新しく作る。

### 作業中の見分け方は `develop 開始` のコメントと開いた紐づく PR の 2 つにする

`gh issue view <番号> -R <owner/repo> --json comments` でコメントを、`gh pr list -R <owner/repo> --state open --search "<番号> in:body" --json url,body` で PR を見る。`--json url,body` を付けるのは、既定の出力には本文も URL も無く、参照の判定も問いに書く URL も取れないためである。`-R` を書くのは、#1377 の親のように別リポジトリから足す経路があるためである。

`closedByPullRequestsReferences` を使う案は取らない。閉じるキーワードの PR しか返さないので、このリポジトリの対応の規則の `Refs #<番号>` の PR を取りこぼし、state も持たない。実例として、#580 は PR #1436 が `Refs #580` で作業中だが、`closedByPullRequestsReferences` は空で、`develop 開始` のコメントも無い。

本文の検索は番号が現れるだけの PR も返す（#580 の検索は `Refs` の #1436 のほかに #1491 を返す）。結果の PR の本文を見て、`Closes` / `Fixes` / `Refs #<番号>` のあるものだけを数える。誤って返っても本文を見れば分かるので、害は小さい。

マージ済みの PR だけが残る open の issue は、`develop 開始` のコメントの有無で読む。`Refs` の PR がマージされた後も作業が続く場合を、コメントで拾える。

### 作業中なら新しい issue に切り出すのを既定にする

切り出しは `develop/SKILL.md` の「範囲外の問題の起票」と同じく主に聞かずにできるので、作業を止めない。#1377 の結末も切り出しだった。同じ issue に足したいときだけ主に聞くので、聞く回数は増えない。

### 対象外は G の振り分けの経路に限る

`triage.md` の段 C の子の行は「その子 issue の受け入れ条件に足す」と定めていて、rules の決まりと食い違う。G の経路だけを対象外にして、rules に「G がレビュー指摘の振り分けで足す場合は `dev-workflow:pr-review-gate` に従う」と書く。本体は範囲外の問題の起票で段 C の問いを借りる（`develop/SKILL.md:70`）が、この経路は対象外に入らず、rules の決まりを優先する。`develop/SKILL.md` は他の PR と重なるので触らない。

### 予算は足した後の実測に合わせて引き上げる

代わりに他の常時注入の文を削る案は取らない。常時注入に残す文は `always-on-injection-scope` の判定で残したもので、この変更の範囲で削る根拠を持たない。実測の 5% 増しにする案も取らない。余裕を持たせると、次の増加が PR の差分として主の前に出なくなる。実装の終わりに実測し、その値をそのまま予算にする。

## Risks / Trade-offs

- [全セッションの固定分が約 720 バイト増える] → 文を発火条件と要点だけに留める
- [PR も `develop 開始` のコメントも無い作業と、番号が本文に現れない PR で進む作業は見分けられない] → 受け入れる。守備範囲は spec の要件のとおりで、塞ぎ切ることを完了条件にしない
- [作業が放置された issue も `develop 開始` のコメントで作業中と読む] → 新しい issue に切り出すだけで、害は小さい
- [予算の余裕が他の PR と同時に動く] → 実装の終わりと、origin/main を取り込んだ後に実測を取り直す（tasks 2.1）
- [`--json comments` はコメントの多い issue で読む量が増える] → 受け入れる。足す前の 1 回だけである

## Migration Plan

マージ後は marketplace の更新で届く。戻すときは PR を revert する。
