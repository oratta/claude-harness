## Context

#1132 の実機確認: 確認画面（Dangerous rm …）には `PermissionRequest` hook が答えられ、`PreToolUse` の allow では通せない。入力にはなぜ確認が出たかが無く、default モードでは普通の Bash 確認でも同じ hook が呼ばれる。#1133 で、拒否の記録 `denied/<key>.json`・許可 `permits/<key>.json`・`git-guard-scratchpad.py` の一時領域の判定・`git-guard-permit.sh` が入った。

## Decisions

1. **別の hook スクリプトにする（`rm-permission-guard.sh`）。** `git-destructive-guard.sh` は PreToolUse 用で出力の形も違う（`permissionDecision` と `decision.behavior`）。962 行ある既存に足すより、短い別スクリプトが共通ファイルを読む形にする。ただし key・許可ファイル・許可の使い方（rename で取る・4 値の一致・期限・使う時点の再判定・permit-log）は #1133 と同じ規則で、同じ `<base>`（`${TMPDIR:-/tmp}/dev-workflow-git-guard`）を使う。許可を書くのは今までどおり親の `git-guard-permit.sh` 1 本。
2. **答える範囲は「子 かつ 先頭の語が rm の単純コマンドがある」だけ。** `rm` でない確認に deny を返すと普通の Bash 確認を壊す。`rm` を含むが判定を満たさない形（引用符・パイプなど）は deny にする（許可を書くスクリプトも同じ判定で断るので、許可は書けない）。主の呼び出しは何も返さない（人が見る）。
3. **rm 用の判定は git 用の判定と同じファイルに置き、入口は `check_rm`、振り分けはコマンドで決める。** `git-guard-permit.sh` は記録の `command` に先頭が `rm` の単純コマンドがあれば `check_rm`、なければ `check` を使う。記録の `kinds` は書き換えられるので振り分けに使わない。
4. **cd が失敗した場合を両方の基準で見る。** 実際に出る形は `cd <dir>; rm … <rel>/*` で、`;` なので `cd` が失敗すると `rm` は元の `cwd` で走る。git 用の判定は「`cd` があれば区切りは `&&` だけ」と拒むが、`rm` ではこの形が本命なので拒まず、相対の削除先を `cd` の移り先と `cwd` の両方を基準に解決し、両方が scratchpad の中であることを求める。`cd` は 1 個までで `rm` より前だけ。
5. **削除先は「末尾の要素の 1 つ前までを realpath、末尾はそのまま」で解決する。** `rm` は symlink を辿らず symlink 自体を消すので、末尾が外への symlink でも中の削除として扱ってよい。親の途中が外への symlink なら realpath で外に出るので拒む。
6. **scratchpad そのもの、およびその直下の glob 全消しは拒む。** 同じセッションの親の作業ファイルも scratchpad に置かれうるため。個別に名指しした直下のファイル・ディレクトリは通す。
7. **フラグは `-r -R -f` の組み合わせだけ、`--` と他のフラグは拒む。** 判定が読めない形を増やさない（止めすぎる向きに倒す）。
8. **打ち切りの回数は数えない。** deny の message が「打ち直さず親に返す」と案内する。子が従わずに繰り返しても、毎回 deny なので害は無く、止める価値が低い。git の打ち切りの仕組み（回数のファイル・continue: false）は流用しない。
9. **fail-open は「何も出力しない」。** payload が読めない・python3 が無い・agent_id が無い、のときは本体の確認画面に任せる。判定のファイルを読めない子の `rm` は deny（許可を探さず、記録も書かない）。

## Risks / Trade-offs

- 子が `permits/` に直接許可を書く・判定後に symlink を差し替える穴は #1133 と同じく残す（通るのは scratchpad の中だけ）。
- default モードでは scratchpad の中の絶対パスの `rm` も普通の確認として hook が呼ばれ、許可が無ければ deny になる。これまで確認画面（人の操作）で通っていた子の rm が、親の許可か報告が必要になる。子の rm の確認は子の呼び出しでは元から出せず拒否されていたので、振る舞いの退化ではない（実機で確かめる）。
- 実機確認が受け入れ条件。PermissionRequest の出力 JSON の形は実機で確かめる。

## Migration

hook を足すだけで、既存の状態ファイルの形は変えない。戻し方は差分を戻す。
