## Context

PreModelSwitch hook の入出力は公式ドキュメント（https://code.claude.com/docs/en/hooks の PreModelSwitch）で確かめた。

- 2.1.251 以降。`/model <名前>`・モデルの選択画面・`/config` の Model 設定・fast mode の切替・Agent SDK や Remote Control からの `set_model` で走る。Claude Code 自身による切替（自動フォールバック、resume 時の復元）では走らない
- 入力は共通項目（`session_id`・`transcript_path`・`cwd`・`hook_event_name`）に加えて次を持つ

  | 項目 | 型 | 意味 |
  |---|---|---|
  | `from_model` / `to_model` | 文字列 | 切替元 / 切替先のモデル ID |
  | `requested_model` | 文字列か `null` | 依頼で指定された名前 |
  | `source` | 文字列 | `command` / `picker` / `sdk` |
  | `context_tokens` | 数値 | 次のリクエストが送り直すトークン数。最初の応答の前は `0` |
  | `prompt_cache_warm` | 真偽値 | 今のモデルのキャッシュがまだ有効そうか（＝切り替えると捨てることになるか） |
  | `cache_ttl` | 文字列 | `5m` か `1h` |
  | `estimated_cache_write_usd` | 数値 | `context_tokens` を切替先のキャッシュに書く推定費用（USD）。次の応答の費用は含まない |
  | `pricing` | 文字列 | 推定に使った単価。`configured`（組織の設定単価）/ `catalog`（定価）/ `default`（単価不明で既定値を仮定） |

- 出力: `{"systemMessage": "…"}` を返して exit 0 にすれば、decision に関係なくユーザーに表示される（ドキュメントが費用表示の hook の形として明記）
- 切替が止まる条件: exit 2、トップレベルの `decision: "block"`、`permissionDecision: "deny"`、**タイムアウト**（既定 30 秒。PreToolUse と逆で、時間切れは切替を止める）。0 と 2 以外の終了コードで JSON を出さなければ止まらない
- `permissionDecision: "allow"` を返すと、キャッシュが有効なときに本体が出す確認画面が飛ばされる
- 使える hook の種類は `command`・`http`・`mcp_tool` だけ。`additionalContext` は受け付けない
- **未確認**: `systemMessage` が本体の確認画面の前に出るのか後に出るのか、画面上でどう見えるかは、ドキュメントに書かれていない。どちらでも成り立つよう、この hook は表示だけを担い、確認画面の有無や順序に依存する文言（「続けますか」など）を書かない
- **未確認**: 2.1.251 より前の Claude Code が、hooks.json の知らないイベント名（`PreModelSwitch`）をどう扱うか（無視するか、プラグインの読み込みで警告やエラーになるか）は確かめていない

既存の hook スクリプト（`team-mode-warning.sh` など）は bash から `python3` を呼んで JSON を組み、失敗しても `exit 0` で終える形に揃っている。

## Goals / Non-Goals

**Goals:**
- モデル切替のたびに、読み直すトークン数と推定費用をユーザーに見せる
- この hook が原因で切替が止まることを無くす

**Non-Goals:**
- 切替を止める・確認を求める（issue #714 が「止めはしない」としている）
- 本体の確認画面を飛ばす（`permissionDecision: "allow"` を返さない）
- 円換算（為替を取りに行くと外部通信になる。statusline の為替キャッシュは別プラグインの内部ファイルなので読まない）
- effort の変更や 5 分以上の放置でキャッシュが切れることの表示（PreModelSwitch の対象外）
- PostModelSwitch での記録、cost-ledger への記録（issue の備考で別検討）

## Decisions

### 1. dev-workflow プラグインの hooks.json に matcher なしで足す

`"PreModelSwitch": [{"hooks": [{"type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/model-switch-recache-notice.sh\""}]}]`。

理由: 置き場所は issue の指定（dev-workflow の `hooks/hooks.json`）。費用の表示は切替先のモデルによらず要るので matcher を付けない。

### 2. `timeout` は指定しない（既定の 30 秒のまま）

理由: この event では時間切れが切替を止める。短い `timeout` を付けると、負荷の高い瞬間に止まる確率を上げるだけになる。スクリプトは stdin を読んで JSON を 1 つ書くだけで、待つものが無い。

採らなかった案: `timeout: 5` を付ける。万一固まったときの待ち時間は短くなるが、固まった時点で切替は止まるので結果は同じで、正常時に止まる可能性だけが増える。

### 3. 返すのは `systemMessage` だけ

標準出力は `{"systemMessage": "<1 文>"}` の 1 行で、キーは `systemMessage` の 1 つだけにする。`decision`・`hookSpecificOutput`・`permissionDecision`・`continue`・`suppressOutput` を返さない。

理由: 受け入れ条件が「`systemMessage` を返し、`decision` を返さない」。`permissionDecision` を返さないのは、`allow` が本体の確認画面を飛ばし、`ask` が対話以外の経路（`-p`・`/config`・`set_model`）で拒否扱いになるため。この hook は表示だけを足し、切替の可否は本体の既定の動きに任せる。

### 4. 文言はトークン数と推定費用の両方を出し、片方が無ければある方だけ出す

基本形:

```
モデル切替（claude-sonnet-5 → claude-opus-5）: 会話の約 182,340 トークンを切替先のモデルで読み直します。キャッシュ書き込みの推定費用は $1.14（定価）。今のモデルのキャッシュはまだ有効で、切り替えると使えなくなります。
```

| 部分 | 出す条件 | 表記 |
|---|---|---|
| `（<from> → <to>）` | `from_model` と `to_model` がどちらも空でない文字列 | 制御文字を除いてそのまま。条件を満たさなければ括弧ごと省く |
| トークン数の文 | `context_tokens` が 0 より大きい有限の数値（真偽値は数値とみなさない） | 整数に丸めて 3 桁区切り（`182,340`） |
| 推定費用の文 | `estimated_cache_write_usd` が 0 以上の有限の数値（真偽値は数値とみなさない） | 小数 2 桁の `$1.14`。0 より大きく 0.01 未満は `$0.01 未満` |
| 単価の注記 `（…）` | `pricing` が下の 3 値のどれか | `catalog` →「定価」、`configured` →「組織の設定単価」、`default` →「単価が不明なため既定の単価で計算」。それ以外は括弧ごと省く |
| キャッシュが有効だという文 | `prompt_cache_warm` が `true` | 上の基本形の最後の文 |

理由: issue の本文は「再キャッシュの推定トークン」、タイトルは「再キャッシュ費用」で、入力には両方ある。トークン数だけでは費用の大きさが分からず、費用だけでは何に払うのかが分からないので両方出す。トークン数を `182k` のように丸めない理由は、入力の値をそのまま見せたほうが検算でき、1 文に収まる長さだから。`pricing` を添えるのは、`default` のとき（切替先の単価が不明）に金額の信頼度が下がることを伝えるため。

### 5. 出さない条件

次のどれかに当たれば、標準出力に何も書かず exit 0 にする。

| 条件 | 理由 |
|---|---|
| `prompt_cache_warm` が `false` | 捨てるキャッシュが無い。キャッシュが切れているなら、切り替えなくても次のリクエストで読み直しが起きるので、この費用は切替が原因ではない |
| `context_tokens` が `0` | 最初の応答の前で、読み直すものが無い |
| トークン数の文も推定費用の文も出せない。または、トークン数の文が出せず推定費用が `0` | 伝える数字が無い |
| `hook_event_name` が `PreModelSwitch` でない（キー無しを含む） | 別のイベントに誤って配線されたときに、意味の通らない文を出さない（`subagent-start-context.sh` が `agent_type` を自分でも照合しているのと同じ考え方） |
| stdin が空・JSON として読めない・トップレベルがオブジェクトでない | 判断の材料が無い |
| `python3` が無い・スクリプトの中で例外が起きた | 同上 |

`prompt_cache_warm` がキー無しや真偽値でないときは「出さない条件」に入れず、キャッシュが有効だという文を省いて残りを出す。

理由: 明示的に `false` のときだけ黙る。項目が将来消えたり名前が変わったりしたときに、表示ごと黙って消えるのを避ける。

### 6. どの経路でも exit 0、標準エラーは空、外部には触らない

スクリプトは stdin だけを読み、ネットワークアクセスもファイルの読み書きもしない（`transcript_path` を開かない）。終了コードは常に 0。標準エラーには何も書かない。payload は環境変数や引数に載せず stdin のまま `python3` に渡す。

理由: exit 2 とタイムアウトは切替を止める。0 と 2 以外の終了コードは止めないが標準エラーが画面に出るので、失敗時は何も見せない。外部通信をしなければ待ちが発生しない。

### 7. 実装は bash から `python3` を呼ぶ既存の形に揃える

理由: dev-workflow の他の hook と同じ形で、JSON の組み立てと数値の型判定（真偽値を数値とみなさない、NaN・無限大を弾く）を `python3` に任せられる。`python3` が無ければ `|| true` と `exit 0` で無出力になる。

## Risks / Trade-offs

- [`systemMessage` が確認画面の前後どちらに出るか未確認] → 文言を順序に依存させない（Context）。実際の見え方は実機の画面で確かめる（tasks。W は画面で確認せず、return の `画面確認:` 行で本体に伝える）
- [2.1.251 より前の Claude Code で、知らないイベント名を持つ hooks.json がどう扱われるか未確認] → 実装の段で `claude plugin validate`（手元は 2.1.294）を通す。古い版での挙動は確かめる手段が手元に無いので、変更の記録に「PreModelSwitch は 2.1.251 以降」と書く。古い版でプラグインの読み込みが壊れるという報告が出たら、このエントリを外すだけで戻せる
- [`estimated_cache_write_usd` は推定で、サーバー側が全体を書き直さないこともある（ドキュメント）] → 文言を「推定費用」とする
- [`sdk` 経路（Agent SDK・Remote Control）では `systemMessage` が画面ではなくメッセージの流れに届く] → 止めないので害は無い。表示先の違いは扱わない
- [hooks.json は自己統治物件] → PR 本文で主の承認を求める
