## Why

`scripts/git-destructive-guard.sh`（#710・PR #794）は、Bash のコマンド文字列を `shlex` で字句に分け、その前後に改行・ヒアドキュメント・置換を正規表現と単純な走査で処理している。そのため、シェルが実際にコマンドとして実行する形を取りこぼし、シェルが文字列として扱う形を誤ってコマンドと読む箇所が 8 件ある（PR #794 一周目レビューの F1・F4〜F10。固定 HEAD 2480f917 と現在の main ba8f9838 の実 hook で再現済み）。PR #794 のゲートは spec の守備範囲（「穴を塞ぎ切ることは完了条件にしない」）に照らして follow-up に回したが、どれもルールを読み飛ばした Claude が普通に書きうる形（コメント付きの複数行、行継続、`>/dev/null` を途中に挟む形、ハイフン入りのヒアドキュメント区切り語など）なので、ここでまとめて直す。

取りこぼし（現状は何も出ない。実行される）:

- F1 改行を含む引数: `bash -c '<改行>git reset --hard<改行>'`、`git -c core.x='first<改行>second' reset --hard`
- F4 置換内の引用符付き `)`: `echo "$(printf ')'; git reset --hard)"`
- F5 コメント内の引用符: `# It's cleanup<改行>git reset --hard`
- F6 リダイレクトの位置: `git reset >/dev/null --hard`
- F7 行継続: `git \<改行>reset --hard`
- F9 区切り語とhere-string: `cat <<END-TAG<改行>body<改行>END-TAG<改行>git reset --hard`、`cat <<< EOF<改行>git reset --hard`

誤検知（現状は ask / deny が出る。シェルは git を実行しない）:

- F8 引用された `;`: `echo ';' git reset --hard`
- F10 引用ヒアドキュメント内の `$(...)`: `cat <<'EOF'<改行>$(git reset --hard)<改行>EOF`

## What Changes

- `git-destructive-guard.sh` の字句の読み（現在の `substitutions` / `normalize` / `tokenize` / `simple_commands`）を、引用状態と「演算子か語か」の種別を保ったまま 1 回の走査で字句に分ける読みに置き換える。行継続・コメント・リダイレクト・ヒアドキュメント（区切り語の全体、`<<-`、引用された区切り語）・here-string・置換の中の引用を、シェルと同じ単位で扱う
- 判定の 9 種・モード別の ask / deny・逃げ道・fail-open・git のオプション解釈（`parse_opts` 以降）は変えない
- spec `destructive-git-hook` に要件「コマンド文字列をシェルと同じ単位で読む」を足す（ADDED）。既存要件の MUST NOT「引用符の中の改行より後ろの行もコマンドとして読んではならない」は、`bash -c` / `eval` の引数にならない引用文字列についての規則だと、新しい要件の中で書き分ける
- bats に #820 用のまとまり（見出しコメント付き）を足し、F1・F4〜F10 の各入力と、それぞれの対になる「通す」入力を検査する

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `destructive-git-hook`: 要件「コマンド文字列をシェルと同じ単位で読む」を足す。既存要件「破壊的 git 操作を Bash の実行前に検出する」の文面は変えない（#821 が同じ要件ブロックを並行して直しうるため、MODIFIED で丸ごと置き換えると archive で片方の変更が消える。理由は design.md）

## Impact

- `plugins/dev-workflow/scripts/git-destructive-guard.sh`（字句の読みの部分。`judge_simple` の wrapper の読み飛ばしと `parse_opts` 以降は触らない）
- `plugins/dev-workflow/tests/git-destructive-guard.bats`（#820 用のまとまりを 1 か所に追加）
- `plugins/dev-workflow/changes/820.md`（変更の記録）
- 範囲外: #821（`--no-dry-run`・長いオプションの省略形・`--end-of-options`・`env -u` などの git / wrapper のオプション解釈）、#822（Unicode エスケープのテスト）、PR #794 指摘の F2・F11・F12（修正済み）・F13・F14
- 影響: hook の判定結果が変わるのは上の 8 件の形と、それに類する形（行継続・コメント・途中のリダイレクト・引用された演算子を含むコマンド）だけ。python3 の起動条件は変わらない
