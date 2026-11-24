# Design

## Context

動機と分割の根拠は proposal の Why / Impact を参照する。change 1 の `resolve_thresholds(model_id, environ)` は 4 指標をまとめて返すが、環境変数 mapping を明示でき、import API は出力しない。両スクリプトはすでに Python で対象ログを読んでいるため、モデル取得に別のログ探索や外部照会は要らない。

- `subagent-context.sh` は選択したログを全行走査し、エラーレコードと全 usage が 0 のレコードを除外した最後の計測値を使う。
- `context-tripwire.sh` は親の `transcript_path` から対象サブエージェントのログを導出し、末尾 256KB の最後の usage を使う。CLI のエラー除外と揃える変更は今回しない。
- CLI は従来 `--cap` > env > 定数で 0 も受理する。hook は空白を除いた正数だけを受理し、0 や不正な env では fail-open。共通 API は空白を未設定、ASCII 非負整数と 0 を有効とする。P1-F1 の接続時の差はこの層で扱う。

## Goals / Non-Goals

**Goals:** 既存の計測値を変えず、同じ計測レコードのモデルと共通の値・診断を結び付ける。呼出元の優先順位と fail-open を明確にする。

**Non-Goals:** モデルの実在確認・自動推定、エラー時の計測方法の統一、新しい通知状態ファイル、別プロセスのモデル照会、表や値の変更。累計上限・利用手順の注記の更新は proposal の分担どおり change 3。

## Decisions

### 1. モデルは計測に採用したレコードと対にする

各スクリプトの既存の走査で、採用した usage と同じ assistant の `message.model` を同時に取り出す。非空文字列ならそのまま渡す（別名・未知 ID も無加工）。欠落・非文字列・空白だけは `None`。ID の前後の空白を除いて既知に合わせる処理もしない。`subagent-context.sh` がエラーとして読み飛ばす末尾レコードのモデルを採用しない。hook は現行の末尾走査で選んだ usage のレコードをそのまま使い、モデルが欠けても前のレコードへ探し戻らない。

親ログ・payload のモデル・metadata のモデル・`AGENT_MODEL`・`ANTHROPIC_MODEL` 等の環境・spawn の別名はモデル入力に使わない。計測対象とモデルの対応を一意にするためである。モデルが不明でも測定できる usage があれば失敗にせず、共通 API の fallback と再検証診断を使う。計測自体ができないときの従来エラー・無出力の経路では共通処理を呼ぶ必要はない。

### 2. import API を同じ Python プロセスから呼ぶ

スクリプト自身の実体を基準に同梱 `scripts/token_thresholds.py` をロードする。cwd や Python の環境変数を探索元にせず、hook の `python3 -I` とメインスレッドの早期終了を保つ。実行時に `.pyc` 等のファイルを書き込まない。CLI を subprocess で起動する案は起動回数・stdout 混入・実行コストが増えるため採らない。2 本の計測実装の共通化も既存仕様どおり行わない。

### 3. 呼出元に関係する上書きだけを渡す

API は 4 指標の env を検査するので、`environ` に渡すのは下表のものだけにする。不正な累計 env が文脈計測まで無効にする結合を避ける。API の表・返り値の構造は変更しない。

| 呼出元 | 利用する値 | 明示 mapping に含める env / 優先順位 |
|---|---|---|
| subagent-context | `context_cap` | `--cap` 指定時はその文字列で `DEV_WORKFLOW_CONTEXT_CAP` を置き換える。未指定なら現在の同 env だけを渡す。`--cap` > env > モデル行 / fallback |
| context-tripwire | `context_cap`, `context_hard_cap` | 現在の `DEV_WORKFLOW_CONTEXT_CAP`, `DEV_WORKFLOW_CONTEXT_HARD_CAP` だけを渡す。各 env > モデル行 / fallback |

CLI の `--cap` の引数検証は既存どおり ASCII 数字列のみ（`0` 可、前後空白は不可）。有効な `--cap` は不正な env をも遮蔽する。env は共通契約へ合わせ、未設定・空文字・空白だけを未設定とし、前後空白付き ASCII 非負整数を許す。従来 CLI が空白 env を拒否していた点を変えるが、共通 API と別の解釈を増やさないためにこの差は解消する。

CLI は解決値 0 を有効とし、`ctx > cap` で判定する。hook は解決成功後も **cap と hard の両方が正数** であることを要求し、どちらかが 0 なら両イベントとも判定を行わず fail-open（stdout 空、exit 0）。`hard <= cap` の場合は従来どおり PreToolUse だけ fail-open、PostToolUse は cap 超を通知する。API の 0 許容・大小関係を判定しない契約は変えず、hook の既存の正数条件を呼出側で保持する。

### 4. 診断の通知先は stderr、手順はプラグイン基準の絶対パス

成功した解決結果の `unknown_model` と、利用する指標に対する `revalidation_required` を各呼出しの stderr に出す。CLI は `context_cap`、hook は `context_cap` / `context_hard_cap` の診断だけを対象とし、累計・権限の再検証通知はここでは出さない。上書きがあっても通知を消さず、状態保存や一度だけの通知への変更もしない。

再検証文には要求モデル（不明なら不明）、根拠モデル、対象指標と手順を残す。API の repo 相対 `guide` をそのまま表示せず、ロードしたプラグインの `skills/develop/references/token-thresholds.md` の絶対パスに置き換えて人向け文を整える。ソース checkout と `~/.claude/plugins/cache/...` のように `plugins/dev-workflow` が無い配布先のどちらでも、実在する同梱手順を開ける。P2-F2 は呼出元の表示だけで解決し、共通 API は変えない。

stdout は従来の測定 JSON / hook JSON に限定する。hook の cap 超の `additionalContext`、hard 超の `permissionDecision: deny` と理由を変更せず、診断を追加の JSON 行や生テキストとして混ぜない。未知モデルが cap 内でも stderr では知らせ、stdout は空のまま。PreToolUse に許可決定を追加せず、診断だけで deny しない。

### 5. 解決の失敗は計測不能として既存の fail-open に接続する

`invalid_table` / `invalid_override` は握り潰さず、呼出元名・エラーコード・理由を stderr に出す。CLI は `error` を持つ 1 行 JSON を stdout に出して exit 1、hook は stdout 空・exit 0 としてツール実行を止めない。共通部品の欠損・ロード失敗も理由付き `resolver_unavailable` として同様に扱う。CLI の error は既存利用者が文字列として扱える形を保つ。hook の正数条件違反は `invalid_hook_threshold` として理由を出し同じ fail-open にする。表が壊れているときに隠れた定数を使ったり、env だけで成功したことにしたりしない。未知 ID への正規の fallback は成功であり、この失敗経路とは区別する。

これまでの「不正 env では無音」は stdout の契約として維持し、設定不良を黙殺しないため stderr にだけ診断を加える。対象が無い・usage が無い・全解除・メインスレッドなどの既存早期終了は引き続き両出力とも無音。`PY_SRC` が読めない場合の既存 exit 1 まで一律 fail-open へ変える作業はしない。

### 6. 正本の接続状況だけを今回更新する

`decision-criteria.md` の未配線期間の説明を、文脈の 2 スクリプトが共通処理を利用し、累計 `pr-token-budget.sh` は未配線、という事実へ変更する。同じ節でモデル入力・優先順位・0 の差・stderr と失敗時の扱いを説明し、現在の表の値は初期モデル / fallback の値であることを示す。停止の意味・手渡し権限・return-declaration の本文は変えない。P3-F1 の受け持ちは補正コメントどおりとし、利用手順の古い注記の解消を本 change の完了条件へ広げない。

## Risks / Trade-offs

- 未知モデルでは毎ツール呼出しに診断が出る → 黙って継続しない契約を優先。既知モデルに余計な診断が出ないことを確認する。モデル本人への cap 超通知は既存の additionalContext のまま。
- hook と CLI のエラーレコードの選別が異なる → 各自の採用 usage とモデルを対にして、今回計測値を変えない。末尾にモデルが無い場合も過去の ID を流用しない。
- API の import と表読み込みのコストが加わる → Python を追加起動せず、既存の 5MB / 100ms、末尾読み取り、早期終了のテストを維持する。
- 表の破損時は判定が効かない → 既存 hook の可用性を優先して fail-open、stderr に理由を残す。定数への二重 fallback は作らない。

## Migration Plan

5 ファイルの実装と 2 Bats の回帰確認後に導入する。テストは一時 plugin 配置へスクリプト・共通処理・表・手順をコピーし、同梱のモデル行と fallback を異なる値にした fixture で実際の接続を検査する（本物の表は変えない）。壊れた表・共通処理の欠損も同じコピーで模擬する。標準出力と標準エラーは別々に捕捉する。切り戻しはこの 5 ファイルの変更を戻せば change 1 の未接続状態へ戻る。仕様レビュー前には実装に進まない。
