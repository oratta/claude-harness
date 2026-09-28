## Context

develop は作業者 W とゲート実行者 G を `general-purpose` で起こしている。`general-purpose` はすべての道具を持つので、ブラウザ操作（`mcp__claude-in-chrome__*` 約 25 個）・デザインツール・ドキュメント連携・ライブラリ文書検索の定義文が起動した時点でコンテキストに乗る。2026-09-20 の #326 の実測では W / G の最初の usage 合計が 43,208〜50,577、読み取り 3 つだけの `dev-workflow:decider` が 18,299 だった。前任 W の実測（Claude Code 2.1.283・haiku・同じ短い指示）でも `general-purpose` 30,073 に対して `dev-workflow:decider` 13,770 で、差の大半が道具の定義文であることは変わらない。

プラグインの agent 定義（`plugins/<name>/agents/*.md`）では frontmatter の `tools` / `disallowedTools` が効き、`mcpServers` / `hooks` は無視される（前任の実測）。agent の `description` は常時注入の予算（`tests/injection-budget.txt`）の集計対象で、`.claude-plugin/marketplace.json` の description は `tests/marketplace-sync.bats` の一致検査だけに当たる。

`scripts/agent-model-guard.sh` は、`model: fable` を `dev-workflow:decider` 以外に渡すと拒否し、`model` を省略した spawn は `general-purpose` などの定義に model を持たない種別だけ拒否する。プラグインの種別は定義側の `model` が使われる前提で省略を許しているので、新種別の定義に `model` を書かないと親（多くは Fable）を継承する。

## Goals / Non-Goals

**Goals:**

- W と G を、仕事に要る道具だけを持つ種別で起こし、最初のコンテキストを減らす。
- 画面での動作確認が要る作業を、W の種別を大きくせずに扱えるようにする。
- 新種別が Fable で起こされないことと、ブラウザの道具を持たないことを検査で固定する。
- 効果を合否の閾値で決め打ちせず、比べられる形で記録する。

**Non-Goals:**

- 仕様レビュー R1（決める役でないとき）と、G が要求するレビュアーの種別を変えること（`general-purpose` のまま。効果を測ったあとで別に扱う）。
- `agent-model-guard.sh` の判定ロジックを変えること。
- 指示文（worker.md・gate-runner.md）そのものを短くすること（issue のコメントの指摘どおり、強制停止が減ったあとの実測を見てから扱う）。

## Decisions

### 画面での動作確認は、短命の画面確認役 V に切り出す

比べた案は 3 つある。

| 案 | 中身 | 最初のコンテキスト | 接頭辞の種類 | 問題 |
|---|---|---|---|---|
| ブラウザ入りの W を別種別にする | `dev-workflow:worker` と、ブラウザの道具を足した `dev-workflow:worker-browser` を用意し、本体が spawn 時に選ぶ | ブラウザ入りは実装の全期間を通して約 25,000 多い | 新しく 3 種類 | W は (1)〜(3b) を同じコンテキストで続けるので、画面確認が要るかを spawn 時（仕様化の前）に決めなければならない。外れたら種別の違う W に手渡すことになる。定義文 25,000 が実装ループの全ターンに乗り続ける |
| 画面確認が要る記録先だけ W を `general-purpose` で起こす | 新種別は `dev-workflow:worker` だけ | 画面確認が要る記録先では今と同じ | 新しく 2 種類 | 画面確認が要る記録先では削減がゼロ。spawn 時に決める問題は上の案と同じ |
| **（採用）画面確認役 V を切り出す** | W は常にブラウザ無し。画面確認が要るときだけ、本体が (3a) と (3b) の間に V を `general-purpose`・`model: sonnet` で起こす | W は常に小さい。V は 25,000 を払うが、数ターンで終わる | 新しく 2 種類（V は既存の `general-purpose` を使う） | 起動が 1 回増える。V は実装の経緯を知らないので、何をどう見るかを W が書いて渡す必要がある |

採用した理由は、定義文の大きさがかかるのが「ブラウザを実際に使う数ターン」だけになること、画面確認が要るかを実装の後（(3a) の終わり）に決められること、V が新しい種別を増やさないことの 3 つである。V に新しい種別（ブラウザだけ持つ種別）を作らないのは、V は数ターンで終わるので定義文を削る効果が小さく、逆に接頭辞の種類が 1 つ増えるからである。

W の (3a) の return に `画面確認:` の 1 行を足す。書式は `画面確認: 不要` か `画面確認: 要る — <開く URL か起動手順> / <見る点>`。要るかどうかは、受け入れ条件または記録先の「動作確認ポイント」が画面での観測を求めているかで W が決める。本体は `要る` のときだけ V を起こし、V の return を (3b) の W に渡す。(3b) の W はそれを動作確認の証拠の入力にする。

V の return の 1 行目は `画面確認結果: (合格|不合格|実行不能)` のどれかにする。

- `合格`: 観測した内容（開いた URL・見た要素・値）を 2 行目以降に書く。本体はそれを (3b) の W に渡す。
- `不合格`: 期待と違った観測を書く。本体は W を (3a) で再開して直させる（(3b) には進まない）。同じ画面確認で 2 回続けて `不合格` なら、テストが 2 連続で落ちたのと同じ扱いで昇格トリップワイヤーの失敗ループに当てる。
- `実行不能`: Chrome 拡張が繋がらない（`list_connected_browsers` が空、または道具の呼び出しが失敗する）、無人実行で拡張が無い、などで観測できなかった理由を書く。本体は (3b) の W に「画面確認は実行不能（理由）」と渡し、W は画面確認の証拠を書かない。そのあと G が pr-review-gate 手順 4 で、自力で検証できない動作確認として pr-review-gate の既存の保留経路（主への動作確認の依頼）に落とす。V の側で待ったり、主に直接頼んだりはしない。

V の指示書は `skills/develop/references/roles/screen-checker.md` に新しく置く（W・R1・G と同じく役割ごとに 1 ファイル）。V の名前は `V-<記録先番号>-<n>`、description は `V: screen check for #N`（役割別集計が description の接頭辞で役を判定するため、先頭の `V:` を残す）。

### 最初のコンテキストの差と、接頭辞が分かれることによるキャッシュ作成費は、別々に記録する

変更後に 1 本の develop で使う種別は、`dev-workflow:worker`・`dev-workflow:gate-runner`・`dev-workflow:decider`・`general-purpose`（R1・レビュアー・V）の 4 種類になる。今は W / G / R1 / レビュアーが `general-purpose` の接頭辞を共有している。種別ごとに接頭辞が違うので、それぞれの最初の起動で `cache_creation_input_tokens`（入力の 1.25 倍で請求）を払う。1 体あたりの最初のコンテキストが減っても、1 本の develop の請求額が同じだけ減るとは限らず、条件によっては増える。

役は数分から数十分の間隔で順に起こされるので、キャッシュの保持時間内に次の同じ種別が起こされるかは推論では決まらない。そこで合否の閾値を仕様に書かず、計測で次をすべて記録する。

- 最初の `message.usage` の `input_tokens` / `cache_creation_input_tokens` / `cache_read_input_tokens` を合計せず分けて書く。
- 同じ Claude Code の版で、同じ指示文を `general-purpose` と `dev-workflow:worker` / `dev-workflow:gate-runner` に渡して並べた値。
- issue 本文の 2026-09-20 の実測（43,208〜50,577）との比較。
- 新種別で develop を 1 本通したときの、全エージェント合計の `cache_creation_input_tokens` と `cache_read_input_tokens`。
- 上限による強制停止の回数と、手渡しの回数を分けた値（初回の削減が効くのは強制停止のほうで、手渡しは余裕が増えても起きうるため）。

受け入れ条件 1 の比較基準と条件 4 の分け方は主に確認中なので、合否はこの記録を見て主が決める。

### 新種別の定義は `model: sonnet` を書き、ガードは変えない

定義に `model` を書かないか `inherit` にすると、ガードが省略を許したうえで親の Fable を継承する。そこで両方の定義に `model: sonnet` を書く。本体は従来どおり spawn のたびに `model` を明示する（事前分類に当たる W は `opus`）ので、定義の値は明示し忘れたときの下限として働く。

`DECIDER_TYPES` には足さない。新種別に `model: fable` を渡すと、今のガードのまま拒否される。この挙動を `agent-model-guard.bats` で固定する。判定ロジックを変えないので、ガードのコメントに新種別の扱いを書き足すかは実装時に決める（足すなら 1 行）。

### 道具の範囲

| 種別 | tools | 持たないもの |
|---|---|---|
| `dev-workflow:worker` | Read, Edit, Write, Bash, Grep, Glob | ブラウザ・デザインツール・ドキュメント連携・ライブラリ文書検索・WebFetch・WebSearch・Skill・Agent・NotebookEdit |
| `dev-workflow:gate-runner` | Read, Bash, Grep, Glob | 上に加えて Edit・Write |

G は Codex の起動と `gh` の操作を Bash で行い、ファイルを編集しない（修正は W の仕事）。W がサブエージェントを起こさないこと（worker.md「W がしないこと」）と、G がレビュアーを自分で起こさず `needs-reviewer` を返すこと（adapter 経路）は既に決まっているので、Agent を外しても手順は変わらない。G の従来経路（develop の本体以外が起こす G）は Codex を Bash から起こすので、これも Agent に依存しない。

### W は Skill を使わず openspec CLI で進める

`Skill` を持たないので `/opsx:ff` / `/opsx:apply` / `/opsx:verify` / `/opsx:archive` は呼べない。worker.md には既に「opsx コマンドが無く openspec CLI だけある場合」の経路（`openspec new change` → artifact の直書き、`openspec validate <change> --strict`、`openspec archive <change>`）があるので、新種別の W は常にこの経路を使う。artifact の雛形と書き方の指示は `openspec instructions <artifact> --change <name>` で得る。R1 の仕様レビューと工程の区切りは opsx 経路と同じである。

### worktree が `.worktreeinclude` を持たないときの `/wt-setup` は本体が行う

worker.md には「context に `.worktreeinclude` が無いと載っているときだけ W が `/wt-setup` を呼ぶ」例外がある。新種別の W は Skill を持たず呼べないので、この例外を本体の仕事に移す。develop/SKILL.md の「worktree は本体が用意する」と一致する。

### description は短くする

agent の description は常時注入の予算に入る。2 つの description は 1 文ずつにし、長い説明は本文に置く。それでも予算を超えたら `tests/injection-budget.txt` を動かし、PR 本文に「何を削ろうとして、なぜその値にするか」を書く（予算ファイルは聖域）。

## Risks / Trade-offs

- **名前付き spawn の return が本体に届くかを実機で確かめていない。** 本体がチームの形（名前付きで起こし、SendMessage でやり取りする形）で W / G を起こすとき、tools を絞った種別が return を本体へ返せるかは、SendMessage を tools に持つかどうかに依存する可能性がある。実装の最初に実機で確かめ、届かなければ tools に `SendMessage` を足す（道具 1 つ分の定義文なので、削減への影響は小さい）。
- **V は実装の経緯を知らない。** W の `画面確認:` の行が不十分だと V は何を見ればよいか分からない。行の書式に「開く URL か起動手順」と「見る点」の両方を必須にして抑える。
- **接頭辞の種類が増えることで、1 本の develop の請求額が増える可能性がある。** 上の計測で `cache_creation_input_tokens` を分けて記録し、主が判断する。
- **Skill を使えないことで、opsx スキルが持つ細かな手順（artifact の依存順の確認など）を W が自分でたどることになる。** `openspec status` と `openspec instructions` で代わりに得る。
- **既存の要件・文書に `/opsx:*` を W が呼ぶ記述が残る。** develop の仕様に読み替えの要件を足し、worker.md の本文は CLI 経路を既定に書き換える。
