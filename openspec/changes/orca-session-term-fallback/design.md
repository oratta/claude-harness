# Design

## Context

`epic-launch-orca.sh` の `pick_session_term` は、端末一覧の JSON だけから子のセッションの端末を選ぶ。先に `agentIdentity == "claude"` の端末を見て、無ければ題名に `Claude Code` を含む端末を見る。どちらかがちょうど 1 つならその端末を返す。#1598 の観測では、端末は 1 つで子の Claude Code が動いていたが、`agentIdentity` は null、題名はセッション名だった。同じ子に 2 時間前は `reply` が `sent` で届いていたので、`agentIdentity` か題名は途中で変わる。

## Goals / Non-Goals

Goals:
- 端末が 1 つで子の Claude Code が入力待ちのとき、`notify-closed` と `reply` が `ambiguous-terminal` にならない
- Claude Code が終わってシェルに戻った端末には、今までどおり打ち込まない

Non-Goals:
- 端末が 2 つ以上あり、どれも識別できない場合を救うこと
- `launch` の起動待ち（`shell_start`）の判定を変えること
- Orca が `agentIdentity` を null にする原因を Orca 側で直すこと

## Decisions

### 1 端末のときだけ画面の入力枠で確かめる（採用）

識別も題名も外れ、ワークツリーの端末がちょうど 1 つのときだけ、`orca terminal read --terminal <h> --screen --json` を 1 回呼ぶ。`keepalive_screen_reason` が使う入力枠の判定（`resolve_frame`。下端に罫線・`❯` の行・罫線・フッターが順に並ぶ形）で枠が取れれば、その端末を選ぶ。判定は既存の Python の中に、入力枠が取れたかだけを返すモード（例: 第 2 引数 `identify`）を足して使い回す。フッターの後ろにシェルのプロンプトがある画面は `resolve_frame` が None を返すので選ばない。

- `deliver` に送る直前で止まっている子は入力待ちなので、入力枠が下端にある。busy な子（ツールの実行中）も入力枠は下端に出るので選ばれる。そのあと `orca terminal send --wait-submit` とターンの開始の確かめは今までどおり働く
- `keepalive` は選んだあとに同じ画面をもう 2 回観測するので、ここで選んでも送信の条件は緩まない
- `keepalive` のこの段の出力: 入力枠が無ければ `skipped ambiguous-terminal`（一覧で決まらないときの今の語と同じ）。画面の読み取りが失敗した・出力の形を読めないときは、`keepalive` の今の規則「読み取り自体の失敗や壊れた出力は `failed observe`」に合わせて `failed observe` にする。`deliver` には `failed observe` の語が無いので、`deliver` では読み取りの失敗も `failed ambiguous-terminal` にする
- 起動部品の契約（dev-workflow-epic-state の要件「起動部品は epic-launch-<名前>.sh の 1 本ずつで…」）は、Orca の部品の `deliver` が呼んでよい `orca` のコマンドを MUST NOT 付きで限り、呼び出しの順と回数を切り出す前と同じにすることを MUST にしている。この change はその要件を MODIFIED にし、`deliver` の許すコマンドと同一性の例外に、識別できない 1 端末のときだけの `orca terminal read --terminal <h> --screen --json` 1 回を足す

### 退けた案: 状態の記録の `.session` のハンドルを使う

`launch` は `started <handle>` を記録の `.session` に書く。そのハンドルが一覧にあれば選ぶ案もある。ただし起動部品は記録を読まない（契約）ので、`deliver` の引数を足すことになり、tmux の部品にも波及する。それに Claude Code が終わってシェルに戻った同じハンドルを見分けられない。

### 退けた案: 端末が 1 つなら無条件に選ぶ

シェルだけの端末に文を打ち込むと、主の返事の文がシェルのコマンドとして走りうる。要件の「シェルの端末だけのときは送らない」を崩す。

## Risks / Trade-offs

- 画面の読み取りが 1 回増える（1 端末で識別できないときだけ）。読み取りが失敗したら `ambiguous-terminal` のまま。`failed observe` という新しい語は足さない
- 入力枠の見た目が Claude Code の版で変わると、この段は選ばなくなる（今の `ambiguous-terminal` に戻るだけで、誤って送ることはない）
