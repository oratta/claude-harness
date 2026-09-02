## Context

pr-review-gate は「宣言・証拠が現在の HEAD SHA を含む PR コメントとして実在することを API で実測してから passed を付ける」fail-closed の構造を持つ（`対象 HEAD:` 規約）。auto-merge workflow も同じコメントを機械照合する。仕様の有無はこの構造に乗っていない。先行 change で入口（github-issue Step B / Step D）の記録書式が決まり、`references/spec-review.md`「判断記録の契約」に照合規則（1 行目の正規表現・最新 1 件・PR→issue は本文最初の Closes/Fixes/Refs）がある。

制約: リポ非依存（flatmate 固有のパス構成を固定しない）。auto-merge workflow は配備 4 リポにテンプレ展開済みで、合格条件を変えると全リポへの伝播が要る。スキルの規範は bats で「SKILL.md に規定が存在する」形で検証する（既存 `dev-workflow-pr-review-gate` の Scenario 形式）。

## Goals / Non-Goals

**Goals:**
- 仕様化判断の記録が無い PR、記録と矛盾する PR（「する」なのに openspec 差分もレビュー APPROVE も無い）を出口で止める
- github-issue スキルを通らなかった経路でも、出口で記録を取りに戻らせる
- 「変更なし」宣言の妥当性を機械的な材料（規範パスへの接触と openspec 差分の有無）で裏取りする

**Non-Goals:**
- auto-merge workflow の合格条件変更（別 issue。伝播を伴う）
- 仕様の**質**の審査（先行 change の仕様レビューが担う）
- `.spec-touch-paths` の各リポへの配布

## Decisions

### D1. 仕様宣言は手順 3 の第 3 のコメント、`対象 HEAD:` 規約に乗せる
- 採用: `## 仕様宣言` 見出し・1 行目 `対象 HEAD: <40 桁>`・本文は次の 2 形のどちらか
  - `仕様: 更新した — change <name>（archive 済み）／仕様レビュー: APPROVE（<issue コメント URL>）`
  - `仕様: 変更なし — 理由: <なぜ spec 不要か。規範パスに触れているならその理由も>`
- 理由: リスク宣言・動作確認と同じ規約に乗せれば、手順 5 の SHA 照合式（`contains($HEAD_SHA)` → 1 行目抽出）をそのまま流用でき、将来 auto-merge に組み込むときも同じ照合になる
- 却下: リスク宣言コメントに節を足す（リスク宣言の文言は書き換え禁止で、仕様宣言だけ出し直したいときに困る）

### D2. 手順 5 で 3 見出しの実在＋issue 記録との整合を照合する
- 採用: SHA 照合の出力に「リスク宣言」「動作確認」「仕様宣言」の 3 見出しが揃うことを要求。加えて元 issue（PR 本文最初の Closes/Fixes/Refs）の最新 `仕様化判断:` コメントを取り、次の表で判定

| issue の記録 | 合格に必要な状態 |
|---|---|
| `仕様化判断: する` | PR の変更ファイルに `openspec/` が含まれる **または** 宣言が指す change が base で archive 済み（スタック PR）、**かつ** issue に `仕様レビュー: APPROVE` がある。仕様宣言は「更新した」形 |
| `仕様化判断: しない` | 仕様宣言は「変更なし＋理由」形で、PR に `openspec/` 差分が無い（あれば矛盾＝合格しない）。`spec-touch-check.sh` が規範パス接触を報告していれば理由にその言及があること |
| 記録なし | **合格しない**。今から判断して issue に `仕様化判断:` を投稿する（「する」なら仕様化からやり直し）。issue が無い PR は PR 自身のコメントに同書式で記録してよい |

- 理由: 記録なしを通すと本体直回し経路の穴が残る。issue 無し PR まで拒むと hotfix が止まるので、PR コメントへの記録を逃げ道にする。ただし PR 本文に issue 参照があれば issue 側が正（issue に記録が無ければ issue に投稿する）で、PR コメント経路は issue 参照が無い場合に限る

### D3. `spec-touch-check.sh` は判定材料を出すだけ、判定はスキル手順が持つ
- 採用: `scripts/spec-touch-check.sh <owner/repo> <PR番号>` が `SPEC_TOUCH=yes|no`・`OPENSPEC_DIFF=yes|no`・触れた規範パス一覧を出力。exit 0 = 材料出力成功、exit 2 = 規範パスに触れて openspec 差分なし（注意喚起）、exit 1 = 取得失敗
- 規範パスの既定は `docs/` `.claude/` `templates/` `scripts/` `CLAUDE.md` `AGENTS.md`。リポ直下の `.spec-touch-paths`（1 行 1 prefix、`#` コメント可）があればそれで**置き換える**
- テスト容易性: `SPEC_TOUCH_FILES`（改行区切りのファイル一覧）が設定されていれば `gh pr diff --name-only` を呼ばない
- 却下: スクリプト内で合否を決める（記録との整合は issue コメントを読む LLM 側の判断が要る）

### D4. auto-merge は別 issue
- 仕様宣言コメントは `対象 HEAD:` 規約に乗っているので、auto-merge 側は「3 見出しの実在」を足すだけで組み込める。伝播は別 issue で扱う

## Risks / Trade-offs

- [PR 1 本あたりコメントが 1 通増える] → 定型 2 形なので実務コストは小さい
- [issue の無い PR で記録が PR コメントに散る] → 照合順「issue → PR」を契約に明記
- [既定の規範パスが合わないリポ] → `.spec-touch-paths` で置き換え可。無ければ既定で動く（fail-soft）
- [auto-merge が仕様宣言を見ないままの期間] → スキル手順が passed を付けない限りマージされないので、手順が守られる範囲では穴にならない
