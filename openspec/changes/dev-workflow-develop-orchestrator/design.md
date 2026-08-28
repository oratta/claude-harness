## Context

dev-workflow 1.13.0 の `github-issue` スキルは、本体セッションが Step A〜D を自分で実行する手順書で、仕様レビュー（#191）と pr-review-gate の別コンテキストレビューだけをサブエージェントに出す構造になっている。Claude Code のサブエージェントは Agent ツールを持たない（孫を spawn できない）ため、この手順書をサブエージェントに渡すと、別コンテキストを要する工程がすべて自己レビューに退化する。本 change は「本体はオーケストレータ、作業は役割別サブエージェント」に反転し、あわせて入口を issue から解放する。制約: pr-review-gate の #193 の契約（`対象 HEAD:` 規約・記録先の探索順・仕様宣言の突き合わせ）は auto-merge 配備済みリポの合格条件と繋がっているので変えない。

## Goals / Non-Goals

**Goals**
- 本体が Edit でコードを書かず、レビューを代行しない構造を SKILL.md の規定として固定する
- 別コンテキストを要する工程（R1・G）を本体が起こす形にして、エピックの子を並列で回しても孫問題が起きないようにする
- issue の無い依頼でも仕様化判断・仕様レビュー・仕様宣言が記録先（Draft PR）に残るようにする
- エピックの条件・作り方・回し方・完了条件を 1 箇所に置く

**Non-Goals**
- pr-review-gate の手順自体の変更（G の手順書として据え置く）
- auto-merge workflow テンプレートの変更
- loop-dev-agent の外形（ラベル・Draft PR・Review Queue）の変更。委譲先の名前の付け替えだけ行う
- 配備済みリポの `docs/agent-loop.md` の自動更新（再生成は各リポの運用）

## Decisions

### D1. 役割は W / R1 / G の 3 つに固定し、指示書を `references/roles/` に分ける
SKILL.md 本文は本体向けの「誰をいつ起こすか」だけを持ち、各役割が読む手順は別ファイルにする。理由: サブエージェントに渡すプロンプトは「この 1 ファイルを読め」で完結させたい（SKILL.md 全体を渡すと本体向けの禁止事項と役割向けの手順が混ざる）。代替案として「1 ファイルに役割ごとの節を置く」を検討したが、役割ごとに読む範囲を切り出す指示が毎回必要になるので却下。

### D2. 実行戦略の 3 分岐を廃止し「W のモデル」に畳む
solo / delegate+verify / workflow 型は「本体が自分でやるか委譲するか」の判断だった。本体が常に委譲する構造では選択肢が W のモデルしか残らない。4 象限モデル・決定論的シグナルの収集コマンド・self-contained 条件はすべて削除する。残量モード（`FABLE_BUDGET_MODE`）の表と自動導出は、hooks（`session-tripwires.sh` / `usage-probe.sh`）が参照しているのでそのまま `references/decision-criteria.md` に残す。

### D3. 入口 0: issue が無ければ Draft PR を記録先にする（issue を自動で切らない）
issue を切ると追跡対象が増え、閉じる手間が発生する。GitHub の「open a draft PR early」の慣行に合わせ、最初の commit の時点で Draft PR を開き、受け入れ条件を PR 本文に書く。pr-review-gate の手順 5 は既に「PR 本文に issue 参照が無い PR は PR 自身のコメントに記録してよい」（#193）となっているので、照合側の変更は不要。issueify フォールバックは残すが、既定ではなく「追跡・キュー・議論が要る」とユーザーが選んだときの経路にする。

### D4. G が孫を持てない問題は `needs-reviewer` の return で本体に戻す（issue に無い決定を埋めた）
pr-review-gate の手順 2 は「full = Codex CLI、light または Codex 不可 = Task サブエージェント」で、後者は Agent ツールを要する。G はサブエージェントなので自分では起こせない。選択肢は (a) G が本体に `needs-reviewer` を return し、本体が別のレビュアー（既定 `opus`。マージ条件・聖域・層間契約に触れれば `fable`）を spawn して要約を G に SendMessage で渡す、(b) 本体が G を起こす前に常にレビュアーも起こしておく、(c) G のレビューを本体が代行する。(c) は「本体がレビューを代行しない」に反する。(b) は Codex で済む full の場合に無駄なレビューが走る。(a) を採る。G はレビュー以外の手順（1・3・4・5）を自分で行い、レビュー要約を受け取った後に手順 3 以降を続ける。

### D5. `commands/work-issue.md` はエイリアスとして残す
他リポの運用メモや memory に `/work-issue` が残っている。エイリアスは develop.md へのポインタだけを持ち、5 分岐の本文は develop.md にのみ置く（既存テスト `work-issue-command.bats` の「正本は 1 箇所」の思想を維持）。

### D6. 昇格トリップワイヤーの「規模超過 → workflow 型」は「分割へ」に付け替える（issue に無い決定を埋めた）
テンプレート `templates/escalation-tripwires.md` のトリップワイヤー 1 は `/lr:e` 系への乗り換えを指示している。develop から workflow 型を外すので、規模超過の乗り換え先は「W を止めて本体に return し、本体が change / 子 issue（エピック）に分割する」にする。`/lr:e` 自体は longrun プラグインの経路として残るため、テンプレートの文面は「分割（エピック化）または /lr:e 系」の両方を挙げる。loops 憲法テンプレートの対応行も同じ文面に揃える。

### D7. loops 側は名前の付け替えだけ行い、Step 3 の外形は変えない
`agent-loop-template.md` / `recipes/loop-dev-agent.md` / loops `plugin.json` の `github-issue` を `develop` に置換し、loops のバージョンを上げる。unmanned の「複数 change → サブ issue に分割してサイクル終了」はエピックの「子 issue」に相当するので、文面をエピック用語に寄せるが挙動は変えない。

## Risks / Trade-offs

- [配備済みリポの憲法 `docs/agent-loop.md` が `github-issue` を Skill ツールで呼び続ける] → 憲法は各リポで再生成する運用。本 change の PR 本文と loops の README に「テンプレート更新後に再生成」を明記する。移行期間は `github-issue` 削除で Skill 呼び出しが失敗し、loop-dev-agent は失敗コメント → `agent-blocked` の既存セーフティネットに落ちる（無言で壊れない）
- [本体が「Edit でコードを書かない」を守らない] → 文書アサーション（bats）で規定の存在は保証できるが行動は保証できない。pr-review-gate の別コンテキストレビューが最後の網
- [W を fable で起こす頻度が上がり Fable 枠を消費する] → 事前分類に当たるときだけ fable。残量モードの表（`exhausted` は全経路 opus）はそのまま効く
- [Draft PR を記録先にした PR で、pr-review-gate の照合が issue を探しに行って空振りする] → 手順 5 の探索順は「PR 本文に issue 参照が無ければ PR 自身のコメント」（#193）で既に対応済み。本 change では文言の参照先だけ直す

## Migration Plan

1. `skills/develop/` を新設し、`skills/github-issue/` の本文を役割別に移す（同一 PR 内で削除まで行う。中間状態を作らない）
2. `commands/develop.md` を新設し `commands/work-issue.md` をエイリアス化
3. pr-review-gate・escalation-tripwires・README・plugin.json・marketplace.json の参照を付け替え、バージョンを上げる（dev-workflow 1.13.0 → 2.0.0、loops 0.24.0 → 0.25.0）
4. loops テンプレート・レシピの委譲先を付け替える
5. bats 4 本を develop の構造に移行し、`scripts/test.sh` 全件合格を確認
6. ロールバック: PR を revert すれば `github-issue` が戻る。他リポへの伝播はプラグイン更新のみ

## Open Questions

- なし（D4・D6 は issue に無い決定を本 change 側で埋めたもの。仕様レビューと PR の説明で明示する）
