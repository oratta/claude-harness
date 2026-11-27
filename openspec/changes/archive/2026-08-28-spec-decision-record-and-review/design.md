## Context

`github-issue` スキルのパイプラインは `worktree 確認 → 仕様化要否（Step B）→ change 分割（Step C）→ TDD 実装（Step D）`。Step B は判定基準（`references/decision-criteria.md`）を持つが結果をどこにも残さず、Step D は `/opsx:ff → apply → verify → archive` が直結で、生成した仕様を実装前に第三者が見る工程が無い。出口の pr-review-gate は実装 diff を受け入れ条件に照らすだけで、仕様の有無・質は見ない。

longrun には longrun-reviewer による Build Contract レビュー（plan.md を実装前に審査、APPROVE / REQUEST_CHANGES を schema で返す。上限 2 周）と、Spec Review モード（openspec の artifact を審査。上限 3 周。ただし自動配線されておらず手動でしか発火しない）がある。dev-workflow はこれを引き継いでいない。

制約: dev-workflow はリポ非依存プラグイン（flatmate 固有の仕組みを無条件参照しない）。サブエージェントは孫を spawn できないので、レビューは本体セッションが直接 spawn する。前提ツール: `gh`（issue コメント投稿権限）・Agent ツール・opsx コマンドまたは openspec CLI（どちらも無いリポは仕様化経路自体が無い）。

このスキルの規範（SKILL.md に何が書かれていなければならないか）は実行時挙動を bats で直接検証できないため、既存の `dev-workflow-pr-review-gate` capability と同じく **Scenario は「SKILL.md / references の該当節を読む → その規定が存在する」という文書アサーション形**で書く。`/opsx:verify` の判定基準もこれに揃える。

## Goals / Non-Goals

**Goals:**
- 仕様化要否の判断を機械照合できる書式で残し、「不要と判断した」と「飛ばした」を後から区別できるようにする
- 書いた仕様を実装前に別コンテキストが審査し、仕様レベルの穴を実装レビューに持ち込まない
- 本体セッションが自分で issue を回す経路（スキル未経由）にも同じ記録を要求できる土台を作る（照合そのものは後続 change の pr-review-gate 側）

**Non-Goals:**
- pr-review-gate での照合・auto-merge 合格条件への組み込み（後続 change）
- longrun-reviewer の agent 定義を dev-workflow に複製すること（観点だけを持ってくる）
- 仕様レビューを hooks で機械強制すること（スキル手順の範囲に留める）

## Decisions

### D1. 記録先は issue コメント、書式は機械照合できる固定 1 行目
- 採用: 元 issue に、**1 行目が正規表現 `^仕様化判断: (する|しない)$` に完全一致**するコメントを投稿する。太字・コロン全角・末尾句点などの装飾は禁止（issue #191 本文の `仕様化: **する**` のような揺れが実際に起きている）。2 行目以降が理由
- 照合規則（後続 change の pr-review-gate が使う契約）: ①同接頭辞のコメントが複数あれば **作成日時が最新の 1 件** を正とする（判定のやり直しを許す）②PR から元 issue を解決するのは **PR 本文中で最初に現れる `Closes #N` / `Fixes #N` / `Refs #N`**（大文字小文字不問）。見つからなければ「記録なし」扱い
- 理由: issue は PR より先に存在し、複数 PR に割れても 1 か所に集まる。`対象 HEAD:` 規約と同じく 1 行目を固定すれば `gh api .../comments --jq` で照合できる
- 却下: PR 本文の定型節（PR 作成前に判断が済んでいるので時点が合わない）／ラベル（理由を持てない）

### D2. レビュアーは別コンテキストの Task サブエージェント、観点は references に置く
- 採用: `references/spec-review.md` にレビュー観点・入力・出力書式・往復上限を書き、SKILL.md Step D からはそれを読んで `Agent` ツールで spawn する。agent 定義ファイルは作らない
- 理由: dev-workflow の他手順（pr-review-gate の別コンテキストレビュー）と同じ形。agent 定義にすると plugin.json の agents 登録と longrun-reviewer との二重管理が生じる
- モデル: 既定は中位ティア（`opus`）。仕様が **Step D の「重要実装の事前分類」表**（正本はそこ。ここに再掲しない）に当たる場合は `fable`。残量モードは `dev-workflow-execution-strategy` の規定に従う — `FABLE_BUDGET_MODE=reserve` は**自動実行（unmanned / cron / loop 経由）のみ** `opus` 上限、`exhausted` は全経路で `opus` 上限。interactive の reserve は制限しない
- 実行戦略との接続: solo / delegate+verify では本体セッションが spawn する。**workflow 型（`/lr:e` に委ねる）では longrun の Build Contract レビューをもってこの工程の代替とし、二重にはレビューしない**
- 却下: longrun-reviewer をそのまま呼ぶ（longrun プラグイン未導入リポで動かない／plan.md 前提の入力が合わない）

### D3. 往復上限は 2 周、REQUEST_CHANGES は差分再レビュー
- 採用: 初回＋修正後の差分再レビュー 1 回で確定。2 周目でも BLOCKER が残るなら issue に `needs-approval` を付けて経緯をコメントし、interactive なら AskUserQuestion、unmanned ならサイクル終了
- 理由: pr-review-gate の 2 周キャップと揃える。pr-review-gate の「新規の高深刻度 blocking のみ 3 周目可」の例外は設けない（仕様段階なら人に返す方が安い）。longrun の Spec Review 3 周は plan.md からの自動生成が前提で人間が途中にいなかったための値

### D4. レビュー結果も issue コメントに記録する
- 採用: 1 行目が `^仕様レビュー: (APPROVE|REQUEST_CHANGES)$` に完全一致するコメントを投稿し、2 行目以降に周回数・レビュアーのモデル・残課題を書く。投稿手順は SKILL.md Step D に置く（references だけに書かない）
- 理由: 判断記録と同じ場所に並べると「仕様化した→レビューした→実装した」の連鎖が issue だけで追える

### D5. 縮退経路（openspec CLI のみ）でも同じ
- opsx コマンドが無く CLI だけの経路でも、artifact を書いた時点でレビューを挟む。opsx も CLI も無いリポでは仕様化経路が無いので Step B の記録だけが残る

## Risks / Trade-offs

- [レビュー 1 回分のコストが毎 change に乗る] → 仕様化しない（コード直行）判定には掛からない。往復 2 周キャップで上限を固定
- [固定 1 行目の表記揺れで照合に失敗する] → 正規表現を SKILL.md と references の両方に同一文字列で置き、bats で存在を検証。後続 change の照合側は同じ正規表現を参照する
- [本体直回し経路はスキルを読まないので記録が残らない] → この change では塞がない。後続 change の pr-review-gate 照合が「記録が無い PR は合格しない」形で出口を閉じる
- [サブエージェントが既存 spec 全読みでコンテキストを溢れさせる] → references で「`grep -rn` で当たりを付けてから該当 spec のみ Read」を指示
- [Step C の interactive 記述にも `ff → apply` の列がある] → Step D と同時に書き換える（tasks 3.4）

## Open Questions

- 後続 change で「規範を持ちうるパス」を触った PR に openspec 差分を要求する `spec-touch-check.sh` を置く場合、対象パスはリポごとの設定にする必要がある（flatmate 固有の構成を harness に固定しない）
