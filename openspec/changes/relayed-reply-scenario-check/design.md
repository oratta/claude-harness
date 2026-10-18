## Context

#1066 の受け入れ条件は 2 段で判定していた。(a) 偽の文では、試しの PR の宣言に追記が無く `needs-approval` が付いたまま、子 issue に `REASON=not-owner` / `REASON=not-after` の停止の記録が出る。(b) 本物の文では、宣言に 2 行が追記され `needs-approval` が外れる。この判定の中に、スクリプトの出力で決まる部分と、LLM が手順書（`stages/pass.md` / `hold.md`）に沿って行うゲートの動作で決まる部分が混ざっている。

## Goals / Non-Goals

**Goals:**
- 偽 2 件・本物 1 件に対する `--relayed` の合否を、主の入力も GitHub も Orca も使わず、コマンド 1 つで出す。
- 「偽では通らない」「本物では通る」の両方を同じ実行で固定する。

**Non-Goals:**
- 宣言コメントへの追記と `needs-approval` の付け外しの検証。これはゲートの LLM 動作で、機械では回せない。
- 試しのエピック・子 issue・PR を実 GitHub に作る方式。外部状態が残り、後始末が要る。

## Decisions

1. **固定する範囲は `owner-reply-check.sh --relayed` の出力と終了コードまで。** 偽の文を落とす判定の実体はここにある。ゲートが `REASON` を見て通さない側に倒す文言は `pr-review-gate-skill.bats` / `develop-skill.bats` が既に固定している。残る継ぎ目（LLM が実際にその手順を守るか）は実機 Orca の確認に残す。
2. **形は新しい bats 1 ファイル。** 新しい実行用スクリプトは足さない。`scripts/test.sh` が `git ls-files '*.bats'` で拾うので、`scripts/test.sh owner-reply-relayed-scenario` が「コマンド 1 つ」になる。代案（`plugins/dev-workflow/scripts/` に自己診断スクリプトを置く）は、保守するコードが増えるのに得るものが無いので採らない。
3. **既存の個別テストと別ファイルにする理由。** 既存は 1 ケース 1 ログ。ここでは実際の試しと同じく、1 本の親ログに偽 → 偽 → 本物を並べ、停止の記録・親の報告・主の発言を実物に近い順に置く。混在ログでの取り違え（偽の行が本物の判定に影響する・その逆）を見る。既存の fixture の書き方（`OWNER_REPLY_PROJECTS_DIR` と jsonl の行）は同じものを使う。
4. **主の「許容」の代わりの入力** は、ログに書く主の発言の行（`origin.kind` が `human`、本文「許容」）。`OWNER_REPLY_PROJECTS_DIR` を bats の一時ディレクトリに向ける。
5. **ケース。** 同一ログ・同一の停止の記録で次の 3 件に加えて対の確認を行う。
   - 偽 1a: uuid が親の発言の行 → `REASON=not-owner`、exit 1
   - 偽 1b: uuid がツールの結果の行 → `REASON=not-owner`、exit 1
   - 偽 2: 停止の記録より前の主の発言の行 → `REASON=not-after`、exit 1
   - 本物: 親の報告（停止の記録の URL を含む）のあとの主の「許容」の行 → exit 0、`MATCH:` 行に「許容」、`MATCHES=1`
   - 偽が本物の前後どちらに並んでも結果が変わらないこと（偽の行を足したログでも本物が通る）。

## Risks / Trade-offs

- ゲートの LLM 動作（宣言追記・ラベル付け外し）はこのテストでは守れない。実機 Orca の確認が必要な場面は変わらず残る。仕様にその範囲を明記し、「全部自動化した」と読まれないようにする。
- `owner-reply-check.sh` の 9 条件を変えたとき、個別テストとこのシナリオの両方を直す。重複は許容する（観点が違うため）。
