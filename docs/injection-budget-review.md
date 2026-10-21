# 常時注入の予算を見直すときの診断手順

`tests/injection-budget.txt` の値を見直すとき（`tests/injection-budget.bats` が超過側か下振れ側で落ちたとき、または固定分を削りたいとき）に、削れるものを Claude Code の公式の診断コマンド 3 つで探す手順。予算の仕組みそのもの（測定対象・上下両方向の判定・聖域扱い）は `openspec/specs/injection-budget-gate/spec.md` が正本。

確かめた Claude Code の版: 2.1.294（2026-10-08）。`/doctor prompt-audit` は 2.1.283 以降、`/skill-doctor` は 2.1.261 以降にある。コマンド名や出力の形は版で変わりうるので、手順を確かめ直したらこの行の版と日付を書き換える。

## 実行コマンド

リポジトリのルート（作業中の worktree）で実行する。3 つともリポジトリを書き換えない。

```
claude -p "/doctor prompt-audit"
claude -p "/skill-doctor"
claude plugin details <プラグイン名>
```

| コマンド | 何が分かるか | 実行するときに知っておくこと |
|---|---|---|
| `/doctor prompt-audit` | 旧モデル向けの言い回し（思考の深さを文で指示する句、大文字の強調語）、古くなった事実、指示ファイル同士の食い違い | 対話セッション用のスラッシュコマンドだが、print モード（`claude -p`）で動く。数分かかる。モデルを呼ぶので費用がかかる |
| `/skill-doctor` | スキルごとの、毎ターン載る一覧の大きさ・直近 7 日の消費トークン・使用回数・最後に使った日 | 同じく print モードで動く。集計はその PC のセッション履歴から作られる |
| `claude plugin details <プラグイン名>` | プラグインごとの毎セッションの固定分（概算トークン）と、スキル別の固定分・起動時の大きさ | install 済みのプラグインにしか使えない。未 install だと `Plugin "<名前>" not found` で exit 1 になるので、`claude --plugin-dir plugins/<名前> plugin details <名前>` でディスクから読ませる（`--plugin-dir` は `plugin` の前に置く。後ろに置くと `unknown option` になる） |

この 3 つをテストや CI から実行しない。モデルを呼ぶので費用がかかり、結果も実行ごとに変わる。見直す人が手で実行する。

## 出力の読み方

**`/doctor prompt-audit`** は指摘の一覧を標準出力に出し、報告（`report.html`）と提案差分（`proposed-project.patch`・`proposed-user-level.patch`）を一時ディレクトリに書く。場所は出力に書かれる（2026-10-08 の実行では `/tmp/claude-501/prompt-audit-<日付>/`）。監査の範囲は `CLAUDE.md`・`AGENTS.md`・`.claude/` 配下・`~/.claude/rules/`・output style・個人のスキルで、有効なプラグインは検索での確認だけになり編集案は出ない。`~/.claude/rules/` と output style は install 済みの版が読まれ、作業ツリーの編集は反映されない（rules を削った後に監査をやり直しても、削る前の内容への指摘が出るはずだが未確認）。

**`/skill-doctor`** の `context` 列が毎ターン載る大きさ、`uses` 列が使用回数。「一度も使われていない」と出たスキルがそのまま削れるわけではない。hook の注入で動くプラグイン（casting など）は、スキルの起動回数が 0 でも働いている。プラグインのスキルは個別には無効化できず、プラグイン単位になる。

**`claude plugin details`** の `Always-on` が毎セッションの固定分、`on-invoke` がスキルが起動したときだけ払う分。値は install 済みの版のもので、作業ツリーの内容ではない。書き換えた結果を見たいときは、上の表の `--plugin-dir` の形で作業ツリーを指す。予算テストの単位はバイト、このコマンドの単位は概算トークンなので、数値どうしを直接は比べない。

## 指摘の扱い

- **提案差分をそのまま適用しない。** `~/.claude/rules/` と `~/.claude/output-styles/` は install 先への symlink なので、直すならこのリポジトリの `rules/` と `output-styles/`、プラグインなら `plugins/` 側を編集する
- **思考の深さを文で指示する句（「よく考えて」「Think deeply.」の類）は削る。** `rules/`・`CLAUDE.md`・`output-styles/`・`plugins/*/skills/*/SKILL.md`・`.claude/commands/`・`.claude/skills/` にこの句があると `tests/injection-budget.bats` が落ちる。テストが見るのは決まった 5 つの句だけなので、言い換えはこの診断で見つける
- **`.claude/commands/opsx/` と `.claude/skills/openspec-*/` は openspec CLI の生成物。** 再生成すると「Think deeply.」が `.claude/commands/opsx/explore.md` と `.claude/skills/openspec-explore/SKILL.md` に戻り、テストが落ちる。そのときは同じ 1 文を削り直す。これらのファイルの `IMPORTANT`・`MUST`・`NEVER` の強調は直さない（2026-10-08 の診断で 18 ファイル 34 箇所。再生成のたびに全部を直し直すことになるため）
- **「必ず」「絶対」は一律には削らない。** 破壊的操作・データ消失・認証情報の扱いに理由つきで付いているものは残す
- **`CLAUDE.md` を書き換えるときは `AGENTS.md` も同じに直す**（`tests/agents-md-sync.bats` が同期を見ている）
- 個人の `~/.claude/skills/` への指摘はこのリポジトリの外なので、ここでは直さない

## 記録

- 診断結果の要点を、見直しの issue か PR にコメントする。このリポジトリは public なので、個人の `~/.claude/skills/` にあるスキルの名前と中身は載せず、件数だけ書く
- 削減量の数値目標は置かない。削った結果（`scripts/test.sh injection-budget` の失敗時の出力に出る内訳の、前後のバイト数）を記録する。内訳はテストが落ちたときしか出ないので、通っている状態の数値は、`tests/injection-budget.txt` を一時的に 1 にして `scripts/test.sh injection-budget` を実行し、出力の「内訳（測定対象 8 種）」の下を控えてから元の値に戻す（この変更はコミットしない）。落ちる件数が増えるのは予算を 1 にしたためで（予算値に依存する他のテストも `not ok` になる。2026-10-10 に git 管理下のリポジトリの複製で測ったときは「約 5% の余裕」「予算ファイルから読む」「10% を超える削減が under 側で落ちる」の 3 件）、見るのは bats の出力で各行に `# ` が付いた `# --- 内訳（測定対象 8 種）---` の下だけ
- 予算値を動かす PR は、本文に理由を書く（`CLAUDE.md`「常時注入の予算」）。値を動かさなかったときも、動かさなかった理由を 1 行書いておくと後で読む人が迷わない
- 直さないと決めた指摘は、理由と一緒に issue に残す

## 実行の記録

| 日付 | Claude Code の版 | 記録 |
|---|---|---|
| 2026-10-08 | 2.1.294 | https://github.com/oratta/claude-harness/issues/712#issuecomment-6055775344 |
