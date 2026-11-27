# idle compaction の受動的な実機観測（#1388）

これは手順書と収集部品であり、実機起動・設定変更の承認ではない。#1385 の受け入れ項目の正本は [changes/1385.md](../../../changes/1385.md#マージ後の実機確認担当-主-oratta未実施)。設定の適用・live 確認・戻し方は [reply-after-idle.md](reply-after-idle.md#開始時の設定) に従う。disk 設定だけで live の実効値を断定しない。通常の自動 compact と既存の再読み込み hook を維持する。

## 実行時に主が埋める承認欄

空欄がある間は実機セッションを起動しない。推奨値は承認の代わりではない。

| 項目 | 主の記入欄 | 推奨（未承認） |
|---|---|---|
| 承認者・承認記録の位置 | | issue コメント等 |
| 親の起動上限本数 | | 初回 1 本 |
| 子の起動上限本数 | | 初回 1 本 |
| 単発の起動上限本数 | | 初回 1 本 |
| 消費上限と単位（金額/token 等） | | 主が決める。既定値なし |
| 対象 worktree・設定適用先と範囲 | | 専用 worktree。正本の範囲を確認 |
| 停止条件 | | 消費上限・想定外の設定/compact・観測条件の不足 |
| 追加試行の上限本数 | | 0 本。再試行は追加承認 |
| LLM_LOG_DIR の保存先 | | 主が指定する repo 外の場所 |

親・子・単発は逐次実行する。待機中の追加 API リクエストは 0。承認範囲を超える追加起動・再試行・消費は主に戻して判断する。本手順の作成・fixture の成功を実機実施や #1385 の完了扱いにしない。

## 実行者が記録するもの

1. 親・子・単発ごとに Claude Code の版、plugin commit、`/config` 等で確認した実効 idleCompaction と方法を記録する。親は develop 前の on/off、後の on/off、live 反映か再起動かを分ける。子は起動引数の idleCompaction 指定だけを確認する。`ps` 全体・起動引数全体・settings 全体を貼らない。live を確認できなければ unknown とし、disk-only を実効確認済みにしない。
2. 親・子は、その版で idle が有効なら対象となる実際の idle 閾値と出典を確認する。明示設定なら explicit-setting、既定値なら version-default と版を残す。120000 や子の再起動閾値 150000 を流用しない。不明なら null/unknown。
3. 対象 JSONL と、開始時に完結していた行数 S・終了時に完結していた行数 E を外側で記録する。行区間は **S < 行番号 <= E**。時刻はタイムゾーン付き秒精度とし、最後の API リクエスト時刻と確認元を別に記録する。応答時刻・ファイル mtime で代用しない。不明なら null/unknown。ログ回転の探索はしない。別ファイルや切り詰めなら未検証として残す。
4. 実行者が対象セッションの外側で時計を測り、PC を起こしたまま最後の API リクエストから 3600 秒以上待つ。対象へ声をかけない。追加 API リクエストや待機維持リクエストを送らない。スリープ・追加リクエストの有無は実行者が yes/no/unknown で記録し、JSONL から推測しない。通常または手動 compact が混じった idle 試行は未検証。
5. 通常利用で上限近くに達した自動 compact は idle と重ならない **別の行区間** と metadata で記録する。自動か手動かの確認元、hook の案内、続く SKILL 本体の Read による再読み込みを別々に確認する。hook の存在だけでは yes にしない。承認範囲内でできなければ not-performed として未実施を残す。
6. 単発は kind=config で実効値を確認する。60 分待機は不要。親・子の idle と合算しない。

元 JSONL、metadata、一時データ、結果は repo 外に置く。収集 CLI は `LLM_LOG_DIR` が未設定/空なら何も作らず、主に保存先を確認するよう案内して exit 1 とする。cwd の repo と plugin の repo 内への保存は symlink 解決後も拒否する。入力ファイルもこの 2 つの repo 外を指定する。設定先を勝手に決めない。

## CLI と入力例

```sh
python3 <plugin>/scripts/idle-compaction-observation.py \
  --transcript <repo外の対象.jsonl> --metadata <repo外のmetadata.json>
```

`LLM_LOG_DIR` は承認欄で主が指定した外部ディレクトリを環境変数に設定する。CLI に起動・設定変更・API リクエスト機能はない。1 回の入力は 1 セッションの 1 区間。

次は秘密値のない **fixture 用** metadata であり、実機結果ではない。150000 は例の fixture の閾値であって利用版の既定値ではない。実機では測った値に置き換える。

```json
{
  "role": "parent",
  "kind": "idle",
  "version": "2.1.0",
  "plugin_commit": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "effective_idle": "off",
  "config_method": "config",
  "parent_before": "on",
  "parent_after": "off",
  "parent_application": "live",
  "child_idle_argument": "unknown",
  "start_line": 1,
  "end_line": 2,
  "start_time": "2026-11-20T00:00:00Z",
  "end_time": "2026-11-20T01:00:00Z",
  "last_request_time": "2026-11-20T00:00:00Z",
  "last_request_source": "request-log",
  "idle_threshold": 150000,
  "threshold_source": "version-default",
  "sleep": "no",
  "extra_requests": "no",
  "compact_kind": "none",
  "compact_source": "unknown",
  "hook_notice": "not-performed",
  "skill_read": "not-performed"
}
```

この例に対応する fixture JSONL（実機ログに追記しない）:

```jsonl
{"type":"assistant","message":{"usage":{"input_tokens":50000,"cache_creation_input_tokens":50000,"cache_read_input_tokens":50000}}}
{"type":"user","message":{"content":"fixture"}}
```

全項目は次のとおり。自由文のログ貼り付け欄はない。既知項目の不正な型/列挙値は exit 1。未知キーは捨てる。観測不足は補完せず null/unknown/not-performed のまま保存する。

| 項目 | 型・値と意味 |
|---|---|
| role / kind | 必須。parent / child / standalone、および idle / config / normal-compact |
| version / plugin_commit | 版は数字3組（例 2.1.0）、commit は小文字16進40桁。不明は null |
| effective_idle | on / off / unknown。実効値 |
| config_method | config（`/config`）/ live-inspection（実効値の直接確認）/ disk-only / unknown |
| parent_before / parent_after | on / off / unknown。親の develop 前後 |
| parent_application | live / restart / unknown。親の反映方法 |
| child_idle_argument | off / on / absent / unknown。子の idleCompaction 起動指定だけ |
| start_line / end_line | 非負整数または null。完結した行数 S / E |
| start_time / end_time | 開始/終了時刻。`YYYY-MM-DDTHH:MM:SSZ` または `±HH:MM`、不明は null |
| last_request_time | 最後の API リクエスト時刻。同形式または null |
| last_request_source | request-log / external-record / unknown。リクエスト時刻の確認元 |
| idle_threshold | 実際の閾値の token 数（正整数）または null |
| threshold_source | version-default / explicit-setting / unknown。閾値の出典。既定値は version と組にする |
| sleep / extra_requests | yes / no / unknown。スリープ/追加 API リクエストの有無 |
| compact_kind | none / automatic / manual / unknown。区間内の通常/手動 compact の確認 |
| compact_source | session-observation / external-record / unknown。compact 種別の確認元 |
| hook_notice / skill_read | yes / no / unknown / not-performed。案内の作動と、その後の SKILL 本体 Read を分ける |

role/kind 以外は省略時 null または unknown。normal-compact は別入力で kind を変え、重複しない S/E と時刻、compact_kind=automatic、その確認元、hook_notice と skill_read を記入する。未実施なら各確認を not-performed とする。

## 計測値と結果の読み方

CLI は S 行までの prefix を `LLM_LOG_DIR` 内の一時領域へ切り出し、既存 `subagent-context.sh --file` の exit 0/2 の context_tokens だけを採用する。prefix は収集後に消す。開始後の大きな usage で不足を埋めない。計測不能は null。区間内の JSON object の type=system かつ subtype=compact_boundary だけを数え、過去の境界・会話文中の単語・E より後の追記は数えない。未知の正常な type は無視する。不正 JSON、非 object、未完の行、切り詰め、読めない区間は理由付き unverified。

結果は `LLM_LOG_DIR/idle-observation-*.json` の新規ファイル。元ログは変更しない。metadata は実行者申告、context_tokens/boundary_count/elapsed_seconds はその入力に基づく機械計測として分ける。JSON の result と reasons を読む。

- idle: 親/子、版/commit、実効 off の直接確認、確認済み閾値以上の開始時会話量、有効な行位置/時刻、最後のリクエストから3600秒以上、その時刻の確認元、スリープなし、追加リクエストなし、通常/手動 compact 混在なしが揃って初めて、0 件を observed、1 件以上を unexpected-boundary とする。
- config: 版/commit と役割別の実効値を直接確認できれば observed。on/off は metadata に残るため、observed だけで off と読まない。
- normal-compact: 別区間の自動 compact と境界、種別の確認元、hook 案内、その後の Read を確認できれば observed。idle の結果とは合算しない。
- それ以外は unverified。reasons は固定コード（例 context-below-threshold、idle-too-short、effective-off-unconfirmed、invalid-line-range）。欠測・unknown は合格にしない。

exit 0 は unexpected-boundary/unverified を含め **保存成功のみ**。exit 1 は入力の解釈/保存など収集自体の失敗。stdout は保存成功と結果区分、stderr は固定原因のみで、会話本文・tool 入出力・未知キー・依存部品の出力・エラーの入力断片を転記しない。入力したログや申告の真偽を独立に保証しない。実機結果は承認範囲内で主が別途 #1385 に記録する。
