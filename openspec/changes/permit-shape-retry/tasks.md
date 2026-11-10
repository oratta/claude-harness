# Tasks

## 1. 許可を書くスクリプトの終了コードの振り分け

- [ ] 1.1 着手時に origin/main を取り込み、#1159・#1166 の open PR と、許可を書くスクリプト・SKILL.md・2 つの bats の差分が重ならないかを確かめる（許可を書くスクリプトの名前は Bash のコマンドに書かず、ファイルは Read / Edit で読み書きする）。触る範囲: plugins/dev-workflow/scripts/git-guard-permit.sh:1-116、plugins/dev-workflow/skills/develop/SKILL.md:218
- [ ] 1.2 一時領域の判定に落ちたとき（`check_command` が理由を返したとき）、記録の `command` が単独のコマンドの形か（共通ファイルの `is_rm_command` で git 用か rm 用かを選び、その文字の集合 `_ALLOWED_CHARS` / `_RM_ALLOWED_CHARS` に合い、`;`・`&`・改行を含まない）を見て、そうでなければ今の理由の行に加えて「実パスで単独のコマンドに打ち直せば判定し直せる形の理由で断った」旨の 1 行を stderr に書いて 3 で、そうなら今までどおり 1 で終わる。集合や関数を取り出せないときは 1 に倒す。冒頭のコメントの終了コードの説明（0 / 1 / 2）に 3 を足す。触る範囲: plugins/dev-workflow/scripts/git-guard-permit.sh:14（終了コードのコメント）、plugins/dev-workflow/scripts/git-guard-permit.sh:35-37（fail）、plugins/dev-workflow/scripts/git-guard-permit.sh:80-84（check_command の呼び出し）
- [ ] 1.3 bats を足す: spec destructive-git-hook の 3 つの Scenario（形の理由で 3・単独の形や記録の確かめで 1・打ち直した単独のコマンドで許可を書いて hook が allow）。既存の `setup_permit`・`mk_record`・`deny_then_permit`・`permits_empty` を使う。既存の「0 以外」を見るテストはそのまま通ること。触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:1060-1075（helpers）、plugins/dev-workflow/tests/git-destructive-guard.bats:1648-1676（refuses commands whose targets cannot be fixed の直後に足す）

## 2. develop の本体の手順

- [ ] 2.1 `returned no output` を含む段落を直す（段落は 1 行のまま。既存の bats が求める文字列（`0 以外で終わった`・`同じ指示で起こし直さない`・`1 回求めても報告が空` など）は残す）。(a) オーナーに上げる条件の「許可を書くスクリプトが 0 以外で終わった（stderr を添える）」に、終了コード 3 で直後の段落の打ち直しの条件を満たし、同じ W の同じ操作についてまだ打ち直しを指示していないときを除く旨を足す。(b)「同じ指示で起こし直さない」のところに、許可を書いて同じ W を再開することと、打ち直しを指示して同じ W を再開することは、同じ指示での起こし直しに数えない旨を足す（spec dev-workflow-develop の要件「空の return を受けたら報告を 1 回だけ求め、同じ指示で起こし直さない」の例外）。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:218
- [ ] 2.2 その直後に打ち直しの段落を足す（spec dev-workflow-develop の要件の「形の理由で断られたときの打ち直し」のとおり: 条件 1・3・4 と報告の対象のパスが scratchpad の下の形／測ってから同じ W を再開／準備は別の呼び出しで先に／破壊的な操作だけを実パスの単独のコマンドで 1 回／承認ではなく拒否される見込みで、拒否されたら打ち直さず 5 項目を報告／新しい記録で許可の手順をやり直す／打ち直しのあとに打ち切られて空で返ったら、その打ち直しについて報告を改めて 1 回だけ求めてよく（打ち直しの前に求めた 1 回とは別に数える）、それも空なら空だったことと作業ツリーの状態を主に上げる／打ち直しは同じ W の同じ操作（戻す・片付ける対象と目的が同じもの）について 1 回までで、新しい拒否の記録になっても回数を戻さず、同じ W の別の操作は別に数える／打ち直したコマンドの記録でまた 0 以外（3 でも）ならオーナーに上げる）。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:218-219（直後に段落を挿入）
- [ ] 2.3 develop-skill.bats を直す。(a) #1135 のテスト（`returned no output` を含む段落の文言を確かめるもの）の「オーナーに上げる条件」の確かめに、終了コード 3 の例外（`終了コード 3`・`同じ W の同じ操作`）を足す。(b) 空の return の要件の例外を確かめるテストを足す: `returned no output` を含む段落に、打ち直しを指示して同じ W を再開することは同じ指示での起こし直しに数えない旨があり、直後の段落に、打ち直しのあとの空の return には報告を改めて 1 回だけ求めてよく、それも空なら主に上げる旨がある（#1117 のテストはそのまま通ること）。(c) 新しい打ち直しの段落の文言を確かめるテストを足す（spec dev-workflow-develop の Scenario「形の理由で断られたら 1 回だけ打ち直しを指示する」の各項目。段落は `returned no output` を含む段落の直後の行で取り出す）。触る範囲: plugins/dev-workflow/tests/develop-skill.bats:1247-1261（#1117 のテスト）、plugins/dev-workflow/tests/develop-skill.bats:1348-1378（#1135 のテストと、その直後に足すテスト）

## 3. 確認と記録

- [ ] 3.1 `bats plugins/dev-workflow/tests/git-destructive-guard.bats plugins/dev-workflow/tests/develop-skill.bats plugins/dev-workflow/tests/rm-permission-guard.bats plugins/dev-workflow/tests/hook-python-invocation.bats` と `openspec validate permit-shape-retry --type change --strict` を通す。触る範囲: なし（実行のみ）
- [ ] 3.2 design.md「実機確認の手順」の 2 ケースを `claude -p --plugin-dir <worktree>/plugins/dev-workflow --permission-mode default` で確かめる。どちらのケースも、子がまず破壊的でない別の Bash の呼び出しで対象を作り（中は scratchpad の repoA、外は scratchpad の外の新しいパスに repoC と scratchpad の中のリンク linkC）、そのあと追加の準備と checkout を `&&` でまとめて打って拒否される形にする。外の repoC の場所は親がプロンプトで新しいパスとして指定し、既存のものとして名指ししない。最初の報告で子が対象を作ったコマンドを示せていることを確かめる（示せず親が条件 3 で止まったら、打ち直しの経路を確かめたことにならないので、プロンプトを直して取り直す）。結果（子の agent_id・スクリプトの終了コードの並び（中は 3→0、外は 3→1）・permit-log の行（中は permit と use、外は permit なし）・最終状態（a.txt が orig に戻る、c.txt は changed のまま））を PR に記録する。触る範囲: なし（scratchpad と、scratchpad の外の一時の場所だけを使う）
- [ ] 3.3 変更の記録を書く。触る範囲: plugins/dev-workflow/changes/1173.md（新規）
- [ ] 3.4 PR を出す前に origin/main を取り込み直し、#1159・#1166 の open PR と差分が重ならないかを再び確かめる。触る範囲: なし
