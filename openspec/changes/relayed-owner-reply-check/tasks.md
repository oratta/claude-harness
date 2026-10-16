## 1. owner-reply-check.sh

- [ ] 1.1 主の発言の判定（`owner_text`）に 9 つ目の条件を足す: 本文（先頭の空白を除く）が `主の返事（親エピック #` か `親エピック #` で始まる行と、`<command-args>` の中身が `#<数字> （エピック #<数字> の子。` で始まる行を数えない。冒頭の説明の条件の列挙と守備範囲の文も 9 条件に直す。触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:1-22（冒頭の説明）、plugins/dev-workflow/scripts/owner-reply-check.sh:64-104（`owner_text`）
- [ ] 1.2 `--locate <セッション ID> <原文>` を足す（`MATCH: <timestamp> <uuid> <全文>`、uuid の無い行は出さない、終了コードは既定と同じ）。触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:23-58（引数の解釈）、plugins/dev-workflow/scripts/owner-reply-check.sh:107-135（照合と出力）
- [ ] 1.3 `--relayed <セッション ID> <uuid> <停止の記録の作成日時> <停止の記録の URL>` を足す（引数の検査 → not-found → not-owner → not-after → not-asked の順、時刻は `Z` と `+00:00` を同じに扱って比べる、行の timestamp を読めなければ exit 2、成功で `MATCH: <timestamp> <全文>` と `MATCHES=1`、失敗で `REASON=<…>` と `MATCHES=0`）。触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:23-58、plugins/dev-workflow/scripts/owner-reply-check.sh:59-135（python の本体）
- [ ] 1.4 bats を足す: 9 つ目の条件（2 つの頭・起動の指示の `<command-args>`、`<command-args>721 許容する` は従来どおり通る）、`--locate` の出力と uuid の無い行、`--relayed` の通る場合（親の報告と主の答えのあいだに `isCompactSummary` の行を挟んだ形を含む）、`not-found`、`not-owner`（ツールの結果・親の発言・要約・頭付きの打ち込み・起動の指示の各 uuid）、`not-after`、`not-asked`（URL を書いた親の発言が無い・停止より前にしか無い・サブエージェントの発言にしか無い）、exit 2（引数 3 個・uuid の形・日時を読めない・会話ログ無し）。入力の行の形は design.md の Context に書いた 2026-10-15 の実物に合わせる。触る範囲: plugins/dev-workflow/tests/owner-reply-check.bats:1-226（末尾に足す。setup の `add` を使う）

## 2. pr-review-gate

- [ ] 2.1 手順 5 の合格条件の表に `親経由で受領` の行を足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:46-54（合格条件の表）
- [ ] 2.2 手順 5 に「親経由で受けた許容（親経由で受領）の真正性確認」の段落を足す（記録の 1 行の書式、停止の記録のコメントの確かめ方、`--relayed` の呼び方と出力の意味、全文の読み方、宣言コメントの作成日時との比較、`真正性確認: 済 …（owner-reply-check.sh --relayed 終了コード 0）`、通らないときは手順 6 で主に子のタブでの返事を頼む）。「会話で受領」の守備範囲の文を、決まった頭の打ち込みは数えない・頭の無い文は区別できない、に書き直す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:73-94（「会話で受けた許容」の段落と守備範囲の文。その直後に新しい段落を置く）
- [ ] 2.3 手順 6 の復帰手順のリスク許容待ちの行に、親経由で受けた回答なら `親経由で受領` の 1 行を追記してから手順 5 の真正性確認に進むことを足す。手順 3-c の引き継ぎの条件 3 と、引き継ぎの 1 行目の置き換えに `親経由で受領` の形を足す（`--relayed` で確かめ直す）。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:39（3-c の条件 3）、plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:51（1 行目の置き換え）、plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:67（リスク許容待ちの行）
- [ ] 2.4 bats を足す: pass.md の手順 5 に `親経由で受領` の書式・停止の記録の確かめ方・`owner-reply-check.sh --relayed`・真正性確認の行があり、合格条件の表に行があること、hold.md の 3-c と復帰手順に `親経由で受領` があること、守備範囲の文が書き直されていること。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:1308-1360（「会話で受けた許容」の既存テストのうしろに足す）

## 3. develop の SKILL.md（3 か所だけ）

- [ ] 3.1 Orca 経路の手順 8 の `reply --as owner` の送り方に、`--locate` で uuid を引いて ` [主の発言: セッション <ID> / uuid <uuid>]` を主の答えの末尾に添えること、引けないときは添え書きなしで送り主に子のタブでの返事を頼むことを足す（手順 8 のほかの文は変えない）。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:434（手順 8 の「主の答えを受けたら」以降の文）
- [ ] 3.2 「親から届いた返事」に、添え書き付きの親経由のリスク許容を `--relayed` で確かめてから保留の解除の G に渡すこと、確かめられなければ G を起こさず主に子のタブでの返事を理由付きで頼むことを足す（書式は pr-review-gate 手順 5 の「親経由で受領」を参照し再掲しない）。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:350（「親から届いた返事」の箇条）
- [ ] 3.3 保留の行の「リスク許容を会話で受けたら」の文に、エピックの子が親経由で受けたときは「親から届いた返事」の手順に従うことを参照で足す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:183（保留の行の末尾）
- [ ] 3.4 bats を足す: 3 か所に spec の Scenario の語があること。触る範囲: plugins/dev-workflow/tests/develop-skill.bats:1-677（末尾に足す）

## 4. 記録と確認

- [ ] 4.1 既存の bats が通ることを確かめる（`scripts/test.sh owner-reply-check`・`pr-review-gate-skill`・`develop-skill`・`epic-dispatch`）。`openspec validate relayed-owner-reply-check --type change --strict` を通す
- [ ] 4.2 手元の実物の会話ログで読み取り確認をする（design.md の決定 6 の「手元の実物の会話ログでの読み取り確認」の 3 点。読むだけ）。結果を PR に書く。会話ログが手元に無ければ省いてその旨を書く
- [ ] 4.3 変更の記録を書く。触る範囲: plugins/dev-workflow/changes/1059.md（新規）
- [ ] 4.4 実機の Orca 経路の確認は、ゲートの動作確認で「主に依頼」とし、design.md の決定 6 の手順（親エピック #1038 のセッションが代行し、主は親のタブで「許容」と打つだけ）を依頼に書く
