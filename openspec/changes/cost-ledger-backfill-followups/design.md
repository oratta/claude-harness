## Context

`backfill.sh` は `COST_LEDGER_PATH` が空なら `python3` を起動せずに抜ける。一方、`cost-ledger-persistence`（#713）は台帳の場所を `CLAUDE_PLUGIN_OPTION_LEDGER_PATH`（userConfig の `LEDGER_PATH`）と `COST_LEDGER_PATH` の 2 つから解決し、前者を優先すると定めている。`ledger-hook.sh` は解決した値を `COST_LEDGER_PATH` に写して `cost_ledger.py` に渡すが、`backfill.sh` はこれに合わせていない。`backfill.py` 側は `cost_ledger.ledger_path()` を呼ぶので、すでに 2 つの入口から解決できる。直すべき入口は `backfill.sh` の 1 行だけ。

控えは `sweep()` の末尾で、候補が上限を超えたとき（最後に処理した候補の時刻）と、一覧が 1 件以上あるとき（更新時刻の最大値）にしか書かれない。一覧が 0 件で控えに値が無い回は、何も書かずに終わる。

## Goals / Non-Goals

**Goals**
- userConfig だけで台帳を設定した環境でも後追いが動き、控えとロックが解決後の台帳の隣にできる
- 一覧が空の回が続いても、24 時間の窓が最初の実行の位置に固定される
- `backfill.bats` の取りこぼし 6 件を直す
- 待ち時間と `gh` の回数を増やさない（実測して記録する）

**Non-Goals**
- `gate_report.py`・`cost_ledger.py` の変更（台帳パスの解決の共通化を含む。#703・#698 が並行して触る）
- `backfill.sh` での `${user_config.` プレースホルダの除外。後追いは SessionStart の hook で、コマンド本文の置換前の文字列は渡らない。`ledger-hook.sh` も同じ扱いにしてあり、`backfill.py` は `cost_ledger.ledger_path()` で除外している
- 一覧に載せたリポジトリでの同名ブランチのコスト混在など、#761 の範囲

## Decisions

### 決定 1: 台帳パスの解決は `ledger-hook.sh` と同じ 3 行を `backfill.sh` に置く

```sh
COST_LEDGER_PATH="${CLAUDE_PLUGIN_OPTION_LEDGER_PATH:-${COST_LEDGER_PATH:-}}"
[ -n "$COST_LEDGER_PATH" ] || exit 0
export COST_LEDGER_PATH
```

`:-` は空文字も未設定として扱うので、「空文字は未設定と同じ」の規則と合う。代案: 共通のシェル関数を作り両方の hook から読む。2 つの hook に同じ 3 行を置く現状と比べて、読み込みの失敗経路が増え、`gate_report.py`・`cost_ledger.py` の外でも共通化が要るので採らない。

### 決定 2: 一覧が空で値が無い回は、今回の `since` を控えに書く

`sweep()` の末尾を次の形にする。

```python
elif items:
    write_seen(state_path, key, max(item["updated"] for item in items))
elif seen_until(read_state(state_path), key) is None:
    write_seen(state_path, key, since)
```

`since` は先頭で決めた「控えの値、無ければ実行した時刻の 24 時間前」。値が無かった回は後者なので、書くのは最初の実行の 24 時間前の時刻になり、以降の回の窓はその時刻から始まる。一覧の失敗では `return` するので書かない。

#691 の「手元の時計で値を書かない」とは逆になる。ただし初回の `since` はもともと手元の時計で決めている（決定 5）。手元の時計が GitHub より進んでいるときの見落としは、一覧が 1 件以上返る回に書く値が GitHub の時刻になることで、1 回目の窓の外へ押し出される。代案: 一覧が空でも常に実行時刻の 24 時間前を書く。値がある回の控えが毎回後ろに動くので、24 時間より長く開いた間のマージを見落とす。値が無い回だけに限る。

壊れた控えで一覧が 0 件のとき、#691 は控えを壊れたまま残していた。この決定で、読める形に直る（「壊れた控え」の Scenario と合う）。

## Risks / Trade-offs

- [手元の時計が GitHub より進んでいる状態で最初の実行が空だと、書いた `since` より前の出来事を拾わない] → もともと初回の `since` が同じ時計で決まるので、増えるリスクは無い。窓は 24 時間なので、ずれる量は時計のずれの分だけ
- [控えを消した直後の最初の実行が空だと、その時点で窓が固定される] → 控えを消せば初回の状態に戻る、という既存の説明と一致する

## Migration Plan

反映に `/reload-plugins` は要らない（`hooks.json` は変えない）。戻し方: `backfill.sh` の 3 行を元の 1 行に戻し、`backfill.py` の `elif` 1 つを外す。
