## 1. 先に起こす issue と確認

- [x] 1.1 flatmate の `scripts/agent-status.sh` の `read_harness_rules_state`（`$CLAUDE_DIR/rules` 直下の symlink を数える）を、新しい張り先（`rules/claude-harness/`）でも「配線あり」と数えるように直す issue を flatmate に起こす（この change では直さない）。issue 番号を PR 本文に書く 触れる範囲: scripts/ なし（起票のみ）。起票済み: https://github.com/genetta-inc/flatmate/issues/1738

## 2. sync.sh

- [x] 2.1 `link_dir` に「この harness の根」「旧位置の掃除先」を渡せるようにし、公開版の張り先を `$CLAUDE_DIR/rules/claude-harness` にする。新位置に張ったあとで旧位置の公開版を指す symlink を消す 触れる範囲: scripts/sync.sh:61-117、scripts/sync.sh:119-120
- [x] 2.2 dirty 判定つき ff-only pull を関数にし、overlay の clone にも使う 触れる範囲: scripts/sync.sh:37-58
- [x] 2.4 壊れた symlink の掃除を「行き先が `<CLAUDE_DIR>/plugins/marketplaces/` の下」で決める形にし、`claude-harness/*/` と output-styles を対象に含め、空になった `claude-harness/<名前>/` を消す。公開版の output style を張るとき、同名の既存 symlink の行き先が marketplace の下なら張り替える 触れる範囲: scripts/sync.sh:61-117
- [x] 2.3 overlay の探索（許可ファイル `<CLAUDE_DIR>/harness-overlays` の読み取り、許可に無い marketplace を張らず pull もしない、許可したのにディレクトリ・印が無い、`.harness-overlay` の名前の検証、重複名の扱い）と、overlay の rules を `claude-harness/<名前>/`、output-styles を直下に張る。冒頭のコメント（挙動の節）を直す。個人版の名前を書かない（`tests/public-names` が見る） 触れる範囲: scripts/sync.sh:1-33、scripts/sync.sh:119-123

- [ ] 2.5 許可の取り消しの掃除（要件「許可から外した overlay の symlink は、リンク先が残っていても消す」）を実装する。許可ファイルと overlay の処理が済んだあとに呼ぶ別関数にし、今回張られた overlay の marketplace 名と公開版の名前の一覧を渡す。対象は `rules/claude-harness/*/` と `output-styles/` の symlink で、行き先が `<CLAUDE_DIR>/plugins/marketplaces/<名前>/` の下かつ名前が一覧に無いもの。リンク先が存在していても消し、空になった `claude-harness/<名前>/` を消す。許可ファイルが無くても呼ぶ。何も出力せず、終了コードに影響させない 触れる範囲: scripts/sync.sh:61-135、scripts/sync.sh:140-200（overlay の処理のあと）

## 3. テスト

- [x] 3.1 `tests/rules-sync.bats` の既存テストを新しい張り先に直す。overlay のテストは許可ファイルを書く形に直し、許可していない marketplace・許可ファイル無し・空行とコメント・許可したのにディレクトリが無い／印が無い・不正な行、のテストを足す。pull が許可に無い marketplace に行かないことは `--no-pull` なしで偽の git リポジトリを使って確かめる。仕様の各シナリオ（新位置・旧位置の移行・overlay・不正名・overlay 名の重複・overlay 名と同名の実ファイル・張り先の内容の違う実ファイル・overlay 無しで標準エラー空・同名ルール・output style の同名・output style の順序の食い違い・他所を指す symlink の保持・overlay 撤去後の掃除・無関係な壊れたリンクと実ファイルが残ること。終了コードも各テストで確かめる。許可ファイルが空行とコメントだけで標準エラー空・終了 0 のテストと、検査エラー（ディレクトリが無い・印が無い・印の名前が空・不正名）がそれぞれ単独で起きる＝有効な overlay が他に無い状態のテストも足す）に対応するテストを足す。テスト名は ASCII のみ 触れる範囲: tests/rules-sync.bats:1-80（新規テストは末尾に追加）

- [ ] 3.2 許可の取り消しのテストを足す: 許可から外すとリンク先が残っていても rules と output style の overlay の symlink と空ディレクトリが消える・公開版の symlink は残る・2 つの overlay の片方だけ外すと外した側だけが消える・marketplace の外を指す symlink と実ファイルは残る・許可ファイルを消しても跡が消える。いずれも標準エラー空・終了コード 0 を確かめる。客の Mac の模擬（overlay 無しで標準エラー空・終了 0）が変わらないことも確かめる。テスト名は ASCII のみ 触れる範囲: tests/rules-sync.bats（新規テストは末尾に追加）

## 4. 文書

- [x] 4.1 `rules/README.md` の「導入・更新」節と `docs/worktree-recovery.md` に、許可ファイルの書き方と置き場を足し、張り先のサブディレクトリ・overlay の印のファイル・同名ルールの扱い（両方読まれる、食い違う内容は書かない）・output style は公開版優先を書く。個人版の名前は書かない 触れる範囲: rules/README.md:7-30
- [x] 4.2 `docs/worktree-recovery.md` の `~/.claude/rules/*.md` の記述を新しい張り先に合わせる 触れる範囲: docs/worktree-recovery.md:12-14
- [ ] 4.4 `rules/README.md` と `docs/worktree-recovery.md` の許可ファイルの説明に、許可ファイルから外すと次の sync.sh の実行で張った symlink が（リンク先が残っていても）消えることを一文足す。個人版の名前は書かない 触れる範囲: rules/README.md:7-30、docs/worktree-recovery.md:12-14
- [x] 4.3 変更記録 `plugins/dev-workflow/changes/1130.md`（版は上げない。changes/ の置き場の既存例に合わせる） 触れる範囲: plugins/dev-workflow/changes/1130.md（新規）

## 5. 個人版リポジトリ側（別 PR。このリポジトリの worktree の外）

- [ ] 5.1 個人版の根に `.harness-overlay`（中身 `oratta` の 1 行）を置き、オーナーの PC の `~/.claude/harness-overlays` に個人版の marketplace のディレクトリ名を 1 行書く手順（例: `printf '%s\n' <個人版の marketplace のディレクトリ名> >> ~/.claude/harness-overlays`。住人にも届く）を README に足し、README の `ln -sfn ... ~/.claude/rules/harness-dev.md` の手順を、sync.sh が張る説明に直す。記録先はこの issue

## 6. 確かめ方（マージ後の確認として PR 本文に移す。6.1 の前にオーナーの PC で許可ファイルに 1 行書く）

- [ ] 6.1 マージ後、marketplace の clone で `scripts/sync.sh` を 1 回走らせる（開発用 clone や worktree の sync.sh は走らせない）。`ls -l ~/.claude/rules/claude-harness ~/.claude/rules/claude-harness/oratta` で出どころが見え、`~/.claude/rules` 直下に公開版の symlink が残っていないこと
- [ ] 6.2 別の cwd で `claude -p --model haiku` に、公開版のルール 1 本と個人版のルール 1 本（`harness-dev.md`）の冒頭の文を答えさせる。スキルは `claude -p "/weekly-report が使えるか"` のような 1 問、hook は `/hooks` の一覧で確認する
- [x] 6.3 客の Mac の模擬: 使い捨ての `CLAUDE_CONFIG_DIR` で overlay 無しの `scripts/sync.sh --no-pull` が標準エラー空・終了コード 0（テストが同じことを見る）
