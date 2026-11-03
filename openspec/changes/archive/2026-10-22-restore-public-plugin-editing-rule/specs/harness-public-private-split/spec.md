## MODIFIED Requirements

### Requirement: 個人版に移した部品は移した記録に載せ、公開版に残さない

issue #1129 で個人版のリポジトリ `oratta/claude-harness-oratta` に移した部品（プラグイン `weekly-report`・プラグイン `daily-report`・`plugins/dev-workflow/docs/auto-merge-deployments.md`・`plugins/capability-registry/scripts/fmtoken.sh`・`plugins/capability-registry/skills/capability-registry/1password.md`・`plugins/capability-registry/skills/capability-registry/SKILL.md` の「表記規約（生成文にも適用すること）」と「資格情報の階層（どこに置くかはプロジェクトごとに決めない）」の 2 節）は、`docs/public-private-split.md` の節「個人版に移した部品」の表に 1 行ずつ載せなければならない（MUST）。各行は部品・移した先（個人版のリポジトリの中のパス）・写し元の公開版の commit SHA を持つ。移した部品の行は仕分けの表に置いてはならない（MUST NOT）。`rules/plugin-editing.md` はこの表に載せない。ファイル 1 本をまるごと移したのではなく、全員に要る部分を公開版に残し、Harness 開発者向けの部分だけを個人版の `rules/harness-dev.md` に移したので、公開版に部品が残る。移した部分は、表のあとの段落に移した先と写し元の commit SHA を書く（MUST）。

公開版は移した部品を持ってはならない（MUST NOT）。具体的には、移したファイルとディレクトリのパスの `git ls-files` が 0 件で、`.claude-plugin/marketplace.json` の `plugins[]` と bundle に `weekly-report`・`daily-report` が無く、capability-registry の SKILL.md に移した 2 節の見出しが無い。`tests/public-private-split.bats` が、移した部品のパスと見出しを節「個人版に移した部品」の表から読んで確かめる。プラグイン `weekly-report`・`daily-report` を移したことで付属のファイル（`changes/`・`tests/` など）もプラグインごと公開版から無くなる。capability-registry の `tests/fmtoken.bats` は付属のファイルの扱いに従い `fmtoken.sh` と一緒に移す。

個人版の固有名（`fmtoken`・`weekly-report`・`daily-report`・`auto-merge-deployments`・`1password.md`・`Fieldy` など）が公開版の作業ツリーに残っていないかは、個人版のリポジトリに置いた辞書と検査（`scripts/check-public-leak.sh`）で確かめ、公開版の辞書には足さない（要件「公開版の辞書は公開済みの語だけを持ち、語は辞書にだけ書く」）。

この要件を確かめる公開版の検査の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 想定する入力の出どころ: このリポジトリの管理者が書く節「個人版に移した部品」の表と、テストの実行時点の `git ls-files`・`marketplace.json`・SKILL.md の `## ` の見出し
- 拾う誤り: 移した部品が公開版に戻ること（ファイルの復活・marketplace への再登録・節の見出しの復活）／移した部品の行が仕分けの表に残ること／節の表の行が移した先か写し元の SHA を欠くこと
- 通してよい具体例: 個人版に移した中身が写し元と一致しているか、写し元の SHA が実在するか、公開版に残った文に個人版の固有名があるか。個人版の `scripts/check-public-leak.sh` と人のレビューが見る
- 見つかる穴をすべて塞ぐことは完了条件にしない

個人版の検査（`scripts/check-public-leak.sh <公開版の作業ツリー>`）は、個人版の辞書を公開版の `plugins/dev-workflow/scripts/forbidden-words-check.sh` に `--dict` で渡し、当たりが許可に載った行を除いて 1 件でもあれば終了コード 1 で終わり、当たりを `<パス>:<行番号>:<語>` の形で出さなければならない（MUST）。当たりが無ければ終了コード 0 で終わる。公開版の消す PR は、終了コード 0 の結果を本文に載せるまでマージしない。この検査の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 想定する入力の出どころ: 引数に渡した公開版の作業ツリーの `git ls-files` のうち、`rules/`・`output-styles/`・`scripts/`・`plugins/` の配下とルート直下の `README.md`・`CLAUDE.md`・`AGENTS.md`・`CONTRIBUTING.md`（`openspec/`・`docs/public-private-split.md`・`_longruns/`・`changes/`・`CHANGELOG.md`・`tests/`・`evals/` を除く）と、オーナーが書く個人版の辞書と許可。敵対的な入力は想定しない
- 拾う誤り: 辞書の語（`fmtoken`・`weekly-report`・`daily-report`・`auto-merge-deployments`・`1password.md`・`Fieldy`）が、検索の範囲のファイルの本文かパス名に、許可に無い形で残ること
- 通してよい具体例: 辞書に無い個人版の固有名、除いた範囲（経緯の記録や公開版の検査）に残る語、公開版の過去の履歴に残る語。人のレビューと辞書の整備が見る
- 見つかる穴をすべて塞ぐことは完了条件にしない

#### Scenario: 移した部品が公開版に無い
- **WHEN** 公開版で、節「個人版に移した部品」の表の各パスを `git ls-files` で調べ、`marketplace.json` と capability-registry の SKILL.md の見出しを読む
- **THEN** どのパスも 0 件で、`weekly-report`・`daily-report` は `plugins[]` にも bundle にも無く、移した 2 節の見出しは SKILL.md に無い

#### Scenario: 移した部品を戻すと落ちる
- **WHEN** 公開版に `plugins/capability-registry/scripts/fmtoken.sh` を置き直す
- **THEN** `tests/public-private-split.bats` が、そのパスを挙げて落ちる

#### Scenario: 移した部品の行を仕分けの表に残すと落ちる
- **WHEN** 仕分けの表に `plugins/capability-registry/scripts/fmtoken.sh` の行を残す
- **THEN** `tests/public-private-split.bats` が落ちる

#### Scenario: 移した記録が読める
- **WHEN** `docs/public-private-split.md` の節「個人版に移した部品」を読む
- **THEN** 移した部品ごとに移した先のパスと写し元の commit SHA が書かれ、`rules/plugin-editing.md` については表のあとの段落に、個人版の `rules/harness-dev.md` へ移した部分と写し元の commit SHA が書かれている

#### Scenario: 公開版に個人版の固有名が残っていない
- **WHEN** 個人版のリポジトリで `scripts/check-public-leak.sh <公開版の作業ツリー>` を実行する
- **THEN** 終了コードが 0 で、結果が公開版の消す PR の本文に載っている

#### Scenario: 公開版に個人版の固有名が残っていると落ちる
- **WHEN** 公開版の作業ツリーの `README.md` に `weekly-report` を含む行が残ったまま、個人版のリポジトリで `scripts/check-public-leak.sh <公開版の作業ツリー>` を実行する
- **THEN** 終了コードが 1 で、`README.md:<行番号>:weekly-report` が出る。公開版の消す PR はこの状態ではマージしない

#### Scenario: 除いた範囲の語は個人版の検査を通る
- **WHEN** 公開版の `docs/public-private-split.md` の節「個人版に移した部品」に `fmtoken.sh` がある
- **THEN** 個人版の検査は終了コード 0 で終わる

## ADDED Requirements

### Requirement: 公開版のプラグイン編集ルールは全員に要る部分だけを持ち、個人版の側のファイル名を変える

公開版の `rules/plugin-editing.md` は、プラグインを入れた誰の環境でも当てはまる次の 5 点だけを書かなければならない（MUST）。(1) インストールされたフォルダ（`~/.claude/plugins/marketplaces/...`）は自動更新されるので直接編集しない、(2) `~/.claude/commands/` と `~/.claude/skills/` へのローカルコピーを編集しない、(3) `~/.claude/rules/*.md` は marketplace のフォルダを指す symlink なので、ルールもその部品を持つリポジトリ側で直す、(4) 部品は、その部品を持つリポジトリの開発用 clone（marketplace のフォルダの外）で直す。公開版の部品にも個人版の部品にも当てはまる書き方にし、個人版の名前とパスは書かない、(5) 状態がおかしくなっても手動で削除せず、`/plugin uninstall` → `/reload-plugins` → `/plugin install` → `/reload-plugins` の順で直す。

次のものは公開版の `rules/plugin-editing.md` に書いてはならない（MUST NOT）: Harness 開発者向けの手順（開発用 clone の場所を決める環境変数 `CLAUDE_HARNESS_DEV_DIR`、別プロジェクト作業中に Harness を直すときの手順、`/wt-setup`、`sync.sh`、版を上げないことと `changes/` の記録と Draft PR）と、個人版の名前（`claude-harness-oratta`）。これらは個人版のリポジトリ `oratta/claude-harness-oratta` の `rules/harness-dev.md` に置く。

個人版のルールのファイル名は、公開版と同じ `plugin-editing.md` にせず `harness-dev.md` とする。どちらも `~/.claude/rules/` に symlink で並べるため、同じ名前だと片方がもう片方を上書きし、全員に要る部分か Harness 開発者向けの部分のどちらかが読まれなくなるからである。`docs/public-private-split.md` の仕分けの表は `rules/plugin-editing.md` を「公開版」の 1 行で載せ、その理由に、全員に要る部分を残して Harness 開発者向けの部分を個人版に移したことを書く。

この要件を確かめる検査（`tests/public-private-split.bats`）の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 想定する入力の出どころ: このリポジトリの管理者が書く `rules/plugin-editing.md` の本文と仕分けの表。敵対的な入力は想定しない
- 拾う誤り: `rules/plugin-editing.md` が公開版に無いこと／本文に上の「書いてはならない」語（`CLAUDE_HARNESS_DEV_DIR`・`/wt-setup`・`sync.sh`・`claude-harness-oratta`・`Draft PR`）のどれかがあること／本文に (5) の復旧の手順の語（`/plugin uninstall`・`/plugin install`・`/reload-plugins`）が無いこと／仕分けの表の `rules/plugin-editing.md` の分類が「公開版」でないこと
- 通してよい具体例: (1)〜(4) の書き方の良し悪し、検索語に無い Harness 開発者向けの語が混ざること、個人版の `rules/harness-dev.md` の中身。人のレビューが見る
- 見つかる穴をすべて塞ぐことは完了条件にしない

#### Scenario: 公開版のルールが全員に要る部分だけを持つ
- **WHEN** 公開版の `rules/plugin-editing.md` を読む
- **THEN** 上の (1)〜(5) が書かれ、`CLAUDE_HARNESS_DEV_DIR`・`/wt-setup`・`sync.sh`・`claude-harness-oratta`・`Draft PR` のどれも書かれていない

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
