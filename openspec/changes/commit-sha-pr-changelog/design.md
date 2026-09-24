## Context

このリポジトリは Claude Code プラグインのマーケットプレイス（git ソース、相対パスのプラグイン 13 本）。今は全プラグインの `plugin.json` と `marketplace.json` の `plugins[]` エントリが `version` を持ち、`rules/plugin-editing.md` と `tests/marketplace-sync.bats` の S130・S131 が PR ごとの版上げを求めている。並行 PR が同じ版の行と `CHANGELOG.md` の先頭を書き換えるので、マージのたびに残りが衝突する。

着手前の裏取り（issue #447 のコメント 5805433233）で分かっていること:

- Claude Code 2.1.281 の版の決め方は `plugin.json` の `version` → marketplace.json のエントリの `version` → マーケットプレイス clone の HEAD SHA 先頭 12 桁。最新かの判定は文字列一致。両方から消せば SHA が版になり、マージごとに更新が届く
- 実行時にプラグイン版を読むのは `plugins/dev-workflow/scripts/prompt-tripwires-refresh.sh` だけで、`version` が無いと黙って exit 0 し機能が止まる
- 多数の bats が `jq -r .version` と `sort -V` で版の下限を検査している
- `docs/worktree-recovery.md` の「cache はバージョンを上げなくても HEAD に追随する」は実挙動と違う（版が同じならキャッシュは更新されない）

## Goals / Non-Goals

**Goals:**

- 全 `plugin.json` と `marketplace.json` の `plugins[]` から `version` を消し、版を commit SHA に任せる
- `version` が復活したら CI で必ず落ちる検査を置く（`origin/main` 不要の決定論的な検査）
- 変更の記録を PR ごとの別ファイルにして、2 本の PR が同じファイルを書き換えない状態にし、それをテストで固定する
- `prompt-tripwires-refresh.sh` を `version` 無しで動かす
- 版上げを求める規約・文書・テストを全部書き換える

**Non-Goals:**

- SKILL.md の frontmatter の `version`（develop・pr-review-gate・wt-clean など）。Claude Code の更新判定に使われず、今回の衝突の主因でもないので残す。ただし `plugins/infra/skills/infra-setup/SKILL.md` の `version` は plugin の版の写しとして同期を要求されているので、写す元が無くなるこの change で消す
- 過去の `CHANGELOG.md` の書き直し
- `openspec/changes/archive/` と `_longruns/` の中の版への言及（過去の記録として残す）
- 他リポジトリのプラグイン運用、`plugins/telegram/package.json` の npm の `version`、`codex-role-profiles.json` のスキーマ版など、プラグインの版と無関係な `version`
- マージ後の利用者側の更新確認と、稼働中の作業への周知（issue の受け入れ条件 7・8。マージ後に本体が行う）

## Decisions

### 版を消す範囲: plugin.json と marketplace.json の両方

片方でも残るとその値が版として固定され、上げない限り更新が止まる。両方から消し、両方を検査する。

### S130・S131 の置き換え: 「version を持たない」決定論的検査

S130（marketplace と plugin.json の版の一致）は「全 plugin.json に `version` が無い」「全 `plugins[]` エントリに `version` が無い」に置き換える（テスト名は S130・S131 の番号を引き継ぎ、どちらが何を見るかを名前に書く）。S130b のディレクトリ登録の検査はそのまま残す。S131 が使っていた merge-base の解決関数は他に使われなくなるので消す。

検査は `jq` だけで書き、`origin/main` を参照しない。CI の `actions/checkout` は浅い clone で `origin/main` を持たないが、この検査は skip されずに走る。`scripts/test.sh` が拾うので `.github/workflows/ci.yml` に手を入れる必要は無く、S131 を「ローカル実行で担保」と説明していたコメントだけを直す。

代案として「merge-base からの差分で `version` 行の追加を検出する」も考えたが、CI では skip されるので、版を上げる古い PR が後からマージされる経路を塞げない。不採用。

### S139（無関係な PR がクリーンにマージできる）は description で確かめる

版の行が無くなるので、先頭と末尾のエントリの `description` をそれぞれ別ブランチで書き換えてマージする形にする。確かめたい性質（エントリごとの変更が互いに衝突しない）は同じ。

### 各プラグインの bats の版の検査は削る

版の下限（`sort -V`）や marketplace との版一致を見ている検査は、版が無くなると意味を失う。代わりの検査（該当機能が実在するか）はそれぞれのファイルが既に持っているので、版の検査部分だけを削り、同じテストに版以外の検査（例: description に「仕様宣言」を含む、agents の登録）が同居しているものはその部分を残す。`plugins/product-handover/tests/plugin-structure.bats` の「版が semver 形式」は「`version` が無い」に変える。SKILL.md の frontmatter の版の下限を見る検査は Non-Goals のとおり触らない（`infra-fixes.bats` の S29 だけは「infra-setup の SKILL.md に `version` が無い」に変え、S31 は削る）。

### prompt-tripwires-refresh.sh は CLAUDE_PLUGIN_ROOT の値をそのまま比較する

比較する値の候補は 3 つあった。

| 候補 | 更新の検知 | 毎プロンプトのコスト | 採否 |
|---|---|---|---|
| `CLAUDE_PLUGIN_ROOT` の値そのもの（パス全体） | キャッシュの版名（SHA）のディレクトリが変われば変わる | 追加の処理なし（変数の比較だけ） | 採用 |
| `CLAUDE_PLUGIN_ROOT` のディレクトリ名（basename） | 同上 | `basename` かパラメータ展開が要る | パス全体が同じ情報を含むので不要 |
| テンプレート（`templates/escalation-tripwires.md`）の内容のハッシュ | 本文が変わったときだけ変わる。`--plugin-dir` の開発時も検知できる | 毎プロンプト `cksum` などの外部コマンドが走る | fast path を重くするので不採用 |

パス全体を採る。`plugin.json` を読む処理（`tr` と `sed` で `version` を抜く部分）は消す。状態ファイルに旧方式の版番号が残っているセッションは、次のプロンプトで値が一致しないので 1 回だけ再注入し、以後はパスで比較する（更新が起きた直後なので、この 1 回は正しい挙動）。`--plugin-dir` で開発中のプラグインを読んでいる間はパスが変わらないので再注入されないが、これは今の版方式でも版を変えない限り同じで、開発時の手動確認の範囲に留める。

### 変更記録の方式: plugins/<name>/changes/<番号>.md

1 PR 1 ファイルにすれば 2 本の PR が同じファイルを書き換えない。番号は記録先が issue ならその番号、Draft PR が記録先ならその PR 番号（issue と PR は同じ番号空間なので別の PR と同じ名前にならない）。ファイル名 `^[0-9]+\.md$` と 1 行目の `# ` 見出しをテストで確かめる。

変更記録を書くことを全 PR に強制する検査は置かない。強制するには merge-base との差分が要り、CI で決定論的に走らせられないため。書く対象は規約（`rules/plugin-editing.md`）で示す。

変更記録のファイルをリリースごとにまとめ直す仕組み（towncrier のような集約）は置かない。版が SHA になり、リリースという単位が無くなるため。

### 過去の CHANGELOG.md の凍結を決定論的に検査する

`plugins/dev-workflow/CHANGELOG.md` と `plugins/product-handover/CHANGELOG.md` のタイトル行の直後に移行の 1 行を書き、その後に最初に現れる `## ` 見出しが移行時点の最新の項目（dev-workflow は `## 2.13.37 —`、product-handover は `## v0.1.0 —`）で始まることをテストで確かめる。先頭に項目を足す PR はこれで落ちる。あわせて `plugins/*/CHANGELOG.md` がこの 2 件だけであることも確かめる。

代案として「CHANGELOG.md のハッシュをテストに固定する」も考えたが、落ちたときに何が悪いのかが読み取れないので不採用。

新しい規約のテストは、規約の置き場所に合わせてリポジトリ直下に `tests/plugin-release-convention.bats` として置く（プラグインをまたぐ規約なので、特定プラグインの tests/ に置かない）。

### 聖域ファイルは最小限の差分にする

`CLAUDE.md`・`AGENTS.md` は「`plugin.json` の bump」の語を外すだけにし、`rules/plugin-editing.md` は版上げの 1 行を「版は上げない（commit SHA が版になる）。変更の記録は `plugins/<name>/changes/<番号>.md` に書く」に置き換えるだけにする。PR は `human-merge` ラベルで出す。常時注入の文字数はほぼ変わらない見込みで、`tests/injection-budget.txt` の予算を超えたときだけ値を動かし、理由を PR 本文に書く。

## Risks / Trade-offs

- [版を上げる古い PR が後からマージされて `version` が復活し、更新が止まる] → 置き換え後の S130・S131 が CI で常に走り、main を取り込んでいない PR も取り込んだ PR も `version` があれば落ちる。周知（受け入れ条件 8）はマージ後に本体が行う
- [移行のマージ直後、利用者のキャッシュは semver 名から SHA 名に 1 回切り替わる] → 文字列一致の判定なので更新として扱われる（裏取り済み）。受け入れ条件 7 でマージ後に確認する
- [`CLAUDE_PLUGIN_ROOT` のパスはプラグインの中身以外の理由（キャッシュの置き場所の変更など）でも変わりうる] → そのときは再注入が 1 回余分に起きるだけで、機能は壊れない（fail-soft）
- [変更記録を書き忘れても検査で落ちない] → 強制は規約のみ。版上げの強制が衝突の原因だったので、記録の強制を CI に載せるより書き忘れを許すほうを取る
- [触るファイルが多い（manifest 14 件、bats 十数件、文書数件）] → いずれも「版の撤去」から機械的に決まる書き換えで、論点は増えない。分割すると移行中に版の有無が混在するので 1 PR にまとめる

## Migration Plan

1. 1 本の PR で manifest・テスト・スクリプト・文書・変更記録の方式を同時に変える（`human-merge`）
2. マージ後、本体が利用者側で `/plugin update` を行い、`~/.claude/plugins/cache/oratta-claude-harness/dev-workflow/` に SHA 名のディレクトリができることを確かめる（受け入れ条件 7）
3. 開いている PR と稼働中の worktree に、main を取り込んで自分の版の変更を消し、CHANGELOG の追記を `changes/` のファイルに移すよう伝える（受け入れ条件 8）

戻す場合は PR を revert すれば版が戻り、利用者のキャッシュは semver 名に再び切り替わる。

## Open Questions

なし。
