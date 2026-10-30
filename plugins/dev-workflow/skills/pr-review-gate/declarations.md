# 宣言

## 入口

止める指摘無しが前提。

## 前提と理由

- **HEAD SHA**: 仕様宣言等は `対象 HEAD: <40桁フル SHA>` 必須、push 後に再投稿。規約変更は `templates/auto-merge/` と同時。
- **仕様宣言**: auto-merge 対応は別 issue。

### 3. リスク宣言（positive affirmation・必須）

PR 必須（不明は許容必要）:

| 宣言 | 条件 | 後続 |
|---|---|---|
| **リスクなし** | プロダクトのユーザーに及ぶ影響・データ喪失・課金/法務・外部公開面の変化・資格情報への接触・安全ゲートの弱体化・エージェント権限の拡張がいずれも無い | 手順4へ |
| **主のリスク許容が必要** | 1 つ以上（実装中の発覚も含む） | 手順6へ、passed 禁止。issue で承認済みなら手順 4 へ |

コード・設定も対象。

- **資格情報**: 取得・保管・利用・受け渡し変更（時機も）のエージェントへの行動指示（SKILL.md）。不変・秘密無しの説明は除外。
- **安全ゲートの弱体化**: 止め具を外す・緩める・迂回するエージェントへの行動指示。追加・厳しくする変更は当たらない。
- **エージェント権限の拡張**: 権限・外部サービス・書き込み先等を増やすエージェントへの行動指示。

資格情報・安全ゲートの弱体化・エージェント権限の拡張も `needs-approval`（承認済み除く）。

`gh api -X POST repos/$R/issues/$N/comments -F body=@<file>` 。2 行目の `対象 HEAD:` は必須:

```
## リスク宣言
対象 HEAD: <$HEAD_SHA 40桁フル>
リスクなし — この変更でプロダクトのユーザーに及ぶ影響・データ喪失・課金/法務・外部公開面の変化・資格情報への接触・安全ゲートの弱体化・エージェント権限の拡張はいずれも無い。
根拠: <変更範囲が何で、なぜ外部影響が閉じているか。1〜3行>
```

許容必要（論点は1行選択）:

```
## リスク宣言
対象 HEAD: <$HEAD_SHA 40桁フル>
主のリスク許容が必要。

論点なし — 分類に当たったので決まりで主の OK が要る。この変更を入れることで新たに生じるリスクは無い。
論点あり — この変更を入れることで新たに生じるリスク: <誰に何が起きうるか>
- 該当する観点: <7 観点のうち当たったもの>
- 発生条件: <いつ起きるか。論点なしなら「なし」>
- 起きたときの影響範囲と戻し方: <revert 可否・データが戻るか。論点なしなら「なし」>
- 根拠ファイル: <パス>, <パス>
- 検知時点: issue 記載済み / 実装中に発覚
```

論点: `~/.claude/output-styles/readable.md` 節3。

`- 根拠ファイル:` は発生源（論点なしも）。PR 自身の差分は3-c、中身は判定役。

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

#### 3-b. 仕様宣言（positive affirmation・必須）

仕様宣言は別コメントで必ず投稿。判断無しは記録。3 形のどれかちょうど。

`仕様化判断: する`:

```
## 仕様宣言
対象 HEAD: <$HEAD_SHA 40桁フル>
仕様: 更新した — change <change-name>（archive 済み）／仕様レビュー: APPROVE（<issue コメントの URL>）
```

文言合わせ:

```
## 仕様宣言
対象 HEAD: <$HEAD_SHA 40桁フル>
仕様: 更新した — change <change-name>（archive 済み）／仕様レビュー: 省いた（文言合わせ。<仕様化判断のコメントの URL>）
```

最新の仕様化判断のコメントに `^通し方: 文言合わせ$` の行がある PR だけ（develop `references/decision-criteria.md` Step B）。

`仕様化判断: しない`:

```
## 仕様宣言
対象 HEAD: <$HEAD_SHA 40桁フル>
仕様: 変更なし — 理由: <なぜ spec が不要か。規範を持ちうるパス（docs/・.claude/ 等）に触れているなら、それでも規範が変わらない理由>
```

## 出口

- 前 HEAD の直接の `主の回答: 許容`・`真正性確認: 済` は `stages/carryover.md` 3-c、不可・無しなら issue で承認済み、不可なら手順 6。先に当たったほうだけ追記して pass へ。
- `stages/pass.md`。
- W は投稿後 (3b)。
