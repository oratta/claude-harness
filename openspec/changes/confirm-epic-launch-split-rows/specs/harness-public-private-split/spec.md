## MODIFIED Requirements

### Requirement: 各行は決めた分類と理由を持つ

表の各行の分類は「公開版」「個人版」のどちらかでなければならない（MUST）。ただし 1 つのプラグインの中で行き先が割れるプラグインの行は「分割」とし、そのプラグインを次の要件「分割したプラグインは部品の行で全体を重複なく覆う」に従って部品の行で覆わなければならない（MUST）。どの行も理由の欄が空であってはならない（MUST NOT）。理由は #1128 の判断の基準（公開版: 誰の環境でも意味がある道具・住人のふるまいに効くもの・営業で見せる動き。個人版: オーナーに固有の業務・アカウント・資格情報の置き場・固有名に依存するもの）のどれに当たるかが読めるように書く。

#1128 で「保留（#1123 の後）」にした 5 行（`epic-dispatch.sh`・`epic-launch-orca.sh`・`stop-judge.sh`・`parent-pass-criteria.md`・`parent-merge-criteria.md`）は、#1129 で #1123 の結果を見て公開版に確定した。分類の値「保留（#1123 の後）」は使わない（MUST NOT）。文書の節「保留の行の確定」は、どの行を何を見て確定したかの記録として残す。

#### Scenario: 分類の値が決めた値だけである
- **WHEN** 表の分類の欄を読む
- **THEN** すべての値が「公開版」「個人版」「分割」のどれかで、部品の行の分類は「公開版」か「個人版」である

#### Scenario: 理由が空の行がない
- **WHEN** 表の理由の欄を読む
- **THEN** 空の行がない

#### Scenario: 保留の値の行は落ちる
- **WHEN** 表のある行の分類を「保留（#1123 の後）」に書き換える
- **THEN** `tests/public-private-split.bats` が決めた値以外の分類として落ちる

#### Scenario: 確定したエピック実行の部品は公開版の部品として扱われる
- **WHEN** 固有記述の一覧に `plugins/dev-workflow/scripts/epic-launch-orca.sh` の実在する行を指す行を足す
- **THEN** 一覧の行が公開版に決まる部品に属さないという理由では落ちない

#### Scenario: 確定した理由が表と文書に残る
- **WHEN** 確定した 5 行の理由の欄と節「保留の行の確定」を読む
- **THEN** #1123 の結果のどこを見て公開版に決めたか（起動部品が Orca と tmux から選ぶ形になり、Orca が無い環境でもエピックを回せる）が書かれている

### Requirement: dev-workflow の公開版の部品は Orca 経路を除いて決めた固有名を持たない

公開版に残る dev-workflow の部品は、固有記述の一覧で担い手なしだった Orca 経路以外の行の語を、許可リストに載った行を除いて持たない。次の検索の当たりは、許可リストの行を除いて 0 件でなければならない（MUST）。検索は大文字と小文字を区別する。

- `moko`: `plugins/dev-workflow/` の公開版のファイル
- `new-resident`: `plugins/dev-workflow/references/pr-body-format.md`・`plugins/dev-workflow/skills/issueify/SKILL.md`・`plugins/dev-workflow/skills/push-guard-setup/SKILL.md`
- `flatmate`: 上の 3 ファイルに加えて `plugins/dev-workflow/templates/escalation-tripwires.md`・`plugins/dev-workflow/scripts/pr-state.sh`・`plugins/dev-workflow/skills/memory-refresh/SKILL.md`・`plugins/dev-workflow/templates/auto-merge/docs/auto-merge.md`
- `CLAUDE_HARNESS_DEV_DIR`: `plugins/dev-workflow/references/ci-watch.md`・`plugins/dev-workflow/skills/memory-refresh/SKILL.md`
- 公開版のファイル: 仕分けの表で個人版に決まるファイル（`plugins/dev-workflow/docs/auto-merge-deployments.md`）は対象に含めない。#1129 で公開版に確定したエピック実行の部品（`epic-dispatch.sh`・`epic-launch-orca.sh`・`stop-judge.sh`・`parent-pass-criteria.md`・`parent-merge-criteria.md`）は対象に含める。付属の `changes/`・`CHANGELOG.md`・`tests/`・`evals/` は含めない
- 許可リスト: 載せない行の基準のうち「出典や経緯としてだけ名前を挙げる行」に当たる行は、`tests/public-private-split.bats` の中の許可リストに「ファイルのパス・行に含まれる固定の文字列・当たる基準」の 3 つ組で 1 件ずつ載せたものだけを通す。許可リストに無い当たりは落ちる。許可リストの各件は、判定の表（tasks の実施欄）に同じ行がなければならない

この検索の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 拾う誤り: 直した語が上のファイルに戻ってくること／許可リストに無い当たりが現れること
- 通してよい具体例: 検索語に無い別の固有名・許可リストの載せ方の良し悪し・書き換えた文の良し悪し。人のレビューと固有記述の一覧が見る
- 見つかる穴をすべて塞ぐことは完了条件にしない

#### Scenario: 直した語が戻ると落ちる

- **WHEN** `plugins/dev-workflow/references/pr-body-format.md` に flatmate の `new-resident` が issue テンプレートを配ると書く
- **THEN** `tests/public-private-split.bats` が落ちる

#### Scenario: 許可リストの出典の行は通る

- **WHEN** 検索対象のファイルに、出典としてだけ flatmate の名を挙げる行があり、許可リストに載っている
- **THEN** 検索のテストは通る。同じファイルの別の行に flatmate を書き足すと、許可リストに無いので落ちる

#### Scenario: 検索語に無い固有名は検査を通る

- **WHEN** 対象のファイルに検索語に無い別の固有名がある
- **THEN** 検索のテストは通り、その誤りは人のレビューが見る

#### Scenario: 確定したエピック実行の部品も moko の検索の対象になる

- **WHEN** `plugins/dev-workflow/scripts/stop-judge.sh` に `moko` を書き足す
- **THEN** `tests/public-private-split.bats` が落ちる

### Requirement: 載せない行の基準に起動部品の 1 つとして並べた行を含める

`docs/public-private-split.md` の「載せない行の基準」は、「差し替え可能な起動部品の 1 つとして Orca を並べた行」を載せない行に含めなければならない（MUST）。当たる行は、Orca を tmux など他の起動部品や方式と並べた 1 つとして書いていなければならず（MUST）、Orca だけを前提にした行（Orca 経路と名乗る・Orca に登録済みのリポジトリを探す・Orca の親が子のターミナルに打ち込む）は当たらない（MUST NOT）。develop `SKILL.md` の「部品ごとの欄」の見出しと表は、この基準に当たる行として一覧に載せない。既存の基準の例「Orca や端末から起動した Claude Code」は一般の製品を並べた例で、この基準は `epic-launch-<名前>.sh` の差し替えの部品として並べた行である。

この基準は `epic-launch-orca.sh` が公開版に決まる前提で当てるもので、#1129 で `epic-launch-orca.sh` は公開版に確定した。文書はこの前提が満たされたことを書かなければならず（MUST）、#1177 で外した行（節「起動部品の 1 つとして一覧から外した行」）は一覧に戻さない。節は外した行の場所の記録として残す。

「載せない行の基準」は、さらに「Orca の起動部品の中の行と、起動部品を呼ぶ側で Orca の部品を選んだときの振る舞いを書いた行」を載せない行に含めなければならない（MUST）。当たるのは `plugins/dev-workflow/scripts/epic-launch-orca.sh` の行と、`plugins/dev-workflow/scripts/epic-dispatch.sh` の中で Orca の部品を選んだときの動き（orca のコマンド・Orca の画面の印・Orca 管理のワークツリーの判定・Orca に登録されたリポジトリ）を書いた行だけで、起動部品の外で Orca だけを前提にした手順を書く行（develop の SKILL.md や `references/` の文書の「Orca 経路の…」）は当たらない（MUST NOT）。当たらない行は「Orca を使う場合」の書き方か別セッション方式の書き方に直すか、一覧に載せて担い手を付ける。

#### Scenario: 起動部品を並べた行は一覧に載せなくてよい

- **WHEN** 「部品ごとの欄」の表の Orca の部品の列の行を候補語 `Orca` で検索する
- **THEN** 当たった行は基準で説明でき、一覧に載せなくてよい

#### Scenario: 公開版に確定したので外した行は戻さない

- **WHEN** 節「起動部品の 1 つとして一覧から外した行」を読む
- **THEN** `epic-launch-orca.sh` が #1129 で公開版に確定したので、その行を一覧に戻さないことが書かれている

#### Scenario: Orca の起動部品の中の行は一覧に載せなくてよい

- **WHEN** `epic-launch-orca.sh` と、`epic-dispatch.sh` の Orca の部品を選んだときの動きを書いたコメントを候補語 `Orca` で検索する
- **THEN** 当たった行は基準「Orca の起動部品の中の行と、起動部品を呼ぶ側で Orca の部品を選んだときの振る舞いを書いた行」で説明でき、一覧に載せなくてよい

#### Scenario: Orca だけを前提にした手順の行は基準に当たらない

- **WHEN** `parent-pass-criteria.md` の冒頭のように、起動部品の外で「Orca 経路のエピックで…」と Orca だけを前提にした行を候補語で検索する
- **THEN** その行はどちらの基準にも当たらず、別セッション方式の書き方に直すか、一覧に載せて担い手を付ける
