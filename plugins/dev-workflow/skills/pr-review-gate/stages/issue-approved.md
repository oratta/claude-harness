# issue で承認済み（手順 3・5）— pr-review-gate

手順 3 で「主のリスク許容が必要」と判定し、3-c の引き継ぎが成り立たず、分類が資格情報への接触・安全ゲートの弱体化・エージェント権限の拡張に収まるときに読む。手順 5 の確かめ直しも同じこのファイルで行う。

#### issue で承認済み

資格情報への接触・安全ゲートの弱体化・エージェント権限の拡張の 3 分類だけ。外部公開面の変化・データ喪失・課金/法務・プロダクトのユーザーに及ぶ影響は issue に書いてあっても主に聞く。4 分類・引用無しが 1 つでもあれば宣言全体を手順6で主に聞く。

無人運用（loop-dev-agent）と、主に事後報告を届ける先が無い経路（会話も G return も無い）は issue で承認済みを当てない。手順6で保留。

1. 目的を分類ごとに引用（背景は不可）
2. 会話の起票の承認か `/develop <番号>` を `owner-reply-check.sh` 終了コード 0 で確認。 `lastEditedAt`（`gh api graphql -f query='{repository(owner:"<o>",name:"<r>"){issue(number:<N>){createdAt lastEditedAt}}}'`）が null か承認 timestamp 前
3. 実装中に発覚した影響ではない（`issue 記載済み`）

`bash <plugin>/scripts/owner-reply-check.sh <セッション ID> <原文>`:

- **`/develop <番号>`**: ID=`$CLAUDE_CODE_SESSION_ID`（G は本体）、原文= `<command-args><番号>` か `<command-args>#<番号>`。exit 0、`MATCH:` 全文に `<command-name>/dev-workflow:develop</command-name>` か `/develop` があり、`<command-args>` の直後が `<番号>` か `#<番号>`、後続が空白か `</command-args>`
- **起票の承認**: URL 初出前の主の発言のうち、最後のものが候補。S は `grep -l '<URL>' "${OWNER_REPLY_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}"/*/*.jsonl` （subagents/ 除外）。
  - 初出行=`gh issue create` または `gh api -X POST repos/<R>/issues` の tool_result だけ。`gh issue view`・主の発言・`/develop` の引数は除外
  - 候補が 0 件なら手順6で主に聞く
  - `<command-name>` を含む行は使わない。 `owner-reply-check.sh <S のセッション ID> <原文>` で exit 0・同 timestamp の `MATCH:` 全文に承認の意思
  - 返事が答えた起票の提案を会話から特定し、issue の目的・引用した各効果の全部を照合。特定できない・不足なら証拠にせず手順6で主に聞く（不足条件も）
    - 負例: README の誤字修正の OK 後の安全ゲートを撤去する issue は起票の承認の証拠にならない
    - 正例: 「安全ゲート X を撤去する issue を起票しますか」への OK が目的・引用した効果を含むなら起票の承認の証拠になる
  - エピックの起票の承認: 同じセッションの子で目的・効果が承認された提案の範囲内なら可。範囲外なら証拠にせず手順6。別のセッションは証拠にならない

当てない issue・証拠: `agent-proposed`、主の承認の記録が無い起票は不可。`EPIC_DISPATCH_PARENT_EPIC` 有りの `/develop`、`--unmanned` 入りの `/develop`、保留や却下は数えない。

宣言の本文は書き換えない。追記して4・5へ:

```
issue で承認済み — issue #<N> の目的: 「<本文からの引用>」
承認の証拠: <起票の承認 | /develop の打ち込み>（セッション <セッション ID> / <日時>）原文: <原文>
真正性確認: 済 — 確認者 <エージェント名> / <日時>（owner-reply-check.sh 終了コード 0）
```

複数は `issue で承認済み — <分類>: issue #<N> の目的: 「…」` で列挙。`主の回答: 許容` では始めない（引き継ぎ元不可）。不成立は手順6。

#### 手順 5 の確かめ直し

issue で承認済みの宣言は、上の全条件を確かめ直す（`owner-reply-check.sh`・`agent-proposed`・`lastEditedAt`・`EPIC_DISPATCH_PARENT_EPIC`・`--unmanned`・事後報告を届ける先・返事が答えた起票の提案に目的と引用した各効果、子は承認された提案の範囲内）。不成立は手順6（不足条件も）。通れば `確かめ直し: 済 — 確認者 <エージェント名> / <日時>（手順 5）` を追記する。

`真正性確認: 済` の行は足さない（3-c「前の宣言の選び方」）。

無人運用（loop-dev-agent）・主に事後報告を届ける先が無い経路は issue で承認済みを当てない。あっても手順6。

事後報告は 1 回: 宣言コメントの URL・引用・分類（G は return）。後日の不許容は手順6（revert 等）。
