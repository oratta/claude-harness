## Context

- `~/.claude/rules/` のサブディレクトリの .md が読まれることを、実ホームで確かめた（2026-10-22）。`~/.claude/rules/<試験用>/a.md`（symlink）と `<試験用>/sub/b.md`（symlink）と `<試験用>/sub/c.md`（実ファイル）を置き、別の cwd から `claude -p --model haiku` で 3 つの合言葉をすべて答えられた。試験用のファイルとディレクトリは確認後にすべて削除した。symlink 経由でも 2 階層でも読まれる
- 公開版は営業で見せる動きを置く側で、個人版の固有名を書いてはならない（`tests/public-names`）。だから sync.sh は個人版を名指しせず、overlay の仕組みだけを持つ
- 客の Mac には個人版が無い。何も見つからないときは、何も出さず公開版だけを張る

## Goals / Non-Goals

**Goals**
- オーナーの PC の対話セッションと住人に、公開版と個人版の rules・output style を同じ入口（公開版の sync.sh）で届ける
- `~/.claude` を見て、どの Harness が置いたかが分かる
- 同名のルールがぶつからない

**Non-Goals**
- #1226 の改名（marketplace 名の変更）
- plugin（スキル・hook）の配線。plugin は marketplace を 2 つ入れれば効き、sync.sh の仕事ではない
- flatmate 側の `agent-status.sh` の直し（別 issue）
- 優先順位の仕組み。Claude Code のルールには優先順位が無い

## Decisions

1. **張り先を出どころごとのサブディレクトリに分ける（採用）**。公開版は固定名 `claude-harness`、overlay は `claude-harness/<名前>`。
   - 却下した案: フラットのまま同名を接頭辞で避ける（見て出どころが分からない）。個人版に別の sync.sh を持たせる（住人が呼ぶのは公開版の sync.sh 1 本なので、個人版が届かない。重複もする）
   - `claude-harness` は marketplace のディレクトリ名から作らない。#1226 で公開版の名前が変わっても張り先が動かない
   - 公開版の中に overlay のディレクトリが入る形（`claude-harness/<名前>/`）はオーナーの提案どおり。公開版の symlink の掃除は `claude-harness/*.md` だけを見るので、overlay のサブディレクトリには触れない
2. **overlay の見つけ方は印のファイル**。`<CLAUDE_DIR>/plugins/marketplaces/*/.harness-overlay`（1 行目がサブディレクトリ名、`[a-z0-9][a-z0-9-]*` に合うもの）。名前が不正・空・`claude-harness` の下に既にある実ファイルの名前と衝突するときは、その overlay だけ警告して飛ばし非 0 にする。overlay が 1 つも無いときは何も出さない。探す場所を `CLAUDE_DIR` 基準にするので、テストは使い捨ての `CLAUDE_CONFIG_DIR` の中に偽の overlay を置ける
3. **規則の名前がぶつかったとき**: 張り先が別ディレクトリなのでファイルとしてはぶつからず、公開版と個人版の同名ルールは両方とも読まれる（上書きも優先もしない）。内容が食い違うルールを作らないのは個人版を書く人の責任とし、README に書く。同じ overlay 名を持つ印のファイルが 2 つの marketplace にあるときは、先に見つけた（辞書順で先の）1 つだけを張り、もう片方を警告して飛ばす
4. **output style はフラットのまま、公開版優先**。output style は設定の `outputStyle` に名前を 1 つ書いて選ぶので、同名が 2 つあると選択が曖昧になる。サブディレクトリを読むかも確かめていない。overlay の output style が公開版と同名なら、公開版の symlink を残し、overlay の分は張らず警告して非 0 にする（既存の「他所を指す symlink には触らない」と同じ動き）
5. **旧位置の片付け**: 新位置に張ったあとで、`~/.claude/rules/*.md` のうち symlink で、行き先が `<公開版>/rules/` 直下のファイルのものを消す。新を張ってから旧を消す順なので、読まれないルールが出る時間が無い（一時的に同じ規則が 2 か所に見えるだけ）。実ファイルと他所を指す symlink には触らない
6. **pull**: 今の dirty 判定つき ff-only pull を関数にして、overlay の clone にも同じ条件で行う。overlay の pull の失敗は警告して非 0（配線は続ける）
7. **--no-pull の住人**: 住人は `--no-pull` で呼ぶので、overlay も張り直しだけになる。pull は Claude Code の marketplace 自動更新と、手で打つ sync.sh が担う

## Risks / Trade-offs

- flatmate の `agent-status.sh` が張り先の移動後に「未配線」と誤表示する。起こるのは公開版の sync.sh が新しい張り先に張り直した PC（オーナーの PC と、公開版を更新した PC）。実害は表示だけ。公開版の merge 後に flatmate 側の直しが入るまで続くので、直しの issue を先に起こしておく
- 古い公開版の clone を持つ PC は旧位置のまま動く（旧 sync.sh は旧位置に張る）。新しい sync.sh が走った時点で新位置に移る
- #1226 で marketplace 名が変わると、旧位置の symlink の行き先（旧名のパス）が `<公開版>/rules/` に一致しなくなり、片付けの対象から外れる。#1226 側の入れ直しの手順で旧名の symlink の扱いを決める（この change では扱わない）

## 触れない既存の記述

- `always-on-injection-scope` の「path スコープは配布形での両方向の実機確認」は `~/.claude/rules/<name>.md` の形で書かれているが、すでに終わった確認の手順で、張り先の移動で要件の MUST は変わらない。次に確認をやり直すときに新しい張り先で行う
- `harness-public-private-split` の個人版ルール名 `harness-dev.md` の要件は、名前を決める理由の文だけが古くなる（今は同名でもぶつからない）。名前は変えない（MUST の部分は不変）。理由の文を直す PR は別に起こしてよい
