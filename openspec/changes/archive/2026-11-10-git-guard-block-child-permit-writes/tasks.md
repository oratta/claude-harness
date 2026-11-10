# Tasks

## 1. Write / Edit / NotebookEdit の hook を足す

- [x] 1.1 `scripts/git-guard-base-write-guard.sh` を新しく作る。`DEV_WORKFLOW_GIT_GUARD=off`・python3 が無いときは何も出さずに exit 0。payload の必要条件（置き場所の名前か `\u00` か `agent_id` の文字列）で python3 の起動を絞り、本体は `python3 -I -c` で渡す（git ガードと同じ形。#869 の理由で `/dev/fd/3` は使わない）。子の書き先（Write / Edit は `file_path`、NotebookEdit は `notebook_path`）を、相対なら `cwd` を前に付け、`normpath` と `realpath` の両方で部品に分け、大文字小文字を区別せずに `dev-workflow-git-guard` と一致すれば `deny` を出す。`<base>` を作らず、回数・拒否の記録・許可に触れない。理由文は「許可の置き場所」を含み、打ち直さず親に返すよう案内し、`dev-workflow-git-guard` と `permits` を両方は含めない（spec destructive-git-hook「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」「置き場所への書き込みを止める hook の配線と逃げ道」「許可の置き場所への書き込みの拒否は親に返すよう案内する」） 触る範囲: plugins/dev-workflow/scripts/git-guard-base-write-guard.sh（新規）、plugins/dev-workflow/scripts/git-destructive-guard.sh:1-75（書き出しのコメント・早期 exit・本体の渡し方を手本にする）、plugins/dev-workflow/scripts/unattended-ask-guard.sh:1-20（短い hook の書き出しの手本）
- [x] 1.2 `hooks/hooks.json` の PreToolUse に `matcher: "Write|Edit|NotebookEdit"` のエントリを、`AskUserQuestion` のエントリのあと・git ガードの `Bash` のエントリの前に足す（末尾は git ガードのまま） 触る範囲: plugins/dev-workflow/hooks/hooks.json:50-87（PreToolUse の配列）

## 2. git ガードに Bash の名指しを足す

- [x] 2.1 `LABELS` に種類 `permit-store`（ラベルは「許可の置き場所を名指しするコマンド（許可を書くのは親の役目）」。2 つの名前を書かない）を足し、`PERMIT_NAME` の近くに 2 つの名前の定数を置く。子のコマンドに両方が含まれれば `permit-store` を種類に足す（`self_permit` と同じ場所で、`kinds is not None and not kinds` の早期 exit より前。`kinds` が None のときも当たったことを覚えておく） 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:88-113（`LABELS`・`PERMIT_NAME`）、plugins/dev-workflow/scripts/git-destructive-guard.sh:762-773（`self_permit` と早期 exit）
- [x] 2.2 子の経路で、`permit-store` が当たったら許可を探さず（`use_permit` を呼ばない）、拒否の記録を書かない。ほかの種類（`permit-store` 以外の種類か、`kinds` が None）が無ければ、共通ファイルの読み込み・`check_base`・回数を飛ばして `deny` だけを返す。あれば今までどおり `check_base` して回数を数える 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:887-919（子の経路）
- [x] 2.3 子向けの理由文に、`permit-store` が当たったときの文（「拒否の記録を作らない」を含み、親も許可を書けないこと）を足し、そのときは通常の記録未作成の文（「拒否の記録を作れなかった」）は出さない。ただし、ほかの種類にも当たり `<base>` の確かめに失敗した場合は、既存の確かめ失敗の案内を保つ（要件「`<base>` を確かめられない子の呼び出しには deny だけを返す」に合わせる）。2 つの名前を理由文に並べない 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:937-954（子向けの理由文）
- [x] 2.4 書き出しのコメント（返す値の説明）に、`permit-store` の扱いと、Write / Edit / NotebookEdit は別の hook が止めることを 1〜2 行で足す。字句解析部（`join_words`〜`judge`）には触らない（Draft PR #1463 と重ねない） 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:23-33

## 3. テスト

- [x] 3.1 新しい hook のテストを作る: spec の Scenario「Write / Edit / NotebookEdit で `<base>` の中に書くと拒否する」「書き先の書き方を変えても拒否する」「主の呼び出しと置き場所の外への書き込みは止めない」「新しい hook が hooks.json に登録されている」「理由文が親に返すよう案内し、2 つの名前を並べない」（Write の側）。加えて、新しい hook の置き場所の名前が `git-guard-scratchpad.py` の `BASE_NAME` と同じであることを確かめる。TMPDIR は bats の一時フォルダに差し替え、本物の `<base>` に書かない 触る範囲: plugins/dev-workflow/tests/git-guard-base-write-guard.bats（新規）、plugins/dev-workflow/tests/git-destructive-guard.bats:1-92（setup と補助関数の手本）
- [x] 3.2 git ガードのテストを足す: spec の Scenario「Bash のコマンドに 2 つの名前があれば拒否し、数えない」「名前が 1 つだけのコマンドと主の呼び出しは止めない」「破壊的 git 操作も含むなら数えるが、記録を書かず許可も使わない」「理由文が親に返すよう案内し、2 つの名前を並べない」（git ガードの側）。許可を書くスクリプトの名前と 2 つの名前の両方を含むコマンドは、回数を数え（2 回目に `"continue": false`）、記録を書かないことも確かめる 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:1748-1833（「a child calling the permit script is denied」から「a self-permit call does not use a permit」の並びのあと）
- [x] 3.3 hooks.json の既存のテスト（git ガードが PreToolUse の末尾・先頭が Agent）が通り続けることを確かめる。新しい hook が python3 を `-c` で起動するなら、`tests/hook-python-invocation.bats` の `BODY_HOOKS` と `payload_for` に足す 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:939-955（「hooks.json: guard is the last PreToolUse entry on Bash without if」）、plugins/dev-workflow/tests/hook-python-invocation.bats:30-50（`BODY_HOOKS`・`payload_for`）
- [x] 3.4 `bats plugins/dev-workflow/tests/git-destructive-guard.bats plugins/dev-workflow/tests/git-guard-base-write-guard.bats plugins/dev-workflow/tests/hook-python-invocation.bats plugins/dev-workflow/tests/rm-permission-guard.bats plugins/dev-workflow/tests/context-tripwire.bats` を全件通す 触る範囲: 上の 5 ファイル

## 4. 変更の記録

- [x] 4.1 `plugins/dev-workflow/changes/<PR 番号>.md` に、何を止めるようにしたか・止めないもの（変数で組み立てたパスなど）・HMAC を使わない理由・止めすぎの頻度・戻し方を書く（`changes/1155.md` は PR #1614 の記録として main にあるので、この PR の番号で作る） 触る範囲: plugins/dev-workflow/changes/<PR 番号>.md（新規）、plugins/dev-workflow/changes/1155.md:1-20（書き方の手本）
