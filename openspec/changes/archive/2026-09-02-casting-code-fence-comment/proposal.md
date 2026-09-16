## Why

`casting-check.sh` の `strip_html_comments` は Markdown のコードフェンスを認識しないため、フェンス内に書式の説明用として置いたリテラルの `<!--`（閉じマーカーなし）だけで正常な配役表が unclosed-comment で止まる（exit 1。resolve も fail-closed で出力しない）。誤検出は fail-closed 側に倒れるので壊れた解決結果は出ないが、正しい配役表が使えない（oratta/claude-harness#187。PR #145 の Codex レビューで検出され follow-up に切り出したもの）。

## What Changes

- `strip_html_comments` にコードフェンス状態（バッククォート型 ```` ``` ```` / チルダ型 `~~~`。字下げは3スペースまで、閉じは開きと同じ記号を同じ本数以上だけ置いた行）を持たせ、フェンス内の `<!--` / `-->` を走査対象から外す。フェンス内の行はコメント内の行と同じく出力からも落とす
- フェンスの閉じ忘れは新しい検出項目 `unclosed-fence` として報告する。フェンス内の行を落とす扱いの裏返しで、閉じ忘れたフェンスは以降の行を EOF まで無視させ、閉じ忘れた `<!--`（既存の `unclosed-comment`）とまったく同じ形で上書き行を黙って全滅させるため。HTML コメントの中にあるフェンス記号はコメントの一部としてフェンスを開かないので、2つの閉じ忘れは同時に立たない
- 検出（unclosed-comment / unclosed-fence）とパース（stripped_copy）は同じ走査を共有しているので、報告と解決結果が同時に直る。フェンスの外にある本物の閉じ忘れは従来どおり検出する
- フィクスチャ6本（`code-fence-comment` / `code-fence-unclosed` / `code-fence-unclosed-swallow` / `code-fence-plus-unclosed` / `code-fence-example-row` / `comment-with-fence-marks`）と退行テスト8件を追加する
- `plugin.json`・`marketplace.json` の casting バージョンを `0.5.2` に上げ、検出項目数の表記（README・SKILL.md・スクリプト冒頭・2つの description・spec）を `7項目` から `8項目` に揃える

捨てた代案1: フェンス内の行をそのまま出力する（挙動の変化を最小にする）。当初はこちらに倒したが、レビューで、書式の説明としてフェンス内に置いた記入例の表行が実在の配役として抽出され、同じ観点は先頭行が勝つ規則でフェンスより後ろの人間の指定に優先することが判明した（担い手が `主` から `エージェント` に化け、人間承認が要る論点が自走扱いになる）。落とす側に倒し直した。

捨てた代案2: 落とす側に倒したうえで、フェンスの閉じ忘れは従来どおり報告しない（spec の MUST NOT を残す）。閉じ忘れたフェンスより後ろの上書き行が EOF まで黙って落ちる新しい fail-open が残り、同一の失敗モードである `unclosed-comment` を検出していることと説明がつかないため、検出項目を1つ足す側に倒した。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `casting-project-files`: Requirement「casting-check.sh の検出項目」の ⓪' にコードフェンス内を走査対象から外す MUST / MUST NOT を追加し、検出項目 ⓪''（unclosed-fence）を新設して「フェンスの閉じ忘れを閉じ忘れとして扱ってはならない (MUST NOT)」を「unclosed-fence として報告しなければならない (MUST)」に書き換え、項目数の表記を8項目に揃え、Scenario を6つ追加・1つ書き換える

## Impact

- `plugins/casting/scripts/casting-check.sh` の `strip_html_comments`（戻り値を 0/1/2 に拡張）と `check_unclosed_comment`（`check_unclosed_markers` に改名し、戻り値 2 を `unclosed-fence` として報告）。`stripped_copy` は変えない
- 既存の `unclosed-comment` / `stray-close-plus-unclosed` / `inline-comment` フィクスチャの結果は変わらない
- 並行 PR #200（fix/186-consultation-check-anchors）とはスクリプトの関数が重ならない。version 行（0.4.2 → 0.4.3）の衝突はマージ順に応じて後から積む側が解決する
