## Context

`claude plugin eval <target>` は `<plugin>/evals/<case>/` の `prompt.md` と `graders/*.md` を読み、各ケースを既定 3 回、プラグインありとなしの 2 腕で実行してスコアと差（Δ）を出す。grader は `regex` / `tool_used` / `tool_order` / `file_exists`（無料）と `llm` / `baseline`（判定モデルを呼ぶ有料）。各 run は空の作業ディレクトリで始まる。`--ablation with-without` では `tool_used: Skill` の grader は採点から外れ、プラグインが発火したかの表示だけになる。

## Goals / Non-Goals

**Goals:**
- 3 つの測定項目（Skill の発火、casting の返信前チェック、破壊的 git 操作の前で止まる）を、過去の失敗に基づくお題で測れるようにする
- 初回は 10 件程度を目標に、受け入れ条件は dev-workflow 5 件以上・casting 1 件以上
- 実行手順と費用を docs に残し、誰でも同じ手順で回せる

**Non-Goals:**
- 閾値で CI を落とすこと（`--threshold` ゲート、CI への組み込み）
- 効果量（Δ）を合否に使うこと。記録のみ
- お題を 20〜50 件に増やすこと（後続）

## Decisions

1. **置き場所はプラグイン直下の `evals/`（既定）。** manifest の `experimental.evals` は使わない。理由: 既定のまま `claude plugin eval plugins/dev-workflow` で動き、`plugin.json` の description も触らずに済む。代替の `--eval-dir` 指定は実行のたびに引数が増えるので採らない。
2. **発火の測定は `tool_used: Skill` の `input_match` で行う。** ablation 下ではこの grader は採点外（with 腕の発火表示）になるため、各ケースに「結果」を測る grader（`llm` か `regex`）を最低 1 つ併置する。理由: 発火しただけで中身が外れるケースを拾え、Δ が発火表示だけで 0 にならない。
3. **casting は `llm` grader（短い返信を対象にした PASS/FAIL ルーブリック）。** 作業ディレクトリが空なので、配役表（project.md / local.md）はお題の prompt か `case.yaml` の setup で用意する。判定は「主へ上げる/上げない」の二択に絞り、聖域（権限設定の変更など）を上げる側と、観点を移譲済みで上げない側の両方を入れる。
4. **destructive-git-guard は「実行されなかった」ことを測る。** 空の作業ディレクトリに使い捨ての git repo を作らせる setup を置き、対象コマンド（`git reset --hard` など）を依頼する。Bash は `--allow-tools` で許可が必要。判定は、hook が拒否した結果、コマンドが実行されなかった状態（作業が残っていることを示す `file_exists` か、transcript への `regex`）で行う。plugin の PreToolUse hook が eval の run でも読まれるかは implement 段で最初に実機確認し、読まれない場合は測定項目 3 を「依頼を受けて確認を求めるか」（ルールの効き）に落とし、その旨を docs に書く。
5. **grader は無料のもの（`tool_used` / `regex` / `file_exists`）を主にし、`llm` は casting と中身判定に限る。** 理由: 費用と判定のぶれを減らす。判定モデルは既定の haiku、ぶれたら `--judge-model sonnet`。
6. **費用管理: `--max-cost-usd 10` を付け、部分実行（exit 2）は受け入れない。** 超えそうなら `-j` ではなく件数・`max_turns` を減らす。結果の `results/` は `.gitignore` に入れ、JSON の要点だけを PR 本文に貼る。

## Risks / Trade-offs

- [eval の run で plugin の hook が効かない可能性] → implement 段の最初に 1 ケースだけ `--runs 1 --ablation none` で確かめ、効かなければ Decision 4 のとおり測定項目を落として docs に明記
- [費用が上限 10 USD を超えて部分実行になる] → 10 件程度から始め、`max_turns` を小さく保つ。部分実行なら件数を減らして取り直す
- [llm grader のぶれ] → ルーブリックを具体的な PASS/FAIL にし、ぶれたら判定モデルを上げる
- [発火の測定が自然な言い回しに依存] → 依頼文はスキル名を含めず、実際の失敗時の言い回しから作る

## Migration Plan

新規ファイルの追加のみ。戻すときは `evals/` と docs のページを消す。

## Open Questions

- eval の run で `hooks/hooks.json` の PreToolUse が働くか（implement 段の最初に確認）
