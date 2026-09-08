## 1. 決める役の種別を作る（Red → Green）

- [x] 1.1 `plugins/dev-workflow/tests/decider-agent.bats` を新規作成し、`plugins/dev-workflow/agents/decider.md` が存在すること・frontmatter が `model: fable` と `tools: Read, Grep, Glob` を持つこと・`plugins/dev-workflow/.claude-plugin/plugin.json` の `agents` に `./agents/decider.md` があること・本文に入力契約（記録先の本文とコメントを呼び出し側が貼る / 失敗の出力 / 対象ファイルのパス / 実行役の return）と出力の 3 点（原因の分類 / 実行役がそのまま実行できる指示 / 次の実行役のモデル）・コードを書かない旨・記録先への投稿は呼び出し側が行う旨があることを assert する（この時点では Red）
- [x] 1.2 同ファイルに、`plugins/*/agents/*.md` を走査して frontmatter の `model` が Fable（`fable` / `claude-fable-*`）の定義の `tools` に Edit / Write / NotebookEdit / Bash が含まれないことを assert するテストを足す（違反時にどの定義かを出力する）
- [x] 1.3 `plugins/dev-workflow/agents/decider.md` を新設する（frontmatter の書式は `plugins/casting/agents/casting-arbiter.md` に倣う）。本文には入出力契約に加えて、記録先への投稿は呼び出し側の責務であること・Opus で立てるときも種別は `dev-workflow:decider` のままで `model` だけ変わることを書く。6.1 の `agents` 宣言と合わせて 1.1 / 1.2 が緑になることを確認する

## 2. ガードを拡張する（Red → Green）

- [x] 2.1 `plugins/dev-workflow/tests/agent-model-guard.bats` に新しい assert を足す（この時点では Red）: `general-purpose` への `model: "fable"` が deny され理由に `dev-workflow:decider` と `sonnet` / `opus` が含まれる／`model: "claude-fable-5-1"` も同じく deny／`subagent_type` 未指定・`Explore`・`Plan`・`casting:casting-arbiter` への `fable` も deny／`dev-workflow:decider` への `fable` は許可（無出力・exit 0）／`general-purpose` への `opus` / `sonnet` / `haiku` は従来どおり許可／`dev-workflow:decider` への `model: "opus"` と `model` 省略も許可（決める役は種別を固定して `model` だけ切り替えるため）／`DEV_WORKFLOW_MODEL_GUARD=off` では `general-purpose` への `fable` も許可
- [x] 2.2 `plugins/dev-workflow/scripts/agent-model-guard.sh` に Fable 判定を足す。挿入位置は `fork` の早期 return より後、`if model: sys.exit(0)` より前。Fable の検出は前後空白除去＋小文字化のうえで `fable` の完全一致と `claude-fable` の前方一致。許可種別は `DECIDER_TYPES = {"dev-workflow:decider"}` のリテラルとし、環境変数で足せるようにしない
- [x] 2.3 同スクリプトの `model` 未指定時の拒否文から `fable（最終 verify・マージ権限・層間契約・課金/法務）` を外し、`fable` は決める役の種別（`dev-workflow:decider`）でだけ使える旨に差し替える（`agent-model-guard.sh` 86 行目付近）
- [x] 2.4 `plugins/dev-workflow/tests/agent-model-guard.bats` の既存 14 テストと `tripwire-hook.bats` が緑のままであることを確認する（exit code を出力に残す）

## 3. 昇格ラダーを書き換える

- [x] 3.1 `plugins/dev-workflow/tests/model-escalation-policy.bats` 60〜64 行目付近の旧ラダー（sonnet → opus → fable の 1 段昇格）の assert を、新ラダー（原因分類で決める役 / 実行役の一方だけを上げる・実行役の上限 opus・fable は `dev-workflow:decider`）の assert に直す（この時点では Red）
- [x] 3.2 `plugins/dev-workflow/templates/escalation-tripwires.md` 42 行目付近の失敗ループの記述を、決める役 / 実行役の分離ラダーの表に置き換える
- [x] 3.3 `plugins/dev-workflow/skills/develop/SKILL.md` 85 行目・106 行目を新ラダーに合わせる
- [x] 3.4 `plugins/dev-workflow/skills/develop/references/roles/worker.md` 152 行目の失敗ループを新ラダーに合わせ、return に「指示のどこまでやって、どこで何が起きたか」を書く義務を足す
- [x] 3.5 `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` 55 行目・`plugins/dev-workflow/skills/pr-review-gate/SKILL.md` 133 行目を新ラダーに合わせる
- [x] 3.6 決める役は段階によらず `subagent_type: dev-workflow:decider` に固定して `model` だけ切り替える（`general-purpose` に読み替えない）ことを、3.2〜3.5 で触る各ファイルのラダー記述に含める
- [x] 3.7 `rules/subagent-model-selection.md` に「最上位ティアは決める役の種別（`dev-workflow:decider`）でだけ spawn する」「強制層は `plugins/dev-workflow/scripts/agent-model-guard.sh`」を各 1 行足す
- [x] 3.8 3.1 が緑になり、`tests/rules-sync.bats` も緑であることを確認する

## 4. 重要実装の事前分類表を書き換える

- [x] 4.1 旧表を assert している 4 テストを新表の assert に直す（この時点では Red）: `plugins/dev-workflow/tests/model-escalation-policy.bats` 22〜31 行目付近、`develop-roles.bats` 144 行目付近、`spec-decision-and-review.bats` 123 行目付近、`develop-skill.bats` 212 行目付近
- [x] 4.2 `plugins/dev-workflow/skills/develop/references/roles/worker.md` 130〜143 行目（正本の表）を書き換える: マージ権限・層間契約・課金/法務の「1 周目」を `fable` から `opus` にし、聖域パスの `opus` は据え置き。読んで判断する役（R1・G が要求するレビュアー）が該当するときは `subagent_type: dev-workflow:decider` で spawn し `general-purpose` に `model: fable` を付けないこと、W の上限が `opus` であることを明記する
- [x] 4.3 `plugins/dev-workflow/skills/develop/SKILL.md` 72・75・97・98・100・102 行目を新表に合わせる
- [x] 4.4 `plugins/dev-workflow/skills/develop/references/roles/spec-reviewer.md` 28 行目・`references/roles/gate-runner.md` 34 行目・`plugins/dev-workflow/skills/pr-review-gate/SKILL.md` 148 行目・`plugins/dev-workflow/README.md` 14 行目を新表に合わせる
- [x] 4.5 R1 を `dev-workflow:decider` で起こす経路の記録手順を反映する: `plugins/dev-workflow/skills/develop/references/roles/spec-reviewer.md` の「結果を記録先に記録する（R1 が投稿する）」節（62 行目付近）と「レビュアーへの入力」節（32 行目付近）に、decider 経路では R1 が `gh` を実行せず return し本体が同じ書式で代理投稿すること・記録先の本文と関連コメントは呼び出し側が入力文に貼ることを書き分ける
- [x] 4.6 `plugins/dev-workflow/skills/develop/SKILL.md` 47 行目「記録先のコメントは各役割が自分で投稿する」に decider 経路の例外（本体が代理投稿する）を足し、1 ループの (2) の行にも同じ例外を書く
- [x] 4.7 `plugins/dev-workflow/skills/develop/references/roles/worker.md` の「仕様化する場合」（92 行目付近）に、対象の change が既に存在し artifact が揃っているなら `/opsx:ff` を再実行せずそのまま return する旨を足す
- [x] 4.8 4.1 の 4 テストが緑になり、`plugins/dev-workflow/tests/spec-decision-and-review.bats` と `develop-skill.bats` が緑であることを確認する

## 5. Workflow 経路の実測

- [x] 5.1 `Workflow` スクリプト内の `agent(prompt, {model:'fable'})` が `Agent` の PreToolUse を通るか実測する
- [x] 5.2 実測結果（通る / 通らない、確認方法）を issue #250 にコメントする。通らないなら別 issue を切り、その番号もコメントに残す（この change では塞がない）

## 6. リリースと検証

- [x] 6.1 `plugins/dev-workflow/.claude-plugin/plugin.json` に `agents: ["./agents/decider.md"]` を足す（casting プラグインの宣言に揃える）
- [x] 6.2 `plugins/dev-workflow/.claude-plugin/plugin.json` を 2.4.1 → 2.5.0 に上げ、`.claude-plugin/marketplace.json` の該当バージョンも合わせ、両ファイルの `description` に残る旧表の文言（「マージ権限・層間契約・課金/法務は 1 周目から fable」「実装品質起因のときだけ前回モデルの 1 段上（sonnet → opus → fable）」）を新しいラダーと事前分類に書き換え、`CHANGELOG.md` に追記する
- [x] 6.3 `scripts/test.sh` を全件実行し、exit code と失敗件数を出力に残す（緑であること）
- [x] 6.4 `openspec validate fable-decider-only --strict` が通ることを確認する
