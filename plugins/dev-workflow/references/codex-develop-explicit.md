# 手動 develop provider adapter — 明示指定の規則

`references/codex-develop.md` から分けた、`--profile` / `--account`（旧形式）を明示したときだけ使う規則。無指定の自動選択では読まない。明示指定のときは `references/codex-develop.md` を先に読み、この文書を続けて読む。

## request の検証（明示指定）

明示 profile と旧形式の併用、旧形式の片方欠落、profile-file だけの指定は依頼ファイルを作らず拒否する。明示指定は自動選択より優先し、構成の選択に usage snapshot を使わず、usage probe も走らせない（残量モードの導出には Claude の実効値を読む）。形式版 2 の profile は全 canonical role の `executor` / account / effort と任意の `tier_cap` を検証する。

Codex オフのあいだ、Codex の role を含む明示 profile と旧形式は `codex is off: set "codex"."enabled" to true or remove it in <登録簿のパス>` を出して拒否し、Claude へ差し替えない（Codex に投げる role が 1 つも無い profile は通る）。`codex` が無い・`enabled` が `false` 以外の登録簿では選択も evidence も変わらない。

## profile の種類と外部設定

組み込み profile は `codex-standard`、`codex-economy`、`hybrid-standard`、`claude-write-codex-review`、`claude-default`。外部設定は形式版 2 で書く。全 canonical role を含み、Codex role の account は呼び出し側の対応表に存在し、Claude role は account=current である必要がある。entry に `model` は書けない（モデルは格から `references/model-tier-map.json` で引く）。`tier_cap` は任意で、その role の格を指定した格まで下げる（`最安`・`中位`・`上位`・`最上位` のどれか）。`review` は `impl-review` と同じ entry にする。

```json
{
  "version": 2,
  "profiles": {
    "custom": {
      "roles": {
        "spec-write": {"executor": "codex", "account": "mapped", "effort": "medium", "tier_cap": "最安"},
        "spec-review": {"executor": "claude", "account": "current", "effort": "high"},
        "implement": {"executor": "codex", "account": "mapped", "effort": "medium", "tier_cap": "最安"},
        "impl-review": {"executor": "claude", "account": "current", "effort": "high"},
        "review": {"executor": "claude", "account": "current", "effort": "high"},
        "decider": {"executor": "claude", "account": "current", "effort": "high"},
        "explore": {"executor": "codex", "account": "mapped", "effort": "low"},
        "summarize": {"executor": "codex", "account": "mapped", "effort": "low"}
      }
    }
  }
}
```

形式版 1 の profile は拒否する。書き換え方は次のとおり。`version` を 2 にし、各 entry の `model` を消す。`luna` のように役の格より低いモデルを使っていた entry には `tier_cap` を足す。完全なモデル ID（`gpt-6-sol` 等）で版を固定していた場合は、旧形式 `--account NAME --model MODEL` に移る。旧形式の model は系統名（英小文字だけの値）か完全なモデル ID で書き、adapter は変換せずに request へ写す。

系統名は worker が呼ぶ直前にその account の model/list から最新版へ解決する。新しいモデルが一覧に出るには Codex CLI の更新が要る（CLI が古いと旧世代に解決される）。歴史的な `references/codex-role-profiles.json` というファイル名は互換性のため維持するが、中身は provider-neutral な role table である。

## account-home（明示指定）

profile 全体を先に検証するため、選択 role が Claude でも明示 profile 内の Codex account はすべて明示対応表に必要である。明示 profile・旧形式の account も既定値や別 account へ倒さない。

## 導入方法

account 名から CODEX_HOME への対応の導入方法は `docs/codex-develop.md` に示す。
