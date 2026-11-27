# Design

## Context

`agent-model-guard.sh` は Python 本体をヒアドキュメントで持ち、`USAGE_VIEW_DIR`（guard 自身のディレクトリ）を `sys.path` に足して `usage_view` を import している。fork 判定は今、明示 env を自分で読み、無ければ `usage_view.build_view` で active スロットの `weekly_all_pct` / `weekly_resets_epoch` を取り、90 超・週経過との比較を自分で行う。`usage_view.budget_mode_details(slot, now, environ)` は同じ優先順位（明示 env → データ無し → 90 超 → 週経過との比較）で `{"fable": …, "shared": {"mode", "shown", "source"}}` を返す。

両者の挙動を照らすと、明示の未知値（guard は ok 以外なので拒否、usage_view は `throttled` に正規化して拒否）、空白だけの明示値（両者とも未設定扱い）、データ無し・リセット時刻無し（両者とも `ok`）で一致する。違いは `usage_view.py` を読み込めないとき（guard は明示 env だけは効かせる）だけである。

## Goals / Non-Goals

- Goals: guard から共有枠モードの式と明示 env の優先の判定を無くし、fork の可否が注入文・adapter と同じ導出で決まる
- Non-Goals: 導出の式や入力（実効値の求め方）を変えること。fork 以外の判定を変えること

## Decisions

### 明示 env があるときは実効値を読まずに判定する（2 段の呼び出し）

guard はまず `budget_mode_details({}, now)` を呼ぶ。明示 env があれば `shared.source` が `明示 env`（`usage_view.SOURCE_EXPLICIT`）になるので、その結果で判定し、`build_view` を呼ばない。そうでなければ `build_view` で active スロットを取り、`budget_mode_details(slot, now)` の結果で判定する。

- 理由: 仕様の守備範囲は「アカウント一覧・セッション記録・snapshot は `SHARED_BUDGET_MODE` が未設定のときだけ読む」と書いている。また常に `build_view` を先に呼ぶと、記録や snapshot が壊れて例外になったときに fail-open（`ok`）へ倒れ、明示 `depleted` が効かなくなる
- guard は env を自分で読まず、明示かどうかを `usage_view` が返す出どころで知るので、優先の判定の写しにならない
- 退けた案: 常に `build_view` → `budget_mode_details`（上の理由で明示 env が壊れたデータに負ける）。guard で env の有無を見て分岐（優先の判定の写しになる）

### usage_view.py を読み込めなければ明示 env も読まず通す

import に失敗したとき（ファイルが無い・例外）は `ok` として通す。

- 理由: 仕様は `session-tripwires.sh` について「明示 env の優先の判定も式の一部で、写しを残さない」とし、読めなければ明示 env も読まず既定を出す。guard も同じにすると、壊れた install のとき注入文（`ok`）と fork の可否が食い違わない
- 退けた案: import 失敗時だけ guard が明示 env を読む（式の一部の写しが残り、受け入れ条件の趣旨に反する）
- `budget_mode_details` の呼び出しや `build_view` が例外を出したときも `ok`（今の fail-open と同じ）

### 拒否理由のモード名は shown を出す

拒否理由の文面には `shared.shown`（明示値ならその値のまま、導出なら導出値）を出す。今の文面（明示の未知値もそのまま出る）と同じ見え方を保つ。許可・拒否の判定は正規化後の `shared.mode == "ok"` で行う。

### 現在時刻の取り方は guard に残す

`USAGE_PROBE_NOW`（整数）があればその値、無ければ `time.time()`。これは式ではなく入力の取り方で、既存の bats が時刻を固定するのに使っている。

## Risks / Trade-offs

- [`usage_view.py` が壊れた install で明示 `SHARED_BUDGET_MODE=depleted` が fork を止めなくなる] → 壊れた install では注入文も `ok` になり、他の dev-workflow の読み手も動かない。頻度は低く、`session-tripwires.sh` と同じ扱いにそろえる利点を取る。仕様のシナリオに明記する
- [`usage_view` の関数名や返り値の形が将来変わると guard が fail-open で黙って通す] → 偽の `usage_view.py` で導出を `usage_view.py` から得ることを確かめる bats と、実物の `usage_view.py` での既存の fork の bats（throttled / depleted の導出）が落ちて気づける

## Migration Plan

hook の差し替えだけで、設定や保存データの移行は無い。戻すときはこの PR を revert する。
