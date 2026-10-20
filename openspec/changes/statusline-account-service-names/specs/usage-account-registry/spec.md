## ADDED Requirements

### Requirement: Codex の表示名を codex.label で決める
レジストリのトップレベルの `codex` オブジェクトは、任意の `label`（文字列）を持てる（SHALL）。statusline が Codex の行の名前 `Codex <label>` の `<label>` に使う。次の読み方に従わなければならない（SHALL）:

- `codex.label` が空でない文字列で、制御文字（C0 制御文字および DEL）を含まなければそれを使う。表示幅（East Asian Width が W / F の文字を 2 桁と数える）が 8 を超える場合は、スロットの `label` と同じ規則で 8 桁に切り詰める
- それ以外（`codex` や `label` の欠落、文字列でない値、空文字、制御文字を含む値、壊れたレジストリ、レジストリ不在）は `A` を使う。不正な値を報告したり、Codex の行を消したりしない
- `codex.enabled` とは独立に読む。`label` を足しても `schema` は `1` のまま変えない（古い読み手は未知のキーとして読み飛ばすため）

`accounts-init.sh` はスロットの更新時にトップレベルの `codex` を保つ既存の規定に従い、`label` もそのまま残す。

#### Scenario: label が無ければ A
- **WHEN** `{"schema":1,"accounts":[...],"codex":{"enabled":true}}` と `codex` 自体が無いレジストリのそれぞれを与えて Codex の表示名を求める
- **THEN** どちらも `A` になる

#### Scenario: label があればそれを使う
- **WHEN** `"codex": {"label": "X"}` を持つレジストリを与えて Codex の表示名を求める
- **THEN** `X` になる

#### Scenario: 不正な label は A に戻す
- **WHEN** `"codex": {"label": ""}`、`"codex": {"label": 3}`、制御文字を含む label のそれぞれを与えて Codex の表示名を求める
- **THEN** いずれも `A` になる

#### Scenario: 長い label は 8 桁に切る
- **WHEN** 表示幅が 8 を超える `codex.label` を与えて Codex の表示名を求める
- **THEN** 8 桁に切り詰めた値になる
