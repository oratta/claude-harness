## 1. owner-reply-check.sh に --delegated を足す

- [ ] 1.1 冒頭の使い方の説明に `--delegated <セッション ID> <uuid> <委任の記録の作成日時> <委任の記録の URL> <停止の記録の作成日時>` と出力・理由（`not-found`・`not-owner`・`not-after`・`not-asked`・`not-direct`・`not-before`）・終了コードを足す（「3 つ」の数え方も直す） 触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:1-53
- [ ] 1.2 引数の解釈に `--delegated` を足す（引数ちょうど 5 個、ID と uuid の UUID の形、URL の `https://`。違えば exit 2） 触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:56-98、plugins/dev-workflow/scripts/owner-reply-check.sh:116（python へ渡す引数）
- [ ] 1.3 python 側に委任の確かめを足す。順は design.md D3 の表どおり。URL の境界の正規表現と「URL を書いた最後の親の発言」「あいだの主の発言」の判定は `relayed()` と共有する形にし、`relayed()` の動きは変えない 触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:285-337（`fail`・`relayed`・モードの振り分け）

## 2. テスト

- [ ] 2.1 新しい bats を作り、spec の要件「主の委任の合否を、名指しの許容と混在したログで機械的に固定する」の 4 つの Scenario（委任の記録より後で、URL を書いた親の発言より前に別の主の発言があっても通るケースを含む） と、`--delegated` の要件の各 Scenario（引数の不備の exit 2・`not-found`・`not-owner`・許容の語を見ないこと）を固定する。テスト用の会話ログの作り方は既存の relayed のシナリオの bats に倣う 触る範囲: plugins/dev-workflow/tests/owner-reply-delegated-scenario.bats（新規）、plugins/dev-workflow/tests/owner-reply-relayed-scenario.bats:1-91（読むだけ。書き方の手本）
- [ ] 2.2 既存の owner-reply-check の bats が、`--relayed` と既定・`--locate` について変わらず通ることを、触った bats だけ回して確かめる（全体は CI に任せる） 触る範囲: plugins/dev-workflow/tests/owner-reply-check.bats:1-852（読むだけ）

## 3. develop の参照（親と子）

- [ ] 3.1 手順 8 に、主が任せる旨を述べたときの委任の記録の投稿（定型の 1〜4 行目と `きっかけ:`）と、本文での確認の問い（範囲と期間の文・URL・答え方の行に「親のタブで `任せる` を、この問いの直後に別の発言を挟まずに打つ」）を足す。直後の発言の全文から任せる意思が読めないときと、あいだに別の発言が挟まったときは委任を使わず問いを本文で出し直すことを書く。確認を受けたら `owner-reply-check.sh --locate "$CLAUDE_CODE_SESSION_ID" <確認の全文>` で uuid を引き、エピックに `委任の確認の場所: セッション <親のセッション ID> / uuid <uuid> / 記録 <委任の記録の URL>` の 1 行を投稿すること、起動し直したあとは最新の `主の委任:` の URL を `記録` に持つ最新のこの行から値を取り、引けなければ委任を使わないことを書く。取り消しは、主の取り消しの発言を受けた次のターンの最初のツール呼び出しでエピックに 1 行目 `主の委任: 取り消し` を投稿すること、投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` のどれかなら効きそれ以外の投稿者の `主の委任:` は数えないことを書く。委任が有効かの 6 条件（spec の要件「委任が有効かを決まった条件で確かめる」の文。エピックの番号 3 つの一致を含む）も書く 触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:55（手順 8）
- [ ] 3.2 手順 8 の「主に上げる前に親が自分で記録を照らす」の前に、委任で送る条件（spec の要件「親は有効な委任があり子の推奨が許容のときだけ、委任で許容を送る」）と送る文の書式、エピックへの `主の委任で送った: 子 #<N> <停止の記録の URL>` の 1 行を足す。委任が効く止まりは spec の要件「委任が効く止まりを決まった条件で確かめる」の 4 条件の文（①子 issue の番号を、本文で最初に現れる `Closes #N`・`Fixes #N`・`Refs #N` の `N` に持つ開いた PR に `needs-approval` が付いている ②その PR の、投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` で `## リスク宣言` で始まる最新のコメントが `主のリスク許容が必要。` の行を持ち、`対象 HEAD:` が PR の今の HEAD と同じで、`主の回答:` で始まる行をまだ持たない（G では、今確かめている委任の形の記録の行だけは除く） ③停止の記録の作成日時が、そのコメントの作成日時と委任の確認の timestamp の両方より後 ④停止の記録の `推奨:` の値（先頭の空白を除く）が `許容する` で始まる）をそのまま書く。二重送信の防止（手順 7・8 で同じ子が再び挙がったとき、その子の `主の委任で送った:` の行の URL が最新の停止の記録の URL と同じなら送り直さず子の再開を待つ）も書く 触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:55（手順 8）
- [ ] 3.3 「親から届いた返事」に、末尾が `[主の委任: …]` の返事の受け取り方（`--delegated`・委任が有効かの 6 条件・委任が効く止まりの 4 条件の文を epic.md と同じ文字列で・`[主の委任: …]` の返事を `--relayed` に掛けないこと・通らないときの頼み方）を足す。既存の「添え書きが無い」の判定に `[主の委任: …]` も添え書きとして数えることを足す。`[主の発言: …]` の経路の文は変えない。書式と真正性確認の正本は pr-review-gate 手順 5 と書く 触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:14
- [ ] 3.4 文面を固定する bats に、3.1〜3.3 で足した文の検査を足す。少なくとも次を固定する: 推奨の判定の固定文字列 `` `推奨:` の値（先頭の空白を除く）が `許容する` で始まる ``／「委任が効く止まり」の 4 条件の文が epic.md と epic-child-stop.md に同じ文字列で入っていること（4.3 で pass.md も同じ文字列を検査する）／答え方の行の `任せる`／`委任の確認の場所: セッション ` の行の書式／`主の委任: 取り消し` と「次のターンの最初のツール呼び出し」／二重送信の防止の文／`[主の委任: …]` の返事を `--relayed` に掛けない文 触る範囲: plugins/dev-workflow/tests/develop-skill.bats:843-884（relayed reply の検査の後ろ）

## 4. pr-review-gate

- [ ] 4.1 手順 5 の合格条件の表に `親経由で受領（委任）` の行を足し、「親経由で受けた許容」の段落のあとに、委任の形の記録の書式と真正性確認（spec の Scenario「委任の形の真正性確認」の各項目、`真正性確認: 済 …（owner-reply-check.sh --delegated 終了コード 0）`、落ちたときの扱い、守備範囲）を足す 触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:64（表）、plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:109-132（親経由で受けた許容の真正性確認）
- [ ] 4.2 手順 3-c の条件 3 と 1 行目の書式に委任の形と、引き継ぎの時点で委任が有効かを確かめ直すことを足し、手順 6 の復帰手順の表のリスク許容待ちの行に委任の形の追記を足す。spec の MODIFIED の 2 要件に合わせる: 要件「引き継ぎの元は真正性確認済みの主の直接の回答に限る」の分として、委任の形の元の記録は `--delegated` で回し直し（`--relayed` は使わない）、委任が今も有効で、停止の記録が元の記録を最初に追記した宣言より後のときだけ引き継ぐこと・取り消し後は引き継がないこと、守備範囲の①②に委任の形を足すこと。要件「引き継いだ宣言の書式と合格条件」の分として、1 行目の `<元の回答>（<日時>）` の形を、回答リンク・`会話で受領`・`親経由で受領`・`親経由で受領（委任）` の 4 つにし、追記は 4 行のままにすること。3-c には「`親経由で受領（委任）（親セッション ` で始まる行は委任の形、`親経由で受領（親セッション ` で始まる行は従来の形」と見分け方を 1 文書くこと 触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:39（3-c 条件 3）、plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:51（1 行目の書式）、plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:67（復帰手順の表）
- [ ] 4.3 文面を固定する bats に、4.1・4.2 で足した文の検査を足す。少なくとも次を固定する: pass.md の推奨の判定の固定文字列（3.4 と同じ）／「委任が効く止まり」の 4 条件の文が pass.md に epic.md・epic-child-stop.md と同じ文字列で入っていること／`真正性確認: 済 — 確認者 ` の行の `owner-reply-check.sh --delegated 終了コード 0`／hold.md 3-c の 1 行目の形が 4 つあること（`親経由で受領（委任）（親セッション ` を含む）／hold.md 3-c で委任の形は `--delegated` で確かめ直し `--relayed` を使わない旨の文 触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:1568-1637（relayed reply の検査の後ろ）

## 5. 仕上げ

- [ ] 5.1 変更の記録を書く 触る範囲: plugins/dev-workflow/changes/1293.md（新規）
- [ ] 5.2 公開版の検査を通す（オーナーの固有名・アカウント名・PC の絶対パスを足していないこと。新しい bats はスクリプトの部品の表の対象かを docs/public-private-split.md で確かめ、要れば表を直す） 触る範囲: docs/public-private-split.md（確かめるだけ。要れば直す）、plugins/dev-workflow/scripts/forbidden-words-check.sh（回すだけ）
