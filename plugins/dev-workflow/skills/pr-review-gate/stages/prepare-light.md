# prepare-light — pr-review-gate

入口: 最新の仕様化判断に `通し方: 軽い` の行があるときだけ読む。

6. **軽い通し方の確認**: 手順 1 の 3 で解決した記録先（issue 参照が無い PR は PR 自身）を `REC` に置き、最新の仕様化判断だけを読む。最新コメントに `^通し方: 軽い$` と完全一致する行があるときだけ、レビュアーを起こす前に次を確かめる。その行が無ければこの確認をせず、コメントも投稿しない。

   ```bash
   DEC=$(gh api --paginate --slurp repos/$R/issues/$REC/comments | jq -r 'add | [.[] | select(.author_association | IN("OWNER", "MEMBER", "COLLABORATOR")) | select(.body | split("\n")[0] | test("^仕様化判断: (する|しない)$"))] | last | .body')
   LIGHT=$(printf '%s\n' "$DEC" | grep -cx '通し方: 軽い')
   if [ "$LIGHT" -ge 1 ]; then
     printf '%s\n' "$DEC" | head -1
     KIND=$(printf '%s\n' "$DEC" | sed -n 's/^種類: //p')
     printf '%s\n' "$KIND"
     CHECK_COUNT=$(printf '%s\n' "$DEC" | grep -c '^確かめ方: ')
     printf '%s\n' "$CHECK_COUNT"
     FILES=$(gh api --paginate repos/$R/pulls/$N/files --jq '.[] | "\(.additions) \(.deletions) \(.filename)"' | grep -vE ' ([^ ]*/)?changes/[0-9]+\.md$')
     SPEC_COUNT=$(printf '%s\n' "$FILES" | grep -c ' openspec/')
     printf '%s\n' "$SPEC_COUNT"
     printf '%s\n' "$FILES" | awk 'NF {n++; a+=$1; d+=$2} END {print n+0, a+0, d+0}'
     KIND_COUNT=$(printf '%s\n' "$DEC" | grep -c '^種類: ')
     printf '種類の行数=%s\n' "$KIND_COUNT"
     MACHINE_RESULT=条件内
     [ "$(printf '%s\n' "$DEC" | head -1)" = '仕様化判断: しない' ] &&
       [ "$KIND_COUNT" -eq 1 ] && [ "$CHECK_COUNT" -eq 1 ] &&
       [ "$(printf '%s\n' "$DEC" | grep -c '^確かめ方: .')" -eq 1 ] &&
       [ "$SPEC_COUNT" -eq 0 ] || MACHINE_RESULT=条件外
     case "$KIND" in
       typo|lint|コメント|フォーマット|設定値) ;;
       'ワンライナー fix')
         read -r COUNT ADDED DELETED <<< "$(printf '%s\n' "$FILES" | awk 'NF {n++; a+=$1; d+=$2} END {print n+0, a+0, d+0}')"
         [ "$COUNT" -eq 1 ] && [ "$ADDED" -le 1 ] && [ "$DELETED" -le 1 ] || MACHINE_RESULT=条件外 ;;
       *) MACHINE_RESULT=条件外 ;;
     esac
     printf 'MACHINE_RESULT=%s\n' "$MACHINE_RESULT"
     if [ "$MACHINE_RESULT" = 条件外 ]; then
       printf '%s\n' '軽い通し方の確認: 条件外' "対象 HEAD: $HEAD_SHA" '機械で測る点: 条件外'
       printf '%s\n' 'Status: failed' '次の段: 前提確認と重さ判定' '原因: 軽い通し方の条件外'
     fi
   fi
   ```

   grep の 0 件は終了コード 1 になるので、このブロックは `set -e` を有効にせず走らせ、終了コードではなく出力の値で判定する。出力は順に、仕様化判断の 1 行目・種類・確かめ方の行数・openspec のファイル数・変更ファイル数と追加／削除行数、種類の行数、機械判定。`MACHINE_RESULT=条件外` なら出力した確認コメントと Gate Result の欄を使って下の条件外の処理を行い、return する。条件内なら G が差分を読む判断に進む。

   **機械で測る点**: 1 行目が `仕様化判断: しない` ちょうど、`種類:` の行が 1 行ちょうどで値が `typo` / `lint` / `コメント` / `フォーマット` / `ワンライナー fix` / `設定値` のどれか 1 つちょうど、`確かめ方:` が 1 行ちょうど（値が空でない）、`openspec/` が 0 ファイルであること。さらにワンライナー fix だけは、変更ファイルが 1 つ、追加 1 行以下かつ削除 1 行以下であること。変更の記録（パスが `changes/<数字>.md` で終わるファイル）はどの種類でも数えない。ワンライナー fix 以外にファイル数・行数の上限を置かない。

   **G が差分を読んで判断する点**: `gh pr diff $N --repo $R` で、変更の記録を除くすべての変更が宣言した種類に収まるかを読む。typo・lint・コメント・フォーマット・設定値はプログラムの挙動を変えないこと（設定値も値を変えて挙動が変わらないこと）。ワンライナー fix は明白なバグの 1 行修正で直し方に選択肢がないことを判断し、挙動が変わることを条件外の理由にしない（比較の向きの取り違えの修正は条件内、既定値の選び直しは条件外）。判断がつかない場合も条件外。

   **結果**: PR コメントの 1 行目を `^軽い通し方の確認: (条件内|条件外)$` に完全一致させ、2 行目を `対象 HEAD: <40 桁フル SHA>`（手順 1 の 5 の `$HEAD_SHA`）、続けて確かめた点ごとの結果と、条件外なら外れた点を書く。条件内なら手順 2-0 へ進む。条件外なら `agent-review:pending` を外し `agent-review:failed` を付け、レビュアーを起こさず終了する。develop の G の return は下の「軽い通し方の条件外」を使い、それ以外の呼び出し元は確認コメントを見て通常の通し方に戻す。

   **守備範囲**: 入力は本体が書いた最新の仕様化判断と PR の差分・変更ファイル一覧。書式・種類・openspec の差分・宣言した種類からの逸脱・ワンライナー fix の大きさ超えを拾う。変更の記録は機械の点と G の判断の両方から外すため、その中身は通ることを許す（レビュアーが差分全体と一緒に見る）。`確かめ方:` のコマンドの妥当性も見ない。穴を塞ぎ切ることは完了条件にしない。



手順 1 の 6 で条件外なら、確認コメントを投稿しラベルを切り替えてから、Status `failed`・`次の段: 前提確認と重さ判定`・`原因: 軽い通し方の条件外` で return する。固定 HEAD と確認コメントの URL も Gate Result に含める。手順 2-0 とレビュアーの起動には進まない。この failed はレビューの周に数えず、本体は次の G を前の Gate Result を貼らずにゲートの開始として起こし、`周回: 1` の全体レビューにする（W の修正後の再レビューとして扱わない）。

出口: 条件内なら `stages/prepare.md` の手順 2-0 へ戻る。条件外なら本文の「軽い通し方の条件外」の failed で return する。
