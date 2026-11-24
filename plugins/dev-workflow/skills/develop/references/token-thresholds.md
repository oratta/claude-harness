# モデル別トークンしきい値の利用と再検証

根拠付きの既定値は [token-thresholds.json](../../../references/token-thresholds.json) にある。`schema_version: 1` の `models` は固定 ID ごとの行、`fallback` は未知モデル用の行。各行の `context_cap`・`context_hard_cap`・`pr_token_cap`・`epic_child_token_cap` を読み、各レコードの `value` と `decided_models`・`decided_at`・`evidence`・`source` を一緒に扱う。数値の表はここには複製しない。

初期登録の `claude-opus-5-5` / `claude-sonnet-5-5` は、[#1799 の結論](https://github.com/oratta/claude-harness/issues/1799#issuecomment-7120074012)の測定対象ラベル `opus-5-5` / `sonnet-5-5` に対応する。日付付き ID を推測して足したものではない。調査役が sonnet だったことと測定対象は別である。累計の標本は Claude サブエージェントと Codex の混合で、固定 Codex ID 別の内訳は無いため Codex を測定済みモデルとして登録していない。根拠モデル集合は、全指標をそれぞれのモデルで単独検証した意味ではない。品質の最適値は未測定である。

この部品は `subagent-context.sh`・`context-tripwire.sh`・`pr-token-budget.sh` へ**未配線**。この change だけでは既存 hook に通知は出ず、既存の停止・権限・fail-open は変わらない。後続 change が API と診断を各経路へ接続する。

## CLI と import API

repo ルートから次を実行する（repo 外ではスクリプトの絶対パスを使う）。表はスクリプトの位置から読むので cwd に依存しない。

```sh
python3 plugins/dev-workflow/scripts/token_thresholds.py --model claude-opus-5-5
python3 plugins/dev-workflow/scripts/token_thresholds.py --model claude-opus-future
python3 plugins/dev-workflow/scripts/token_thresholds.py
DEV_WORKFLOW_PR_TOKEN_CAP=45000000 python3 plugins/dev-workflow/scripts/token_thresholds.py --model claude-opus-future
```

成功時は stdout に1行の JSON、診断があれば stderr に人向け文を出して exit 0。未知モデルも成功で、`unknown_model` と `revalidation_required` が出る。GitHub への投稿や状態ファイルへの保存、通知の抑制はしない。呼ぶたびに診断を返す。

Python からは `scripts` ディレクトリを import パスに置き、`from token_thresholds import resolve_thresholds`、`resolve_thresholds(model_id, environ=None)` で同じ結果を得る。API 自体は stdout/stderr に出力しない。`environ=None` は現在の環境、mapping を渡したときはその mapping だけを使う。実効固定 ID は呼出元が明示する。親のモデルや `AGENT_MODEL`、別名から推測しない。

結果の読み方:

- `requested_model` は要求 ID（省略は null）、`matched_model` は完全一致した ID（未知は null）。空文字、未登録 ID、`opus` / `sonnet` のような可変別名は一致しない。
- `fallback_used` は共通既定値を選んだか、`revalidation_required` は選んだ根拠のモデル集合に使用 ID が含まれない指標があるか。不明モデルも再検証対象。登録行でも根拠と ID が異なれば通知する。
- `thresholds` の各項目には採用した `value`、`source_kind`（`model` / `fallback` / `environment`）、表の根拠レコード `baseline` がある。上書きでも `baseline` は表の値と根拠を保ち、上書き値を検証済みと扱わない。
- `diagnostics` は `code` と `message` の配列。再検証診断には `requested_model`・`decided_models`・`metric`・`guide`（この手順の repo 相対パス）も含む。fallback は現在値を引き上げないという安全側であって、未知モデルの窓に収まる保証ではない。

`DEV_WORKFLOW_CONTEXT_CAP` / `DEV_WORKFLOW_CONTEXT_HARD_CAP` / `DEV_WORKFLOW_PR_TOKEN_CAP` は対応する指標だけでモデル既定値より優先する。空文字・空白だけは未設定、前後空白を除いた ASCII 非負整数を受け付け、0 も通す。負数・小数・非数値は不正。指標間の大小関係や権限は判定しない。hook 接続時の正数チェックは後続 change の責務。`epic_child_token_cap` 用 env は無く、返すのは親が使える権限の候補値だけであり、`pr_token_cap` へ自動適用しない。呼出元の `--cap` はこの部品の外で引き続き最優先である。この CLI には `--cap` は無い。

不正 env は API で名前と理由付きの `ValueError`（`invalid_override`）、CLI では stdout に `{"error":{"code":"invalid_override","message":"…"}}` と stderr に理由、exit 1。利用可能な `thresholds` は返さない。表の欠損・不正 JSON・schema 不一致・必須指標や根拠の欠落も同じエラー契約で code は `invalid_table`。隠れた第二の定数表へは倒さない。追加フィールドは許容する。共通処理の失敗を既存 hook の拒否へ結び付ける配線は今回行わない。

## 同じ集計を再実行する段取り

今回の実装は再測定を行わず #1799 の結論を採用する。モデルが変わったときや値を更新するときは次の順で行う。原スクリプトの取得・実行自体は、この部品の実装完了条件ではない。

1. 対象期間・実効固定 ID・採用単価と適用日・対象 PR / issue の集合・調査時 HEAD を記録する。基準標本は #1799 の結論が挙げる子38本・エピック5本の一覧で特定し、新しい期間の標本とは分ける。ログの開始日 2026-10-25、欠損する古い子、#1238 の除外理由を記録する。
2. ログの所有者から #1799 の一時スクリプト一式、実行引数・依存バージョン・設定を取得する。hash と起動コマンドも記録する。原スクリプトは repo に無い。取得できなければ再現未完と記録し、「同じ集計を再実行した」とは扱わない。代替集計を黙って同等としたり、品質の最適値を測定済みとしたりしない。
3. `$TMPDIR` または `mktemp -d` で repo 外の作業領域を作る。会話ログは所有者が示す場所から読み、親セッションとサブエージェントを対応付ける。保存する会話ログの派生物・引き継ぐ集計一式の保存先は `LLM_LOG_DIR` で解決し、未設定なら所有者に確認する。個人のパスや生ログを git に入れない。
4. `gh` で記録先コメントを全ページ取得する。停止印・再開判断・スレッド別 Codex 消費と、各 PR の差分・変更後のファイル情報を集め、`cap_comments.json` / `codex.json` / `prfiles.json` を作る。Codex は thread ID ごとの最大値で重複排除する。ログ欠損を0消費として扱わない。
5. 取得した原スクリプトの実行引数を確認し、`collect.py` → `calib.py` → `analyze.py` → `analyze2.py` → `analyze3.py` → `handover.py` → `ctxcap.py` → `analyze4.py` → `analyze5.py` の順で実行する。`units.jsonl` / `children.json` と各集計結果を保存し、基準標本の再現と新モデル標本の比較を分ける。取得前に架空のコマンド引数を決めない。
6. 本体＋Claude サブエージェントの総消費と、上限計測対象の Claude サブエージェント＋Codex の消費を分ける。usage の入力・キャッシュ作成・キャッシュ読み・出力を重複排除し、応答別単価でドル換算する。固定分（起動文脈×ターン数、共通手順書5本の保持、回帰切片）、消費見積もり（Read/Bash 換算、逐次ファイル量、1件ずつ除いた補正と誤差）、手渡し（立ち上がり費用、旧文脈の継続費用差からの損益分岐ターン）を出す。係数 0.77 / 0.65、補正 1.37 は基準標本の値としてのみ扱い、新モデルでは再校正する。
7. 表の文脈上限・強制停止への到達分布、モデル別ターン単価、累計上限・エピックの子の権限候補値の超過・非超過・停止後判断を出す。#1684 の停止時合計 69,491,619 と PR #1689 の変更ファイル数などを原記録と検算する。標本数・欠測・p10〜p90・回帰の区間・品質未測定を残し、値を動かす根拠の有無を判断する。
8. 値を変えるごとに対象モデル・日付・材料・再実行コマンド/hash・集計表・旧新値・採否理由・限界を判断用 issue または PR のコメントに残す。表の該当する各値の `decided_models`・`decided_at`・`evidence`・`source` をその結果へ更新する。環境上書きは検証済み既定値を追加したことにはならない。
