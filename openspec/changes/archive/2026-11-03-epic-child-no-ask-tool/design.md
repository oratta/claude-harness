## Context

エピックの子の止まりは、親の `wait` が子の会話ログから検知し、返事は `epic-dispatch.sh reply` の端末入力で届く。質問ツールの選択肢の画面は入力欄が使えず、声かけも `reply` も送れない。一方 `epic-child-stop.md` は質問ツールで待つことを認めている。

## Decisions

- **読み替えは 1 か所に書く。** develop の SKILL.md・decision-criteria.md・fix-check.md・roles/ には「interactive は AskUserQuestion で聞く」が散らばる。channel と同じく、各文書には書き足さず、`epic-child-stop.md` に「エピックの子では本文で質問してターンを終えると読む」を 1 つ書く。棄却案: 各文書の該当行に子の例外を足す（直すときに片方が漏れる。channel.md が既に同じ理由で退けている）。
- **子の判定は既存の `route`（子の番号なし）が `nested`。** 新しい判定を作らない。
- **選択肢は本文に番号つきで書く。** 主は子のタブで文字で答えても、親のタブで答えて親が `reply --as owner` で届けてもよい。
- 子でないセッションの文面と、channel の読み替え（`channel.md`）には触らない。`tests/develop-channel-mode.bats` の AskUserQuestion の行の検査が通る形を保つ（`epic-child-stop.md` の節内の行は許容される）。新しい文面は AskUserQuestion の語を使うため、同 bats の対象行の判定に合う書き方にする。

- **検査は develop の手順書の全部を対象にする。** 読み替えが 1 か所でも、他の文書に子へ質問ツールを使わせる指示が足されたら落ちるように、新規 bats は SKILL.md・references/*.md・roles/ の `AskUserQuestion` の行を grep し、interactive の条件つきか否定の形だけを許す。既存の `develop-channel-mode.bats` は SKILL.md だけなので補わない。

## Risks

- 読み替えを知らずに他の手順書だけを読んだ子が質問ツールを呼ぶ余地は残る。`epic-child-stop.md` は子が止まる前に読む文書として SKILL.md が案内しており、この残りは許容する（機械的に止める検査は範囲外）。
