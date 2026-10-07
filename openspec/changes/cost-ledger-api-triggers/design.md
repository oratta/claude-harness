## Context

#303 で入った hook は 2 段になっている。`gate-report.sh` が stdin の文字列だけを見て、きっかけになりえない Bash 呼び出しを `python3` を起動せずに落とす（fast path）。通ったものは `gate_report.py` の同期部分（`find_triggers()` → `build_job()`）がコマンド文字列を語に分けて判定し、対象があれば自分を切り離して起こす。裏の処理（`work()` → `resolve()` → `stack()`）が GitHub に対象を確かめ、`cost_ledger.py timeline` で本文を作って書き込む。

`gh api` を見るのは合格ラベルの付与（`api_targets()`）だけで、これは引数の全部からラベルのパスを探す作りになっている。

制約はエピック #272 の「全体の制約」: LLM のトークンを使わない・hook は何も出力しない・セッションを 1 秒以上止めない・`gh` の呼び出し回数と所要時間を実測して PR に書く・積む 1 行は短く保つ。行の書式・コメントの形・裏で動かす作りは #303 のものを変えない（主の指示）。

同時に PR #744（#691、後追い）が動いている。#744 が触るのは `backfill.py` / `backfill.sh`（新規）、`cost_ledger.py`、`hooks.json`、`gate_report.py` の `stack()`（引数 `extra` を足す 3 行）、`cost-ledger-timeline` の spec の 2 か所、`README.md`。

## Goals / Non-Goals

**Goals:**

- `gh api` の REST で行ったコメント投稿・クローズ・再オープン・マージと、`gh pr create`・`gh pr reopen` に行を積む
- `gh api` の読み取り（GET）で `python3` を起動しない
- `gh api` の引数を endpoint とオプションの値に分けて読み、合格ラベルの付与の判定の誤りを直す

**Non-Goals:**

- 行の書式・コメントの形・ロック・裏で動かす作りの変更（`stack()`・`cost_ledger.py` は触らない）
- `gh api graphql` の mutation、`--input` で渡した JSON の中身、完全な URL（`https://api.github.com/...`）で書いた endpoint の解釈
- auto-merge や自動クローズへの後追い（#691 / PR #744 の範囲）

## Decisions

### 1. `gh api` は endpoint を 1 つだけ読む。値を取るオプションの表を持つ

`gh api` の位置引数は endpoint 1 つだけなので、`api` より後ろの語を前から見て、値を取るオプション（`-X` / `--method`・`-f` / `--raw-field`・`-F` / `--field`・`-H` / `--header`・`--input`・`-q` / `--jq`・`-t` / `--template`・`-p` / `--preview`・`--hostname`・`--cache`）はその値ごと飛ばし、最初に残った語を endpoint とする。`--name=値` と、短いオプションに値を続けた形（`-XPATCH`・`-fstate=closed`）も 1 語として読む。表に無い `-` 始まりの語は値を取らないものとして扱う。

- 採らなかった案: 今までどおり全引数からパスを探す。`--input repos/.../issues/300/labels` のように値がパスの形をしていると、コマンドが触れていない番号を対象にする（#697 のコメントの指摘）。きっかけを増やすと当たる形も増えるので、ここで直す
- 表は `gh` 2.67.0 の `gh api --help` から取った。`gh` に値を取るオプションが増えると、その値を endpoint と取り違えうる。取り違えても endpoint の形（`repos/<owner>/<repo>/...`）に一致しなければ積まない

### 2. メソッドは gh と同じ規則で決める

`-X` / `--method` があればその値（複数あれば最後）。無ければ、フィールド（`-f` / `-F` / `--raw-field` / `--field`）か `--input` があれば POST、どちらも無ければ GET。値が解決できないメソッド（`-X "$M"` で `M` が分からない）は積まない。

これで `gh api repos/o/r/issues/300/comments -f body=x`（メソッド省略）が POST と読め、`gh api repos/o/r/issues/300/comments`（読み取り）は GET と読める。

### 3. きっかけにする endpoint とメソッドの組は 4 つだけ。`state` はフィールドで見える場合だけ

| endpoint | メソッド | 条件 | きっかけ |
|---|---|---|---|
| `issues/<番号>/comments` | POST | なし | `issue コメント` |
| `pulls/<番号>` | PATCH | フィールド `state=closed` / `state=open` | `PR クローズ` / `PR 再オープン` |
| `issues/<番号>` | PATCH | 同上 | `issue クローズ` / `issue 再オープン` |
| `pulls/<番号>/merge` | PUT | なし | `マージ` |

- `issues/<番号>` 系は種別を issue として裏へ渡す。番号が PR かどうかは既存の `resolve()` が `issues/<番号>` の応答で見分け、PR なら呼び名を読み替える（既存の「issue 向けのコマンドに渡された番号が PR だったとき」と同じ経路）。同期部分で `gh` を呼ばない制約を守るため、同期部分では見分けない
- PATCH で `state` のフィールドが無いもの（タイトルや本文の編集）は積まない。issue の記述が「`state` の変更」だから
- `--input` で JSON を渡した PATCH は、`state` を変えているか分からないので積まない。採らなかった案: `--input` の PATCH をクローズと再オープンの両方の候補にして、状態の確認で残った方を積む。閉じたままの PR のタイトルを直しただけで `PR クローズ` の行が積まれるので採らない
- コメントの POST は `--input` でも積む（POST であることだけで投稿と分かる）
- コメントの編集（`issues/comments/<id>` への PATCH）は表に無いので積まない。hook 自身がコストのコメントを書き換えるときの形でもある

### 4. 新しい呼び名は `PR 作成` と `PR 再オープン` の 2 つ

`gh pr create` と PR の再オープンには、既存の呼び名に当てはまるものが無い。既存の呼び名（`PR クローズ`・`issue 再オープン`）と同じ作りで、いちばん短い形にした。`cost_ledger.py timeline` の `--trigger` は任意の文字列を受けるので、`cost_ledger.py` の変更は要らない。

PR の再オープンが表に入るので、`gh issue reopen <PR の番号>` と `issues/<PR の番号>` への `state=open` も `PR 再オープン` に読み替えて積む。今は「PR の再オープンはきっかけの表に無い」という理由で捨てており、その理由が無くなる。

### 5. `gh pr create` の番号は `cwd` のブランチ（`--head` があればそのブランチ）から解決し、作成時刻で確かめる

issue は「コマンドの出力か `cwd` のブランチから解決する」と 2 案を挙げている。ブランチから解決する方を採る。

- 番号を省いた `gh pr comment` と同じ問い合わせ（`pulls?head=<owner>:<ブランチ>&state=all` の先頭）がそのまま使え、`gh` の呼び出しは 3 回のまま
- 出力から読む案を採らなかった理由: 同期部分が読むのは `tool_input.command` だけという守備範囲を `tool_response` まで広げることになる。複合コマンドでは出力に他の PR の URL が混ざる。`gh pr create` が「このブランチの PR は既にある」で失敗したときも、出力には既存の PR の URL が出るので、失敗の見分けにならない
- `-H` / `--head <ブランチ>` があればそのブランチで探す（`develop` の手順は `gh pr create --draft --head <branch> --base main` と書く）。`owner:branch` の形と、ブランチ名が英数字と `._/-` 以外を含むものは積まない（問い合わせの URL にそのまま入れるため）
- `--dry-run` と `-w` / `--web` は PR を作らないのできっかけにしない
- 作成の確認: 見つけた PR の `state` が open で、`created_at` がきっかけの時刻の前後 300 秒以内のときだけ積む。`gh pr create` が失敗して既存の PR が見つかった場合に、作っていない PR へ `PR 作成` の行を積まないため。300 秒は PR #744 の後追いが手元の時計と GitHub の時計のずれに見込んでいる幅と同じ値

### 6. fast path は `gh api` を 3 条件で絞る

`gate-report.sh` の `case` に足すのは次の 2 つ。

- `gh pr create`・`gh pr reopen` の文字列
- `gh api` を含み、かつ `/issues/` か `/pulls/` を含み、かつ書き込みを示すオプションの文字列（空白に続く `-X`・`--method`・`-f`・`-F`・`--field`・`--raw-field`・`--input`）のどれかを含む

- 採らなかった案: `gh api` を含めば通す。このリポジトリでは `gh api` の読み取りが頻繁に走るので、そのたびに `python3` が起動する（1 回数十 ms）。きっかけになる `gh api` は、メソッドを明示するかフィールドか `--input` を持つので、その文字列の有無で読み取りの大半を落とせる
- 判定対象は今までどおり stdin 全体（`tool_response` を含む）。読み取りの出力にこれらの文字列が出ると `python3` が起動するが、その先の判定で落ちる（既存の fast path と同じ割り切り）
- 合格ラベルの付与は今までどおり `agent-review:passed` の文字列で通る

### 7. hook 自身の書き込みで行が積まれないことの確かめ方

hook の書き込み（裏のプロセスの `gh api -X POST .../issues/<番号>/comments --input -` と `gh api -X PATCH .../issues/comments/<id> --input -`）は Claude Code の Bash ツールを通らないので、PostToolUse が起きず、再び行が積まれることは無い。この前提は変えていない。bats では次の 2 つで固定する。

- `gh api` のコメント投稿のきっかけを 1 回流すと、`gh` の呼び出しは対象の確認・既存コメントの取得・書き込み（番号が PR なら対象の確認が 2 回）だけで、書き込みは 1 回、表の行は 1 行増えるだけ（hook の書き込みを受けてもう 1 回動いた形跡が無い）
- hook の書き換えと同じ形のコマンド（`gh api -X PATCH repos/<owner>/<repo>/issues/comments/<id> --input -`）を Bash のコマンドとして流しても、`gh` は 1 回も呼ばれない

hook の新規作成と同じ形のコマンド（`issues/<番号>/comments` への POST）をエージェントが Bash で実行した場合は、コメントの投稿なので積む（区別する理由が無い）。

### 8. PR #744 と同じファイルに触る箇所の扱い

| ファイル | #744 が触る場所 | この change の扱い |
|---|---|---|
| `gate_report.py` | `stack()` の引数と 3 行 | `stack()` を触らない。きっかけの判定（`api_targets()`・`trigger_targets()`・`find_triggers()`・`build_job()`）と対象の確認（`pr_checks()`・`resolve()`）だけを変える |
| `openspec/specs/cost-ledger-timeline/spec.md` | 「行を積むきっかけ」の守備範囲の段落の最後の 1 文、「1 本のコメントに行を積む」の 1 文、末尾への要件の追加 | 「行を積むきっかけ」は要件を丸ごと書き換える差分になるので、守備範囲の最後の 1 文が重なる。差分は今の main の文で書き、archive の前に origin/main を取り込んで、#744 が先に入っていればその 1 文を #744 の文（後追いへの言及を含む）に合わせてから archive する |
| `README.md` | 「やらないこと」の箇条書き（`gh api` の直叩き…では積まない、の 1 文を含む）と、後追いの節の追加 | きっかけの表への行の追加と、その 1 文の書き換え。同じ行に触るので、後から入る側で衝突を解く。実装の前に origin/main を確かめ、#744 が入っていれば取り込んでから書く |
| `cost_ledger.py`・`hooks.json`・`backfill.*` | あり | 触らない |

## Risks / Trade-offs

- [`gh api` の読み取りの出力に書き込みのオプションの文字列が出ると `python3` が起動する] → 判定で落ちて何も書かれない。起動の時間は実測して PR に書く
- [`issues/<番号>/comments` への POST は、番号が PR のとき `gh` を 4 回呼ぶ（issue として確かめてから PR として取り直す）] → 既存の「issue 向けのコマンドに渡された番号が PR だったときの 1 回」と同じ扱いで、裏のプロセスで動くのでセッションは待たない。このリポジトリでは PR へのコメントを `gh api` で投稿することが多いので、回数を実測して PR に書く
- [手元の時計が GitHub より 300 秒を超えてずれていると `PR 作成` の行が積まれない] → 次の節目の行の増分がその分を含む（裏の処理が失敗した節目と同じ）
- [`gh pr reopen` を既に open の PR に実行しても `PR 再オープン` の行が積まれる] → 既存の `Ready`（既に Ready の PR への `gh pr ready`）と同じ性質で、数字は正しい
- [#744 と spec・README の同じ文に触る] → 上の表のとおり、archive と実装の前に origin/main を確かめる

## Migration Plan

`hooks.json` を変えないので、マージ後に marketplace dir が更新されれば次の Bash 呼び出しから効く。戻すときは PR を revert する。緊急停止は今までどおり `COST_LEDGER_GATE_REPORT=off`。

## Open Questions

なし。
