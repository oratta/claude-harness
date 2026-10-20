## Context

一覧の dev-workflow 以外の担い手なしの行は約 50 行。行の中身は 4 種類に分かれる: 出力例・テストの入力にある固有名（moko・suimei・uranai・shukan・`/Users/oratta`）、手本として固有名の実例を指す行、flatmate との取り決めを書く行（rules/README.md・sync.sh・statusline・casting・product-handover）、保管庫の名前を書く行（capability-registry）。

## Decisions

### D1: 直し方の選び方

- 出力例・テストの入力・手本の指示: 固有名を `example` 系の名前に置き換える（`workspace/moko/CLAUDE.md` → `workspace/example/CLAUDE.md`、`/Users/oratta/wt/bar` → `/Users/example/wt/bar`）。「置き換える前提の例」は載せない行の基準に既にある。検査が文字列を読むテストは、置き換えた入力でも同じ結果になることを確かめる。実例の参照（`suimei` の `marketing-daily-report.yml`）は、実例なしでも読める文にするか「自分のリポジトリの同種のファイル」に直す
- flatmate との取り決めを書く行: flatmate の名を外し、一般の言い方にする（「定期実行は利用者の環境が担う（cron など）」）。オーナーの環境の事実（flatmate の boot.sh がやっていること）は rules/README.md のような「オーナーの環境でだけ読まれる」文書では個人版へ書き分けられるが、ここでは #1129 の範囲に入れず、公開版に必要な事実だけを残す
- 保管庫名（`human-only` 保管庫・`agents` 保管庫・`uranai--...`）: 「秘密情報の保管庫」と書き、アイテム名は `<project>--<NAME>` の形にする。製品名の対応は個人版の `1password.md` が持つ
- 個人版へ移す部品を指す行（`rules/README.md:43` の `plugin-editing.md`、`SKILL.md:65` の SA の権限変更）: 「個人版が入っていれば」の条件つきに直す。消すのでなく、公開版だけの環境でも読める文にする
- 選ばなかった案: 行を全部「載せない行の基準」に足して一覧から外す。基準を広げると、候補語の取りこぼしを確かめる意味が薄れる

### D2: statusline の環境変数は中立の名前を主に、旧名を互換で読む

`FLATMATE_RATE_SHARE_DIR`・`FLATMATE_RATE_SHARE_CONF`・`~/.claude/flatmate-rate-share` は flatmate 側の reader と揃えた契約（README:96）で、名前を変えると flatmate 側の設定が静かに効かなくなる。そこで、主の名前を `CLAUDE_RATE_SHARE_DIR`・`CLAUDE_RATE_SHARE_CONF`（既定 `$HOME/.claude/rate-share`）にし、旧名は「新名が未定義のとき読む」互換として残す。優先順は新名の DIR → 旧名の DIR → 新名の CONF の設定ファイル → 旧名の CONF の設定ファイル。空文字を定義すれば共有を無効にする既存の規則は、新名・旧名のどちらでも同じ。選ばなかった案: ①旧名をやめて新名だけにする（flatmate 側の変更が先に要り、#1168 の範囲を越える）、②旧名のままにして一覧から外す（flatmate の名がコードに残り、受け入れ条件 1・2 の趣旨に反する）。

旧名を読む行は候補語に当たり続けるので、載せない行の基準に「互換のために残す旧名の読み取り（新名が主であることと互換であることを同じ箇所に書いた行）」を足す。これを足す根拠は、旧名の行は固有名が読み手に見えても指示としては実行できる（新名で足りる）ため。

### D3: 候補語の判定

一覧に載っていない当たり（dev-workflow を除く）は、`git grep` で取り直して、載せない行の基準のどれに当たるかを 1 件ずつ判定し、判定を `plugins/<name>/changes/1168.md` ではなく tasks の実施欄に表で残す。当たらないものは D1 で直す。行番号は #1174 などで既にずれているので、一覧の行番号でなく候補語の検索で対象を決める。

### D4: テスト

固有記述の取りこぼしは検査で全部は拾えない（既存 spec「表と一覧の検査の守備範囲」）。直した語が戻ってくるのを落とす検索だけを `tests/public-private-split.bats` に足す: 対象ファイルごとに固定の語（`moko`・`suimei`・`uranai`・`shukan`・`sns-autopilot`・`/Users/oratta`・`flatmate`・`FLATMATE` の該当するもの）が 0 件であることを検査する。statusline の旧名の読み取りは statusline の bats が検査する。
