# Design

## Context

動機は proposal.md を参照。Codex の `local` キャッシュには `.git` が無く、Claude の SHA 付きキャッシュ名も内容一致の証拠にはしない。既存 `develop_procedures` は SKILL と配下 references、`codex_procedures` は plugin 直下の `references/codex-develop.md` も扱うため、provider 共通の参照手順まで対象にする。
本設計は [決める役の判断](https://github.com/oratta/claude-harness/issues/1864#issuecomment-7234377970) の転記であり、R1 APPROVE や実装品質の承認ではない。

## Goals / Non-Goals

**Goals:** Git の有無にかかわらず同じ手順書集合を識別する。取得した main の過去の配布状態との一致だけで古さを証明し、マージ前候補を明示して試せるようにする。取得・判定・投稿の失敗を区別し、続行理由を記録できるようにする。
**Non-Goals:** キャッシュの由来台帳、署名、期限、発行履歴、使用回数制限、悪意あるローカル改ざんへの認証、同期機構、hook、工程ごとの再検査。エピックの他の子の範囲は proposal.md の除外を維持する。

## Decisions

### 1. 共通 CLI と生バイトの内容指紋

`plugins/dev-workflow/scripts/develop-procedure-freshness.py` に `check` と `mark-preview` を置き、Python 標準ライブラリと git／gh を使う。shell wrapper は増やさない。詳細な呼出契約は `plugins/dev-workflow/skills/develop/references/procedure-freshness.md` に置く。
対象集合と SHA-256 のバイト形式は `specs/develop-procedure-freshness/spec.md` の「版の同一性」に固定する。ファイル集合を読込元・各 Git tree で列挙することで追加・削除・改名も捕捉し、Git 外コピーにも同じ判定を使える。絶対パス・mtime・mode は指紋に含めない。
却下: キャッシュ名、plugin.json version、作業 repo の HEAD による版判定、内容の正規化。これらは実際に読んだ内容を同定できない。

### 2. 取得 tip の第一親履歴で配布済みの古さを証明する

比較元は明示引数、無ければ `CLAUDE_HARNESS_DEV_DIR` のみとし、cwd やホーム探索を使わない。指定の fetch 成功後の tip OID を固定し、その tree と第一親履歴の過去の tree を照合する。判定順は次の通り。

| 条件 | 結果 |
| --- | --- |
| 読込元と取得 main が同じ指紋 | 同一、続行 |
| 有効な印 | マージ前検証対象、続行 |
| main と異なり過去の第一親状態と一致 | 古い版、停止 |
| 十分な履歴で未発見 | `fingerprint-not-in-main-history`、記録して続行 |
| shallow など履歴不足で未発見 | `history-incomplete`、記録して続行 |
| 比較元不在／利用不能、fetch 失敗 | 取得不能、記録して続行 |

第一親履歴は main に載った状態を表し、第二親にしか無い未配布の版を古い版と誤認しない。main が revert した場合は最初の同一判定で続行する。先行・分岐 worktree も内容が過去の main と同じなら印なしでは停止する。
却下: main と違うだけで停止、取得失敗時の既存 remote-tracking ref 利用、由来の復元用 metadata／依存グラフ。差だけでは新旧を証明できず、古い ref は取得成功の代わりにならない。

### 3. マージ前の印を worktree・読込対象・記録先に拘束する

元 worktree の absolute git dir の `develop-procedure-preview.json` 1 個を使う。tracked ファイルや共有 git-common-dir に置かず、キャッシュから自動探索もしない。6フィールド、完全な URL の正規化、発行・検査の照合項目は新規 capability の仕様通りとする。
発行時は読込元・元 worktree の `plugins/dev-workflow`・元 HEAD tree の指紋一致を要求する。対象内容に未コミット差分があれば commit 後に発行する。検査時も3者に加え実体パス2個・現在 HEAD・今回の記録先を再照合し、無効な印は警告して通常判定に戻す。同じ tuple は再利用できるが、変更・移動後は再発行する。
却下: boolean や環境変数のみの bypass、期限・署名・使用回数制限。前者は常時 bypass になり、後者は「この候補を意図して読む」という宣言に不要な機構を増やす。印はテスト成功を証明しない。

### 4. 判定不能の続行と記録失敗を分離する

取得不能・取得後の判定不能の正確な本文と理由コードは仕様に固定する。gh で `--record` の issue／PR に1回投稿し、stdin または `--body-file` で本文を渡す。shell 展開しない。投稿失敗も exit `0` のまま、stdout の結果 JSON に本文と `recording: "failed"`、stderr に失敗を残す。本体は次の記録機会に代理投稿し、成功するまでは記録済みと報告しない。
却下: 投稿失敗による停止、黙って記録成功扱い、永続 spool、再試行ループ。取得不能で開発を止めない条件と、記録の正直さを両立する。

### 5. 記録先を得た入口で一度だけ検査する

SKILL の入口 0 と1ループに、記録先確定直後・仕様化判断と編集前の必須検査を置く。issue がある経路と軽い通し方は本体、W が Draft PR を作る経路は `roles/worker/spec.md` にも作成直後の検査を置く。実際に読んだ SKILL の場所から解決した plugin root を渡し、W にもその値を引き継ぐ。追加の return 工程は設けない。
却下: 記録先確定前の一律検査、hook・sync.sh・provider 別入口への実装。記録先が無ければ取得不能を投稿できず、別入口は本 issue の範囲を越える。

## Risks / Trade-offs

- [導入前キャッシュには guard も呼出規定も無い] → 本変更単体で強制実行できない限界を reference と1864.mdに明記する。同期は他の子の範囲とする。
- [履歴不足や未知の内容で古さを証明できない] → 停止せず理由を投稿する。異なるだけで停止する誤検知を避けるための意図した制限である。
- [投稿失敗] → 本文を JSON に保持し、次の記録機会の代理投稿へ渡す。自動的な永続再送はしない。
- [印を改変・流用できる] → tuple を再照合する。悪意あるローカル改ざんを防ぐ認証は対象外とする。

## Migration Plan

R1 APPROVE 後にタスクを実装し、一時 HOME・一時ディレクトリ内のローカル bare origin と偽 gh で検証する。マージ前は実ホームを変更しない。入口には短い必須検査と詳細 reference への接続を置き、既存の起動予算を検査する。plugin.json version や予算値を変更して通すことは計画しない。導入後に問題があれば、本変更の入口接続とスクリプトを通常の修正 PR で戻せる。
