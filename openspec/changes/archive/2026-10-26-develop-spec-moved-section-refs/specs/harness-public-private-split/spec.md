## MODIFIED Requirements

### Requirement: 載せない行の基準に起動部品の 1 つとして並べた行を含める

`docs/public-private-split.md` の「載せない行の基準」は、「差し替え可能な起動部品の 1 つとして Orca を並べた行」を載せない行に含めなければならない（MUST）。当たる行は、Orca を tmux など他の起動部品や方式と並べた 1 つとして書いていなければならず（MUST）、Orca だけを前提にした行（Orca 経路と名乗る・Orca に登録済みのリポジトリを探す・Orca の親が子のターミナルに打ち込む）は当たらない（MUST NOT）。develop の `references/epic.md` の「部品ごとの欄」の見出しと表は、この基準に当たる行として一覧に載せない。既存の基準の例「Orca や端末から起動した Claude Code」は一般の製品を並べた例で、この基準は `epic-launch-<名前>.sh` の差し替えの部品として並べた行である。

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
