## Context

issue #712 は 3 つのことを求めている。診断 3 コマンドを実行して結果を issue に記録すること、指摘のうち旧モデル向けの言い回しを rules とスキルから削ること、3 コマンドを予算値の見直し手順として `CLAUDE.md` の「常時注入の予算」節か docs に書くこと。

2026-10-08 に Claude Code 2.1.294 で 3 コマンドを実行した（結果の要点は https://github.com/oratta/claude-harness/issues/712#issuecomment-6055775344 ）。分かった事実は次のとおり。

- 対話セッション用の `/doctor prompt-audit` と `/skill-doctor` は、print モード（`claude -p "/doctor prompt-audit"`、`claude -p "/skill-doctor"`）で exit 0 で動く。サブエージェントや端末から実行できる
- `/doctor prompt-audit` は報告と提案差分を一時ディレクトリ（今回は `/tmp/claude-501/prompt-audit-20261008/`）に書き、リポジトリは書き換えない
- `claude plugin details <name>` は install 済みのプラグインにしか使えず、未 install だと `Plugin "<name>" not found` で exit 1 になる。値は install 済みの版のもので、作業ツリーの内容ではない
- `/doctor prompt-audit` はルール 10 本（`rules/*.md`）に編集案を 1 件も出さなかった。`grep -rn 'よく考え' rules/` は着手前から 0 件で、`慎重に`・`必ず確認` も `rules/`・`plugins/*/skills/*/SKILL.md`・`CLAUDE.md`・`output-styles/` に無い
- 旧モデル向けの言い回しとして挙がったのは、openspec CLI 1.2.0 が生成した `.claude/commands/opsx/*.md` と `.claude/skills/openspec-*/SKILL.md` だけ。「Think deeply.」が 2 ファイル、`IMPORTANT`・`MUST`・`NEVER` の強調が 18 ファイル（提案差分で 34 箇所）
- このリポジトリは public で、`/doctor prompt-audit` と `/skill-doctor` の出力には個人の `~/.claude/skills/` のスキル名が含まれる

既存の制約は 2 つある。`openspec/specs/injection-budget-gate/spec.md` の「予算ファイルの変更手続きを CLAUDE.md に定める」は、`CLAUDE.md` の該当記述を 1〜2 文に収めることを求め、「詳しい手順はテストの失敗メッセージ側に置く」としている（現状ちょうど 2 文）。`tests/agents-md-sync.bats` は `AGENTS.md` を `CLAUDE.md` と同期させる。

## Goals / Non-Goals

**Goals:**

- 予算値を見直す人が、3 コマンドの実行方法・読み方・記録先を 1 つの文書で分かる
- その文書に、予算テストが落ちたその場で辿り着ける
- 思考の深さを文で指示する言い回しが、リポジトリ内の常時注入の文書とスキル・コマンドから無くなり、戻ってきたらテストで分かる

**Non-Goals:**

- 削減量の数値目標を置くこと。issue の受け入れ条件に数値目標は無く、削った結果を記録するだけにする
- `tests/injection-budget.txt` の値を動かすこと。この change は測定対象のバイト数を変えない
- 診断が挙げた、旧モデル向けの言い回しではない指摘を直すこと。`CLAUDE.md:31` の「CI を将来追加する場合」が古い件、`CLAUDE.md:18` のマージ手順が `plugins/dev-workflow/references/commit-and-pr-operations.md:18` と食い違う件、`plugins/dev-workflow/skills/issueify/SKILL.md:61-62` の「AskUserQuestion でまとめて質問する」が `rules/communication-style.md` と逆の件は、issue の概要 2 の範囲（旧モデル向けの言い回し）に入らない。別の issue にするかは本体と主が決める
- 使われていないスキルやプラグイン（casting の 3 スキルなど）を外すこと。casting は hook の注入で動くので、スキルの起動回数だけでは判断できない
- 個人の `~/.claude/skills/` への指摘を直すこと。このリポジトリの外にある
- 3 コマンドを CI やテストから自動実行すること。モデルを呼ぶので費用がかかり、結果も実行ごとに変わる

## Decisions

### 手順は `docs/injection-budget-review.md` に書き、テストの失敗時の出力から指す。`CLAUDE.md` は書き換えない

`CLAUDE.md` は測定対象で、既存の要件が該当記述を 1〜2 文に制限している。手順を `CLAUDE.md` に書くと、削ろうとしている固定分を自分で増やすことになる。

検討した案:

| 案 | 採否 | 理由 |
|---|---|---|
| `CLAUDE.md` の「常時注入の予算」節に手順を書く | 不採用 | 固定分が増え、既存の「1〜2 文」の要件を外すことになる |
| docs に書き、`CLAUDE.md` に 1 文の案内を足す | 不採用 | 3 文になり既存の要件に反する。要件を緩めれば通るが、毎セッション載る 1 文に対して、読まれるのは予算を見直すときだけ |
| docs に書き、`tests/injection-budget.bats` の失敗時の出力から指す | 採用 | 既存の要件が詳しい手順の置き場をテストの失敗メッセージ側と定めている。予算を見直すのはテストが落ちたときなので、必要な瞬間に目に入る。固定分は 0 バイト増 |

受け入れること: テストが落ちていないときに自発的に見直す人は、`CLAUDE.md` からは手順に辿り着けない。`docs/` の一覧かテストのコメントから見つけることになる。

### 生成ファイルからは「Think deeply.」だけを削り、強調語は残す

`.claude/` 配下の該当ファイルは openspec CLI の生成物で、`openspec update` などで再生成すると元に戻る。

| 案 | 採否 | 理由 |
|---|---|---|
| 生成ファイルには触らない | 不採用 | issue の概要 2 が挙げる「よく考えて」の類に当たる指摘が実際に 1 種類あり、`.claude/skills/openspec-explore/SKILL.md` はスキルである。削らないと概要 2 でやったことが何も無くなる |
| 「Think deeply.」だけ削る（2 ファイル、各 1 文） | 採用 | 公式記事が悪化要因として挙げる「よく考えて」系の指示そのもの。差分が 2 行で、再生成で戻ったらテストが落ちて気づける |
| 強調語（`IMPORTANT`・`MUST`・`NEVER`）も外す（18 ファイル、34 箇所） | 不採用 | 生成元との差分が大きくなり、再生成のたびに 34 箇所を直し直すことになる。issue が例に挙げる言い回し（「慎重に」「必ず確認」「よく考えて」）とは種類が違い、制約そのものは必要な文に付いている |

受け入れること: 強調語は残る。再生成すると「Think deeply.」が戻り、足したテストが落ちる。そのときは同じ 2 行を削り直す（手順の文書に書く）。

### 言い回しのテストは「思考の深さを文で指示する句」に絞る

`必ず` や `絶対` を禁止語にはしない。診断は、これらの大半が破壊的操作・データ消失・認証情報の扱いに付いていて理由が書かれているので残す、と判定した。テストで禁じるのは `よく考え` と `Think deeply`・`think hard`・`think carefully`・`think step by step`（大文字小文字を区別しない）だけにする。対象は `rules/`・`CLAUDE.md`・`output-styles/`・`plugins/*/skills/*/SKILL.md`・`.claude/commands/`・`.claude/skills/`。issue の概要 2 が名指ししているのは「rules とスキル」なので、プラグインの SKILL.md は本文ごと対象に入れる（仕様づくりの時点で 0 件。追加の編集は要らない）。スキルの `references/` などそれ以外の `plugins/` 配下は対象にしない。

拾うのは 5 つの句が 1 行にそのまま現れた場合だけで、言い換えや改行またぎは通り、`think hard-coded` のような無関係な英文には当たりうる。これを塞ぎ切ることは目標にしない。言い換えを見つけるのは `/doctor prompt-audit` の役目で、テストは一度消した句が戻るのを止めるだけにする。

### 手順の文書に書く内容

- 確かめた Claude Code の版と日付
- 3 コマンドの実行方法（print モードで動くこと、未 install のプラグインは `--plugin-dir <path>` を使うこと、`claude plugin details` の値は install 済みの版のものであること）
- 出力の読み方: `/doctor prompt-audit` の報告と提案差分の場所、`/skill-doctor` の「一度も使われていない」の読み方（hook で動くプラグインは起動回数に出ない）、`claude plugin details` の固定分と起動時の区別
- 指摘の扱い: 提案差分をそのまま適用せず、このリポジトリの `rules/`・`output-styles/`・`plugins/` 側を直す（`~/.claude/rules/` は install 先への symlink）。openspec の生成ファイルは「Think deeply.」だけ削る
- 記録先: 見直しの issue か PR にコメントする。リポジトリが public なので、個人スキルの名前と中身は載せない
- 削減量の目標は置かず、削った結果（前後のバイト数）を記録する。予算値を動かすときは PR 本文に理由を書く（既存の規約）

## Risks / Trade-offs

- [診断コマンドの名前や出力が Claude Code の更新で変わり、手順が古くなる。根拠: 3 つとも 2.1.261 以降に入った新しいコマンドで、`docs/plugin-evals.md` も版を明記して同じ問題に備えている] → 手順に確かめた版と日付を書く。テストは文書に 3 コマンドの名前があることだけを見て、出力の形には依存しない
- [openspec の再生成で「Think deeply.」が戻り、無関係な PR でテストが落ちる。根拠: 該当ファイルは `generatedBy: "1.2.0"` を持つ生成物。頻度は openspec CLI を上げたときだけ] → テストの失敗メッセージに「該当の 1 文を削る」と手順の文書のパスを書く

## Open Questions

- 範囲外にした 3 件（`CLAUDE.md` の CI の記述、`CLAUDE.md` のマージ手順、issueify の質問の仕方）を別の issue にするか。この change では扱わない
