## Why

今の develop は「テスト作成は全経路で必須」（`references/decision-criteria.md`「どの判定でも変えないもの」）で、本体は Edit でコードを書かないので、1 語の書き間違いの修正にも回帰テストと作業担当（W）のサブエージェントが入る。例: 判例ファイルの観点名 1 語の直し（oratta/claude-harness#1581）は、既存のチェックスクリプト `casting-check.sh` を走らせれば確かめられるのに、develop を通すと新しいテストを書くことになる。会話で頼まれた修正も develop から入るようにする対の issue（#1583）が入ると、この重さがすべての些細な修正にかかる。

主の決定（issue #1584 の本文。テスト必須を緩めることは 2026-11-07 に主が承認）: 「仕様化しない」の一覧に当たる些細な修正で、既存のテストかチェックで確かめられるものは、新しいテストと W の起動を省き、本体が直接直してよい。記録先・判断の記録・pr-review-gate は残す。

## What Changes

- 仕様化判断の「仕様化しない（コード直行）」と同じ並びに「軽い通し方」の小節を足す。当てる条件は、変更が次の 6 種類のどれか 1 つだけでできていること（typo・lint 指摘の修正・コメントの修正・フォーマットの変更・ワンライナー fix・挙動を変えない設定値の変更）と、既存のテストかチェックのコマンドで変更を確かめられること。5 種類（typo・lint・コメント・フォーマット・設定値）は挙動を変えないことを、ワンライナー fix は明白なバグの 1 行修正で直し方に選択肢がないことを条件にする（ワンライナー fix は挙動を変えるのが本来なので、挙動不変は求めない）
- 記録先がまだ無い会話の依頼では、本体が受け入れ条件を整理 → 軽い通し方を当てるかを決める → 当てるなら本体が Draft PR を作る → 判断を記録する、の順にする（入口 0 の「W が Draft PR を作る」に、軽い通し方のときだけの例外を足す）
- 軽い通し方の PR で、確認を条件内で通ったあとに通常のレビューが修正を求める failed を返したら、本体は W を `段: spec` で新しく起こす（W はまだ起きていないので再開しない。本体も直さない）。W は `通し方:` の行の無い判断を投稿し直してテストを書き、以後は通常の通し方になる
- 省くもの: 新しいテストの作成と W の起動（本体が直接直す）。残すもの: 記録先（issue、無ければ Draft PR）・仕様化判断の記録・pr-review-gate（重さはゲートが今どおり判定する）
- 「どの判定でも変えないもの」の「テスト作成は全経路で必須」に、軽い通し方だけを例外として書く（既存のテストかチェックを走らせることが、新しいテストの代わりになる）
- SKILL.md の禁止事項「本体は Edit でコードを書かない」に、軽い通し方だけを例外として書き、1 ループの (1) の前に、軽い通し方では (1)〜(3) の W を起こさず本体が直して (4) の G へ進む分岐を足す。G が軽い通し方の条件外として failed を返したら、W を `段: spec` で起こして通常の通し方に戻す
- 仕様化判断のコメントの 1 行目は `仕様化判断: しない` のまま変えず、2 行目以降に `通し方: 軽い`・`種類: <6 種類のどれか>`・`確かめ方: <コマンド>` の 3 行を書く（書式の正本は `references/roles/spec-reviewer.md`「判断記録の契約」）
- pr-review-gate の前提確認と重さ判定の段（`stages/prepare.md` の手順 1）に、`通し方: 軽い` の行がある PR だけ、差分が条件内かを確かめる手順を足す。機械で測る点（1 行目が「しない」・`種類:` の値・`確かめ方:` の行・`openspec/` の差分が無い・ワンライナー fix なら変更が 1 ファイル 1 行）と、G が差分を読んで判断する点（全部の変更が宣言した種類に収まり、挙動が変わらない）を持ち、外れていれば `agent-review:failed` にして failed を返す。結果は PR コメント（1 行目 `軽い通し方の確認: 条件内` / `軽い通し方の確認: 条件外`）に残す
- 前提確認と重さ判定の段が返しうる Status に failed を足す（`gate-runner.md` の段の表）
- 合格処理の段の動作確認（`stages/pass.md` の手順 4）で、軽い通し方の PR は `確かめ方:` のコマンドを G が走らせて表の 1 行にする

変えないもの: 仕様化判断の 1 行目の正規表現、「仕様化しない」の一覧の中身（軽い通し方はその一部を使い、新しい線引きを作らない）、W が通る経路のテスト必須（`worker/spec.md` の「どの判定でもテスト作成は必須」は W が起こされる経路の規則として残る）、pr-review-gate のレビュー重量の判定・三表の照合・宣言・合格処理の整合表、文言合わせの通し方。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-spec-review`: 軽い通し方の Requirement を足す（当てる条件・省くもの・残すもの・記録の書式・本体の手順・途中で外れたとき・モード・守備範囲）
- `dev-workflow-execution-strategy`: 「Step B 基準の重心移動」のテスト作成の必須性を緩めない MUST NOT に、軽い通し方だけを例外として書く
- `dev-workflow-develop`: 「本体はオーケストレータ専任でコードもレビューも書かない」に軽い通し方の例外を足す。「入口 0 は記録先を決める」に、軽い通し方のときだけ本体が Draft PR を作る例外と順序を足す。「1 ループは W→R1→W→G の順で回る」に軽い通し方の分岐と、条件外の failed と通常の failed のあとの戻し方を足す。「G は段ごとに新しく起こし、SendMessage で再開しない」の段の表で、前提確認と重さ判定の返しうる Status に failed を足す
- `dev-workflow-pr-review-gate`: 軽い通し方の PR の条件を前提確認の段で確かめ、外れていれば failed にする Requirement を足す

## Impact

- 指示書: `plugins/dev-workflow/skills/develop/references/decision-criteria.md`（Step B）、`skills/develop/SKILL.md`（本体の役割の禁止事項・1 ループの (1) と (4) の failed）、`references/roles/spec-reviewer.md`（判断記録の契約）、`references/roles/gate-runner.md`（段の表）、`skills/pr-review-gate/stages/prepare.md`（手順 1 と G として動くときの failed）、`skills/pr-review-gate/stages/pass.md`（手順 4）
- テスト: `plugins/dev-workflow/tests/` に bats を 1 本足す（文書の記述と、前提確認の段の照合コマンドを fixture で走らせる確認）。既存の `develop-skill.bats`・`spec-wording-sync-light-path.bats`・`develop-roles.bats` などは通ったままにする
- 起動時に読む量: `skills/develop/SKILL.md` は `tests/develop-startup-budget.txt` の予算まで残り数バイトしか無い。足した分と同じ以上を同じファイルの中で言い換えるか references へ移して削り、予算は動かさない。常時注入の固定分（`tests/injection-budget.txt`）は触らない
- 変更の記録: `plugins/dev-workflow/changes/1584.md`
- 触らないもの: `commands/develop.md` と develop の説明文（#1583 の範囲。親エピック #1585 の注意書き）、`plugins/dev-workflow/scripts/`、`stages/triage.md`・`stages/hold.md`・`declarations.md`、Codex の経路（`references/codex-develop.md`）
- 受け入れたリスク（主の決定）: 軽い通し方に入れてよくない修正がテスト無しでマージされうる。頻度は不明。導入後数週間、`通し方: 軽い` の記録を見直して確かめる
- 記録先: issue #1584（エピック #1585 の子）。PR は `Closes #1584` にする
