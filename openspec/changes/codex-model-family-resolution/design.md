## Context

- 役割表 `codex-role-profiles.json` の Codex entry は `model` に完全なモデル ID を持ち、`codex-develop.py request` はその値をそのまま worker の request に写す。
- `codex-worker.py` の `advertised_model()` は initialize と account 照合の後、thread/start の前に、request の CODEX_HOME で起動した App Server の `model/list`（`includeHidden: true`、全ページ）を引き、`model` フィールドが指定 ID と完全一致する 1 件を要求する。0 件は `model_not_available`、2 件以上は `model_not_unique`。見つかった 1 件の `supportedReasoningEfforts` で effort を検証する。
- 2026-09-23 に Codex CLI 0.156.0 の一覧で確認した表示モデル: `gpt-6-astra`、`gpt-6-sol`、`gpt-6-luna`、`gpt-5.6-sol`、`gpt-5.6-terra`、`gpt-5.6-luna`、`gpt-5.5`。hidden: `gpt-reserve`、`codex-auto-review`。0.153.4 の一覧には `gpt-6-sol` / `gpt-6-luna` が出ない。
- Codex 自体にモデルの短い呼び名は無い。Claude 側は Agent ツールに `opus` 等を渡し、Claude Code が版を解決する。

## Goals / Non-Goals

**Goals:**
- 組み込み profile を系統名で書き、OpenAI が新世代を出しても役割表を直さずに最新版が呼ばれる。
- 解決は実行する account の実際の一覧に対して行い、解決できなければ止まる。
- どの ID で走ったかが結果 JSON と記録先から後で追える。
- 版を固定したい利用者は完全 ID を書ける。

**Non-Goals:**
- PR レビューの投げ先の選び方（#385 / PR #387）。
- Claude 側のエイリアス解決。
- Codex CLI の自動更新（docs に一言書くだけ）。
- 系統名から完全 ID への解決結果を run や pending に保存して固定すること。

## Decisions

### 解決は worker が thread/start の直前に行う

系統名は `codex-develop.py` では解決せず、request の `model` に系統名のまま書き、worker の `advertised_model()` が解決する。worker は既にその account の CODEX_HOME で App Server を起動し `model/list` を引いているので、解決を同じ一覧で行えば「その account で実際に選べるモデル」から選べる。adapter 側で解決する案は、App Server をもう一度起動する必要があり、adapter と worker の間で一覧が変わる隙間ができるので採らない。

帰結: request・`pending_execution`・`execution_config` には系統名が残り、payload hash も系統名で計算される。retry は保存 request をそのまま渡すので、再実行時に一覧が変わっていれば別の版に解決されうる。これは「呼ぶ直前に最新を選ぶ」という目的どおりの振る舞いで、実際に使った ID は毎回の結果 JSON に残る。

### 系統名と完全 ID は値の形で見分ける

`model` の値が正規表現 `^[a-z]+$`（英小文字だけ。数字もハイフンも含まない）に一致すれば系統名、それ以外は完全 ID として扱う。系統名の固定の列挙（astra/sol/luna）は持たない。新しい系統（例: 一覧に既にある `terra`）を書いた場合も同じ規則で解決される。現行のモデル ID はすべて `gpt-` で始まりハイフンを含むので、完全 ID が系統名と誤認されることはない。

完全 ID の照合は従来どおり: `includeHidden: true` の全ページで `model` フィールドの完全一致、hidden でも受理、0 件 `model_not_available`、2 件以上 `model_not_unique`。

外部 profile-file と旧形式 `--model` は、どちらの形も受け付ける。組み込み profile の Codex entry は系統名で書く（テストで `gpt-[0-9]` を含まないことを確認する）。`codex-develop.py` の Codex entry の静的検証は変えない（非空文字列）。

### 系統名の解決規則

`model/list` の全ページ（完全 ID と同じ `includeHidden: true` の呼び出し。呼び出しの形は変えない）から、次をすべて満たす entry を候補にする。

1. `hidden` が `true` でない（キーが無い entry は表示扱い。`hidden` が真偽値以外なら `model_list_invalid`）
2. `model` フィールドが `^gpt-(<版>)-<系統名>$` に完全一致する。`<版>` は `[0-9]+(\.[0-9]+)*`

候補の版を数値の並び（`5.6` → (5, 6)、`6` → (6)）として比べ、末尾の 0 を取り除いてから辞書順で最大のものを選ぶ（`5.10` は `5.9` より新しい。`6` と `6.0` は同じ版）。

- 候補が 0 件 → `model_not_available`
- 最大の版を持つ entry が 2 件以上（同じ slug の重複、`gpt-6-sol` と `gpt-6.0-sol` の並存） → `model_not_unique`
- `gpt-6-sol-mini` のように後ろに語が続くもの、`gpt-reserve` のような版の無いもの、`codex-auto-review` は候補にならない

どちらの失敗も thread/start と turn/start を呼ばず、既存の失敗 JSON と非ゼロ終了で返し、別モデル・別 account・別 provider に倒さない。

現在の一覧では `sol`→`gpt-6-sol`、`luna`→`gpt-6-luna`、`astra`→`gpt-6-astra`。

### 解決後のモデルで検証し、送信する

effort の検証（`supportedReasoningEfforts[*].reasoningEffort` への完全一致）は解決後の 1 件に対して行う。thread/start と turn/start の `model` には解決後の ID を渡す。payload の `model` は書き換えない（payload hash と retry の照合を変えないため）。

### 解決結果の記録

worker の結果 JSON の `execution`（version は 1 のまま、キーを足すだけ）に `model_resolution` を足す。

```json
"model_resolution": {"requested": "sol", "kind": "family", "resolved": "gpt-6-sol", "source": "model/list"}
```

- `requested` は request の `model`。`kind` は `family` か `exact`。完全 ID のときも `kind: "exact"` と一致した ID を入れる。
- 解決の前に失敗したとき、または解決できなかったときは `resolved: null`、`source: "unavailable"`。`kind` は値の形から決まるので常に入る。
- `requested.model` は従来どおり要求値（系統名）。`effective.model` は従来どおり thread/turn の RPC 応答で観測した値だけを入れ、解決結果で補完しない（解決結果は `model_resolution.resolved` にだけ入る）。

develop 本体は Codex 委譲の結果を記録先に書くとき、`model_resolution.requested` と `model_resolution.resolved`（と観測した `effective.model`）を両方書く。`references/codex-develop.md` の委譲手順 3 にこの項目を足す。

### テスト

- worker: `model/list` のフィクスチャに 2026-09-23 の一覧を与え、`sol`/`luna`/`astra` がそれぞれ `gpt-6-*` に解決され、thread/start・turn/start に解決後の ID が渡り、`model_resolution` が入ることを確認する。0 件と同版 2 件で `model_not_available` / `model_not_unique` になり thread/start を呼ばないこと、hidden の候補は選ばれないこと、`5.10` > `5.9`、effort が解決後のモデルで検証されること、完全 ID は従来どおり通ることを確認する。
- develop: 組み込み profile の期待値を系統名に変え、`codex-role-profiles.json` に `gpt-[0-9]` が無いことを確認する。外部 profile-file と旧形式 `--model` で系統名と完全 ID の両方が request にそのまま写ることを確認する。

## Risks / Trade-offs

- OpenAI が slug の形（`gpt-<版>-<系統名>`）を変えると、系統名は `model_not_available` で止まる → 黙って別モデルで走るより止まる方を選ぶ。止まったら利用者は完全 ID を書くか規則を直す。
- 新しい版が一覧に出た直後から自動で使われるので、品質が変わる版が意図せず入りうる → 版を固定したい場合は外部 profile-file に完全 ID を書く。実際の ID は毎回記録される。
- 新しいモデルは新しい Codex CLI でしか一覧に出ない → CLI が古いと旧世代に解決される。docs に CLI 更新が要ることを書く。自動更新はしない。
- 同じ保存 request の retry が別の版に解決されうる → 目的どおりの振る舞いとして受け入れ、結果 JSON で追えるようにする。
