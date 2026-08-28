## ADDED Requirements

### Requirement: 仕様宣言を通過の必須点に加える
pr-review-gate スキルは、手順 3 に「仕様宣言」を positive affirmation として追加しなければならない（MUST）。仕様宣言は `## 仕様宣言` 見出しと 1 行目 `対象 HEAD: <40 桁フル SHA>` を持つ PR コメントで、本文は「仕様を更新した（change 名・archive 済み・`仕様レビュー: APPROVE` の所在）」か「仕様変更なし＋理由」のどちらかちょうどとする（MUST）。「書かない」を選んではならず（MUST NOT）、スキル冒頭の必須点の列挙に仕様宣言を含めなければならない（MUST）。

#### Scenario: 手順 3 に仕様宣言の 2 形がある
- **WHEN** SKILL.md の手順 3 を読む
- **THEN** `## 仕様宣言` 見出し・`対象 HEAD:` 1 行目・「更新した」形と「変更なし＋理由」形の両テンプレートが書かれている

#### Scenario: 冒頭の必須点に仕様宣言が入っている
- **WHEN** SKILL.md 冒頭の「通過の必須」の列挙を読む
- **THEN** リスク宣言・動作確認の証拠・`agent-review:passed` に加えて仕様宣言が挙がっている

### Requirement: 合格処理は仕様宣言の実在と issue 記録との整合を実測する
手順 5 は、現在の HEAD SHA を含むコメントの 1 行目一覧に「リスク宣言」「動作確認」「仕様宣言」の 3 見出しがすべて現れることを確認してからでなければ `agent-review:passed` を付けてはならない（MUST NOT）。さらに、PR 本文で最初に現れる `Closes` / `Fixes` / `Refs #N` から元 issue を解決し、その最新の `^仕様化判断: (する|しない)$` コメントと照合しなければならない（MUST）: 「する」なら、PR の変更ファイルに `openspec/` が含まれる**または**仕様宣言の「更新した」形が指す change が base ブランチで archive 済み（`openspec/changes/archive/*-<name>/` の実在を実測。スタック PR で仕様が先行 PR に入っている場合）であり、かつ issue に `^仕様レビュー: APPROVE$` で始まるコメントがあること（MUST）。「しない」なら仕様宣言が「変更なし＋理由」形であり、PR に `openspec/` 差分が**無い**こと（差分があれば「しない」と矛盾するので合格しない。判断を「する」に取り直すか差分を外す）（MUST）。記録が無い場合は合格処理をせず、判断を記録してからやり直す（MUST）。PR コメントへの記録は PR 本文に issue 参照が無い場合に限り（MUST）、issue 参照があれば issue 側が正で、issue 側に記録が無ければ issue に投稿する（MUST）。

#### Scenario: 3 見出しの実測が規定されている
- **WHEN** SKILL.md の手順 5 を読む
- **THEN** SHA 照合の出力に仕様宣言の見出しも現れることを要求し、欠けていれば合格処理をしない旨が書かれている

#### Scenario: 記録との整合表がある
- **WHEN** SKILL.md の手順 5 を読む
- **THEN** 「する → openspec 差分（または archive 済み change の実測）と `仕様レビュー: APPROVE`」「しない → 変更なし＋理由、かつ openspec 差分なし」「記録なし → 合格しない・記録してからやり直す」の 3 行を含む表が書かれている

#### Scenario: issue の無い PR の逃げ道がある
- **WHEN** SKILL.md の手順 5 を読む
- **THEN** PR コメントへの記録は PR 本文に issue 参照が無い場合に限り、issue 参照があれば issue 側が正である旨が書かれている

### Requirement: spec-touch-check スクリプトが規範パス接触と openspec 差分を報告する
dev-workflow プラグインは `scripts/spec-touch-check.sh <owner/repo> <PR番号>` を含まなければならない（MUST）。スクリプトは PR の変更ファイル一覧を取得し（環境変数 `SPEC_TOUCH_FILES` があればそれを使う）、規範を持ちうるパスへの接触（`SPEC_TOUCH=yes|no`）・`openspec/` 配下の差分の有無（`OPENSPEC_DIFF=yes|no`）・触れた規範パスの一覧を標準出力に出す（MUST）。規範パスの既定は `docs/` `.claude/` `templates/` `scripts/` `CLAUDE.md` `AGENTS.md` とし、リポ直下に `.spec-touch-paths` があればその内容で置き換える（MUST）。終了コードは、規範パスに触れて `openspec/` 差分が無いとき 2、それ以外の正常時 0、取得失敗時 1 とする（MUST）。手順 5 は「しない」判定の PR でこのスクリプトが 2 を返したとき、仕様宣言の理由に規範パス接触への言及を要求する（MUST）。

#### Scenario: 規範パスに触れて openspec 差分が無い
- **WHEN** `SPEC_TOUCH_FILES` に `docs/foo.md` と `lib/a.ts` を渡して実行する
- **THEN** `SPEC_TOUCH=yes` `OPENSPEC_DIFF=no` と `docs/foo.md` が出力され、終了コード 2 で終わる

#### Scenario: openspec 差分がある
- **WHEN** `SPEC_TOUCH_FILES` に `docs/foo.md` と `openspec/specs/x/spec.md` を渡して実行する
- **THEN** `SPEC_TOUCH=yes` `OPENSPEC_DIFF=yes` が出力され、終了コード 0 で終わる

#### Scenario: 規範パスに触れていない
- **WHEN** `SPEC_TOUCH_FILES` に `lib/a.ts` だけを渡して実行する
- **THEN** `SPEC_TOUCH=no` `OPENSPEC_DIFF=no` が出力され、終了コード 0 で終わる

#### Scenario: .spec-touch-paths で既定を置き換える
- **WHEN** カレントディレクトリの `.spec-touch-paths` に `handbook/` だけを書き、`SPEC_TOUCH_FILES` に `docs/foo.md` と `handbook/a.md` を渡す
- **THEN** `SPEC_TOUCH=yes` で一覧には `handbook/a.md` だけが出て `docs/foo.md` は出ない

#### Scenario: 手順 5 がスクリプトを参照する
- **WHEN** SKILL.md の手順 5 を読む
- **THEN** `spec-touch-check.sh` を実行し、終了コード 2 のときは「変更なし」宣言の理由に規範パス接触への言及を要求する旨が書かれている

### Requirement: auto-merge への組み込みは範囲外と明記する
SKILL.md は、仕様宣言が `対象 HEAD:` 規約に乗っているため auto-merge workflow に組み込めるが、配備済みリポへの伝播を伴うため本 change では組み込まない（別 issue）ことを明記しなければならない（MUST）。

#### Scenario: 範囲外の明記
- **WHEN** SKILL.md の仕様宣言に関する記述を読む
- **THEN** auto-merge への組み込みは別 issue である旨が書かれている
