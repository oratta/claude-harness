# Design

## Context

動機は proposal.md の Why、範囲と合否は #1685、テストと予算の方針は #1682 の OWNER の最初のコメントを正とする。基準 HEAD は `bc753b976d866fb58c0e92c0af8a7415a7b6f01f`。本体の起動時の三ファイルは `skills/develop/SKILL.md` 46,258 字、`commands/develop.md` 6,310 字、`references/codex-develop.md` 10,303 字、計 62,871 字（plugins/dev-workflow/ からの相対パス）。字数と予算のバイト数は区別する。

既存の gate-runner.md、fix-check.md、ci-watch.md、handover.md は規則を既に持つ。そこへの到達を保ち、本体にしかできない起動・代理投稿・主への依頼を抜かないことが配置変更の制約である。

## Goals / Non-Goals

**Goals:** 常に読む本体の規則と、特定の結果・操作で読む詳細を分ける。自動要約後の先頭部分だけでも役割・禁止事項・工程と必要な詳細の読み直しへ到達できるようにする。内容の存在と、入口からの参照・読込量を別々に検査する。

**Non-Goals:** 計測や実行モードの判定のスクリプト化、epic-dispatch の変更、エピック手順本文の整理、ゲート自身の規則の修正。`pr-review-gate/` と `roles/gate-runner.md` は本文を変更しない。G の `レビュー経路: adapter`、description の接頭辞・区画・補足の書式、固定 HEAD・周回・宣言・権限の条件も維持する。

## Decisions

### 1. 本体の場面限定手順は三ファイルへ分ける

場所は `plugins/dev-workflow/skills/develop/references/` とし、本体だけが使う詳細を役割別の worker/gate-runner の起動時必読集合に加えない。

| 移動元（基準 HEAD） | 移動先／読込条件 | 保つ内容 |
|---|---|---|
| SKILL.md:235-287「PR トークン上限」 | `pr-token-budget.md`。spawn・再開・Codex 委譲の前に毎回必ず Read して測る。開始・dispatch・消費の印を書くときも規約を読む | 消費の印、description の紐付け、二つの既存スクリプトを順に呼ぶコード、全終了コード、上限の引上げ、エピック権限の参照 |
| SKILL.md:149-215、ループ終端の CI 手渡しの再掲 | `gate-result.md`。該当する G の結果を処理する前に Read | 本体の分岐・入力の作り方・決める役の起動・代理投稿の例外・再要求の上限。既存の正本が詳細を持つ箇所はそこへ接続 |
| SKILL.md:221-223 | `worker-recovery.md`。W の空 return、または通常 return を含む拒否報告を受けたら、再開や許可を書く前に必ず Read | 報告と status 確認、未コミット差分の引取り、許可の四条件、同じ W に結び付く一回限りの許可、終了コード 3 の打ち直し、再拒否時の主への依頼 |

単一の例外集にまとめる案は採らない。通常の spawn のたびに拒否復旧まで読むことになるため。G の手順書に移す案も採らない。本体が代理投稿や決める役の起動を担う条件が G の読込に埋もれるため。

SKILL.md の (4) は **Status → 読むファイル（節）** の表と、Status／`次の段:` だけで次の段を決める原則を残す。表は `次の段へ`・`passed`・`needs-reviewer`・`重複で降りた`・`review-incomplete`・`failed`・`保留`・`needs-fix-check`・`needs-carryover-judge`・`needs-no-point-check`・`needs-decider` を漏らさない。`工程中断:` で返った G も既存の手渡し条件へ接続する。

gate-result.md は、既存の fix-check.md、light-path.md、handover.md、ci-watch.md、gate-runner.md の該当節へ読む指示を持つ。CI の実行手順と手渡しは共有の ci-watch.md → handover.md に寄せる。`issue で承認済み:` の事後報告、`条件の確認待ち` の主への通知、failed 後の手渡し可の無効化は本体の義務として到達先に残す。許容継承・論点なしで同じ入力が再度返ったら役を起こし直さず主に上げる規則と、順 6 の裁定を本体が代理投稿しない例外も保つ。

### 2. Codex の役割解決は既存の一ファイルに寄せる

`plugins/dev-workflow/references/codex-develop.md` の「起動と role 解決」を、入力・resolver の結果・provider 分岐・開始／dispatch 記録・再開と fresh thread の境界を読む一つの入口にする。現在の「本体が行う操作」と「品質と transport 差分」の同じ説明は、この節または同ファイル内の一つの手順へ参照でつなぐ。SKILL.md の Role profile・(4) needs-reviewer・モデル節と commands/develop.md は解決アルゴリズムを再掲せず、この入口を操作前に Read するよう指す。

`commands/develop.md` は `skills/develop/SKILL.md` と `references/codex-develop.md` の絶対パスを探して必読にする責任を維持する。明示指定時だけ codex-develop-explicit.md を読む境界も変えない。SKILL.md の役割表・工程管理・G への `レビュー経路: adapter` の起動指示は provider 解決の重複とは扱わず、本体の契約として残す。

既存要件「失敗の段は `--failure` で request に渡し、返った model を使う」も MODIFIED に含める。三つの Scenario 名と動作条件（first／executor／judgment の対応、request が返した model の使用、model が変わる昇格時の fresh thread）を保ち、SKILL.md「モデル」節の本文指定を、操作前に必読とした codex-develop.md の本文で確認する契約へ置き換える。分類の定義として escalation-tripwires.md を参照することは保ち、そこから model を読み取る指示は禁止のままとする。

解決ロジックを別の新規ファイルに置く案は、正本として既に指定された codex-develop.md をさらに経由地にするため採らない。既存スクリプトや profile 設定・model 対応表は変更しない。

### 3. 先頭には復帰後も要る骨格を置く

SKILL.md の先頭は役割表、本体の禁止事項（軽い通し方の既存例外を含む）、記録先→仕様判断→R1→実装＋verify→必要時 V→archive＋Draft PR＋仕様宣言→G の工程概要、コンパクト後も操作前に正本を読み直す指示を置く。詳細な説明の並べ替えで骨格が後ろへ押されないようにする。

先頭位置の換算は外部 API に依存しない保守的な方法を使う。上の骨格の末尾までの UTF-8 バイト数を 1 byte = 1 token と換算し、5,000 以下を検査する（Claude の tokenizer の実測値とは称さない）。PR 本文には対象見出し・末尾行、換算式、コマンドと結果を書く。役割表の後に長い説明を挟まず短い工程概要を先置きすれば、この上限内で既存の意味を維持できる。

「主に聞かずに決めること」は判断条件と例外を残し、事例・経緯を削る。「モデル」は役割の格と正本への参照を残し、経緯と他ファイルと同文の説明を削る。「前提」は必要な環境と縮退を残し、他節の表の再掲を参照化する。「実行モード」は表・入口のモード決定・channel 時の必読指示を残し、channel.md／epic.md の同文段落を参照化する。「参照」は本文中に同じ案内があるものを重ねない。単発でも必要な安全・権限・工程の規則は削除しない。

### 4. 内容検査と配置・予算の検査を分ける

文言検査は既存の gate_all / worker_all と同じく `skills/develop/SKILL.md` と `skills/develop/references/**/*.md` の全手順書集合で規則を探す。Codex 固有の規則を検査する場合だけ既存の `plugins/dev-workflow/references/codex-develop.md` を加える。無関係な docs・archive に語があることで合格させない。既存の develop_docs helper は plugin references 全体と template も含むため、今回の存在検査の対象を明示した集合として使い分ける。否定の検査は元の責務範囲を維持し、対象拡大で意味を変えない。移動で落ちる節切出しや一ファイル限定の検査を見直し、否定条件・代理投稿例外・回数制約は残す。

一方、必要時に読めるかは別の構造検査で守る。起動の三ファイルが正本を名指しすること、SKILL.md の Status の全行・空 return／通常の拒否報告での必読指示、核心規則の先頭位置、provider 解決本文の一元化を検査する。実際に規則を別ファイルへ移した使い捨て fixture が内容検査を通り、規則を消す・必読参照を外す・予算を超える fixture が落ちる退行検査を用意する。

起動時の三値は既存の `tests/develop-startup-budget.txt` のまま実測バイト数まで下げる（上限超過／1.1 倍を超える余白の拒否を維持）。三つの切り出し先には別の `tests/develop-orchestrator-reference-budget.txt` と対応 bats でファイル別の同じ上下判定を付ける。既存の起動予算に条件付きファイルを混ぜると「起動時の三ファイル」という集合が崩れるため別にする。

検査要件の本文に入力元・拾う誤り・許す範囲外の具体例を明記する。同じ字数・バイト数の場面限定段落を入れ替え、内容・入口・先頭位置・一元化・各ファイルの予算がすべて保たれる fixture は通ることを許す。これは #1682 の OWNER が許容した残りであり、場面に合う配置や文の意味・実エージェントの読解の全てを機械で保証すること、穴を塞ぎ切ることは完了条件にしない。

### 5. 既存仕様は場所の指定だけを追従させる

四 capability の delta は既存要件を全シナリオ付きで維持し、本文があるべきファイルや節を変える箇所だけを修正する。G の再開を新規起動へ読み替える既存要件など、既にある読み替えを本件で再設計しない。エピック要件のうち `SKILL.md「PR トークン上限」` と書いてある参照だけは pr-token-budget.md に付け替え、エピック手順本文の整理はしない。新しい起動配置・検査・測定の契約は dev-workflow-develop の追加要件に置く。

## Risks / Trade-offs

- 必読指示が参照の一覧だけになる → 発火場面と「操作する前に Read」を本文に残し、参照削除で落ちる検査を付ける。破壊的 git の安全手順は任意読込にしない。
- 集合での文言検査は同字数の入替えや読み順の誤りを取りこぼす → ファイル別予算と入口の構造検査を併用する。同字数の入替えを完全には止めない残りは #1682 の OWNER の決定に従い受け入れる。
- Codex 一元化で監査項目や再開条件が抜ける → 元の三箇所と移動先の対応を記録し、requested/applied model、格、account、selection evidence、固定 HEAD、read-only 境界の既存テストを保つ。
- 先頭位置の byte 換算は実際の tokenizer より厳しい → 短い骨格を置いて詳細へつなぐ。字数の削減率自体を合否にしない。
- 並行作業と同じファイルを触る → #1686・#1687・#1693〜#1695 の処理変更を含めず、許された参照先の付替えに留める。

## Migration Plan

今回の spec 段では artifact だけを commit・push して return する。R1 の承認が記録先に記録された後、実装段で tasks を実行し、変更記録に段落の移動元→移動先・削除理由・読む場面の対応を残す。PR 本文には三ファイルの前後の字数、予算の bytes、先頭 5,000 の換算、段落ごとに単発 issue のどの場面では読まずに済むかを記録する。単発でも spawn 前などに必要なものは「その場面では必読」と明記し、読まないことを目標にしない。字数の前後は親 #1682 にもコメントする。

終了の段で通常の archive により delta を main specs に反映し、再検証する。戻す場合は対象 PR の配置変更・参照・テスト・予算を一緒に戻す。スクリプト・実行時データの移行は無い。今回は archive・PR 作成・merge・auto-merge を行わない。
