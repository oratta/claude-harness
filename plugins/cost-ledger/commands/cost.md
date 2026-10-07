---
name: cost
description: そのブランチ・PR・issue にかかった API 換算コストを、会話ログから集計して 1 行で返す。`/cost` は現在のブランチ、`/cost <番号>` は番号が PR か issue かを GitHub に問い合わせて振り分ける。「コストいくら」「この PR の費用」「issue のコスト」で起動。
allowed-tools: Bash
---

会話ログ（`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/**/*.jsonl`）を 1 パスで読み、API 換算のコストを集計する。プラグイン設定「台帳ファイルのパス」または環境変数 `COST_LEDGER_PATH` が設定されていれば、会話ログの増えた分を台帳に追記してから台帳を読む（下の「台帳」）。集計・判別・書式のすべては `scripts/cost_ledger.py` の `cost` サブコマンドが持つ。**このコマンドは単価も換算レートも出力書式も自分では持たない**（単価と換算レートの正本は `pricing.json`、1 行目の書式の正本は `headline()`）。

## 実行

集計スクリプトの絶対パスを特定して、そのまま呼ぶ。

```bash
plugin_root="${CLAUDE_PLUGIN_ROOT}"
for dir in \
  "${plugin_root:+$plugin_root/scripts}" \
  ~/.claude/plugins/marketplaces/*/plugins/cost-ledger/scripts \
  ~/.claude/plugins/installed/*/cost-ledger/scripts; do
  [ -n "$dir" ] && [ -f "$dir/cost_ledger.py" ] && CL="$dir/cost_ledger.py" && break
done
CLAUDE_PLUGIN_OPTION_LEDGER_PATH='${user_config.LEDGER_PATH}' python3 "$CL" cost $ARGUMENTS
```

探索の先頭候補は、コマンド本文の読み込み時に絶対パスへ置換される `plugin_root="${CLAUDE_PLUGIN_ROOT}"` から作る（Bash の実行環境にはプラグインのルートの環境変数が渡らないため、環境変数の形だと先頭が空になり、版の違うインストール済みの旧コピーが選ばれる）。置換されないときは `plugin_root` が空になり、先頭候補は空文字列として飛ばされて、後続の候補へ進む。

引数の解釈はスクリプト側が行う。

| 呼び方 | 何が返るか |
|---|---|
| `/cost` | 作業ディレクトリの現在のブランチに帰属するコスト |
| `/cost <PR番号>` | その PR のヘッドブランチに帰属するコスト |
| `/cost <issue番号>` | その issue を触った区間のコスト合計（作業ディレクトリのリポジトリの行だけ） |
| `/cost <子 issue を持つ issue の番号>` | 子 issue ごとの内訳と、エピック自身と子孫の issue の合計（同じ PR の分は 1 回だけ数える） |

番号が PR か issue かは `gh api` で GitHub に問い合わせて判別する。**認証済みの `gh` と GitHub への到達性が要る**（コスト計算そのものはオフラインで完結するが、判別だけはネットワークに依存する）。どちらでもない番号は 0 円と表示せず、見つからないと伝えて終了コード 2 で終わる。

## 台帳

会話ログは既定 30 日で消える。消えたあとも同じ値を返すために、プラグイン設定「台帳ファイルのパス」（なければ `COST_LEDGER_PATH`）が指すリポジトリ外の append-only の JSONL 台帳へ、応答が終わるたびに `Stop` hook が増えた分を焼き付ける。

- **台帳が未設定なら**（プラグイン設定「台帳ファイルのパス」も `COST_LEDGER_PATH` も空）、会話ログを直接読んで答えたうえで、台帳ファイルをどこに置くかを利用者に聞く（既定の場所は決めない。このリポジトリの配下は不可。パスにシングルクォート `'` を含めない）。決まったら、`/config` でプラグイン設定「台帳ファイルのパス」に設定するよう先に案内し、従来の方法として `~/.claude/settings.json` の `env` に `COST_LEDGER_PATH` を書くこともできると添える。設定が効いたあと（新しいセッションから）の最初の `/cost` が会話ログの増えた分を台帳に取り込む。すぐ取り込むなら `COST_LEDGER_PATH=<決めたパス> python3 "$CL" ledger-sync` を実行する
- 台帳がリポジトリ配下を指していると、スクリプトは終了コード 2 で終わる。その旨を利用者に伝えて場所を聞き直す

## 出力の扱い

1 行目が固定書式で、金額（USD と円）・換算レート・帰属先・帰属の種別をすべて含む。**PR に貼るときは 1 行目だけを取る**。2 行目以降は内訳で、issue 経路では区間ごとの寄せ先が並ぶ。

```
コスト: $108.23 / ¥16,235 @150 — PR #271 (oratta/token-optimize) 帰属: ブランチ
```

利用者にはこの 1 行目をそのまま見せ、内訳は聞かれたときだけ示す。issue 単位の数字は区間分割による推定なので、**断定せずに推定と伝える**。リポジトリ不明として別立てされた行があれば、その件数と金額も併せて伝える（`cwd` が削除済みでどのリポジトリの番号か絞れなかった行で、黙って落としても合算してもいない）。

円換算のレートは `pricing.json` の固定値で、環境変数 `COST_LEDGER_USD_JPY` で上書きできる。レートを変えたいと言われたら、この環境変数か `pricing.json` を案内する。
