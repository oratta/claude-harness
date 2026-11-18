# Design

## Context

対象は #1682 の子 #1684。基準は dispatch の main `e10f0a9896d82d0b86c0f7a10becb70c4983bc63`（着手時の origin/main と一致）。仕様化判断は https://github.com/oratta/claude-harness/issues/1684#issuecomment-6977303297 。

既存 epic.md は 173 行だが、手順が長い一行に集まり 108099 bytes / 49622 字ある。`stop-judge.sh:60` は parent-pass-criteria.md 全体を読み、判断モデルへの入力にしている。parent-merge-criteria.md も親が決める役に渡す。この二つの例や判断条件を短くする設計ではない。

## Goals / Non-Goals

**Goals:** エピック固有の読込を場面で分け、移した段落へその場面の読み手から到達できることを示す。判断規則は同じ条件のまま共通正本へ寄せ、位置の検査を予算と参照接続の検査に置き換える。

**Non-Goals:** #1685 の SKILL.md の節の移動・削除、#1686 のスクリプト化・epic-dispatch.sh の出力語の説明の削除、#1687 のゲート本文整理。実装スクリプト・出力語・返事の添え書き・権限や判断条件の変更。仕様化段での手順書分割・Bats 編集・エピックへの字数コメント。

## Decisions

### 1. 入口と場面の分割

パスは特記以外 `plugins/dev-workflow/skills/develop/references/` から。issue の 7 ファイル案を採用し、親子双方の声かけ契約だけを `epic-keepalive.md` として追加する。reply-after-idle.md 全体を子の停止時に読ませる案は、親の時間分類や見張りの説明まで子に入るため採らない。主な設計判断はこの読込境界と正本の分割一つで、複数 capability の delta は参照の追随であり独立 change に分けない。

| ファイル | 読み手・読む場面 | 移す／残す内容（旧 epic.md の行） |
|---|---|---|
| epic.md | 親子の入口、エピック化の判断、注意書きの受信、子が範囲外の問題を見つけたとき | 読むものの表、条件・作り方（5–21）、nested の子側の扱い（29）、注意書きの author_association 検査（31 の子側）、両経路共通の子 issue 追加・stack PR（159–162）、完了の意味（164–166）。親の起動・片付け・見張りの操作本文は置かない |
| epic-loop.md | 別セッション方式の親、開始と通常の進行・復元 | 経路（25・27）、起動と子の状態と部品（31–45 の親側）、子エピックの事前除外・待ち受け・完了報告（27・121–123）、報告・状態表・ログ優先（46–72）、clear、手順 1–7・9（79–87・90）、closed の確認と待ちの終了条件（121–123）、モデル・CLD_DEFAULT_ARGS・上限の仕様（149–153）、完了時の片付け（168–170）。手順 7 に埋まった停止解決は epic-stop.md を読む指示へ置き換える |
| epic-stop.md | 親、stopped / pending-owner の停止を処理する直前。サブエージェント方式の本体が PR トークン権限に照らすとき | 手順 8（88）、今回の止まった理由の唯一の定義、停止と過去判断の照合、通す／主に上げる・返事・told・判例記録、PR トークン上限の子（127）。委任の記録・確認・取り消しを行う親の操作と、委任での送信・二重送信防止もここに移す（92–120 の親側） |
| epic-delegation.md | 親が委任を受ける／取り消すとき、親子が委任を適用するとき | 委任の二つの記録の定型、確認と期間の意味、失効・取り消しの効き方、委任が有効かの 6 条件、効く止まりの種類別条件（92–120 の共有契約）。記録投稿・返信の操作本文は epic-stop.md へ。子には親の手順を読ませず共有判定だけ読ませる |
| epic-merge-wait.md | 親、今回の止まった理由が PR のマージ待ちのとき | マージ待ちの前提確認・決める役への入力・HEAD 再取得・印とコメントの順・失敗時の扱い（125）。条件の正本は parent-merge-criteria.md のまま。専用ファイルにすることでプロンプトである基準本文を膨らませない |
| epic-multirepo.md | 親、別リポジトリの子があるとき | 別リポジトリの読み替え表・clone と名前の扱い（129–147）、手順 1・6 などに混ざる別 repo 固有の補足。entry / loop / stop / merge の該当箇所から読む |
| epic-subagent.md | 親、route=subagent（unmanned・channel を含む）のとき、子の中で W を並列に起こすとき | サブエージェント方式・枠・再開優先順・別 repo の子を起こさない扱い（157）。状態記録を作らないこと、子エピックの事前除外と状態表は loop の共通規定・報告規定への参照。別セッションの起動・片付けは読ませない |
| epic-keepalive.md | 子が停止する前、親が停止済みの子の声かけを扱う場面 | 共有の予約文の受信契約と自動送信の適用条件・除外・期限・通常の一行往復だけの保証。旧 epic.md:63・173、epic-child-stop.md:7、reply-after-idle.md:63–69 を集約する。親への手動の起動・見張り・片付けの指示は置かない |
| epic-child-stop.md（既存） | nested の子、停止前・親からの返事受信時 | 子の停止記録の形、質問ツールを使わない読み替え、定型の止まり、relayed / delegated の確認と再開。委任条件の複写と声かけ本文を共有正本への読込指示にする。`主に聞く理由:` を書く前に parent-pass-criteria.md「例」を読む指定を置く。親の停止解決は載せない |
| reply-after-idle.md（既存） | 共通入口の設定、親の起床直後、子へ実際の返事を送る前 | 親の時間分類の正本。旧 epic.md:74–77 のみにある未処理イベント・stderr / exit code・元発言の場所・記録失敗の扱いをここへ補い、表と本文で同じ分岐を二重に書かない。起動し直した親の復元操作は loop、返事送信は stop に参照する。声かけの本文は keepalive への参照にする |

番号の 8 は epic-stop.md へ移しても維持する。loop に 8 の操作本文を残さず「stopped / pending は epic-stop.md を読む」を置く。1–7・9 の番号も維持し、文書を跨ぐ手順番号は必ずファイル名を添える。通常進行の手順 7 は pending-owner の取得までを書き、停止の照合・解決は stop を先に読む指示とし、その条件を繰り返さない。

報告の 1 行目・2 行目（issue のいう末尾の状態表を含む）の書き分けは loop の「主への報告」に一度宣言する。stop・merge・subagent の冒頭でこの節を読むよう指示し、各手順末の「上の書き分けの規定に従う」は繰り返さない。問いの直後を「なし」で上書きしない、純粋な短時間 timeout で発言しない、状態表を省ける長時間の旧親だけの例外など、場面固有の条件は残す。

### 2. 正本と参照の契約

| 規則 | 正本 | 参照する面 |
|---|---|---|
| 主の委任の有効性・止まりに効く条件 | epic-delegation.md | stop・child-stop・merge-wait・parent-merge-criteria.md。共有の 6 条件と種類別条件は develop 配下ではこの 1 ファイルだけに置く |
| 親の起床時の時間分類 | reply-after-idle.md「親への適用」 | loop のイベント振り分け・手順 5・9・報告の例外。閾値・時刻の出どころ・優先順を loop に複写しない |
| 停止中の子への声かけの規則 | epic-keepalive.md | child-stop（停止前に読んで予約文を覚える）、reply-after-idle、loop / stop の停止済み子の説明 |
| 声かけの固定文字列・返事の型というデータ | plugins/dev-workflow/references/child-cache-keepalive.json | 既存の script と keepalive。JSON の値や読み方・スクリプト動作は変えない |

ゲート `stages/pass.md:147` 等の判定本文は #1687 の範囲なので、その複写はこの変更で削らない。参照パス `references/epic.md` → `references/epic-delegation.md` のみ付け替える。正本一本化の検査対象は develop 側の手順書であり、ゲートに残す同じ条件は既存どおり確かめる（#1687 が整理するまでの境界）。ゲートを含めて重複がゼロになったとは報告しない。

`SKILL.md` の epic の節を指す参照は、同じ節の位置の付け替えだけにする。PR トークン上限の子→stop、サブエージェントの枠→subagent、注意書き検査→entry、条件・作り方→entry、別セッションの回し方→loop。入口の読む条件は残し、entry の表が次の必要な文書を案内する。spec-decision.md のエピック化の参照は入口のまま保持する。`plugins/dev-workflow/references/commit-and-pr-operations.md:18` のマージ待ちの参照は merge-wait へ付け替える。channel.md・handover.md・fix-check.md 等も参照先を走査し、移した節を指す場合だけ同様に更新する。`references/ci-watch.md` は現状 child-stop への参照で完結しており、実物の照合で古い epic の参照がなければ変更しない。

### 3. 場面別の読込集合とバイト予算

測定単位はまずエピック固有の追加読込。親子に共通の起動文書を混ぜると #1685 の SKILL.md 整理と結合するため、共通起動分は既存 startup 予算の管理を保ち、比較表には共通分を一度だけ足した合計も併記する。SubagentStart の注入、issue 本文、会話ログ、判断対象の動的データは数えない。節を指定する参照でもファイル全文を数え、同じファイルは 1 場面で一度だけ数える。

`R = skills/develop/references/`、全パスは plugins/dev-workflow/ から。

| 予算キー | 分割後の集合 |
|---|---|
| nested-entry | R/epic.md |
| nested-stop | nested-entry ＋ R/epic-child-stop.md ＋ R/epic-keepalive.md ＋ references/child-cache-keepalive.json ＋ R/parent-pass-criteria.md（例の参照でも全文） |
| parent-start | R/epic.md ＋ R/epic-loop.md |
| parent-stopped | parent-start ＋ R/epic-stop.md ＋ R/epic-child-stop.md（記録の形）＋ R/parent-pass-criteria.md ＋ R/reply-after-idle.md ＋ R/epic-keepalive.md |
| nested-delegated | nested-stop ＋ R/epic-delegation.md |
| parent-delegated | parent-stopped ＋ R/epic-delegation.md |
| parent-merge-wait | parent-stopped ＋ R/epic-merge-wait.md ＋ R/parent-merge-criteria.md |
| parent-merge-delegated | parent-merge-wait ＋ R/epic-delegation.md |
| parent-multirepo | parent-start ＋ R/epic-multirepo.md |
| parent-subagent | R/epic.md ＋ R/epic-subagent.md ＋ R/epic-loop.md（子エピックの事前除外・報告規定の全ファイルを保守的に計上） |

nested-stop は `主に聞く理由:` を書く前に読む parent-pass-criteria.md 全文を含み、nested-delegated もこれを引き継ぐ。例の正本と子に残す (a)–(c) は変えない。委任は記録があるとき／受けるときだけ、merge はマージ待ちだけ、multirepo は別 repo の子があるときだけ追加する。子の同一 repo / 別 repo の親の返事の頭は child-stop だけで受けられるので、子に multirepo を読ませない。subagent の PR トークン上限では stop を必要時に追加する。上の基本・追加集合は合成可能とし、複合場面は和集合を用いる。

予算の正本は新規 `tests/develop-epic-scene-budget.txt`、検査は新規 `tests/develop-epic-scene-budget.bats`。形式は `<上表のキー> <先頭ゼロなし正整数bytes>` の全 10 行・重複なし。**各初期上限は、実装後に上表のファイルを `wc -c` で足した値ちょうど（余白 0 bytes）に固定する。** 仕様化時点の未分割ファイルの値を上限に流用せず、実装時に確定する実測整数をコミットする。これは値の選択を後回しにするのでなく、式 `budget(scene) = sum(final_file_bytes)` を全キーに指定するもの。削減目標の数字は置かない。予算を実装前に任意の低い数字へ決める案は、削減量を合否にしない方針に反するため採らない。

検査は #1683 と同じく実測 > 予算で失敗、予算 > 実測の 1.1 倍でも失敗。実測を自動で予算へ書き戻してから検査してはならない。集合は Bats の関数に固定し、txt からファイルを抜いて通せないようにする。txt の書式・全キー・ファイル欠落・1 byte 超過・ちょうど上限・1.1 倍境界・未知キー・重複・不足を使い捨て root で検査する。必要ファイルの案内が entry とその場面の入口にあること、nested から parent-only の手順を読む指定が無いこと、stop/merge/multirepo/subagent を親開始時に無条件で読ませていないことも実ファイルと参照を消した fixture で検査する。

**守備範囲**: 入力は Bats に固定した集合、実ファイル全文、独立した txt のキーと上限値。上限超過・必要ファイル欠落・書式不正・未知キー・重複・不足・緩すぎる上限を検出する。読込指示の意味や同じ字数かつ同じバイト数の文の入れ替わりは検出せず、参照接続検査に違反しなければ予算検査が通ることを許す。すり抜ける入力をすべて塞ぐことは完了条件にしない。場面を分ける意味は仕様レビューと PR の段落対応表で確認する（主が #1682 で受け入れた残り）。`tests/injection-budget.txt` は変更しない。既存の startup 予算を変える必要があれば、参照パスの長さの変化による差だけを扱い、理由を PR 本文に書く。

### 4. 切り出し前の測定（main e10f0a98）

次の表の集合は分割前のもの。分割後は上の集合に置き換え、PR 本文と #1682 の実装段のコメントで前後を比較する。この段では #1682 へ投稿しない。

| 場面 | 分割前のエピック追加読込 | wc -m | wc -c | 共通起動分も一度だけ含む wc -m / wc -c |
|---|---|---:|---:|---:|
| 子 nested の入口 | R/epic.md | 49622 | 108099 | 122102 / 253653 |
| 子 nested の停止 | R/epic.md, R/epic-child-stop.md, references/child-cache-keepalive.json, R/parent-pass-criteria.md | 70959 | 160374 | 143439 / 305928 |
| 親の開始 | R/epic.md | 49622 | 108099 | 122102 / 253653 |
| 親が子の停止を処理 | R/epic.md, R/epic-child-stop.md, R/parent-pass-criteria.md, R/reply-after-idle.md | 80310 | 180453 | 143180 / 305423 |

R1 の計上漏れの修正に伴い、子の停止の分割前の比較集合にも parent-pass-criteria.md 全文（11178 字 / 28464 bytes）を含めて測り直した。旧値 59781 字 / 131910 bytes は同ファイルを含まなかったため、この表の比較値には使わない。分割前には子の例が child-stop にもあるが、分割後と同じ参照依存を含める比較基準として全文を保守的に計上する。他の 3 場面は集合と値が変わらない。

共通起動分 C は `skills/develop/SKILL.md`・`commands/develop.md`・`references/codex-develop.md`・`R/reply-after-idle.md` の和集合で 72480 字 / 145554 bytes。先行 #1683 の起動 3 ファイルの比較にはなかった共通設定の Read を、今回は全文計上して明示した。parent-stopped にも含まれる reply-after-idle は二重に数えない。入口で reply-after-idle の設定節を読む既存指定は #1685 の対象に踏み込まず維持する。エピック固有の入口で子に新たに親の手順を読ませないことを今回の読込境界とする。

再測定は各セルのファイルを git show `<基準SHA>:plugins/dev-workflow/<path>` で取り、表の順に cat 相当で連結し `LC_ALL=en_US.UTF-8 wc -m`、バイト数は `wc -c`。作業コピーを測って「main の値」としない。

### 5. テストの移動耐性と接続の検査

文言の存在の検査は develop 配下の md 全体を読む `develop_all` 相当の helper に寄せる（`develop-roles.bats` の gate_all / worker_all の前例）。巨大な連結を一つの行とみなすのではなく改行を保つ。番号や節を切り出す既存 sed/awk と「その行に全文がある」検査は、対象規則の存在・優先順・正本参照を個別に確かめる形へ直す。実行結果・stdout/stderr/exit code を確かめる script のテストは弱めない。

| Bats | 直し方 |
|---|---|
| plugins/dev-workflow/tests/epic-dispatch.bats | EPIC の全文固定、手順番号や状態表の切出し、Python の epic.md 直読みを移動耐性のある読込へ。経路・注意書き・nested・wait/reap/adopt/reply の振る舞いのテストは維持 |
| plugins/dev-workflow/tests/develop-skill.bats | 移した節の案内を新パスで確認。deleg_para / child_reply_item の重複全文要求を、共有正本の条件と親子からの参照に変更。親の時間分類と声かけの重複を要求しない |
| plugins/dev-workflow/tests/parent-merge.bats | merge の処理は移設後も存在し、基準参照・HEAD の照合・コメント→ラベル順・子へ印を付けさせないことを確認。epic.md の旧位置は要求しない |
| plugins/dev-workflow/tests/owner-escalation-narrowing.bats | step8 / 委任段落の固定位置を外す。親と子に同じ委任本文がある検査を、共有正本と参照に変える。child-stop と parent-pass の重複した日付つき例を両方に要求せず、例の正本 parent-pass と子の参照、子の (a)–(c) の確認は維持 |
| plugins/dev-workflow/tests/pr-review-gate-skill.bats | ゲートの判定文と、移動した共有正本の条件の一致を確認。child-stop の同文複写は要求せず共有正本参照を確認。ゲート本文は編集しない |
| plugins/dev-workflow/tests/develop-channel-mode.bats | エピックの channel の既存条件と新参照を develop のどこかで検査 |
| plugins/dev-workflow/tests/git-destructive-guard.bats:2454–2463 | 手順 5 の旧 sed 切出しをやめ、loop から検知条件・画面で止まる限界を読めることを確認。guard のテストは維持 |
| tests/owner-question-style.bats | 移設先にも正本参照と固有事項があることを確かめ、報告規定を各手順に繰り返す要求を外す |
| tests/openspec-specs-format.bats | 既存の SKILL.md 移設節の検査を維持する。今回の epic の移設は main specs へ archive で反映するため、未 archive の旧 main specs を失敗にする検査は実装段に加えない。参照の新旧は delta と reference-inventory で照合し、archive 後に現行 specs の走査を行う |
| tests/develop-epic-scene-budget.bats（新規） | 上述の集合・予算・入口の案内・親子の読込境界と正本一本化の検査 |

声かけの既存テストは epic-dispatch / develop-skill に加えて child-log-read.bats・epic-launch-tmux.bats を回す。stop-judge.bats も回して基準プロンプトを変えていないことを確かめる。新しい scripts への切出しはしない。

### 6. 現行仕様の参照の移設

対象要件の一覧は同ディレクトリの `reference-inventory.md`。delta は既存の要件名と全 scenario を保ち、移設先と「本文を複写する」から「共有正本を読む」への契約だけを変える。要件名に epic.md が含まれていても互換の識別子として名前を保つ。要件名の変更だけの RENAMED を混ぜない。archive 済みの過去の change は書き換えない。

- develop: entry に残る条件・作り方・nested・注意書きの子側と、loop の通常進行、stop の手順 8、delegation、merge-wait、multirepo、subagent をそれぞれ指す。複数を規定していた要件は、どの段落がどのファイルか明記する。
- epic-state: 片付け・adopt/clear は loop、別 repo は multirepo、状態を書かない subagent は subagent。
- pr-token-budget: 「PR トークン上限の子」と権限の照合は stop、親が既定の権限を置く入口は loop。
- destructive-git-hook: 検知可能性と限界は loop の手順 5・初回通知の手順 2。
- owner-question-style: 共通の書き分けは loop の「主への報告」、固有の子の記録と親への返事は child-stop、止まりの報告は stop。
- harness-public-private-split: 起動部品の欄は loop、別 repo の登録の欄は multirepo。既存の公開／非公開基準は変えない。

本文に「同じ文」がある委任二要件は、条件は丸ごと残しても、手順書の配置契約は共有正本とそれを読む指示に改める。G の同じ判定本文は #1687 まで保つ。声かけの JSON 共有要件にも手順の正本を加え、挙動を変えない。

### 7. 経緯・例と、役目を終えた分岐の確認

意味を変えない削除は、epic 本文の日付・過去の実測・issue 番号の説明（状態表の実例、上限既定値の過去 RSS など）、繰り返す報告の書き分け指定、child-stop の (a)–(c) の後の三つの事例。後者は parent-pass-criteria.md「例」に同じ趣旨の全文があるので子が `主に聞く理由:` を書く前にその節を読む指定にする。この依存は nested-stop / nested-delegated の集合・予算に全文を含め、前後の測定も同じ規則で数える。(a)–(c) の確認自体は子にも残す。parent-pass / parent-merge の例・判断条件は削らず、参照パスだけ付け替える。委任の定型の固定行は文字列契約なので削らない。固定部分の外にある根拠の経緯を削る場合も定型の判定行数・値は変えない。

| 消す候補の分岐 | 調べる根拠 | 今回の判断 |
|---|---|---|
| 更新前の子の停止記録を発言より先に読む／マージ・トークンの旧記録を使う | stop-judge.sh:92–155 は GitHub の今回の停止記録を今も読む。保存済みコメントと旧起動プロセスを全利用環境から排除した保証が無い | 残す。PR 本文の残した互換分岐に挙げる |
| 以前の `親の判断: 判断できなかった` の送信失敗を送り直す | epic-dispatch.sh:1303–1367 の現行の送信失敗は `通すが送れなかった` だが、旧コメントは GitHub に残る | 残す。producer が変わったことだけでは到達不能の証明にならない |
| 記録導入前の子を adopt する | epic-dispatch.sh:2331–2381 は既存の Orca の子を採り直す。記録の無い子が全て消えたという永続的な保証が無い | 残す |
| PR トークン権限コメントが無い再開時に既定を投稿する | 過去のエピックの再開が可能。新規作成だけの契約ではない | 残す |
| closed 時の子エピックの念のための除外 | 現行 route の事前除外はあるが、旧親の状態からの復元と手動の状態変更を排除していない | 残す |

この調査で到達不能と証明できた挙動分岐は 0 件。日付が古いだけで削らない。追加調査で削るなら producer と永続入力の両方から非到達を示し、対応する scenario とテストへの影響を仕様レビューへ返す（この仕様では削除を承認していない）。

## Risks / Trade-offs

- 移動で参照が切れる → 旧段落ごとの移設先・入口・読み手を PR の対応表へ書き、参照接続の Bats と delta の照合、archive 後の現行 specs の旧参照走査を行う。
- 全文一致を弱めた検査では場面の混入を見落とし得る → 予算・案内の検査に加え、PR レビューで読む場面を確認する。字数だけでの入れ替えは主が受け入れた残り。
- G の判定文の複写が一時的に残る → G の本文を変えず共有正本と同じ条件であることを既存テストで維持し、#1687 の範囲を守る。
- 共通の起動ファイルに含まれる場面限定の説明は残る → 追加読込と共通分の和集合を両方報告し、#1685 の効果と混同しない。

## Migration Plan

R1 APPROVE のあとに、読込と予算・文言検査の fixture を先に作り、段落を移して参照元と delta の接続を確かめる。各変更と対応するテストを同じタスク群で仕上げる。実装がそろった時点で初期予算を式どおり実測で固定し、PR の段落対応表・字数前後・残した互換分岐を埋め、#1682 に実装段で字数をコメントする。

`./scripts/test.sh` と `./scripts/lint.sh` は実装段の統合確認。仕様化段は `openspec validate split-epic-reading-contexts --type change --strict` と差分確認のみで、実装の品質の成功を宣言しない。archive・PR の Ready 化・ゲート・マージはこの段に含めない。戻す場合はこの PR の revert で手順書・参照・予算を一緒に戻す。状態ファイルや GitHub の既存コメントを移行・削除する必要はない。
