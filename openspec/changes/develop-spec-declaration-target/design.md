## Context

develop スキルは 3 種のコメントを使う。仕様化判断（W が投稿）と仕様レビュー結果（R1 が投稿）は「記録先」（issue。無ければ Draft PR 自身）に置き、pr-review-gate 手順 5 が PR 本文の `Closes #N` から記録先を解決して照合する。仕様宣言（W が (3) の終わりに投稿）は `対象 HEAD:` 規約に乗るため PR のコメントに置き、ゲートは `issues/<PR番号>/comments` で 3 見出し（リスク宣言・仕様宣言・動作確認）を照合する。この分離は worker.md と pr-review-gate SKILL.md には正しく書かれているが、develop の SKILL.md「入口 0」と openspec spec の同文が 3 種をまとめて「記録先」に置くと書いており、記録先が issue のとき仕様宣言の投稿先が食い違う。

## Goals / Non-Goals

**Goals:**
- SKILL.md 入口 0・openspec spec・develop-skill.bats の 3 点を、worker.md / pr-review-gate の実際の契約（仕様宣言は常に PR コメント）に合わせる
- 同じ食い違いが再発したときにテストで検出できるようにする（記録先に置くものの列挙に仕様宣言が混ざったら落ちる）

**Non-Goals:**
- pr-review-gate の照合ロジックや `対象 HEAD:` 規約の変更（並行 PR #211 の範囲。本 change ではファイルにも触れない）
- worker.md / spec-reviewer.md / gate-runner.md の変更（現状で正しい。同じ食い違いは無いことを grep で確認済み）
- 仕様宣言を記録先（issue）にも複製する案の採用（下記 Decisions）

## Decisions

- **仕様宣言の置き場は PR コメントのみ（issue に複製しない）**: ゲートが照合するのは PR コメントだけであり、issue に複製すると `対象 HEAD:` の SHA が古くなった写しが issue に残って照合されない情報が増える。issue #212 の「直し方」も分離を指示している。代替案「issue にも置く」は採らない
- **spec 側は MODIFIED Requirement で全文を持ち替える**: openspec の archive が delta を main spec に同期する契約のため、SHALL 文 1 文の修正でも Requirement ブロック全体を MODIFIED に載せる（部分だけ載せると archive 時に他の文が落ちる）。分離を検証する Scenario を 1 つ追加する
- **bats は肯定＋否定の 2 面でアサートする**: 「仕様宣言を含む行に `PR コメント` がある」（肯定）と「`記録先のコメントに置く` を含む行に仕様宣言が無い」（否定）。肯定だけだと従来文（記録先に置く）でも `PR` の語が節内に紛れて偽合格しうるため、否定側で従来文を確実に落とす。SKILL.md 側は記録先に置くものと PR コメントに置くものを別の箇条書き行に分け、行単位の grep で判定できる形にする
- **バージョンは `2.0.2` を事前割当**: `2.0.1` は並行 PR #211 用。`plugin.json` と `marketplace.json` の両方を上げる（`~/.claude/plugins/cache/` がバージョン単位キャッシュのため、上げないと他プロジェクトに反映されない）

## Risks / Trade-offs

- [SKILL.md の文言変更で他の bats アサーション（入口 0 節の `仕様化判断: する|しない` / `仕様レビュー: APPROVE|REQUEST_CHANGES` の grep）が落ちる] → 該当の固定文字列は残したまま行を分けるだけにする。`scripts/test.sh` 全件で確認する
- [並行 PR #211 と version 行が衝突する] → 番号は事前割当済み（#211 = 2.0.1 → #212 = 2.0.2）で、衝突は本体がマージ時に解消する。本 change では番号を変えない
