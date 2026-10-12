## Context

Codex を呼ぶ経路は 3 つあり、どれも「Codex を使わない」という設定を読まない。

| 経路 | いまの動き | 確かめた場所 |
|---|---|---|
| develop の投げ先の自動選択 | `automatic_selection` が Codex の使用量を取得して余裕を比べる。古い観測値の余裕が大きいと `claude-write-codex-review` か `codex-standard` を選ぶ | `plugins/dev-workflow/scripts/codex-develop.py` の `select_configuration`（96-105 行）と `automatic_selection`（271-292 行） |
| pr-review-gate の従来経路 | full なら Codex を第一選択にし、バイナリ無し・認証切れ・総待ち上限の実測でだけ Claude のレビュアーに切り替わる | `stages/review-run.md` の 2-1 の表と「従来モードの不可判定」 |
| ステータスラインの Codex 行 | Codex の認証があれば `codex app-server` で使用量を取得し、キャッシュを描く | `statusline-codex.py` の `main` |

Codex には Claude のような登録簿が無く、アカウントは呼び出しのたびに `--account-home` で渡している。したがってオフにするのはアカウント単位ではなく、提供元（Codex 全体）単位になる。

#976 で `accounts.json` に `enabled` が入り、登録簿を読む 5 か所が「`false` だけがオフ」という同じ意味で読む。オンオフの読み方はこれに揃える。

## Goals / Non-Goals

**Goals:**

- Codex をオフにする設定を 1 か所に置き、3 つの経路がそれを読む
- オフのあいだ、Codex の起動・使用量の取得・バイナリ探索を一切しない
- 設定が無い環境では 3 つの経路の挙動が変わらない
- オフが原因であることを、自動選択の reason・PR コメント・ステータスラインのそれぞれから読める

**Non-Goals:**

- オンオフを切り替えるコマンド（#977）
- Codex のアカウントごとのオフ
- Codex がオンのときの投げ先の選択とレビューの変更（エピック #980 の決定どおり、full 判定の既定は Codex のまま）
- モデルの格・役ごとのモデルの決め方（#616）
- 開始済みの phase の途中切り替え（次の phase の開始時に評価する、という既存の決まりのまま）

## Decisions

### 1. 置き場所は `accounts.json` のトップレベルの `codex.enabled`

```json
{
  "schema": 1,
  "accounts": [ ... ],
  "codex": { "enabled": false }
}
```

issue が「着手時に決め、理由を変更の記録に書く」としていた点。`accounts.json` に載せる案と、別ファイル（たとえば `codex.json`）にする案を比べた。

| 観点 | `accounts.json` に載せる（採用） | 別ファイル |
|---|---|---|
| 切り替えの入口 | #977 のコマンドが 1 つのファイルだけを扱えば、Claude のスロットも Codex もオンオフできる | コマンドが 2 つのファイルを扱う。利用者も 2 か所を覚える |
| 場所の解決 | `CLAUDE_ACCOUNTS_FILE` → `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json` の規則が 3 つの読み手（`usage_view.py`・`statusline-codex.py` と、それを使う G）で既にそろっている | 環境変数と既定パスを新しく決め、全員に配る必要がある |
| 既存の読み手への影響 | 5 か所は `doc.get("accounts")` だけを読み、未知のトップレベルのキーを無視する。`accounts-init.sh` は文書全体を読んで書き戻すので `codex` を消さない | 影響なし |
| 意味の混在 | 登録簿が「Claude のスロット」と「Codex の提供元の設定」を持つことになる | Claude の登録簿が Claude だけのまま保たれる |

採用の決め手は、オンオフを切り替える入口と読み手の場所の解決を 1 つにそろえられること。意味の混在は、`codex` を `accounts` と別のトップレベルのキーにし、スロットの配列には何も混ぜないことで、スロットを読む処理への影響を無くしている。`schema` を `1` のままにする理由も #976 と同じで、キーが無いときの意味が従来と同じで、古い読み手はそのキーを読み飛ばすから。

別案に戻す条件: Codex 側に登録簿が必要になり、アカウントの一覧・使用量の取得先まで持たせる要件が出たとき。そのときは `codex.enabled` をその登録簿へ移す。

### 2. オフになる条件は `codex.enabled` が JSON の `false` のときだけ

`codex` が無い・オブジェクトでない・`enabled` が無い・`true`・`"false"`・`0`・`null` はすべてオン。登録簿が無い・読めない・トップレベルが配列のときもオン。#976 の「`false` との一致 1 つ」の規則を使う（書き損じで黙って止めない）。

オンの側に倒すと、書き損じた利用者は Codex が止まらず、止めたつもりで Codex が呼ばれ続ける。ステータスラインに `off` が出ないので気づける。逆に、書き損じを黙ってオフと読むと、使っているはずの Codex レビューが無言で外れる。後者のほうが気づきにくいので、前者を取る。

### 3. 読み手は `usage_view.py` に 1 つ、statusline は自分で持つ

`usage_view.py` に `read_codex_enabled(path)`（真偽値を返す）を足し、CLI に `--codex-enabled` を足す（`on` か `off` を 1 行だけ標準出力に出し、常に exit 0）。使い手は次の 2 つ。

- `codex-develop.py`: 既に `usage_view` を import している。登録簿のパスは `usage_view.default_paths()["accounts_file"]` で解決する
- pr-review-gate の G: LLM が手順書に従って動くので、`python3 <dev-workflow>/scripts/usage_view.py --codex-enabled` を 1 回実行し、標準出力で分岐する。G は設定ファイルの JSON を自分で読まない。読み方が G ごとにぶれるのを避けるため

`statusline-codex.py` は別プラグインなので `usage_view.py` を読まず、同じ規則を自分で持つ（`statusline-multi-account-usage` の既存の方針。#976 の statusline と同じ）。2 つの読み手の解釈が食い違うと、片方だけが Codex を止める。それぞれのテストに「`false` だけがオフ」を置く。

### 4. 自動選択: `select_configuration` に引数を 1 つ足し、オフなら Claude だけを返す

`select_configuration(claude_margin, codex_margin, codex_enabled=True)`。`codex_enabled` が偽なら、余裕の値にかかわらず `('claude-default', 'codex-off')` を返す。

- 既定値 `True` なので、既存の呼び出しと既存のテストは変わらない
- 分岐は関数の先頭 1 つ。#616 が関数の中身を書き換えても、この 1 分岐は衝突しにくい
- reason `codex-off` は、`no-provider-has-headroom` と区別するための新しい値。Claude にも余裕が無いときも `codex-off` を返す（Codex が選ばれない原因はオフであり、Claude の余裕の有無は `claude.margin` に出ている）

`automatic_selection` は、オフなら `read_codex_usages` を呼ばない。Codex の app-server の起動もキャッシュの更新も起きない。selection evidence の `codex` ブロックは `{'account': None, 'margin': None, 'fetched_at': None, 'enabled': False}` とする。オンのときの `codex` ブロックの形は変えない（キーを足さない）。

### 5. 明示指定は拒否する（黙って Claude に差し替えない）

`references/codex-develop.md` の「role の投げ先を暗黙に別 provider で代行してはならない」に合わせる。オフのとき、次を `RuntimeError` で拒否する（既存の `main` が `status: blocked` を出して exit 2 にする）。

- `--account` / `--model` の旧形式（常に Codex を使う）
- `--profile` で、どれかの role の executor が `codex` の profile

エラー文は `codex is off: set "codex"."enabled" to true or remove it in <登録簿のパス>`。登録簿のパスを入れるのは、#976 の `select-account.sh` の拒否文と同じ理由（戻し方を読んだ人が探さずに済む）。

オフの判定は、アカウント対応表の検査（`account is not registered` など）より先に行う。オフにした利用者が `--account-home` を渡さずに profile を指定したとき、原因として「アカウントが未登録」ではなく「オフ」が出るようにするため。そのため、profile の中身を読む `load_profile` は、オフのときだけ `accounts=None`（登録の検査を飛ばす）で先に読んで role の executor を確かめ、拒否しなければ通常どおり読み直す。Codex を使わない profile（現在は無いが、`--profile-file` で渡せる）は拒否しない。

### 6. レビューの従来経路: オフは実測の三条件とは別の「設定」

`review-run.md` は「不可と判定できるのは次の実測だけ」とし、未試行や auth.json の有無から不可を推測することを禁じている。これは「Codex が使えないと思い込んで Claude に逃げる」誤りを防ぐ規則で、利用者が明示した設定には当たらない。オフは「不可の判定」ではなく「試さないと決めてある」状態なので、三条件の表に 4 つ目として混ぜず、別の扱いにする。

- full と判定したあと、Codex を試す前に `usage_view.py --codex-enabled` を実行する。`off` なら、バイナリ探索（`command -v codex`）も呼び出しもしない。`on` なら従来どおり
- オフのとき、レビュー実行者は Task サブエージェント（`dev-workflow:reviewer`、既定モデル `opus`）。G は孫を持てないので `needs-reviewer` を返し、根拠に `Codex オフ（設定）` と書く
- PR コメント: `レビュー実行者: Task サブエージェント（full・Codex オフ）`。証拠欄は `選んだ経路: 未実行（Codex オフ）`・`実行コマンド:` にオフの判定に使ったコマンドと出力（`python3 .../usage_view.py --codex-enabled` → `off`）・`終了コード: 未実行（Codex オフ）`・`出力の要点: Codex オフの設定により Codex を試していない`・`実待ち時間: 未実行（Codex オフ）`。実測した Codex 不可と区別できるよう、「実測した」を含めない
- light 判定・手順 3 のリスク宣言・手順 4 の動作確認・fail-closed の判定順序は変わらない（`light はレビュー実行者だけを変える` の既存の規則と同じ。免除される工程は無い）
- adapter 経路（develop の G）は影響を受けない。そこでは本体が `codex-develop.py request --phase review` で投げ先を選び直すので、オフは決定 4 の自動選択で反映される。G の `レビュー実行者: <executor>/<model>（adapter 経路・...）` の書式も変えない
- 新 Codex モード（App Server 固定）には、従来の exec / Claude fallback を適用しない規則を維持する。オフは「従来モードの full で Codex を試さない」だけを定め、新 Codex モードの経路は広げない

### 7. ステータスライン: `off` を出し、取得しない

`statusline-codex.py` の `main` の先頭で、登録簿の `codex.enabled` を読む。オフなら `off` の 1 行だけを標準出力に出して戻る。`identity()`・`shutil.which`・キャッシュの読み書き・`--refresh` 用の子プロセスの起動のいずれにも進まない（`codex` を起動しない）。`--refresh` で呼ばれた場合も、オフなら何もせず戻る。

オフの判定を最初に置くのは、Codex にログインしていなくても `off` を見せるため（オフにした利用者が、止めたことを確認できる）。`STATUSLINE_CODEX=0` は従来どおり行そのものを出さず、オフの設定より優先する。

`statusline.sh` は、`pending` の行と同じ組み立て（`Codex` ラベル・label 列の幅・`DIM`）で、使用率の代わりに `DIM` の `off` を出す。Codex 行の高さは 1 行のまま。`codex.enabled` が無い環境の出力は変更前とバイト単位で同一。

### 8. 実機確認は実装とマージの外

受け入れ条件の最後の 1 件（実機で Codex をオフにして full 判定の PR を 1 本ゲートに通し、「レビュー実行者:」のコメントの URL を issue に貼る）は、テストでは代えられない（G が実際に `off` を読んで Codex を呼ばないことは、実機でしか確かめられない）。tasks.md では「実機確認」として別に置き、実装の段では行わない。

## Risks / Trade-offs

- G が手順書どおりにオフの判定を実行しないと、オフでも Codex が呼ばれる → 手順書で「Codex を試す前の最初の 1 手」として置き、`pr-review-gate-skill.bats` で手順書に判定が書かれていることを確かめる。G の実際の動きは実機確認で見る。手順書の 1 か所に置き、同じ内容を `gate-runner.md` などへ再掲しない（片方だけ古くなるため）
- statusline と dev-workflow で `codex.enabled` の解釈がずれる → 2 つの読み手それぞれに「`false` だけがオフ」のテストを置く（決定 3）。ずれた場合も、`off` が出ないことで利用者が気づける
- `select_configuration` を #616 のエピックが書き換える → 引数 1 つと先頭の分岐 1 つに抑えた。#616 側が関数の形を変えるなら、そのときにこの分岐を移す
- 開始済みの phase は途中で切り替わらない → 既存の決まり（次の phase の開始時に評価する）のままにする。Codex をオフにしたあとの最初の phase から効く

## Migration Plan

`schema` は `1` のままで、既存の登録簿は書き換え不要。戻し方は `codex` のキーを消すか、`enabled` を `true` にする。コードは PR の差分を戻す（`codex` を書いたままの登録簿は、古い読み手ではトップレベルの未知のキーとして読み飛ばされ、Codex は従来どおりオンに戻る）。

マージ前の実機確認（決定 8）は、実機の `accounts.json` に `"codex": {"enabled": false}` を手で足して行い、確認が終わったら消す。

## Open Questions

なし。
