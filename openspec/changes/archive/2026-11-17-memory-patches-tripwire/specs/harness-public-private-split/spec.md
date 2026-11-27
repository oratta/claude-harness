## MODIFIED Requirements

### Requirement: 公開版のプラグイン編集ルールは全員に要る部分だけを持ち、個人版の側のファイル名を変える

公開版の `rules/plugin-editing.md` は、プラグインを入れた誰の環境でも当てはまる次の 6 点だけを書かなければならない（MUST）。(1) インストールされたフォルダ（`~/.claude/plugins/marketplaces/...`）は自動更新されるので直接編集しない、(2) `~/.claude/commands/` と `~/.claude/skills/` へのローカルコピーを編集しない、(3) `~/.claude/rules/*.md` は marketplace のフォルダを指す symlink なので、ルールもその部品を持つリポジトリ側で直す、(4) 部品は、その部品を持つリポジトリの開発用 clone（marketplace のフォルダの外）で直す。公開版の部品にも個人版の部品にも当てはまる書き方にし、個人版の名前とパスは書かない、(5) 状態がおかしくなっても手動で削除せず、`/plugin uninstall` → `/reload-plugins` → `/plugin install` → `/reload-plugins` の順で直す、(6) プラグインの動きへの指摘をメモリにその場しのぎで書くときは、同じターンでその部品を持つリポジトリに直し先の issue を立て、メモリの frontmatter に `patches: <issue の URL>` を書く（issue が閉じたらそのメモリは消す候補になる）。(6) は全プロジェクトのセッションに常時読み込まれる規則で、メモリを書く時点で効かせるために rules に置く（memory-refresh の手順は整理のときにしか読まれない）。

次のものは公開版の `rules/plugin-editing.md` に書いてはならない（MUST NOT）: Harness 開発者向けの手順（開発用 clone の場所を決める環境変数 `CLAUDE_HARNESS_DEV_DIR`、別プロジェクト作業中に Harness を直すときの手順、`/wt-setup`、`sync.sh`、版を上げないことと `changes/` の記録と Draft PR）と、個人版の名前（`claude-harness-oratta`）。これらは個人版のリポジトリ `oratta/claude-harness-oratta` の `rules/harness-dev.md` に置く。

個人版のルールのファイル名は、公開版と同じ `plugin-editing.md` にせず `harness-dev.md` とする。どちらも `~/.claude/rules/` に symlink で並べるため、同じ名前だと片方がもう片方を上書きし、全員に要る部分か Harness 開発者向けの部分のどちらかが読まれなくなるからである。`docs/public-private-split.md` の仕分けの表は `rules/plugin-editing.md` を「公開版」の 1 行で載せ、その理由に、全員に要る部分を残して Harness 開発者向けの部分を個人版に移したことを書く。

この要件を確かめる検査（`tests/public-private-split.bats`）の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 想定する入力の出どころ: このリポジトリの管理者が書く `rules/plugin-editing.md` の本文と仕分けの表。敵対的な入力は想定しない
- 拾う誤り: `rules/plugin-editing.md` が公開版に無いこと／本文に上の「書いてはならない」語（`CLAUDE_HARNESS_DEV_DIR`・`/wt-setup`・`sync.sh`・`claude-harness-oratta`・`Draft PR`）のどれかがあること／本文に (5) の復旧の手順の語（`/plugin uninstall`・`/plugin install`・`/reload-plugins`）が無いこと／仕分けの表の `rules/plugin-editing.md` の分類が「公開版」でないこと
- 通してよい具体例: (1)〜(4) の書き方の良し悪し、検索語に無い Harness 開発者向けの語が混ざること、個人版の `rules/harness-dev.md` の中身。人のレビューが見る
- 見つかる穴をすべて塞ぐことは完了条件にしない

#### Scenario: 公開版のルールが全員に要る部分だけを持つ
- **WHEN** 公開版の `rules/plugin-editing.md` を読む
- **THEN** 上の (1)〜(6) が書かれ、`CLAUDE_HARNESS_DEV_DIR`・`/wt-setup`・`sync.sh`・`claude-harness-oratta`・`Draft PR` のどれも書かれていない

#### Scenario: Harness 開発者向けの語が戻ると落ちる
- **WHEN** 公開版の `rules/plugin-editing.md` に `CLAUDE_HARNESS_DEV_DIR` を含む行を足す
- **THEN** `tests/public-private-split.bats` が、その語を挙げて落ちる

#### Scenario: ルールが公開版から消えると落ちる
- **WHEN** 公開版から `rules/plugin-editing.md` を消す
- **THEN** `tests/public-private-split.bats` が、そのパスを挙げて落ちる

#### Scenario: 仕分けの表で公開版と決まっている
- **WHEN** 仕分けの表の `rules/plugin-editing.md` の行を読む
- **THEN** 分類が「公開版」で、理由に、全員に要る部分を残し Harness 開発者向けの部分を個人版の `rules/harness-dev.md` に移したことが書かれている

#### Scenario: 個人版のファイル名が公開版と重ならない
- **WHEN** 個人版のリポジトリの `rules/` を列挙する
- **THEN** `plugin-editing.md` が無く、`harness-dev.md` がある

#### Scenario: 公開版のルールがメモリの patches: の書き方を持つ
- **WHEN** 公開版の `rules/plugin-editing.md` を読む
- **THEN** プラグインの動きへの指摘をメモリにその場しのぎで書くときは同じターンで issue を立て `patches:` を書くことが書かれ、個人版の名前とパスは書かれていない
