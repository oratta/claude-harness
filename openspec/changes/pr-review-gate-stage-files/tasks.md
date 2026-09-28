## 1. 検査を先に書く（Red）

- [x] 1.1 `plugins/dev-workflow/tests/pr-review-gate-index.bats` を作る: SKILL.md が 10,000 バイト以下／索引にコードブロックが無い／段の表の各行がちょうど 1 つの段のファイルを指し実在する／手順番号の対応表が 1・2-0・2-1（3 行）・2-2・3・3-b・3-c・4・5・6 を持ち、指す先にその見出しがある／各手順の見出し行（2-1 は括弧書きまで含めた 3 つの見出し行）が pr-review-gate 配下の 1 ファイルにだけある／`description` が、いまの SKILL.md の値を bats に固定で持たせた期待値の文字列と一致する
- [x] 1.2 1.1 を走らせて落ちることを確かめる

## 2. 段のファイルへ移す（節ごとに「段のファイルに足す」と「SKILL.md から消す」を同じ commit にする）

- [x] 2.1 `declarations.md` を作り、手順 3・3-b と前提の「HEAD SHA」「仕様宣言」を移す
- [x] 2.2 `stages/prepare.md` を作り、手順 1・手順 2 の冒頭・2-0 と前提の「stale passed」を移し、「G として動くとき」節に gate-runner.md の needs-reviewer の payload と、その直後の「レビュー実行者:」PR コメントの段落を移す（レビュアーに渡す指示の行は `stages/reviewer-brief.md` を指す）
- [x] 2.3 `stages/review-run.md` を作り、見出しを `#### 2-1. レビューの実行（レビュー実行者）` にして 2-1 のレビュー実行者の優先順・Codex 呼び出し規約・Task サブエージェントのモデル・各 PC の確認を移し、「G として動くとき」節に gate-runner.md の従来経路のレビュー実行者の表と Codex の起動と完了確認を移す
- [x] 2.4 `stages/reviewer-brief.md` を作り、見出しを `#### 2-1. レビューの実行（レビュアー向け指示）` にして 2-1 のレビュアー向け指示ブロック・共通一覧契約・Codex の読み替え表を移す
- [x] 2.5 `stages/triage.md` を作り、見出しを `#### 2-1. レビューの実行（止める判定と仕分け）` にして 2-1 のマージを止めるかの判定・仕分け表・混在の段落・収束ルール・2 周目の終わり・決める役と 2-2 を移し、「G として動くとき」節に failed / needs-decider / review-incomplete の return 書式と、再開のうち W の修正後の再レビュー・決める役の裁定受領を移す
- [x] 2.6 `stages/pass.md` を作り、手順 4・5 と前提の「auto-merge の配備状況」を移し、「G として動くとき」節に passed の return 書式を移す
- [x] 2.7 `stages/hold.md` を作り、3-c・手順 6・4 分類と前提の「リポ固有の仕組み」を移し、「G として動くとき」節に保留の return 書式と、再開のうち保留の解除・許容済み PR で HEAD が動いたときを移す
- [ ] 2.8 各段のファイルの冒頭に入口の条件、末尾に出口（次に読むファイル）を書き、段をまたぐ参照をファイル名と節名に直す
- [ ] 2.9 SKILL.md を索引に書き直す（目的と通過の必須 4 点の要約・段の表・宣言の書式ファイルの案内・手順番号の対応表・develop 以外で本体が直接使うときの読み方）

## 3. 読み手側の付け替え

- [ ] 3.1 `gate-runner.md` から SKILL.md を Read する指示を消し（pr-review-gate の手順 1〜5 を実行する義務の文は残す）、時点ごとに読むファイルの表を置く。段に移した節を消し、残す節（役割と入力・経路の判別・三表の照合と補足受領・return の共通部分・再開の振り分け・モデルとコンテキスト上限）の参照先を段のファイルに直す
- [ ] 3.2 `worker.md` の (3b) の仕様宣言の参照先を `declarations.md` にする
- [ ] 3.3 `skills/develop/SKILL.md` と `plugins/dev-workflow/references/*.md` のうち `pr-review-gate/SKILL.md` のパスや「SKILL.md 手順 2-1 のブロック」を直接指している行を、段のファイルのパスに直す（番号だけの参照「pr-review-gate 手順 N」はそのまま）
- [ ] 3.4 `scripts/codex-develop.py` の正本一覧を、gate phase は索引・6 段・`declarations.md`、review phase は gate-runner.md・`stages/reviewer-brief.md` にする

## 4. 既存検査の付け替えと確認

- [ ] 4.1 pr-review-gate の文言を検査している bats（`pr-review-gate-skill`・`pr-review-gate-spec-declaration`・`develop-roles`・`develop-adapter-review-routing`・`model-escalation-policy`・`subagent-waiting`・`ci-watch` ほか `git grep -l pr-review-gate -- plugins/dev-workflow/tests` の全件）の各アサーションを、その文言が移った段のファイルに付け替える。`pr-review-gate-skill.bats` の `^#### 2-1\. `〜`^#### 2-2\. ` の範囲切り（いまの 289・433 行付近）と、2-0 と 2-1 の見出しの行番号で範囲を取る検査（いまの 610 行付近）は、同じファイルに両方の見出しがある前提なので、移った段のファイルの中での範囲に直す
- [ ] 4.2 `tests/test_codex_develop.py` の `CANONICAL SOURCE` の期待値を 3.4 に合わせる
- [ ] 4.3 `./scripts/test.sh` と `./scripts/lint.sh` が exit 0 であることを確かめる
- [ ] 4.4 `openspec validate pr-review-gate-stage-files --strict` が通ることを確かめる

## 5. 記録

- [ ] 5.1 `plugins/dev-workflow/changes/553.md` に変更記録を書く
- [ ] 5.2 PR 本文に、G の `docs_median`（`scripts/subagent-context-audit.sh --by-role` の値）とファイルごとのバイト数を記録する枠を用意する（実測値は G のゲート通過後に記入。15K トークンを超えたら内訳と follow-up issue の URL を書く）
