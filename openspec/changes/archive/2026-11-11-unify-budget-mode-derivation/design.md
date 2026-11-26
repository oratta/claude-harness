# Design

## Context

動機は proposal.md の Why。今の形は次のとおり。

- `session-tripwires.sh` は heredoc の Python で `usage_view.build_view` を呼んで active スロットの実効値を得たあと、その場で 2 つのモードを導いている（Fable 残量モード: 明示 env > データ無し → conserve > 90% 超 → exhausted > 週経過以下 → abundant > conserve。共有枠モード: 明示 env > データ無し → ok > 90% 超 → depleted > 週経過より速い → throttled > ok）
- `usage_view.budget_modes(slot, now, environ)` は同じ式で `{"fable", "shared"}` を返す。`codex-develop.py` の `read_budget_modes` がこれを使い、結果 JSON の `budget_modes` 欄にそのまま出す
- 2 つには観測できる違いがある。`session-tripwires.sh` はモード名に出どころ（`明示 env` / `既定（usage データなし）` / `自動導出`）を添え、未知の明示値（例 `FABLE_BUDGET_MODE=foo`）はその値のまま表示して効果の文に「未知のモード指定。conserve 相当（安全側）で扱う」を出す。`budget_modes` は未知の値を `conserve` / `throttled` に丸めて返し、出どころを持たない
- `usage_view.py` の場所は `CLAUDE_PLUGIN_ROOT/scripts` から求めている。`CLAUDE_PLUGIN_ROOT` が空のときは読み込まない（#847: 空文字列を検索パスに入れるとカレントディレクトリの偽の `usage_view.py` を読む）。このとき `TRIPWIRES_SCOPE=subagent-budget` は既定の残量ブロックを出す（`tests/hook-python-isolation.bats`）

## Goals / Non-Goals

**Goals:**
- 閾値と優先順位の判定を `usage_view.py` の 1 つの関数だけに置く。`session-tripwires.sh` には閾値の比較も明示 env の優先も書かない
- `session-tripwires.sh` の出力の形（見出し・行の並び・モード名・出どころの語・未知の値の表示）を変えない。変わるのは効果の文だけ
- 効果の文を decision-criteria の表と `model-tier-resolution` に合わせる

**Non-Goals:**
- `agent-model-guard.sh` の fork 判定の写しの解消（#615 が同じファイルを触る。別 issue）
- `dev-workflow-develop` の scenario 見出しの語の修正（別 issue）
- 効果の文を decision-criteria から機械的に抜き出して注入すること（表の列は注入には長く、表の書式に hook が依存すると表を直すたびに hook が壊れる）

## Decisions

### 出どころ付きの導出関数を usage_view.py に足し、budget_modes はその包みにする

`usage_view.py` に、1 つのスロットの実効値と env からモードごとに `mode`（丸めた値）・`shown`（表示する値。明示 env ならその文字列のまま）・`source`（`明示 env` / `既定（usage データなし）` / `自動導出`）を返す関数を足す（名前は実装で決める。例 `budget_mode_details`）。`budget_modes` はこの関数を呼んで `mode` だけを `{"fable", "shared"}` で返す。`session-tripwires.sh` は `shown` と `source` を表示に使い、効果の文は `mode` ではなく `shown` で引く（未知の値に「未知のモード指定」の文を出す今の振る舞いを保つため）。

比べた案:
- `budget_modes` の戻り値に出どころの欄を足す: `codex-develop.py request` の結果 JSON の `budget_modes` 欄が変わり、`model-tier-resolution` の出力契約と `test_codex_develop.py` の等値比較を触ることになる。採らない
- `session-tripwires.sh` が `budget_modes` の丸めた値だけを使い、出どころは自分で推し量る: 出どころの判定（明示 env があるか・値が読めたか）は式の一部で、写しが残る。未知の値の表示も失われる。採らない
- `usage_view.py --json` に budget の欄を足し、`session-tripwires.sh` はコマンドとして呼ぶ: 今も Python から import しているので、プロセスを増やす理由がない。採らない

### usage_view.py の場所はスクリプト自身のディレクトリから求める

`session-tripwires.sh` は `usage_view.py` を `CLAUDE_PLUGIN_ROOT/scripts` ではなく、自分のファイルのあるディレクトリ（`BASH_SOURCE[0]` の dirname を絶対パスにしたもの）から読み込む。導出を `usage_view.py` に寄せると、読み込めないときに残る道が「既定値を出す」しか無くなり、`CLAUDE_PLUGIN_ROOT` が空の起動で明示 env も効かなくなる。自分のディレクトリは空にならず、カレントディレクトリも指さないので、#847 の守り（空の検索先を入れない・ルート直下のパスを作らない）はそのまま保てる。`CLAUDE_PLUGIN_ROOT` が空のときに session の範囲で何も出さない早期終了は変えない。

読み込みそのものが失敗したとき（ファイルが無い・壊れている）は、`conserve` / `ok`、出どころ `既定（usage_view.py を読めない）` を出す。このときは明示 env も読まない。明示 env を読むのは優先順位の写しになるため。これは仕様の「明示 env を優先する」規定の例外として、`dev-workflow-escalation-tripwires` の要件に明記し scenario を置く。`exhausted` を明示していても `conserve` と出るが、これはファイルの欠損という起きにくい壊れ方に限られ、hook を止めない（fail-soft）ことを優先する。

### 効果の文は格の規則の語で書き、モデル名を添える

効果の文は decision-criteria の表の効果の列の要点を、`model-tier-resolution` の格の語（最安・中位・上位・最上位）で書き、読み手が迷わないよう Claude のモデル名を括弧で添える。`depleted` は「explore と summarize（最安）はそのまま、それ以外の役は中位（sonnet）が上限・昇格なし。事前分類に当たっても上位・最上位を使わない」と読める文にする。`throttled` は「上げていない役の既定を中位に落とし、上限は上位。`abundant` の押し上げは無効。最安はそのまま」。`ok` と `conserve` は今の文の意味を保ち、`conserve` の「opus 止まり」の語は既存の bats が固定しているので残す。文面は bats で固定する。

### 一致させるのは正規化後のモード

`session-tripwires.sh` と `codex-develop.py request` が一致させるのは正規化後の `mode` で、提示する `shown` ではない。未知の明示値では `shown` が `foo` / `bar`、`mode` が `conserve` / `throttled` になる。`model-tier-resolution` の要件にこの区別を書く。守備範囲の段落（入力の出どころ・拾いたい誤り・通してよい入力・完了条件）は式と同じく 1 か所（`dev-workflow-escalation-tripwires` の SessionStart の要件）に置き、他の 2 つの要件はそこを指す。

## Risks / Trade-offs

- [decision-criteria の表を直しても注入文が追従しない] → 文面を固定する bats に、`depleted` が最安を上げない旨を含むこと・「固定」の語を含まないことを確かめる行を置く。表との一致そのものは機械照合しない（Non-Goals の理由）
- [`test_codex_develop.py` の `test_same_values_as_session_tripwires` が同じ実装同士の比較になり、検査の意味が薄れる] → 消さずに残す（`session-tripwires.sh` の表示の取り出しと `read_budget_modes` が同じ値を出すことの確認として働く）。注記の「写し」の文だけを直す
- [`session-tripwires.sh` が導出を持たないことを bats で確かめる手段] → `usage_view.py` を差し替えた（モードを固定値で返す偽物を置いた）scripts ディレクトリから `session-tripwires.sh` を走らせ、注入されるモードが偽物の値になることを確かめる。スクリプトのディレクトリから読み込む決定と組み合わせ、bats では scripts ディレクトリを一時領域に写して偽物を置く
