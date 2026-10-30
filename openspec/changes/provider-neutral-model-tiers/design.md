# Design

## Context

動機は proposal.md の Why。要件は specs、特に `model-tier-resolution` が定める。今の `codex-develop.py request` は profile の entry の `model` か `claude_default()` の固定表をそのまま返し、残量モードを読まない。残量モードの適用と事前分類は本体の文章規則にある。#613 はこの現状を 672 ケースと `model-resolution-current.md` に固定し、文章既定との食い違いを印で並べた。

`codex-worker.py` は 105 行目で依頼ファイルの欄を限定している。`session-tripwires.sh` が残量モードの導出の正本で、`agent-model-guard.sh` が W の上限の強制層である。

## Goals / Non-Goals

**Goals:** 格を決める場所を `request` の 1 か所にする。#613 の食い違いをすべて解消する。

**Non-Goals:** 失敗時の昇格の手順（#424）。実行役の上限の強制（#615）。再開前の上限確認（SKILL.md 32 行目の本体の文章規則のまま）。V と引き継ぎの判定役の起動。`rules/subagent-model-selection.md` の変更。

## Decisions

### 1. 格の対応表

語は `最安 / 中位 / 上位 / 最上位`。形式は次のとおりで、`version` / `tiers` / `executors` 以外のキー、重複キー、格か executor の欠けは拒否する。

```json
{
  "version": 1,
  "tiers": ["最安", "中位", "上位", "最上位"],
  "executors": {
    "claude": {"最安": "haiku", "中位": "sonnet", "上位": "opus", "最上位": "fable"},
    "codex": {"最安": "luna", "中位": "sol", "上位": "sol", "最上位": "astra"}
  }
}
```

Codex の上位を `astra` にしない。W が astra になり #424 の事故を再現するため。中位を `luna` にしない。#474 でレビュー役（Claude では上位）を astra から sol に下げ済みで、中位を luna にすると `codex-standard` の通常の W が今より下がるため。

代替案: `terra` 系統（`gpt-6.1-terra` 等）は model/list にあるが、issue の候補外で今の profile にも無いので使わない。

### 2. profile の形式版 2

```json
{
  "version": 2,
  "profiles": {
    "<name>": {
      "roles": {
        "<canonical role>": {"executor": "codex", "account": "current", "effort": "high", "tier_cap": "最安"}
      }
    }
  }
}
```

厳密な形式は次のとおり。

- 最上位のキーは `version` と `profiles` だけで、`version` は整数の 2。profile のキーは `roles` だけ
- `roles` は canonical role 8 つちょうど。`review` は `impl-review` と同じ entry
- entry の必須キーは `executor` / `account` / `effort` で、任意キーは `tier_cap` だけ。値は非空文字列。`tier_cap` は 4 格のどれか。`model` キーは未知のキーとして拒否する
- 重複キーは今の `_unique_object` で拒否する。executor ごとの検証は `codex-role-profiles` の要件のとおり

`execution_config` も `version: 2` で同じ entry を持つ。hash は entry から計算するので残量モードで変わらない。

`claude-default` を組み込み profile に足し、`claude_default()` と `automatic_claude_default` を消す。effort は今の表と同じ（最安の役 low、書く役 medium、レビュー役と decider high）。自動選択で `claude-default` になったときも結果に `execution_config` が載る。

`codex-economy` の spec-write / implement は `tier_cap: 最安` とする。今の luna を保つため。「中位まで」だと sol になり節約にならない。

### 3. 旧形式

完全なモデル ID の固定は旧形式 `--model` だけに残す。旧形式は規則も対応表も通らず、格の欄は null で、`requested_model` は指定値。格の入力の引数は受けて無視する。本体が経路で分岐しなくて済むように。

### 4. request の入力

`--pre-class sacred|merge|contract|billing`（繰り返し可）、`--design-judgment`、`--failure first|executor|judgment`、`--unmanned`。

### 5. 格の規則

構成・executor・自動選択かどうかは入力にしない。W と G はどちらも role が `implement` になるので、規則は role ではなく phase で引く。

| phase | 基準 | 上げる条件 |
|---|---|---|
| `spec` / `implement` / `finish`（W） | 中位 | `--pre-class` のどれか・`--design-judgment`・`--failure executor` で上位。下がらない |
| `gate`（G） | 中位 | 上げない |
| `spec-review` / `review`（R1 / レビュアー） | 上位 | merge / contract / billing で decider に切り替えて最上位。sacred だけでは切り替えない |
| `decider` | 最上位 | `--failure first` / `executor` で上位、`judgment` か無しで最上位 |
| `explore` / `summarize` | 最安 | 上げない |

切り替えは `request` が行う。使う entry は構成の `decider`、返す role は `decider`、指示書は phase のもの。`--failure` が効くのは W と phase `decider` だけで、切り替えたレビューには効かない。本体は role が `decider` なら `subagent_type: dev-workflow:decider` で起こす。

### 6. 残量モードの適用

適用は executor によらず、構成の上限より先に行う。順は次のとおり。

1. depleted: 全 phase を中位にする（最安も中位へ）
2. throttled: 上げていない役は中位まで下げる。W を上げた場合と role が decider の場合は上位まで下げる。最安はそのまま
3. exhausted、および reserve かつ `--unmanned`: 上位まで下げる

abundant と conserve は動かさない。未知の明示値は Fable が conserve、共有枠が throttled（`session-tripwires.sh` 136 行目に合わせる）。

Codex にも Claude の残量モードを効かせる。「提供元を入力にしない」に従うため。depleted の Codex explore は sol/low になるが、実機の models_cache で対応を確認済み。

### 7. 残量モードの導出

明示 env を優先し、無ければ起動 account の実効値から導出する。`usage_view.py` に関数を足して `codex-develop.py` から呼ぶ。入力は `slot_view` の `fable_weekly_pct` / `fable_resets_epoch` / `weekly_all_pct` / `weekly_resets_epoch` で、式は `session-tripwires.sh` 92-122 行目と同じ。データ無しは conserve / ok。`session-tripwires.sh` と `agent-model-guard.sh` は触らない。

### 8. 出力の欄

| 欄 | 中身 |
|---|---|
| `requested_tier` | 規則が決めた格 |
| `tier` | 残量モード適用後の格。構成によらず同じ |
| `tier_reason` | 格が変わったときの原因のモード（`SHARED_BUDGET_MODE=depleted` など）。変わらなければ `unchanged`。両方効くときは共有枠モード |
| `tier_cap` | entry の値。無ければ null |
| `executed_tier` | `tier` を `tier_cap` まで下げた格 |
| `requested_model` | `requested_tier` を対応表で引いた値 |
| `model` | `executed_tier` を対応表で引いた値。本体が使う最終値 |
| `budget_modes` | `{"fable": <値>, "shared": <値>}`。未知の値は読み替えたあとの値 |

格の欄は stdout だけに出す。依頼ファイルの欄は `codex-worker.py` が限定しているので足さない。

### 9. tier-model

`codex-develop.py tier-model --executor <executor> --tier <格>` は `{executor, tier, model}` を返す。未定義は `status: blocked` と exit 2。argparse の `choices` を使うと blocked の JSON が出ないので、値の検査は本体でする。

### 10. 聖域の食い違い

聖域パスだけではレビューを上げない側に揃える。`pre-classification.md` 20 行目と `decision-criteria.md` 106 行目を直す。エージェント設定が製品であるリポではほぼ全実装が聖域に当たり、上げると Fable の枠の大半を使うため。

### 11. #613 のファイルとテスト

`model-resolution-current.md` は削除する。`test_model_resolution_current.py` はファイル名を保ち、役 × 構成 × 12 モード × 入力で `tier` が同じになることをリテラルの期待値で確かめる形に改める。入力は単独の 10 通り（なし・4 分類・設計判断・失敗 3 段・unmanned）に、W の失敗で下がらない組など scenario の組み合わせを足す。ケース数が数千になるので、遅ければ git の呼び出しを差し替える。

### 12. 変えないもの

- 再開前の上限確認は本体の文章規則のまま
- 失敗の昇格は入力だけ足す。手順（`escalation-tripwires.md`）は #424
- `model-tiers.md` の「ティア → opts.model」表は残し、Claude 列と対応表が一致するテストを足す
- `rules/subagent-model-selection.md` は触らない。「中位（重めは opus）」が今回の上位に当たる点を `model-tiers.md` に書く
- V と引き継ぎの判定役は `request` を通らない。SKILL.md の行は今の値のまま格の語を添える（V は 中位（`sonnet`）、判定役は 上位（`opus`））

issue が挙げた `worker.md`「重要実装の事前分類」は `pre-classification.md` へ移っていて、`worker.md` は索引になっている。直す先は `pre-classification.md` で、`worker.md` は触らない。

### #613 の食い違いの解消

印の定義と対象は `model-resolution-current.md` 79-92 行目のもの。

| 食い違い | 解消後 |
|---|---|
| †C: executor=codex のセルは残量モードでも設計判断でも変わらない | 同じ格の規則を通す。格は Claude と同じになる。モデルは対応表で引くので、W の上位は sol のまま、throttled / exhausted の decider は astra から sol、depleted の luna は sol になる |
| †W（depleted を除く）: W は sonnet 固定 | `--pre-class`・`--design-judgment`・`--failure executor` で上位になり、Claude では opus |
| †R: throttled / depleted の 8 モードでレビューが opus のまま | `tier` が中位で sonnet。`requested_model` は opus のまま残る |
| †H: depleted の haiku | 全役を中位に固定するので sonnet |
| †D: decider の全 12 モードが fable 固定 | `--failure first` / `executor` で上位。残量モードの上限も `request` が適用する |
| W の失敗後（文章に無い） | 事前分類に当たる W は `--failure` のどの値でも上位のまま。下がらない |
| throttled の haiku（読み取り） | 最安のまま。`decision-criteria.md` の共有枠モードの節に 1 行足す |
| 聖域（文章間の食い違い） | Decision 10 のとおり、聖域パスだけではレビューを上げない |
| G: 文章は sonnet 固定、adapter は implement entry | 格は中位で上げない。entry は implement のままなので、`codex-economy` の G は `tier_cap` で luna のまま |

読み替えは次の 3 点。

- †W の depleted 24 セルの印は余分。request の sonnet は depleted の文章既定と同じなので、† の定義に当たらない。解消の対象から外す
- W の行の「役自身のモデルは変わらない」は SKILL.md の昇格と食い違う。SKILL.md のとおり実行側の失敗で W は上位になる
- 「落とす」は `decision-criteria.md` の throttled 行の語で、depleted 行は「全役割 Sonnet 固定」。`model-resolution-current.md` 71 行目は depleted の語を取り違えている。throttled は下げるだけなので haiku はそのままで、depleted は固定なので haiku も sonnet に上がる

## Risks / Trade-offs

- [Codex では上位に上がってもモデルは sol のまま] → `tier` は上位になるので記録で区別できる。上位に別の系統を当てるかは #424 の実績を見て対応表を直す
- [depleted で Codex の explore が luna から sol に上がる] → 「提供元を入力にしない」の帰結として受け入れる。Codex の枠の消費は少し増える
- [Claude の枠が詰まると Codex の astra も sol に下がる] → 同じ理由で受け入れる。`tier_reason` に原因が出る
- [`codex-economy` は事前分類の W でも `tier_cap` で luna のまま] → 構成の選択として受け入れる。`tier` と `executed_tier` の差で見える
- [`usage_view.py` と `session-tripwires.sh` に導出の写しが 1 つ増える] → 範囲外（#424・#615）。式が同じことを同じ入力のテストで固定する

## Migration Plan

外部 profile-file の version 1 は拒否する。利用者は `version` を 2 にし、各 entry の `model` を消す。`luna` のように上の格を落として使っていた entry は `tier_cap` を足す。完全なモデル ID を固定していた人は、旧形式 `--account --model` に移る。手順は `codex-develop-explicit.md` と `docs/codex-develop.md` に書き、`changes/614.md` に BREAKING として残す。

戻すときは PR を revert する。保存された状態は無く、`execution_config` は request ごとに作り直される。
