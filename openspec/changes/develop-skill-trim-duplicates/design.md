# Design

## Context

一覧（issue #1239 のコメント https://github.com/oratta/claude-harness/issues/1239#issuecomment-6367437989 ）は HEAD 333b8419 の時点で、項目ごとに正本の置き場所を決めている。本体の分割の決定（ https://github.com/oratta/claude-harness/issues/1239#issuecomment-6367478782 ）で、この change が触るファイルは `skills/develop/SKILL.md`・`skills/develop/references/handover.md`・この change の spec の差分・`plugins/dev-workflow/tests/develop-skill.bats`・`changes/1239.md` の 5 つに限られた。

SKILL.md の文面は、develop-skill.bats のほかに次のテストも grep で固定している。この change ではこれらのテストを書き換えない（触るファイルの範囲の外で、書き換えると編集対象が 5 ファイルを超える）。

| テスト | SKILL.md で固定している文 |
|---|---|
| `plugins/dev-workflow/tests/develop-adapter-review-routing.bats` | 「Role profile の選択」節の `レビュー経路` の規則の全文（起動形を問わず常に・request の instructions・従来は書かない・段ごとに新しく起こす G と後任 G のすべて・行が無い G は従来経路・どの段でも省略しない）と、(4) の「常に `レビュー経路: adapter`」「`レビュー経路: 従来` は書かない」 |
| `plugins/dev-workflow/tests/test_codex_develop.py` | SKILL.md のどこかに `claude-write-codex-review`・`margin`・`SendMessage`・`上限`・`fresh thread`・`requested tuple`・`工程完了`・`停止確認`・`FABLE_BUDGET_MODE`・`SHARED_BUDGET_MODE`・`references/codex-develop.md`・`分岐を再掲せず` |
| `plugins/dev-workflow/tests/spec-decision-and-review.bats` | (2) に「直し方が決まっている」「主に聞かず次の周を回す」「方針の選び直し」「`pr-token-budget.sh` が exit 2」 |
| `plugins/dev-workflow/tests/develop-roles.bats` | SKILL.md のどこかに `isolation: "remote"` と「remote … 使わない」 |
| `plugins/dev-workflow/tests/develop-channel-mode.bats` | 「Role profile の選択」節に `実行モード:` と `チャンネルの返事の確認:` |
| `plugins/dev-workflow/tests/develop-handover.bats` | `handover.md` の再開の手順 2 に `CLAUDE_CODE_SESSION_ID` |

## Goals / Non-Goals

**Goals:**

- 一覧の B1・B2 を消し、C1〜C11（C5 は SKILL.md 側だけ）を「正本 1 か所＋参照」にする
- 本体と W のすることは変えない（B1 は入力が来なくなった分岐を消すだけ）
- `bats tests/` と `plugins/dev-workflow/tests/develop-*.bats` が変更前と同じく通る

**Non-Goals:**

- `commands/develop.md`・`references/codex-develop.md` の書き換え（#1307）、`references/epic.md`（#1308）
- spec の要件が SKILL.md の節を名指ししていて、節を references に移したあと古くなっている件（#1241）。たとえば「1 ループは W→R1→W→G の順で回る」の周辺で `spec-reviewer.md` の判定役・書式の正本を SKILL.md と書いている文は直さない
- 上の表のテストの書き換え

## Decisions

### 消すか残すかと、正本の置き場所は一覧どおりにする

一覧の判定と「正本と根拠」列をそのまま使う。例外は次の「他のテストが固定している文は残す」で決まる C5 と C7 だけ。

### 他のテストが固定している文は残し、固定されていない重複だけを参照に置き換える

上の表のテストを書き換えないので、固定された文は SKILL.md に残す。そのうえで、固定されていない部分（言い換え・理由の重複・細目）だけを削り、正本への参照に置き換える。項目ごとの結果:

| 項目 | SKILL.md（と handover.md）でどうするか |
|---|---|
| B1 | (3) の「(3a) の return に PR 番号と仕様宣言のコメント URL が既に揃っていれば…(4) へ進む」の 2 行を消す。「自分が (3a) を指示したか (3b) を指示したかで決め、工程名の文字列照合では決めない」は残す |
| B2 | 「モデル」節の 1 文目から「実行戦略の分岐はもう無く、」を消す |
| C1 | 前提の表の Agent ツールの行から remote 隔離の禁止と理由を外し、「隔離の決まりは『worktree の用意』」の参照にする。「worktree の用意」の本文はそのまま（develop-roles.bats が固定する文はここにある） |
| C2 | 入口 0 の 2 つの箇条（受け入れ条件は PR 本文・`Closes` 等を書かない）を 1 文の参照にまとめ、正本を `worker/spec.md`「記録先の用意」とする。参照の文には中身の名前（受け入れ条件を PR 本文に書く・`Closes #N` / `Fixes #N` / `Refs #N` を書かない）を残す（読み手が参照先を開かずに何の規則かが分かるように。develop-skill.bats の入口 0 の検査もこの名前で通る） |
| C3 | 「Role profile の選択」の 1 段落目から margin の式と構成の選び方を外し、正本 `references/codex-develop.md`「起動と role 解決」への参照にする。残すのは、記録の義務（adapter が返す構成〔`claude-write-codex-review`・`codex-standard`・Claude 既定構成のどれか〕・reason・両 provider の margin / fetched_at・代表 Codex account を開始コメントと dispatch 記録に残す、欠測は `missing`）と、開始コメントに残す `実行モード:`・`チャンネルの返事の確認:` の行 |
| C4 | 「Role profile の選択」の最後の段落を、正本 `references/codex-develop.md`「本体が行う操作」への参照 1 文と、「以下の spawn / SendMessage 表記は profile 利用時にこの規則を適用した provider 操作を意味する」の 1 文にする。参照の文には test_codex_develop.py が固定する語（`FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` の上限の再確認、SendMessage しない、工程完了か停止確認、requested tuple を変えない、fresh thread）を中身の名前として残す |
| C5 | 正本は「Role profile の選択」節の段落のままにする（一覧は (4) を正本としたが、develop-adapter-review-routing.bats がこの節の全文を固定している）。(4) の起動指示の行からは、その節と重なる括弧書きのうち固定されていない「Codex の G では request の instructions にも」を外し、「理由と書き方の細目は『Role profile の選択』節」の参照にする。(4) の「常に `レビュー経路: adapter`」「`レビュー経路: 従来` は書かない」は固定されているので残す |
| C6 | `handover.md` の「保留で止まるときの引き継ぎ」節に、会話で受けた返事の日時を `owner-reply-check.sh` で取る手順（MATCH: 行の timestamp・複数出たとき・出ないとき・終了コード 1・2）を太字の見出し付きの段落として 1 か所置く。SKILL.md の (4) の保留の行と `handover.md` の再開の手順 2 は、その段落を名前で指す。保留の行の「リスク許容を会話で受けたら主に PR へのコメントを求めず」「エピックの子が親経由で」「『親から届いた返事』」と、手順 2 の `CLAUDE_CODE_SESSION_ID` は残す |
| C7 | (2) の文面は変えない（一覧は「まとめる」としたが、#1222 で SKILL.md から `fix-check.md` に移したとき、コンパクト後も手元に残るよう (2) に要約を意図して残しており、spec-decision-and-review.bats と develop-skill.bats がその要約の語を固定している。今の (2) は Read の指示と固定された語でほぼできていて、削れる重複が残っていない） |
| C8 | 「モデル」節の残量モードの段落を、2 つのモードの名前と「効果は `references/decision-criteria.md` の残量モードと共有枠モードの表が正本で、ここに再掲しない」の 1 文にする。spec の「役割のモデルは事前分類と残量モードで決める」を同じ形に直す |
| C9 | 「モデル」節の昇格トリップワイヤーの段落を、SKILL.md の中の 1 か所の参照にする。残すのは、発火の条件（同じテストが 2 連続で落ちた・同じ箇所を 2 回書き直した）・決める役と実行役のどちらか一方だけを上げる（両方同時に上げない）・判断側なら `dev-workflow:decider`、実行側なら W を `opus`・ラダーの正本は `templates/escalation-tripwires.md`。判断側と実行側の言い換えと `opus` → `fable` の段は正本に任せる。(4) の failed は「どちらを上げるかは『モデル』節の昇格トリップワイヤーの段落」の参照にする。コンテキスト上限と規模超過の文はこの項目の外なので残す |
| C10 | W の上限が `opus` であることの正本は「モデル」節の表の W の行（`agent-model-guard.sh` の拒否を含む）。(1) の spawn の行・(4) の failed・昇格トリップワイヤーの段落から「W の上限は opus」「W を fable にはしない」を外し、(1) は「model は『モデル』節の表の W の行」の参照にする（事前分類の表 `references/pre-classification.md` の「1 周目」列を指す部分は spec「事前分類を参照する箇所」の MUST なので残す）。表の下の、上限を `opus` にした理由の段落はそのまま |
| C11 | 「実行モード」節の unmanned の分割の段落を、正本 `worker/spec.md`「分割判定」への参照 1 文にする。spec「実行モードと unmanned の責務分割」の MUST と develop-skill.bats が見る語（子 issue・`blocked_by`・サイクルを終える）は文に残す。「Discord で質問し」の文は `worker/spec.md` の同じ節にあるので外す |

### develop-skill.bats の直し方

- B1: 「loop: main routes stage 3 by what it instructed…」の 2 本目の grep（揃っていれば (3b) を指示せず）を外し、その文が無いことを確かめる否定の検査に置き換える。1 本目（自分が指示した工程で決め、文字列照合で決めない）は残す
- C8: 「model: reserve only for automatic runs…」と「model: shared budget mode sets the floor…」を、「モデル」節に `FABLE_BUDGET_MODE`・`SHARED_BUDGET_MODE`・`references/decision-criteria.md` があり、`throttled`・`depleted`・`reserve`・`exhausted` の効果の文が無いことを見る検査にする。効果の文が `decision-criteria.md` にあることも同じテストで見る
- C10: 「loop: G failed raises only the cause side (never W to fable)…」の `W を fable にはしない` の grep を、failed の行が「モデル」節を指していることの検査に置き換える
- C2・C6・C9・C11 は既存の検査がそのまま通る形にし、参照先を指していることの検査を足す（C2 は入口 0 が `worker/spec.md`「記録先の用意」を指す、C6 は SKILL.md の保留の行と handover.md の手順 2 が新しい段落の名前を指し、`MATCH: が複数出たら` の文が handover.md に 1 か所だけある）

## Risks / Trade-offs

- [C5・C7 は一覧の判定どおりにまとめきれず、重複が一部残る] → 残す理由（固定しているテストと、C7 は #1222 の意図）を PR 本文と `changes/1239.md` に書く。固定しているテストを直す作業は、この change の範囲外として本体に返す
- [参照に置き換えた箇所で、本体がコンパクト後に正本を読まずに進む] → 参照の文には何の規則かを中身の名前で書き（communication-style の 1 番目）、読む契機を失わないようにする。手順の判断に要る語（C7 の (2) のような）は消さない
- [openspec は MODIFIED でシナリオを減らせないため、本 spec のシナリオ「旧世代の W が (3) を通しで返してきても (3b) を再指示しない」は名前を残したまま、WHEN/THEN だけを B1 のあとの振る舞い（自分が指示した工程で決め、(3a) の return の中身で (3b) を飛ばす分岐は書かれていない）に書き直す。名前と中身が食い違う] → 名前の直しは #1312 で行う（要件を分け直して ADDED し直す案は、要件の説明文が 500 字の上限を大きく超えるので、この change では取らない）
- [B1 を消したあと、手順入りの古い `worker.md` を持つキャッシュが残る環境で W が (3) を通しで返す] → `worker.md` が索引になったのは #556（PR #610）で、それより前のキャッシュから W が起こされることはプラグインの更新で無くなっている。仮に起きても、本体は自分が (3b) を指示していないので (3b) を指示し、W は既にある PR と仕様宣言を見つけることになる（PR の二重作成は `gh pr create` が同じブランチの PR があると失敗するので起きない）

## Migration Plan

文書とテストの変更だけなので移行の手順は無い。戻すときはこの PR を revert する。
