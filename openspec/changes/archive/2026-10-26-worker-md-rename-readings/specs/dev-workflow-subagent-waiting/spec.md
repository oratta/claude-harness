## MODIFIED Requirements

### Requirement: 実行時の検査が文言検査の素通りする違反を止めることを再現ケースで示す
`tests/subagent-stop-guard.bats` は、規約違反の待ち方（背景起動の後に終了通知を待たずにターンを終える）を表す合成トランスクリプトで hook が停止を拒否することを検査しなければならない（MUST）。あわせて、同じ違反を言い換えて指示書に書いた形を `subagent-waiting.bats` の文言検査が検出しないことを、同じスイートで対にして示さなければならない（MUST）。後者は、プラグインのディレクトリを `BATS_TEST_TMPDIR` に複製し、複製の `skills/develop/references/roles/worker/implement.md` に言い換えた違反を差し込み、その複製に対して既存の `subagent-waiting.bats` を実際に実行して exit 0 になることで示す（SHALL）。禁止語のリストを新しいスイートに写してはならない（MUST NOT。2 か所になると片方だけ古くなる）。実セッションでの再現（`claude -p --plugin-dir` で背景 `sleep` を起動してターンを終えるサブエージェントに拒否理由が届くこと）は、実行コマンドと出力を記録先に添付する（SHALL）。

#### Scenario: 文言検査は素通りし、実行時の検査は止める
- **WHEN** 待ちでターンを終える指示を禁止語を使わずに言い換えて複製の worker/implement.md に差し込み、その指示どおりに動いたトランスクリプトを用意する
- **THEN** 複製に対して走らせた `subagent-waiting.bats` は exit 0 で、`subagent-stop-guard.sh` はそのトランスクリプトでの停止を拒否する

#### Scenario: hooks.json の登録
- **WHEN** `hooks/hooks.json` を読む
- **THEN** `SubagentStop` に `${CLAUDE_PLUGIN_ROOT}/scripts/subagent-stop-guard.sh` が登録されており、既存の SessionStart / UserPromptSubmit / PreToolUse / PostToolUse のエントリは変わっていない

#### Scenario: 対の検査の差し込み先

- **WHEN** `tests/subagent-stop-guard.bats` の対の検査を読む
- **THEN** 複製の `skills/develop/references/roles/worker/implement.md` に言い換えた違反を差し込んでいる

### Requirement: 待ち方の契約は共有 references に 1 本置く
待ち方の正本は `plugins/dev-workflow/references/subagent-waiting.md` に置かなければならない（MUST）。`skills/develop/references/roles/worker/implement.md`・`spec-reviewer.md`・`gate-runner.md` と `skills/pr-review-gate/SKILL.md` は、禁止そのものを 1 行で書いたうえでこの正本を参照する（SHALL）。同じ待ち方の手順を複数のファイルに複製してはならない（MUST NOT）。

複製の禁止は具体的に、**完了マーカーの雛形・具体の待ち値（`--timeout-ms <数値>` / `timeout: <数値>`）・総待ちの上限（回数と分数）を正本以外の文書に書かないこと**を指す（MUST NOT）。指示書に残してよいのは、禁止の 1 行・正本への参照・その役割固有の分岐（G なら上限到達時の `needs-reviewer`）・起動コマンドそのものの事実（どのバイナリをどのフラグで呼ぶか）である（SHALL）。この境界は退行検出で機械的に守る（MUST）。指示書に再掲した手順が正本と食い違ったまま残る事故が実際に起きたため（2026-09-09 のレビューで、gate-runner に再掲した companion の判定方法が事実と食い違っていた）。

#### Scenario: 正本の所在
- **WHEN** サブエージェントが待ち方の詳細を知りたい
- **THEN** 自分の指示書にある 1 行から `references/subagent-waiting.md` に到達できる

#### Scenario: 指示書に手順を再掲する
- **WHEN** 指示書に完了マーカーの雛形や具体の待ち値を書き戻す
- **THEN** 退行検出が失敗し、正本へ参照を寄せるよう促す

#### Scenario: 待ちの規約の所在

- **WHEN** `worker/implement.md` の全経路共通の大原則を読む
- **THEN** 長時間処理の完了を待つ目的でターンを終えないことと、正本が `plugins/dev-workflow/references/subagent-waiting.md` であることが書かれている

### Requirement: 待ち方の退行を機械検出する
`plugins/dev-workflow/tests/subagent-waiting.bats` が、dev-workflow の手順書と正本に対して次の各点を検査しなければならない（MUST）。

1. 待ちを背景タスクの完了通知や Monitor に委ねる指示が残っていないこと
2. 文書中に現れる `--timeout-ms <数値>` と `timeout: <数値>` の 2 パターンの数値がすべて前景上限未満であること。上限値はスイート内の 1 変数（`FOREGROUND_LIMIT_MS=600000`）にまとめ、出典（Claude Code の Bash ツールの前景上限）をコメントで書く（SHALL）。この 2 パターン以外の `timeout` の出現は検査対象にしない（無関係な出現が大半のため）
3. `skills/develop/references/roles/worker/implement.md`・`spec-reviewer.md`・`gate-runner.md` に、待ちでターンを終えない旨の記述と `references/subagent-waiting.md` への参照があること
4. 完了マーカーの雛形・具体の待ち値・総待ちの上限が、サブエージェントが読む指示書（W / R1 / G と `skills/pr-review-gate/SKILL.md`）に再掲されていないこと
5. 正本の `codex exec` 雛形を、文言検査と実行時検査の 2 本立てで検査すること（MUST）
   - **文言検査**: nonce が排他生成（`mktemp -d`）で作られる形であること、`date +%s` と `$RANDOM` を nonce の作り方として例示していないこと（「使わない」と禁じる文の中の出現は許す）、プロンプトとログが固定パス（`/tmp/codex-prompt-` / `/tmp/codex-review-`）ではなく生成したディレクトリの配下に置かれること、レビュー指示を標準入力から渡す形であること
   - **実行時検査**: 正本から nonce を作る手順の雛形を抽出して実際に実行し、(a) **同一プロセス内での複数回の呼び出しで nonce が重複しないこと**、(b) 生成された値が英数字のみで既定の長さ以上であること、(c) 一時ディレクトリの生成に失敗したときは非 0 で終了し nonce を印字しないこと、(d) プロンプトが生成したディレクトリの配下に書かれることを検査する

雛形は「読まれる文書」であると同時に「実行されるコード」なので、文言検査だけでは弱体化（テンプレートの `X` を減らす等）が素通りする。実行時検査で (a) を見るときは、抽出したブロックを連結した 1 本のスクリプトを 1 回実行しなければならない（MUST）— 乱数状態の継承は同一プロセス内でしか現れず、別プロセスで繰り返すと原理的に検出できないため。**(a) は、サブエージェントが実際に雛形を走らせるシェルを対象に含めなければならない（MUST）** — 乱数状態がサブシェルに継承されるかどうかはシェルごとに違うため。2026-09-09 の実測では、16 文字に整えた `$RANDOM` 版を 10 個連結して 1 プロセスで走らせると、`sh` と `bash`（3.2.57）はコマンド置換のサブシェルごとに再シードするので 10 個とも別の値になり (a) を素通りしたが、`zsh`（5.9）は 10 個とも同じ値になり (a) が落とした。Claude Code の Bash ツールのシェルは `zsh` なので（`ps -p $$ -o comm=` が `/bin/zsh`）、`zsh` を対象から外してはならない（MUST NOT）。対象シェルのいずれかが環境に無い場合はそのシェルだけを飛ばし、検査全体を skip してはならない（MUST NOT）。文言検査・(a)・(b) の 3 つを併せて 1 つの網とする（SHALL）。

禁止語のブラックリストは既知の言い換えしか止められず、意味を保った別の言い回しは素通りする（grep で意味は見られない）。網羅性を担うのは構造検査（background 起動を書く文書は前景ポーリング・禁止 1 行・正本参照を必ず併記していること、および上記 4 の再掲禁止）であり、ブラックリストはその補助と位置づける（SHALL）。この限界はスイート内のコメントに明記する（SHALL）。

正本ファイル自身とテスト自身は禁止語を説明のために含むため、禁止語スキャンの対象から除外する（SHALL）。

#### Scenario: 古い書き方に戻したとき
- **WHEN** 手順書の待ち値を 900000 に戻す、または待ちでターンを終える指示を書き戻す
- **THEN** `scripts/test.sh` が失敗し、どのファイルの何を直すかを示す

#### Scenario: 雛形の nonce 生成を弱めたとき
- **WHEN** 正本の雛形を乱数ベースに戻す、または nonce の長さの下限を減らす
- **THEN** 抽出して実行する検査が nonce の重複または長さ不足を検出して失敗する

#### Scenario: 上限値の直し先
- **WHEN** ハーネス側の前景上限が変わる
- **THEN** スイート内の `FOREGROUND_LIMIT_MS` 1 か所を直せば検査全体が追随する

#### Scenario: 指示書に待ちの手順を再掲したとき
- **WHEN** 指示書に `--timeout-ms 540000` や完了マーカーの雛形を書き戻す
- **THEN** `scripts/test.sh` が失敗し、正本に寄せるよう示す

## REMOVED Requirements

### Requirement: 待ちの規約を検査する W の指示書の読み替え

**Reason**: 読み替えの対象だった「worker.md」の名指しを、移し先のファイル名で直接書いたため（所在と差し込み先の Scenario は「実行時の検査が文言検査の素通りする違反を止めることを再現ケースで示す」に移した）

**Migration**: 他の要件が移し先のファイル名で直接書き直されたので、読み替えの規則は要らない。
