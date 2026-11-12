# Design

## Context

動機は proposal.md の Why。codex-worker の `run()` は結果を `print(json.dumps({...}))` の 1 行で返し、今のキーは `text` / `status` / `usage` / `execution` / `thread_id` / `turn_id` / `error_kind` で時刻を持たない。develop の本体はこの JSON から `Codex 消費: <thread_id> <tokens>` を書き、2 行目に `[消費記録 …]` の印を置く。読み取り側（flatmate `openspec/specs/burn-consumption-ledger/spec.md`）は `Codex 消費:` コメントの印の `開始=` `終了=` を、rollout から時刻が取れない thread にだけ使う。例の値は `2026-10-19T23:50:00Z` の形で、同じ thread のコメントが複数あれば `開始=` の最も早い値と `終了=` の最も遅い値を使い、`開始=` が `終了=` より後なら読まない。

## Goals / Non-Goals

**Goals:**
- executor が `codex` の委譲 1 回ごとに、その委譲が枠を使った時間帯を `Codex 消費:` コメントに残す

**Non-Goals:**
- G が full レビューで Bash から呼ぶ Codex の時刻を取ること（G の return の形を変える別の仕事になる。今回はキーを書かない）
- description と `develop 開始` コメントの印に時刻を書くこと（読み取り側が読まない）
- 使い捨ての CODEX_HOME をやめて rollout を残すこと（アカウントを依頼された CODEX_HOME で固定する要件と衝突する）

## Decisions

### 時刻を取る区間は worker の実行全体にする
`started_at` は `run()` の入口（依頼を読む前）、`ended_at` は `finally` で一時領域を片付けたあと `print` の直前に取る。

代わりに考えたのは、`turn/start` が受理された時点から終端までにする案。こちらは消費が起きる区間に近いが、ターンが始まらなかった実行では値が無く `null` を出すことになり、本体の書き分けと読み取り側の欠測が増える。worker 全体の区間は消費の区間を必ず含み、差は利用枠の確認やアカウントの照合の数秒なので、リセット期間をまたいだかの判定にはほぼ影響しない。成功・失敗で形を変えないという既存の要件とも揃う。

### 書式は UTC・秒まで・末尾 `Z`
`datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')` で作る。読み取り側の例と同じ形にし、タイムゾーンの表記ゆれ（`+00:00` とマイクロ秒）を出さない。秒未満を切り捨てるので、1 秒未満で終わる実行では `started_at` と `ended_at` が同じ値になりうるが、読み取り側は `開始=` が `終了=` より後のときだけ読まないので問題にならない。単調時計（`time.monotonic()`）は壁時計の時刻にならないので使わない。

### キー名は `started_at` / `ended_at`
既存のキーは英語の snake_case で、読み取り側の行の項目名も `started_at` / `ended_at` なので揃える。結果 JSON に足すだけで、既存のキーは変えない。

### 時刻が取れないときは推測で埋めない
本体は結果 JSON の値をそのまま `開始=` / `終了=` に写し、キーが無いか `null` ならそのキーを省く（古い版の worker がキャッシュに残っている場合に当たる）。本体が委譲した時刻やコメントの投稿時刻で埋めると、読み取り側がそれを rollout 相当の値として使い、誤った時間帯に帰属させる。`アカウント=` の登録名を推測で埋めない既存の規則と同じ考え方。

### 規則の置き場
SKILL.md「PR トークン上限」節の「消費の記録の印」の時刻の行を「`Codex 消費:` コメントの印にだけ書く」に改め、書き方そのものは同じ節の「Codex の消費の記録」の段落に置く（どの値を写すかは Codex の記録の手順の一部なので）。印の一般規約の行には置き場の限定だけを書き、同じ規則を 2 か所に書かない。

### 受け入れ条件の「bats で確かめる」の読み方
codex-worker の振る舞いのテストは既存どおり `tests/test_codex_worker.py`（実物の worker を偽の app-server で走らせる）に足す。この Python のテストは `tests/python-suites.bats` が `scripts/test.sh` から走らせるので、bats の実行で検査される。SKILL.md の文面は `tests/develop-skill.bats` で検査する。

## Risks / Trade-offs

- [区間が消費の区間より数秒広い] → リセットの直前・直後の数秒にまたがる委譲だけ、またいだと判定されうる。頻度は低く、読み取り側は rollout があればそちらを優先する
- [端末の時計がずれている] → 時刻はその端末の壁時計の値になる。rollout の時刻も同じ端末の時計なので、今より悪くはならない
- [本体が `開始=` `終了=` を書き忘れる] → 読み取り側は今どおり null として扱う（守備範囲で許す入力）
