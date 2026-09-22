# Changelog — dev-workflow

## 2.13.22 — 2026-09-22: develop の role profile を週次余裕から自動選択する

- profile 未指定の各工程で Claude 起動 account と登録 Codex accounts の週次 margin を比較し、逆向き hybrid / Codex 標準 / Claude 既定構成を決定論的に選ぶ
- `claude-write-codex-review` を追加し、Claude に書く役、Codex gpt-6-astra/high にレビューと decider を割り当てる
- Codex App Server quota を account ごとに並行取得し、秘密・home path・生応答を含まない 0600 cache を dev-workflow 内で管理する
- freshness 300 秒、代表 account の束縛、selection evidence と明示 profile の snapshot 非読込を契約テストで固定する

## 2.13.20 — 2026-09-22: Codex の旧台帳・継続機構を撤去し、前景実行だけを唯一の transport にする

#340 で入れた前景実行経路（`codex-develop.py request` → `codex-worker.py run`）が動くようになった後も、SQLite のジョブ／所有権台帳、detached start、submit/status/result/cancel/ack/send/reap の lifecycle CLI、unknown/retry 処理、cwd ロック、account slot、run-dir と `run.json`、継続記録 v1/v2 が残っていた。永続的な進捗の置き場は issue / Draft PR と linked worktree に統一する方針（#341）に対し、使われなくなった transport のコードと文書だけが残っている状態で、`openspec/specs/codex-worker-concurrency` と `openspec/specs/codex-develop-continuation` も廃止済みの契約のままだった。

- **`codex-worker.py`（1007 → 612 行）**: SQLite job/account schema、ownership、slot/lock、detached worker、heartbeat、lifecycle subcommands を削除し、`run --request` の前景実行だけを残した。認証固定・model/effort 検証・reader 向け read-only policy・quota preflight は維持
- **`codex-develop.py`（623 → 286 行）**: run-dir、pending、retry、continuation v1/v2、旧 lifecycle CLI を削除し、request 作成と Claude role の `agent-required` routing だけを残した
- `openspec archive remove-codex-legacy-state --yes` を実行し、`openspec/specs/codex-worker-concurrency` と `openspec/specs/codex-develop-continuation` の spec を除去（change は `openspec/changes/archive/2026-09-21-remove-codex-legacy-state/` に archive 済み）
- `scripts/CODEX-WORKER.md` / `docs/codex-develop.md` / `references/codex-develop.md` / `commands/develop.md` から、廃止した台帳 transport（永続 registration・job ID・status/result/cancel/ack/send/reap・unknown recovery・ownership DB・account slot・cwd lock・heartbeat・`--worker-state` / `--run-dir`・継続記録マーカー）の説明を削除し、前景実行と手動 cleanup 条件だけ残した
- `docs/codex-develop.md` に既存状態ディレクトリ（`~/.local/state/claude-harness-codex/`）の削除条件と `rm -rf` の手順を明記した。コードからの自動削除は行わない
- `skills/develop/SKILL.md`: 「旧台帳経路も互換性のため残る」の 1 文を削除（廃止 transport の互換性主張だったため）
- Closes #341 #323 #329 #331 #336

## 2.13.18 — 2026-09-22: pr-review-gate に止める指摘の仕分け表を置き、2 周目キャップの 1 択の質問をやめる

2.13.17 までは、2 周目の終わりに止める指摘が残ると、G は主に「続けるか、範囲外として閉じるか」の 1 択を判断材料なしで出していた。受け入れ条件の中で直せば済む指摘や、同じ文の書き残しのような一覧で閉じられる指摘まで主に上がり、同じ型の指摘が周ごとに場所を変えて再発しても、方式を決める経路が無かった（#354）。

- **SKILL.md 手順 2-1 の「マージを止めるかの判定（全周共通）」の直後に「止める指摘の仕分け表」（順 1〜6）を置いた**。G は周の数に関係なく、指摘が届くたびに上から当てる: 順 1 止める判定に達しない（follow-up issue）／順 2 受け入れ条件の中（W が直す）／順 3 一覧の一致で閉じる型／順 4 今直す 3 条件／順 5 主に「この欠陥を残して切り出すか」を聞く／順 6 同じ型の再発は決める役が方式を裁定する。順 2〜4 は `agent-review:failed`、順 5 は `needs-approval` の保留、順 6 は Status `needs-decider`。2 周目以降の周の終わりには順 2〜4 を使わない。順 5 と順 2〜4 が同じ周に混ざったら保留を先にし、W は修正に着手しない
- 順 3: W が検索コマンドと全ヒットの「直した／該当しない理由」の表を PR コメントに投稿してから push し、G は同じ検索の集合一致だけを見る。差し戻しは 1 回まで、照合はレビューの周に数えず、順 3 だけで戻した周は周を消費しない
- 順 4: 直し方が行レベルで 30 行以内・spec を変えない・その場で直した累計が 30 行以内（手順 2-0 と同じ 30 行）。W は「受け入れ条件の外・その場で直した・直し方 N 行」と記録する
- 順 5: 主への質問に、マージ後に何を起こすか・直す見積もり・別 issue にする固定費・推奨の 4 点を必ず書き、2 周目を待たずその周で聞く。手順 6 の復帰表の「2周目キャップ」行を「切り出しの確認」行（切り出す／この PR で直す）に置き換え、主に承認を求めてよい 4 分類の 1 行目も順 5 に揃えた
- 順 6: 決める役は方式（全部列挙してから直す／切り出す）だけを裁定し、止めるかどうかは G が決める。裁定は PR ごとに 1 回までで、回数は 1 行目 `^決める役の裁定: (全部列挙してから直す|切り出す)$` の PR コメントを `--paginate --slurp` で数える（1 回目が「切り出す」でも数える）
- 収束ルール: 3 周目以降を開けるのは主の「この PR で直す」と決める役の「全部列挙してから直す」だけ。差分限定の再レビューでも例外 3 種の新規指摘は出してよい（レビュアー向け指示ブロックにも但し書きを足した）。手順 5 の合格条件の除外を「主が切り出すと答えて follow-up issue に切ったもの」と「順 3 の集合一致で閉じたもの」にした
- `skills/develop/references/roles/gate-runner.md`: Status に `needs-decider` と「needs-decider のとき」節、仕分け欄を全周の順の記録に、保留節を切り出しの確認の 4 点に、再開節の「レビュアーの要約受領」を周の数でなく順で分岐する形に、「決める役の裁定受領」の行を足した
- `skills/develop/references/roles/worker.md`: 順 3 の一覧を投稿してから push する手順と、(3a) の return に順 4 の記録を足した
- `skills/develop/SKILL.md`: (4) に `needs-decider` の行（本体が `dev-workflow:decider` にマージ可否と同じ可否と根拠の形で問い、裁定を SendMessage で G に返す。代理投稿しない）を足し、decider の return を本体が代理投稿する規則に順 6 の例外を書いた。`agents/decider.md` は変えていない

## 2.13.17 — 2026-09-21: pr-review-gate のレビュー指摘を固定書式にし、マージを止めるかの判定を全周共通にする

レビュアー（Codex・Task サブエージェント）の指摘は書式が決まっておらず、G は深刻度・検証済みか・違反する文を指摘ごとに組み立て直していた。2.13.16 で入れた「欠陥ありなら failed の一般則は 1 周目、2 周目からは収束ルールが優先」は周によって判定が変わり、1 周目は `should` や推測だけの指摘でも周回を開けていた。主の決定（#349 のコメント「判定は全周で同じにする」）に従い、判定を 1 か所にまとめて全周で同じにした。#349 と、同じ G の指示書の要約受領の分岐を直す #352 を同梱。

- **SKILL.md 手順 2-1 にレビュアー向け指示ブロックを置いた**。指摘 1 件ごとに見出し・深刻度（`blocking` / `should` / `nit`）・検証（`confirmed` / `plausible`）・根拠（`blocking` で必須。受け入れ条件か spec の引用、または例外 3 種＝安全機構の穴・データ破壊・無言の機能不全）・場所・何が起きるか・直し方を書かせ、再レビューでは状態（`fixed` / `unresolved` / `wontfix`）を足させる。1 周目は全件列挙まで止まらず、差分限定の再レビューは新規の指摘を出さず、全体レビューに戻った周でも新規は `blocking` だけ
- **「マージを止めるかの判定（全周共通）」を手順 2-1 に 1 か所だけ書いた**。止めるのは `blocking` かつ `confirmed` で、根拠を G が受け入れ条件または spec と照合できた（または例外 3 種に当たる）指摘だけ。それ以外は follow-up issue。周で変わるのは止める指摘が残ったときの動き方だけ（1 周目は failed、2 周目と主の続行指示の周は `needs-approval`）。1 周目で failed にするとき止めない指摘は PR コメントに一覧で残し、follow-up issue は手順 3 へ進むときに切る
- 収束ルールの「2周目の終わりにやること」・決める役の段落・手順 5 の合格条件を、この判定の参照にした（手順 5 は止まる指摘のうち、2 周目キャップで主が範囲外として閉じて follow-up issue に切ったもの以外が 0 件であることを前提に置く）
- **codex exec のルーブリックを実測した**（codex-cli 0.153.4）。書式を指定しない指示で指摘が出ると `[P1]` の優先度見出しが付いた（JSON の `priority` / `confidence_score` は出なかった）。手順 2-1 に Codex の優先度・場所・`confidence_score` から固定書式への読み替え表を置き、`confidence_score` を `confirmed` の代わりにしないと書いた
- `references/subagent-waiting.md` の Codex 指示文雛形: 手順 2-1 のブロックを貼る指示と全件列挙の 1 文を足した（書式は再掲しない）
- `skills/develop/references/roles/gate-runner.md`: needs-reviewer の payload に「レビュアーに渡す指示」の行を足し、needs-reviewer 節の無条件の「手順 3 以降を続ける」を再開節「レビュアーの要約受領」の参照にした（#352）。再開節の分岐・Gate Result の仕分け欄・保留節を「全周共通の判定で止める指摘」の語にそろえた。README の要約も直した

## 2.13.16 — 2026-09-21: pr-review-gate の収束ルールを、G が 2 周目の終わりに実行する手順にする

PR #268 でレビューと修正の往復が 5 周続き、1 本の PR に約 1.2 億トークンを使った。収束ルール（既定 2 周・3 周目は新規の高深刻度 blocking のみ・マージ後に直せるものは blocking にしない）はあったが、G がレビュアーの深刻度ラベルをそのまま blocking と扱い、適用しなかった。ルールを足すのではなく、誰がいつ何をするかを手順にした。#281（2026-09-11 に主が承認した PR-A）。

- **2 周目の結果を受け取った直後に、G が残った指摘ごとに違反する文を引用する**。引用元は記録先の受け入れ条件と、PR が触れる openspec の spec に限る。深刻度ラベルは参考にとどめ、引用元が無ければ全件を「引用なし」として扱う
- **引用できない指摘は follow-up issue に切って `passed` の判定へ進む**
- **引用できる指摘が 1 件でも残ったら 3 周目に入らず、`needs-approval` を付けて主に「続けるか、範囲外として閉じるか」を出す**。無人運用でも同じく止まる。主の続行指示で開いた周の終わりにも同じ仕分けを適用する。「新規の高深刻度 blocking なら 3 周目に入ってよい」の許可条件は削除した
- **W の修正が方式の書き換えなら、次の再レビューは全体レビューにする**。判定に使った 2 つの行数を PR コメントに残し、周回は数え続ける
- 決める役はキャップの判定に関与しない（出力契約は変えない）
- G の指示書の Gate Result に仕分け結果の欄を Status によらない共通項目として置き、レビュアーの要約を受けて再開したときに指摘が残っていれば 1 周目は failed、2 周目以降は収束ルールの仕分けを通す分岐を書いた（SKILL.md の「欠陥ありなら failed」の一般則にも、2 周目からは収束ルールが優先すると添えた）
- 手順 6 の復帰表に保留種別「2 周目キャップ」の行を足した（どちらの回答でも `needs-approval` を外す）。「主に承認を求めてよい 4 分類」のリスク許容の確認に 2 周目キャップを含めた
- `skills/develop/references/roles/gate-runner.md`: return の `周回:` 欄・failed と保留の return・再開節を揃えた。`spec-reviewer.md` の pr-review-gate への言及と README の要約も直した

## 2.13.0 — 2026-09-14: develop の PR をゲート合格まで Draft に保ち、合格処理で Ready にする

W が工程 (3b) で PR を Ready にしてから G に渡していたため、CI を「Draft の PR では回さず、Draft を外したときに回す」設定にしたリポ（genetta-inc/flatmate。harness が配布する `plugins/infra/templates/workflows/ci.yml.template` も同じ形）でも、レビューと修正の周回ごとに CI が走っていた。flatmate では 14 日で org の Actions 無料枠を使い切り、CI と auto-merge が全停止した。#304。

- **W の (3b) は PR を Draft のまま G に渡す**（`skills/develop/references/roles/worker.md` と `skills/develop/SKILL.md`）。issue が記録先なら interactive でも `gh pr create --draft` で作る
- **pr-review-gate 手順 5 の合格処理で、`needs-approval` が無いことを確かめてから、Draft なら `gh pr ready` を実行し、そのあとに `agent-review:passed` を付ける**。実測確認に「PR の `draft` が `false`」を足した（4 点）。人間が作った非 Draft の PR には何もしない
- **順序は issue 本文の「passed → Ready」ではなく「Ready → passed」にした**。passed を先に付けると、その labeled イベントは PR が draft なので auto-merge workflow にスキップされる。Ready 化で CI が走るリポは CI 完了で拾い直されるが、CI を Draft 中に済ませて Ready 化で走らせないリポ（harness 自身）では次の判定が日次の schedule まで来ず、合格からマージまで最大 24 時間待つ。Ready → passed なら、どちらのリポでも passed 付与の labeled か CI 完了のどちらかで判定される
- **手順 1 で stale な passed を外したら、非 Draft の PR を `gh pr ready --undo` で Draft に戻す**（passed が無かった初回・failed から・保留からは戻さない）。CI を Draft で止めるリポでの取り直し 1 周あたりの CI は、合格後の最初の push（非 Draft の PR への synchronize）で 1 回と、合格時の Ready 化で 1 回になる。戻さなければ取り直しの push のたびに走る
- **Ready 化に失敗したら passed を付けずに止まる**（手順 5 の断片が `gh pr ready` の終了コードを見て非 0 で終わる。`draft` を取得できないときも同じ）。draft のまま passed を付けると labeled イベントがスキップで消費され、Ready 化をやり直しても判定が日次まで来ないため。途中で止まったときの復旧は、passed の有無と `draft` の値で 4 通りに分けて書いた。手順 1 の断片も「passed があれば外し、非 Draft なら `--undo`」をそのまま実行できる条件分岐にした
- `skills/develop/references/roles/gate-runner.md`: 手順の要約に Ready 化を入れ、passed の return に「Ready 化: 実施した | 対象外（元から非 Draft）」の欄を足した
- pr-review-gate の frontmatter version を 1.7.0 に上げた
- 古いキャッシュの worker.md を読んだ W が (3b) で Ready にしても、手順 5 の Ready 化は「Draft なら」なので二重実行にならない
- `tests/develop-skill.bats` の (3b) の Ready 検査を Draft の検査に反転し、`tests/develop-roles.bats` に 2 本、`tests/pr-review-gate-skill.bats` に 4 本足した

## 2.11.0 — 2026-09-11: メモリ索引の肥大と放置を検知し、見直す手順を足す

メモリ（`~/.claude/projects/<project>/memory/`）の索引 MEMORY.md は毎セッション注入されるが、repo の外にあるので `tests/injection-budget.bats` では測れない。書く規約はあっても見直す手順が無く、claude-harness プロジェクトでは 27 件・58,428 バイト（索引 5,410 バイト / 34 行）まで、終わった事実や repo と重複する項目を抱えたまま増えていた。エピック #257 の子 #294（検知）と #295（修復）。

- `scripts/memory-tripwire.sh`（新規）: 索引のバイト数・行数、本文 1 件の最大バイト数、索引の最終更新からの日数を測り、閾値を超えたときだけ `[memory]` の 1 行を出す（条件が複数でも 1 行）。閾値は `DEV_WORKFLOW_MEMORY_INDEX_BYTES`（4000）/ `_INDEX_LINES`（20）/ `_FILE_BYTES`（2500）/ `_STALE_DAYS`（30）で上書きでき、数字でない値は既定に戻す。メモリディレクトリは `CLAUDE_PROJECT_DIR`（無ければ cwd）の git 共通ディレクトリの親から Claude Code と同じ規則で導くので、worktree からでも元リポジトリのメモリを見る。`DEV_WORKFLOW_MEMORY_DIR` で直接指定もできる。解決できない・読めないときは無出力で exit 0。所要時間は 1 回 約 35〜45 ms
- `scripts/session-tripwires.sh`: 上のスクリプトを呼び、出力があれば `additionalContext` の先頭に足す。止めない・削らない
- 本文の閾値は issue 本文の案 1,500 ではなく 2,500 にした。初回整理で維持と判断した 12 件のうち 5 件が 1,500 を超えており（最大 2,192）、1,500 のままだと整理直後から毎セッション通知が出る（#294 のコメントに実測）
- `skills/memory-refresh/SKILL.md` と `commands/memory-refresh.md`（新規）: 全件を読み、1 件ずつ削除・統合・短縮・維持に分類した一覧を主に出し、承認後に控えを取ってから手で適用し、索引とファイルの一致と前後の数字を報告する。スクリプトにはしない。claude-harness プロジェクトの初回整理（27 件 → 12 件）を例として載せた
- `tests/memory-tripwire.bats`（新規 14 本）と `tests/memory-refresh-skill.bats`（新規）

## 2.10.0 — 2026-09-10: W の工程 (3) を実装＋verify と archive＋PR＋仕様宣言 に分ける

本体がサブエージェントのコンテキスト量を測れるのは W を SendMessage で再開する直前だけなので、return の区切りの数がそのまま計測点の数になる。これまでの (3) は TDD 実装 → verify → archive → PR → 仕様宣言の 5 段階を 1 回の return に束ねており、膨張が最も大きい実装区間を終えた地点に計測点が無かった。エピック #257 の子 #262。

- **(3) を 2 回の return に分けた**: (3a) apply（TDD）・verify まで行って `工程完了: 実装＋verify` で return、本体が計測してから (3b) archive・PR を Ready に（または作成）・仕様宣言まで行って `工程完了: archive＋PR＋仕様宣言` で return する
- **境界は archive の手前に置き、verify は (3a) 側**にした。verify の失敗は実装への巻き戻しなので、戻る可能性のある区間を 1 人の担い手に閉じ込める。archive 以降は実装内容に手を入れない事務手続きで、テスト結果を受け取れば別の担い手でも完遂できる
- **(3a) の return に、実行したテストコマンドと exit code・`/opsx:verify` の合否を必須にした**。(3b) の担い手が書く動作確認の証拠は pr-review-gate 手順 5 の照合対象で、手渡しが起きると後任はそれを前任の return からしか得られない
- **タスク単位のさらなる分割は禁止**（`tasks.md` の項目単位・5 段など）。手渡しごとに指示書の読み直しと現状確認の固定分が乗るため、区切りを増やすほど 1 区切りあたりの実質作業比が下がる。実装の途中で切ると後任が Red のまま止まったテストから再出発することになる
- **本体の工程ルーティングは指示した工程で決める**（工程名の文字列照合では決めない）。古いキャッシュの `worker.md` を読んだ W が (3) を通しで終えて返してきた場合、(3a) の return に PR 番号と仕様宣言のコメント URL が揃っていれば (3b) を指示せず G の工程へ進む（PR Ready の再実行と仕様宣言の二重投稿を防ぐ）
- **opsx スラッシュコマンドが無く openspec CLI だけある経路も同じ区切りに揃えた**。この経路だけ「実装 → `openspec archive` を直叩き」の一括のまま残っており、(3a) の計測点が作られなかった。(3a) は実装 → `openspec validate <change-name> --strict`（`/opsx:verify` の代わりの検証）まで、`openspec archive` は (3b) とし、(3a) の return には `/opsx:verify` の合否の代わりにこの exit code を載せる
- 手渡しの手順そのものは変えていない。上限超を検知したあとの扱い・宣言の書式・前任が動作中のときの交代手順は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本のままで、本文は増やしていない（差し替えたのは工程名の例のみ）
- `tests/develop-skill.bats` / `tests/develop-roles.bats` に 6 本追加。工程の切り出しは**行頭の工程ラベル**（`top_step` / `substep`）で行い、文言の初出位置（`grep -n … | head -1`）には依存させていない。否定アサーションは `!` で書かない — bats（bash の `set -e`）は `!` を先頭に付けたコマンドの失敗をテスト最終行以外で無視するため、`! … | grep -q …` では退行を検出できない（bats 1.13 で実測）

## 2.9.0 — 2026-09-10: 途中計測 hook の早期 exit を JSON 意味論に合わせる

`scripts/context-tripwire.sh` の早期 exit は payload の生文字列 `"agent_id"` の有無だけを見ていた。JSON のキーは Unicode エスケープでも書けるため（`"\u0061gent_id"` は `json.loads` すると `agent_id`）、この判定は JSON 意味論と一致せず、同値な表記の payload が python3 に届かないまま無音で fail-open していた。強制停止の閾値を超えたサブエージェントの `Bash` 呼び出しでも deny されない（#278。PR #269 の 3 周目レビューで Codex CLI が見つけた非 blocking の指摘）。

- 早期 exit の条件を必要条件で切り直した: 生文字列 `"agent_id"` を含む、または 4 文字の並び `\u00` を含む payload は python3 に渡す。それ以外は従来どおり起動せず exit 0。`agent_id` の 8 文字は文字列エスケープでは `\uXXXX` でしか綴れず（他の 8 種が生む文字に英小文字とアンダースコアは無い）、その 8 文字は U+005F〜U+0074 に収まるので `\uXXXX` の上位 2 桁は必ず `00` になる
- 早期 exit の目的（メインスレッドの通常の payload に python3 の起動コストを課さない）は変えていない。判定を誤ってよいのは「余計に起動して無音で終わる」向きだけで、逆向き（`agent_id` を持つ payload の早期 exit）は spec の MUST NOT
- `tests/context-tripwire.bats`: エスケープ表記のキーで deny が出ることと、その並びを含むだけの payload が python3 に渡っても無音で終わることの退行テストを追加。既存の早期 exit テストには「その payload がエスケープの前置を含まない」assert を足した
- 同 bats の payload ヘルパを `ensure_ascii=False` にして実機（ハーネスの Node の `JSON.stringify`）に寄せた。既定の `True` だと `mktemp -d` のパスに非 ASCII があるだけで `transcript_path` がエスケープの並びを含み、早期 exit のテストが環境依存で落ちる
- 通知・拒否のメッセージ、計測の式、閾値、`hooks.json` の登録は変更なし

## 2.7.0 — 2026-09-09: 起動の途中でコンテキストを測って止める hook

サブエージェントのコンテキスト量は、本体が SendMessage で再開する直前にしか測られなかった。1 回の起動の中でどれだけ膨らんでも誰も止めないため、実測で W が 497,552 トークンに達していた（過去 14 日で上限 150,000 超が W 65%・G 63%）。1 起動の途中で測って止める経路を足した。あわせて、名前 glob が `isolation: "worktree"` のサブエージェントを見つけられない件（#243）を、名前ではなく hook が受け取る `agent_id` から解決する形で統合した。

- `scripts/context-tripwire.sh`（新規）: PostToolUse（全ツール）で `DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）超なら `hookSpecificOutput.additionalContext` で「今の工程を締めて成果を列挙して return せよ」を届け、PreToolUse（`Edit|Write|NotebookEdit|Bash`）で `DEV_WORKFLOW_CONTEXT_HARD_CAP`（既定 220000）超なら編集系を deny する。`DEV_WORKFLOW_CONTEXT_TRIPWIRE=off` で全解除
- 計測対象は payload の `transcript_path` そのものではなく、その親ディレクトリ・`session_id`・`agent_id` から `<親>/<session_id>/subagents/agent-<agent_id>.jsonl` として導出する（`transcript_path` は hook が発火したセッション＝サブエージェントの中でも親のものを指す。着手前実験で確定）。直接パスが無ければ `subagents/` 以下を深さ 3 段まで、エントリ 200 件 / 20ms の上限つきで探す
- 素の stdout + exit 0 はトランスクリプト表示（ctrl+o）にしか出ずモデルには届かないため、通知は `additionalContext` に固定した
- 強制停止中の `Bash` は**コマンド内容によらず全件拒否する**（窓を開けない）。当初は「受理する文法に照合して読める形だけを通す」正の列挙方式（`git` の `status`/`diff`/`add`/`commit`/`push` の一部だけを許可オプション表に沿って通す）を実装したが、#269 で 2 周連続の実機迂回が見つかった: 1 周目は `git -c 'diff.external=sh -c "…"' diff` で `-c` の値を読み飛ばして任意コマンドを実行、2 周目はそれを塞いだ後も、判定側の Python `shlex`（POSIX 文法）と実行するシェル（zsh）のトークン化がずれ、`git push $'--receive-pack=/tmp/x' origin main`（zsh の ANSI-C クォート）が判定側には安全な 1 オペランドに見えて通った。受理する経路が 1 つでも残る限り検査側と実行側のトークン化のずれで迂回が再発するため、方式を反転し、`Bash` は内容を一切見ず拒否する構造に閉じた。拒否理由には計測値・`cwd`（作業ツリーのパス）・編集済みファイル一覧を `cwd` と一緒に return に書けという指示を含め、**後片付け（commit）はサブエージェントではなく本体が行う**
- 読み取り系（Read / Grep / Glob）は拒否しない。PreToolUse の matcher を編集系 + Bash に絞ることで構造的に保証している
- メインスレッド（`agent_id` 無し）では python3 を起動せず bash 側で exit 0 する。この hook は install 先の全ユーザーの全ツール呼び出しで走るため。読み取りは末尾 256KB だけで、5MB のトランスクリプトでも 1 回 100ms 未満
- `scripts/subagent-context.sh` に `--file <path>` を追加（#243 の統合）。名前 glob を使わずそのファイルを測る。名前指定の既存挙動は変えない
- `tests/context-tripwire.bats`（新規）・`tests/subagent-context.bats`（`--file` の追補）

## 2.6.2 — 2026-09-09: サブエージェントのコンテキスト量を母集団で測る（観測のみ）

`subagent-context.sh` は 1 体分しか測らないため、起動時固定分が増えたか・上限超で手渡しになる割合が増えたかを追えなかった（2026-08-31 の約 42,000 → 09-08 の約 58,678 トークンという 8 日で約 4 割の増加に、事後の手集計まで誰も気づかなかった）。観測だけを足し、強制は加えない。

- `scripts/subagent-context-audit.sh`（新規）: `<projects>/*/*/subagents/agent-*.jsonl` の 1 経路を mtime で絞って走査し、件数 / 初回・最終コンテキストの中央値と最大 / 上限超割合を 1 行 JSON で出す。隔離の有無は隣の `agent-<id>.meta.json` の `spawnedWithWorktree` で分類し、`sources.isolated` / `sources.non_isolated` として経路別にも出す。全文は読まない（初回は最初の usage で打ち切り、最終は末尾 256 KiB の窓を 4 MiB まで倍加探索）。結果は `${SUBAGENT_CONTEXT_AUDIT_CACHE:-~/.claude/.subagent-context-audit}` に残し、`SUBAGENT_CONTEXT_AUDIT_TTL`（既定 21600 秒）以内は再走査しない
- `docs/usage-audit.md`（新規）: 監査手順の正本。実行コマンド・出力キーの意味・固定分の増加の読み方・キャッシュの場所
- **既存スクリプトは 1 本も変更していない**。とくに `session-tripwires.sh`（SessionStart hook）には載せない — SessionStart への注入は全セッションの起動時固定分を増やす側の変更で、固定分の削減という目的に反するため
- 引数エラー以外はすべて exit 0（fail-open）。閾値による停止・警告は行わない

## 2.6.1 — 2026-09-09: 手渡し規則を正本 1 箇所に畳む（手渡しは前任の `工程完了:` return が条件）

コンテキスト上限（`DEV_WORKFLOW_CONTEXT_CAP`、既定 150000 tokens）の記述は「上限を超えたら手渡す」という**発火条件**だけを書いており、**手渡してよいタイミング**を規定していなかった。2026-09-08 に、バックグラウンドで `bash scripts/test.sh` の完了を待って一時的に idle になっていただけの W を「工程を終えた」と誤認して手渡し、同じ worktree に新旧 2 人の W が並んだ（PR への重複コメント・共有ブラウザタブでのキー入力混線）。判定材料を本体側の内容判断から W / G 側の宣言に移した。

- **W / G の return に 1 行目完全一致の宣言契約**: `工程完了: <工程名>`（成果一覧を伴う工程の終わり）／`工程中断: <理由>`（バックグラウンドコマンド待ち等）。書式は `仕様化判断: する|しない` と同型。自分が起動したバックグラウンドコマンドが未完了なら、成果一覧を併記していても 1 行目は `工程中断:`
- **「再開の禁止」と「手渡しの許可」を分離**: exit 2 のときは前任の状態にかかわらず作業の継続を指示する SendMessage を送らない（無条件）。手渡し（新しい W / G の spawn）を行ってよいのは、①前任の直近 return の 1 行目が `工程完了:` のとき、②前任へ停止を指示して停止確認を受け取ったとき、のいずれかだけ。停止を指示する SendMessage はこの禁止の対象外
- **前任が動作中の交代手順**: 停止指示 → 停止確認（何を編集・投稿したか。自分で元に戻さない＝破壊的 git 操作をしない）→ 手渡し先を spawn。停止確認待ちはノンブロッキングで、unmanned は待ち続けずサイクルを終える
- **同一 worktree の同一役割は常に 1 人**（並列に起こしてよいのは別々の worktree を持つ役割だけ）
- **規則の本文を正本 1 箇所に畳んだ**: 上の 4 点（送ってよい／送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目の宣言・前任が動作中のまま交代させる手順）の本文は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」にだけ置く。SKILL.md の 1 ループ (3)(4) と昇格ラダー、`worker.md`・`gate-runner.md` の該当節、`README.md`、`templates/escalation-tripwires.md` のトリップワイヤー 4、`scripts/session-tripwires.sh` の毎セッション注入文、`scripts/subagent-context.sh` のヘッダコメント、2 つの live spec は、正本への参照だけを書く。同じ規則を 10 前後の面に言い換えて配ったことが、3 周続けての書き換え漏れ（1 周目 6 箇所・2 周目 1 箇所・3 周目 5 箇所の取り残し）の原因だった
- **ファイルを開かずに届く面にはガードを義務づけた**: `session-tripwires.sh` の注入文は、エージェントが正本を開かずに受け取る唯一の面なので、参照に加えて「正本を読むまで手渡さない」の 1 行を必ず持つ。純粋なポインタにすると、失敗の形が「古い規則を適用する」から「規則を知らないまま即興する」に変わり、二重 spawn 事故の直接原因（即興）に戻る
- **本文が 1 箇所にあることの機械検査は入れない**: 「トリガー語に掛かった面が正本への参照を持つか」を見るホワイトリストと、規則の言い換えを文単位で拾う走査（`tests/lib/handoff-scan.py`）を一度は作ったが、この PR から外した。検査の緑が「違反が無い」のか「何も見ていない」のか区別できない形に 7 周続けて落ち、原因は調整不足ではなく「規則の言い換えを機械で検出する」という目的そのものにある（語彙を増やせば別の言い回しで抜け、除外を書けばそこが穴になる）。本文の一本化は規約として spec の MUST NOT に残し、破りを捕まえるのは仕様レビューとする。機械検査が成立するかごと https://github.com/oratta/claude-harness/issues/265 に切り出した（`tests/handoff-declaration.bats` に残るのは、正本が①〜④を現に規定していることを固定する `criteria:` 系）
- **正本の節の切り出しを次の見出し（`## ` / `### `）で止めた**（後続の小節まで含んでいたため、正本の本文が小節へ移動しても `criteria:` 系が緑のままだった。2026-09-09 のレビュー指摘）
- **正本に 1 点足した**: 固定された 2 つの書式のどちらにも当てはまらない return は `工程中断:` と同じに扱う（展開直後に必ず現れる形で、明記が無いと本体が内容判断へ戻る）。あわせて④の「前任が先に `工程完了:` を返したら、そのまま続行し手渡しはしない」が①②と矛盾していたのを、通常の手渡しに戻る形に直した。「idle と return の違い」も 2 択の列挙をやめ、1 行目の完全一致だけで見分ける形にした（2 択のままだと、どちらにも一致しない 1 行目を「宣言ではないから内容で見る」と読む余地が残る）
- **停止確認が返らないときの終端は入れない**（2026-09-09 のレビュー B1〜B3。行き先: https://github.com/oratta/claude-harness/issues/266）。一度は「本体のターンを 3 回はさんだら人間に手渡しの可否を仰ぐ」と書いたが、①終端の帰結が検査で固定できておらず、事故そのもの（前任を放置して後任を spawn する）を許す文に書き換えても全テストが緑だった、②「人間に可否を仰ぐ」が手渡しの許可条件（工程完了 return か停止確認のいずれかだけ）と矛盾する第 3 の経路になる、③本体のターン数は終端の単位として働かない（他に進める作業が無ければカウンタが進まず、あれば数秒で 3 ターン空回りする）。この論点は別 issue に切り出す
- `gate-runner.md` から正本に無い書式規則（「1 行空けてから」）を落とし、`marketplace.json` の description を手渡しの記述に追随させた（spec がズレを許容したのは `plugin.json` だけ）
- openspec change `handoff-requires-completed-return` を archive

## 2.5.0 — 2026-09-08: Fable は決める役の種別（dev-workflow:decider）でだけ立てる

2.4.1 で配線したガードは `model` 未指定を拒否するが、`model: "fable"` を明示した spawn はどの種別でも素通りしていた（2026-09-08 に develop の本体が「層間契約だから」を根拠に実行役の W を fable で spawn した実例あり）。文書が自分で例外を作れる状態を、ガードに移した。

- `agents/decider.md`（新規・`plugin.json` の `agents` で宣言）: 決める役の種別 `dev-workflow:decider`。`model: fable`、`tools: Read, Grep, Glob` の読み取り専用で Edit / Write / NotebookEdit / Bash を持たない（編集できないので実装ループを物理的に回せない）。入力（記録先の本文とコメントは呼び出し側が貼る・失敗の出力・対象ファイルのパス・実行役の return）と出力（原因の分類・実行役がそのまま実行できる指示・次の実行役のモデル）を契約として持ち、記録先への投稿は行わない
- `scripts/agent-model-guard.sh`: Fable を指す `model`（`fable` の完全一致・`claude-fable` の前方一致）は `dev-workflow:decider` のときだけ許可し、それ以外は deny。判定は fork の後・`model` 有無の前。残量モードは見ない。`model` 未指定の拒否文からも fable の 4 分類を外した
- 昇格ラダー: 「実行役を sonnet → opus → fable と 1 段ずつ」を廃止し、失敗の原因が判断側か実行側かで**決める役と実行役のどちらか一方だけ**を上げる形にした（`templates/escalation-tripwires.md` が正本。develop SKILL.md・worker.md・gate-runner.md・pr-review-gate 2-2・`rules/subagent-model-selection.md` を追随）。実行役の上限は `opus`
- 重要実装の事前分類表（`references/roles/worker.md` が正本）: マージ権限・層間契約・課金/法務の「1 周目」を `fable` → `opus`。聖域パスの `opus` は据え置き。読んで判断する役（R1・G が要求するレビュアー）が分類に当たるときは `subagent_type: dev-workflow:decider` で spawn する
- R1 を decider 経路で起こしたときは、R1 が `gh` を実行できないため本体が同じ書式で代理投稿する（記録先の本文と関連コメントは本体が入力文に貼って渡す）。`general-purpose` + `model` の従来経路は R1 が自分で投稿する
- フォールバック記録の書式を「修正実装モデル: opus」→「決める役モデル: opus（… `subagent_type` は `dev-workflow:decider` のまま）」に変更
- `tests/decider-agent.bats`（新規）: 定義の検証に加え、`plugins/*/agents/*.md` のうち `model` が Fable の定義が編集系ツールを持たないことを横断で assert
- 旧方針が残っていた 4 か所を追随させた（レビュー指摘）: `gate-runner.md` の needs-reviewer 節とモデル節（`general-purpose` に `model: fable` を付けさせる案内）、`references/decision-criteria.md` の残量モード表 `abundant` / `conserve` 行、`scripts/session-tripwires.sh` の残量モード効果文（毎セッション旧方針を注入していた）、pr-review-gate のレビュアー昇格条件（`fable` への昇格を `subagent_type: dev-workflow:decider` に置換）
- 書き換え漏れの再発防止として、`gate-runner.md` は Fable に触れる全行が決める役の種別を伴うことを行単位で assert し、退役した言い回し（「事前分類の fable 行」「Fable は verify / checkpoint のみ」）がプラグイン内の文書・スクリプトに残っていないことを横断で assert する。`session-tripwires.sh` は注入される実文字列で検証する
- openspec change `fable-decider-only` を archive

## 2.4.1 — 2026-09-06: agent-model-guard を hooks.json に配線

2.4.0 で同梱した `scripts/agent-model-guard.sh` を PreToolUse（matcher: Agent）に配線した。これ以降、`model` 未指定の `Agent` 呼び出し（general-purpose / Explore / Plan / 未指定）は拒否され、理由に規範（rules/subagent-model-selection.md）と選ぶべきティアが出る。fork は共有枠モードが ok のときだけ許可。`DEV_WORKFLOW_MODEL_GUARD=off` で一時的に外せる。

## 2.4.0 — 2026-09-06: Fable は判断だけ（聖域パスの実装は opus・G は sonnet・abundant の押し上げ廃止・修正実装は 1 段昇格）

2.3.0 の後に Fable の行き先を再集計した。先週の Fable 消費のうち W 924・G 497・R1 464（API 定価換算）で、Fable で走った W / G 24 本のうち 20 本は事前分類の「聖域パス」（`.claude/` 配下・CLAUDE.md・スキル）によるものだった。エージェント設定が製品であるリポではほぼ全実装が聖域に当たり、例外のはずの Fable が既定になっていた。今週は abundant の押し上げで R1 / G が 100% Fable。G 自身の仕事は照合・ラベル操作で、判定は Codex か needs-reviewer のレビュアーが担っている。オーナー決定（2026-09-06）で「判断は Fable、実装と照合は Sonnet / Opus」に揃えた。

- 事前分類表に「1 周目」列: 聖域パス = `opus`、マージ権限・層間契約・課金/法務 = `fable`
- G の既定 `opus` → `sonnet`（上げない）。needs-reviewer のレビュアーは既定 `opus`、マージ権限・層間契約・課金/法務で `fable`
- R1 は `opus` 固定。聖域パスだけでは `fable` にしない
- `abundant` はどの役割の既定も上げない（session-tripwires の効果文言・decision-criteria 表・spec）
- pr-review-gate 2-2: 実装品質起因の修正実装は `fable` 直行ではなく前回モデルの 1 段上
- openspec change fable-judgment-only を archive
- `scripts/agent-model-guard.sh`（新規）: PreToolUse（Agent）で `model` 未指定の spawn を拒否する hook スクリプト。fork は共有枠モードが ok のときだけ許可。**hooks.json への配線は聖域パスのため別 PR**（配線されるまで効かない）

## 2.3.0 — 2026-09-06: サブエージェントのコンテキスト上限（手渡し）・共有枠モード・W の既定を sonnet に

2026-08-31〜09-05 の使用量監査（521 セッション・API 定価換算 12,159 USD）で、消費の 3 分の 2 が develop の W / G / R1 で、うち W が 44.5%（31 本・平均 174 USD・最大 745 USD）だった。原因はモデルではなくコンテキスト: W は SendMessage 再開のたびに全履歴を読み直し、Opus の W は平均 32.6 万トークンを毎ターン投げていた（W の消費の 63% が 30 万トークン超のリクエスト）。W に Sonnet は 1 本も無く、Fable 残量モードは 4 段すべて下限 Opus で、Fable が尽きた日に総量が最大になった。sonnet の別コンテキストで再集計し、分類境界の差はあるが機構（W の平均 34 万・上限超の割合 68%・Sonnet ゼロ・畳む仕組み無し）は一致した。

### コンテキスト上限（新規）

- `scripts/subagent-context.sh <agent-name> [--cap N]`: 名前付きサブエージェントのトランスクリプト（`~/.claude/projects/*/*/subagents/agent-*<name>*.jsonl`）の最後の usage から input + cache_creation + cache_read を読み、上限超なら exit 2。cwd が一致するトランスクリプトを優先
- 本体は W / G を SendMessage で再開する**前に毎回**測り、`DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）超なら再開せず、前回 return を渡した新しい W / G に**手渡し**する。W は工程ごとに必ず return し、return に「編集済みファイル・通ったテスト・判明した事実・埋めた決定・残作業」を列挙する（手渡しの唯一の入力）
- 昇格トリップワイヤーに 4【コンテキスト上限 → 手渡し】を追加（旧 4 の rate-limit 実エラーは 5 へ）

### 共有枠モード `SHARED_BUDGET_MODE`（新規）

- `session-tripwires.sh` が snapshot の `weekly_all_pct`（全モデル共通の週次枠）から `ok` / `throttled`（週経過ペースより速い）/ `depleted`（90% 超）を導出し、Fable 残量モードと並べて注入する。明示 env が優先
- `throttled`: W / R1 / G の既定を sonnet、昇格上限 opus、abundant の押し上げ無効。`depleted`: 全役割 sonnet 固定。Fable 残量モードと食い違えば共有枠モードの下限が勝つ

### 役割の既定モデル（変更）

- W の既定を `opus` → `sonnet`。`opus` は設計判断を含む記録先と失敗ループ昇格、`fable` は事前分類（従来どおり）。昇格ラダー sonnet → opus → fable の Sonnet 段が初めて到達可能になる
- `abundant` が押し上げるのは R1 / G だけ。W は abundant でも上げない（W の 4 割が Fable で走っていた原因）

## 2.2.0 — 2026-09-04: usage snapshot schema 2（複数アカウント対応）

`usage-probe.sh` を複数の Claude アカウントに対応させ、`~/.claude/.usage-snapshot` を schema 2 に拡張した。`CLAUDE_SECURESTORAGE_CONFIG_DIR` を設定すると `CLAUDE_CONFIG_DIR` を共有したまま Keychain の認証情報だけを分けられるが、probe が Keychain のサービス名を `Claude Code-credentials` に固定していたため、常に既定アカウントの値しか取れず `FABLE_BUDGET_MODE` の導出もそこに固定されていた。

### アカウントレジストリ（新規）

`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json`（`CLAUDE_ACCOUNTS_FILE` で上書き可）にスロットを列挙する。**ファイルが無ければ既定スロット 1 つとして扱われ、挙動も出力も従来と変わらない。** 生成は `scripts/accounts-init.sh` を登録したいアカウントのシェルで実行する（`CLAUDE_SECURESTORAGE_CONFIG_DIR` の実値をそのまま書き出すので、パスの転記ミスが起きない）。

Keychain サービス名の導出は Claude Code 本体と同じ規則: `securestorage` が空なら `Claude Code-credentials`、そうでなければ `Claude Code-credentials-` + NFC 正規化した値の sha256 先頭 8 桁。

### snapshot schema 2

| キー | 内容 |
|---|---|
| `schema` | `2` |
| `active` | 現在アクティブなスロット id |
| `accounts.<id>` | `label` / `securestorage` / `fetched_at` / `five_hour_pct` / `five_hour_resets_at` / `five_hour_resets_epoch` / `weekly_all_pct` / `weekly_resets_at` / `weekly_resets_epoch` / `fable_weekly_pct` / `fable_active` |
| トップレベルの上記同名キー | **active スロットのミラー**（独立に計算しない） |

トップレベルのミラーを残しているのは、`session-tripwires.sh` の `FABLE_BUDGET_MODE` 導出と statusline の 6 時間鮮度ゲート（`fetched_at` を読む）を無改修で動かすため。schema 2 は追加のみなので、古い読み手も新しい読み手も同じ snapshot で動く。

`fetched_at` は **そのスロットの値を実際に取得できた時刻**であって probe の実行時刻ではない。fail-open で前回値を引き継いだスロットは前回の `fetched_at` を保つ。

### fail-open がスロット単位になった

あるスロットのフェッチが失敗しても、そのスロットは既存 snapshot の前回値（`fetched_at` 込み）を引き継ぎ、他スロットの新しい値は書く。使っていないアカウントは OAuth アクセストークンが期限切れでフェッチが落ちるのが常態なので、1 スロットの失敗で snapshot 全体の更新が止まると使い物にならない。

全スロットが失敗したとき、および組み立て・書き込みが失敗したときに snapshot を書かない従来の契約はそのまま。

**API のエラーレスポンスも失敗として扱う。** HTTP 401 / 429 / 5xx でも API は正しい JSON のオブジェクト（`{"type":"error", ...}`）を返すので、「JSON として読めた」を成功の判定に使うと、期限切れトークンのスロットの前回値を全 `null` で上書きしてしまう。HTTP ステータスを見たうえで、使用量の数字が 1 つも取れなかったレスポンスも失敗と判定する。

### そのほか

- `Authorization` ヘッダを `curl --config -` で stdin から渡すようにした。コマンドライン引数に載せると、同一ユーザーの任意プロセスと root から `ps auxww` でアクセストークンが読める
- `label` / `securestorage` に制御文字を含むスロットは捨てる。スロット一覧は区切り付きで受け渡すため、区切りを壊すと列がずれて実在しない「幽霊スロット」が生まれ、`securestorage` が空になって既定サービス名に一致し active を乗っ取りうる
- `accounts-init.sh` が `--id` / `--label` を値なしで渡されたときに無限ループしていたのを修正（`shift 2` が失敗しても `set -e` が無いため回り続けていた）。書き込みの一時ファイル名も固定名から `mkstemp` に変更（アカウントごとに別シェルで実行する運用なので、同時実行で奪い合う）
- `label` は文字数ではなく**表示幅**（全角を 2 桁と数える）で扱い、8 桁を超えたら切り詰める。日本語のラベルで statusline の列がずれるのと、長い label で全行が押し出されるのを防ぐ
- probe のテスト経路の判定を `env | grep` から既知のキー名の直接参照に変更（改行を含む無関係な変数への誤マッチと、空文字設定時に本番経路へ落ちる従来挙動との食い違いを解消）

### refresh_token は使わない

Keychain の `refreshToken` でアクセストークンを更新すれば非 active アカウントの値も新鮮に保てるが、リフレッシュはトークンをローテートするため、Claude Code 本体が同じ refresh_token でリフレッシュしたときに無効化され、そのアカウントがログアウトしうる。使用量表示のために認証を壊すのは割に合わないので意図的に非対応とし、鮮度は statusline 側の経過時間表示で扱う。

## 2.1.0 — 2026-08-31: loops / longrun / lr の解散と契約の移設（#205）

`loops`・`longrun`・`lr` の 3 プラグインを解散し、中に埋まっていた契約だけを dev-workflow に移した（oratta/claude-harness#205、epic #208）。手順書としての層はモデルが自力でできるようになったので持たない。契約は他プラグインからも参照されるため、スキル配下ではなくプラグイン直下の `references/` に置く。

### install 済み環境でやること

marketplace から 3 エントリが消えるため、install 済みの環境ではキャッシュに残った旧プラグインを外す:

```
/plugin uninstall loops@oratta-claude-harness
/plugin uninstall longrun@oratta-claude-harness
/plugin uninstall lr@oratta-claude-harness
/reload-plugins
```

各プロジェクトの `.claude/settings.local.json` の `enabledPlugins` に `loops@oratta-claude-harness` / `longrun@oratta-claude-harness` / `lr@oratta-claude-harness` のキーが残っていれば外す（skill-pack の `enabledPlugins` 編集の規約に従う）。

### 契約の新旧パス

| 旧（loops / longrun / lr） | 新（dev-workflow 2.1.0） | 備考 |
|---|---|---|
| `plugins/loops/references/self-verification.md` | `plugins/dev-workflow/references/self-verification.md` | 自己検証の共通原則。6 スキルの `## 自己検証` 節が参照（旧 `longrun-plan` は対象から外れた） |
| `plugins/loops/references/pr-body-format.md` | `plugins/dev-workflow/references/pr-body-format.md` | PR / issue 本文の型。内容は同じ。`.github/PULL_REQUEST_TEMPLATE.md` と `roles/worker.md` の参照先も差し替え |
| `plugins/longrun/references/model-tiers.md` | `plugins/dev-workflow/references/model-tiers.md` | Workflow 実行のロール別ティア → `opts.model` エイリアス。longrun 固有の resolver・plan.md の割り当て節・`LONGRUN_AUTOMATED` は廃止。`rules/subagent-model-selection.md` の参照先も差し替え |
| `/loops:issueify`（`plugins/loops/skills/loops-issueify/SKILL.md`） | `plugins/dev-workflow/skills/issueify/SKILL.md`（スキル名 `issueify`） | `/develop` の issueify フォールバックは同プラグイン内を Read する。goalify・レシピへの参照は本文に取り込んで解消 |
| `/lr:e` / `/longrun:exec`（plan.md → Workflow スクリプト生成） | ネイティブ Workflow ツール。型は `plugins/dev-workflow/references/workflow-execution.md`、書き方は `workflow-authoring` スキル | 昇格トリップワイヤー 1 と develop SKILL.md の乗り換え先を差し替え。Build Contract レビュー・verifier のしきい値（品質 100% / 完成度 80%）・schema 付きレポートの知見はこの 1 ファイルに集約 |
| `/lr:p` / `/longrun:plan`（brain dump → plan.md） | `/opsx:explore`（openspec ネイティブ） | develop は上流の壁打ちを呼ばない方針のまま。トリップワイヤー 3 の構造的決定の逃がし先も `/opsx:explore` |
| `/loops:review-queue` | **廃止** | このリポに呼び出し元が無く、読み取り専用ビューのデータ源（GitHub Project「Review Queue」）は直接使える。人が捌く PR は `gh pr list --label human-merge --state open` |
| `plugins/loops/references/feature-list-format.md` | **廃止** | 唯一の利用者 `recipes/routine-long-build.md` が同時に消えた。外部状態は Workflow の `args` / return 値と `resumeFromRunId` で持つ |
| `plugins/loops/templates/agent-loop-template.md`（憲法テンプレ） | **廃止**。各リポの `docs/agent-loop.md`（flatmate が保守）が正本 | harness からの再生成・逆同期はしない |
| `plugins/loops/tests/integration.bats` の S130 / S130b / S131 / S132 / S133 / S139 | `tests/marketplace-sync.bats`（リポ直下） | marketplace と `plugins/` の整合ガード。特定プラグインに属さないので loops と一緒に消さない |
| レシピ 10 本・`loops-design`・`goalify`・`dev-agent-start`・longrun の agents / schemas / scripts | **廃止**（git 履歴のみ） | 参照ゼロ。必要なら `git log --diff-filter=D -- plugins/loops plugins/longrun plugins/lr` から復元できる |

`openspec/specs/` の `loops-*`・`longrun-*`・`workflow-exec`・`workflow-tool-reference`・`workflow-run-control`・`legacy-command-removal`・`loop-dev-agent-tripwires`（38 件）も削除した。生き残る契約の要件は `dev-workflow-shared-references`・`dev-workflow-issueify`・`marketplace-plugin-sync`・`loops-longrun-retirement` に引き継いだ。

### flatmate 側で追従が必要なもの

genetta-inc/flatmate#458 で追従する（https://github.com/genetta-inc/flatmate/issues/458）:

- `docs/agent-loop.md`（loop-dev-agent 憲法）: 正本宣言後は flatmate 側で自立。本文の `/loops:issueify`・`plugins/loops/references/pr-body-format.md`・`loops-dev-agent-install` の参照を新パスに
- `docs/burn-mode.md`: 「残り PR を人が捌く経路」の `/loops:review-queue` を `gh pr list --label human-merge` / Project 直接参照に
- issue テンプレート（`agent-task.md` 等）の書式の正本パスを `plugins/dev-workflow/references/pr-body-format.md` に
- リポジトリローカル pre-push フック（main 拒否込み）の雛形と挙動テスト（旧 `pre-push-merged-pr-guard.bats`）が harness から消えた。以後の正本は `new-resident` 側

### その他の変更

- `templates/escalation-tripwires.md`: unmanned の組み込み先を憲法（flatmate 保守）に、乗り換え先を `references/workflow-execution.md` と `/opsx:explore` に
- `skills/develop/SKILL.md`: 「longrun:plan を呼ばない理由」→「上流の壁打ち（`/opsx:explore`）を呼ばない理由」、参照節に憲法の正本宣言と Workflow 実行の型
- `skills/push-guard-setup/SKILL.md`: ローカル層の設置者を「loop-dev-agent 導入済み repo（flatmate の `new-resident` が設置）」に
- 参照を直した他プラグインの patch bump: casting 0.4.1・experience-to-skill 0.3.2・skill-pack 0.2.1・infra 0.5.7・weekly-report 1.1.3・daily-report 0.3.5・worktree 2.12.3
