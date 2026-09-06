## Why

`casting-check.sh` の `strip_html_comments` は Markdown のコードフェンスを認識しないため、フェンス内に書式の説明用として置いたリテラルの `<!--`（閉じマーカーなし）だけで正常な配役表が unclosed-comment で止まる（exit 1。resolve も fail-closed で出力しない）。誤検出は fail-closed 側に倒れるので壊れた解決結果は出ないが、正しい配役表が使えない（oratta/claude-harness#187。PR #145 の Codex レビューで検出され follow-up に切り出したもの）。

## What Changes

- `strip_html_comments` にコードフェンス状態（バッククォート型 ```` ``` ```` / チルダ型 `~~~`。字下げは3スペースまで、閉じは開きと同じ記号を同じ本数以上だけ置いた行）を持たせ、フェンス内の `<!--` / `-->` を走査対象から外す。フェンス内の行はそのまま出力する（リテラルなので落とさない）
- フェンスが閉じられないまま EOF に達しても閉じ忘れとは扱わない（コメントが開いていなければ 0 を返す）。HTML コメントの中にあるフェンス記号はコメントの一部としてフェンスを開かない
- 検出（unclosed-comment）とパース（stripped_copy）は同じ走査を共有しているので、報告と解決結果が同時に直る。フェンスの外にある本物の閉じ忘れは従来どおり検出する
- フィクスチャ4本（`code-fence-comment` / `code-fence-unclosed` / `code-fence-plus-unclosed` / `comment-with-fence-marks`）と退行テスト5件を追加する
- `plugin.json`・`marketplace.json`・`SKILL.md` の casting バージョンを `0.4.3` に上げる（`0.4.2` は並行 PR #200 用）

捨てた代案: フェンス内の行を出力から落とす（コメントと同じ扱い）。フェンス内に表行を書く配役表は想定外だが、従来はフェンス内の行も出力されていたので、挙動を最小限に変えるためそのまま出す側に倒した。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `casting-project-files`: Requirement「casting-check.sh の検出項目」の ⓪' にコードフェンス内を走査対象から外す MUST / MUST NOT を追加し、Scenario を4つ追加する

## Impact

- `plugins/casting/scripts/casting-check.sh` の `strip_html_comments` のみ（呼び出し側の `stripped_copy` / `check_unclosed_comment` は変えない）
- 既存の `unclosed-comment` / `stray-close-plus-unclosed` / `inline-comment` フィクスチャの結果は変わらない
- 並行 PR #200（fix/186-consultation-check-anchors）とはスクリプトの関数が重ならない。version 行（0.4.2 → 0.4.3）の衝突はマージ順に応じて後から積む側が解決する
