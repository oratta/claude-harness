# Design

## Context

動機と 8 件の一覧は proposal.md を参照。起点の HEAD / origin/main は `28e6575826365c6395767ba5ccb587bf36bd6d93`。PR #841 は merge 済みで、issue #843 の対象はすべて存在する。

Step B のユーザー向け docs 更新に該当するため仕様化する。2 本の現行 spec を直すので、1 capability / 1 ファイル限定の文言合わせは適用しない。両 spec の変更は同じ解散の説明整合であり、独立した機能の追加や順序依存のある設計判断はない。受け入れ条件 5 項目を 1 PR で満たす単一 change とする。

## Goals / Non-Goals

**Goals:** issue にある記録のずれと検査の見逃しを、指定された 7 ファイルの範囲で直す。

**Non-Goals:** プラグインを再導入・削除する実装、利用者の設定や distilled ファイルの削除、MUST / MUST NOT / SHALL の意味の変更、archive の過去の delta spec の修正は行わない。

## Decisions

### 文書は指定された記述だけを直す

- archive の tasks.md は 4.1〜4.5 のチェックを完了済みにする。実施済み作業の記録の訂正であり、記載コマンドを再実行する指示ではない。
- archive の proposal.md は What Changes と Modified Capabilities の両方を「2 要件を外し、cooking 残骸掃除の要件から skill-pack の言及を外す」に直す。archive の design と delta に既にある 2 REMOVED + 1 MODIFIED の説明と一致させる。
- archive の design.md は README の 3 手順に合わせる。uninstall → 残った旧 enabledPlugins エントリの削除 → 公式 telegram の導入とし、公式側の設定は公式手順に委ねる。
- README は all から外した対象と、telegram が元から入っていなかったことを区別する。解散手順に、`~/.claude/skills/distilled/e2s-*/SKILL.md` と `<repo>/.claude/skills/distilled/` は uninstall で消えない旨を 1 行足す。手動削除の実行や新しい移行手順は追加しない。
- 現行 spec の守備範囲は dev-workflow README の例示だけを削除し、版履歴など残る例示・許容場所・Scenario は維持する。handoff spec は skill-pack を参照する括弧書きだけを削除する（issue が認める削除案）。要件の全文を MODIFIED delta に保持し、名称・規範文・Scenario の整理は広げない。

### README の第 1 列で対象プラグインを検出する

issue 指定の awk 版に替える。解散済みプラグイン節より前だけを走査し、表の第 1 列の前後空白とバッククォートを取り除いて、3 プラグイン名と完全一致で比較する。例えば `|telegram|`、`| telegram |`、`|` とバッククォート付きの名前が続く行を同じ名前として扱う。別列の説明や似た名前では検出せず、解散済み一覧の行は引き続き許可する。既存の固定空白 grep では表記ゆれを見逃すため、名前と列の境界を比較する。

失敗時は行を出力し、awk 自体の失敗も成功扱いにしない。許容パスの正規表現と参照検査の範囲は変更しない。

### 修正した検査を一時コピーで検証する

永続の修正は既存 bats に収める。指定 scratchpad 内に README と bats の一時コピーを置き、テスト 6 だけを `bats --filter 'README plugin table has no row for the three plugins'` で実行する。検査コードのコピーを書き直すのではなく、修正済み bats 自身を使う。

正常な README は exit 0。解散済み節より前に各対象名の空白・バッククォートなしの行（必須例は `|telegram|`）を入れると非 0 となる。空白やバッククォート付きでも検出し、解散済み節にだけ同じ行があるケースは exit 0 となることを確かめる。実 repo の README は fixture のために編集しない。

## Risks / Trade-offs

- [archive の再解釈が広がる] → 修正は tasks / proposal / design の指定箇所だけ。archive 内の spec とレビューの履歴は保持する。
- [現行 spec の意味が変わる] → delta の差分が例示 1 つと括弧書き 1 つの削除に限られ、元の Scenario 全文が一致することを確認する。
- [一時ファイルの検査が実際のテストと乖離する] → 修正済み bats をコピーしてテスト 6 を実行し、`|telegram|` を見逃さないことを実測する。
- [作業中 delta に元要件の禁止文字列が含まれる] → この検査は git 追跡ファイルを入力にするため、delta を追跡した後、archive 前の参照検査はこの change の spec だけで落ち得る。その一致を確認し、許容範囲は広げず、finish 段で archive してから suite の全件成功を確かめる。README 一覧表の検査と fixture の確認は archive 前にも実行する。
- [実装対象が 7 ファイルで共通規約の 5 ファイル超に当たる] → 本 spec 段では実装しない。既知の対象数と範囲を coordinator に返し、分割や実装段の進め方は coordinator が決める。

## Migration Plan

R1 が仕様レビューを APPROVE した後、coordinator の再開指示で実装する。実装後は issue の受け入れ条件を検証し、finish 段で本 change を archive する。archive で上書きする既存要件の内容は delta と同一にし、現行 spec の直接編集と二重に変更を広げない。配布・version bump・利用者環境の操作は不要で、差し戻す場合は通常の revert とする。
