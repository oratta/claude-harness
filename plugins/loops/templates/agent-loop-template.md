# 自律開発ループ憲法（agent-loop）

> このファイルは自律開発ループの「1サイクルの手順書」であり、ループの実行系ではない。
> 反復は `/loop`（ネイティブプリミティブ）が担い、本ファイルは毎サイクル読み直される前提で書かれている。
> 生成元: `plugins/loops/templates/agent-loop-template.md`（`/loops:dev-agent-install` が値を埋めて配置する）。
> レシピ本体: `plugins/loops/recipes/loop-dev-agent.md`。

## プロジェクト設定

| 項目 | 値 |
|---|---|
| main ブランチ | {{MAIN_BRANCH}} |
| テストコマンド | `{{TEST_CMD}}` |
| lint コマンド | `{{LINT_CMD}}` |
| ビルドコマンド | `{{BUILD_CMD}}` |
| dev サーバー起動 | `{{DEV_SERVER_CMD}}`（URL: {{DEV_URL}}） |
| ブラウザ実機検証 | {{BROWSER_VERIFY}} |
| worktree 置き場 | `{{WORKTREE_BASE}}` |
| 朝ダイジェスト | 環境変数 `AGENT_DIGEST_HOUR`（デフォルト 7）時以降のその日最初のサイクル |
| 提案ストック上限 | {{PROPOSAL_CAP}} 件 |
| Review Queue Project | {{REVIEW_QUEUE}}（`<owner>/<番号>` 形式。`なし` なら連携をスキップ） |

## 大原則（全モード共通・違反禁止）

1. **1サイクル1仕事**。複数の issue / PR を1サイクルで扱わない。
2. **{{MAIN_BRANCH}} へのマージ・直接 push・コミットは絶対にしない**（push は permission deny ルールと pre-push フックで封鎖済み。マージは人間の仕事）。ループが main チェックアウトで行ってよいのは `.agent-loop/` 配下（git 管理外）への追記だけ。ループが main を動かすと origin と恒常的に分岐し、人間のマージ作業が再生産されるため。
3. **完了・合格の宣言には必ず証拠を付ける**。実行したコマンドと exit code・出力の要約をターン内に表示してから宣言する。自己申告のみの「完了」は禁止。
4. サイクル冒頭で `.agent-loop/GUARDRAILS.md` が存在すれば読む。サイクル中に得た教訓（踏んだ地雷・回避策）があれば1行追記し、**同じ内容を GUARDRAILS バックアップ issue（タイトル「GUARDRAILS: ループの教訓集」）にもコメントする**（ローカルファイルは git 管理外のため、耐久コピーは GitHub 側に置く）。
5. サイクル終了時に `.agent-loop/log.md` に実行ログを1行追記する（形式は末尾）。コミットはしない。サイクル結果の正式な記録は issue / PR へのコメントであり、ローカルのログは朝ダイジェスト集計用のキャッシュにすぎない。
6. 実装前に必ず codebase を grep して既存実装を確認する。「未実装」と決めつけて二重実装しない。
7. プレースホルダ・空実装・コンパイルを通すだけの実装で済ませない。

## コンテキスト管理（ディスパッチャ方式）

ループセッション（メイン）のコンテキストはサイクルを跨いで蓄積するため、メインは**配車係に徹する**。

1. メインが自分で行うのは: レートガード（Step 0）、朝ダイジェスト（Step 0.5）、対象選定（Step 0.9 の選定スクリプト実行。目視でモード・対象を選ばない）、サブエージェントへの委譲、ログ追記、結果報告のみ。
2. 各モードの作業本体（Step 1 のレビュー、Step 2 の修正、Step 4 の調査・起票文案）は**サブエージェントに委譲**し、毎回まっさらなコンテキストで実行させる。メイン自身でファイルを読み込んで作業しない。Step 3（実装）だけは委譲対象に含めない — メインが `dev-workflow` の develop スキルの本体（オーケストレータ）として W / R1 を spawn する（サブエージェントは Agent ツールを持たず W / R1 を起こせないため。Step 3 参照）。メインがやるのは spawn と return の転記だけで、作業の詳細は W / R1 側に閉じる。
3. サブエージェントへ渡すもの: 本憲法ファイルのパス（該当 Step を読んで従うよう指示）、対象の issue / PR 番号、`.agent-loop/GUARDRAILS.md` のパス。
4. サブエージェントから受け取るもの: 結果サマリ（実行したコマンドと exit code の証拠、作成した PR / コメントの URL を含む）。メインはそれをログと報告に転記する。
5. 作業中の詳細（ファイル内容・テスト出力・試行錯誤）はサブエージェント側に閉じ、サイクル終了とともに破棄される。長期稼働でメインのコンテキストが自動要約されても、状態はすべて外部（ラベル・issue / PR コメント・`.agent-loop/`）にあるため失われて困る記憶はない。

## ラベル定義

| ラベル | 対象 | 意味 |
|---|---|---|
| `agent-ready` | issue | 人間が承認済み。ループが拾ってよい |
| `agent-proposed` | issue | ループの自己生成タスク案。人間が `agent-ready` に昇格するまで実行禁止 |
| `agent-wip` | issue | ループが着手中（二重着手防止） |
| `agent-blocked` | issue | 2回失敗して隔離。人間の判断待ち |
| `needs-approval` | issue | 準備までは可、実行に人間の承認が必要 |
| `human-only` | issue | ループは触らない（秘密情報・外部アカウント・設計判断など） |
| `size:large` | issue | 1サイクルに収まらない大型。着手せず分割提案のみ |
| `agent-review:pending` | PR | 実装済み・レビューエージェント待ち |
| `agent-review:passed` | PR | レビュー合格。人間はマージ判断のみでよい |
| `agent-review:failed` | PR | レビュー不合格。修正モードの対象 |

## needs-approval の解除判定（3軸ゲート）

`needs-approval` は「人間の承認待ち」を意味するが、その承認が**本当に人間にしか下せないものか**は issue ごとに違う。
承認が形式だけのものまで人間に溜めると、ボードが詰まって承認の意味が薄れる。そこで**次の3軸すべてを満たす issue に限り、
ループが自分で `agent-ready` へ昇格させてよい**。1つでも欠ければ `needs-approval` のまま残す。

| 軸 | 問い | 不合格の例 |
|---|---|---|
| ① 止められるか | 成果物が **PR の diff** として現れ、人間がマージ前に止められるか | 成果物が実行そのもの（本番デプロイ、DB マイグレーション、外部 API の副作用、通知の送信） |
| ② 決められるか | **人間の判断が要る論点がない**か | 複数の方針から1つを選ぶ／仕様が未定／受け入れ条件に「人間の承認コメント」が含まれる |
| ③ 取り消せるか | 実行結果を**元に戻せる**か | 本番 DB、課金、外部への公開・送信、削除、取得済み資格情報の失効 |

**②と③は独立している。** 「やることは決まっている（②合格）が不可逆（③不合格）」は実在する
——本番 DB マイグレーションが典型で、手順に迷いは無いが撃てば戻せない。②だけで判定すると素通りする。
逆に「PR にならない（①不合格）が可逆（③合格）」もある——設定ファイルの書き換えやチャンネルの購読設定など。
この場合①が欠けても②③が揃えば昇格してよい: **止める機会が無くても、間違えたら戻せるなら実害が残らない**。

したがって判定は次のとおり:

- **③が不合格 → 昇格しない**（無条件。可逆性は他の軸で埋め合わせできない）
- **②が不合格 → 昇格しない**（人間の判断を代行しない）
- ①のみ不合格で②③が合格 → **昇格してよい**

**依存は3軸とは別軸で先に弾く。** open な blocking issue（`gh api repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by`）が
1件でもあれば、3軸の結果に関わらず昇格しない。承認の問題ではなく、着手しても完成しないため。

昇格するときは issue に**3軸それぞれの判定と根拠を1行ずつコメントしてから**ラベルを付け替える
（大原則3「宣言には証拠を付ける」の適用）。昇格しなかった場合も、どの軸で落ちたか・人間が何を決めれば通るかを
コメントする。人間はそのコメントだけ読めば承認判断ができる。

**`human-only` はこのゲートの対象外**。3軸を満たしても昇格しない。

## Review Queue 連携（プロジェクト横断レビューボード）

Review Queue Project が `なし` 以外なら、**人間の対応を待っているもの**（PR と issue の両方）をユーザーレベルの
GitHub Project に反映する。人間はこのボード1枚で全リポジトリの「マージ判断待ち PR」「トリアージ待ち issue」
「隔離された issue」を横断で捌く。操作はすべて決定論的な `gh` コマンドで行う。

`State`（単一選択フィールド）はラベルと1対1で対応させる。**ラベルを付け替えたら、同じ手順内で必ず State も揃える**:

| 対象 | ラベル | State | 人間の対応 |
|---|---|---|---|
| PR | `agent-review:pending` | レビュー中 | 不要（ループが処理中） |
| PR | `agent-review:failed` | 修正中 | 不要（ループが処理中） |
| PR | `agent-review:passed` | マージ判断 | **マージするか判断** |
| issue | `agent-proposed` / `needs-approval` | トリアージ | **実行を承認するか判断**（`needs-approval` はここに残っている時点で3軸ゲートを通らなかったもの。落ちた軸が issue にコメントされている） |
| issue | `agent-ready`（未着手） | 着手可能 | 不要（ループの実行待ち） |
| issue | `agent-blocked` | 要介入 | **2回失敗の原因を判断** |

**ボード上のドラッグが承認操作になる**: 人間が issue カードを トリアージ → 着手可能 へ動かすと、
次サイクル冒頭の Step 0.8 がラベルを `agent-ready` に同期する。**issue の item は State（ボード）が正、
PR の item はラベルが正**（PR の State はループだけが動かす）。

`Blocked count`（数値フィールド）= その item が塞いでいる後続タスク数。人間が「どれから捌くか」を決める
ソートキーになる（ボードは Blocked count 降順）。算出は **GitHub ネイティブの issue dependencies** を正とする:

```bash
# PR の場合: 対象 issue（Closes #<N> の N）が blocking している open issue 数
# issue の場合: その issue 自身が blocking している open issue 数
BLOCKED=$(gh api repos/<owner>/<repo>/issues/<N>/dependencies/blocking \
  --jq '[.[] | select(.state == "open")] | length')
```

dependencies API がエラーの場合のフォールバック: `#<N>` を本文参照している open な `agent-ready` issue 数
（`gh issue list --state open --label agent-ready --json number,body --jq '[.[] | select(.body | test("#<N>([^0-9]|$)"))] | length'`）。

登録・更新の手順（`<owner>/<番号>` はプロジェクト設定の Review Queue Project の値）:

```bash
PROJECT_ID=$(gh project view <番号> --owner <owner> --format json --jq .id)
# 登録（登録済み URL に対しては既存 item が返るため冪等）
ITEM_ID=$(gh project item-add <番号> --owner <owner> --url <PR/issueのURL> --format json --jq .id)
# field id / option id を取得してから書き込む
gh project field-list <番号> --owner <owner> --format json
gh project item-edit --project-id $PROJECT_ID --id $ITEM_ID \
  --field-id <State_の_field_id> --single-select-option-id <対応する_option_id>
gh project item-edit --project-id $PROJECT_ID --id $ITEM_ID \
  --field-id <Blocked_count_の_field_id> --number $BLOCKED
```

- **item の削除**: 人間の対応が済んで待ちが解消した issue（トリアージ済みで `agent-ready` に昇格した、
  または `agent-blocked` が解除された）は、ループが着手する時点（Step 3 の着手宣言時）に
  `gh project item-delete <番号> --owner <owner> --id $ITEM_ID` でボードから外す。
- **連携の失敗でサイクルを止めない**: `gh project` / dependencies 系コマンドがエラーになっても警告として
  報告するだけにとどめ、本来の仕事（実装・レビュー・修正）は完了させる。
- マージ・クローズされた PR / issue の後片付けは Project 側の built-in workflow（auto-archive）に任せる。

## 状態機械

Step 0〜0.8 は毎サイクル評価する。**Step 0.9 で対象を決定論的に選定し**、その `mode` に一致する Step（応答モード Step 0.9b または Step 1〜4）の**1つだけ**を実行する。

### Step 0: レートガード（実行系によって判定位置が変わる）

レート判定を「サイクル内でやるか、発火前の hook でやるか」は実行系（配線）によって変わる。憲法としては
どちらの実行系でも同じ閾値観（枠の経過率に連動した動的閾値）が適用されることだけを固定し、判定の実装位置は配線側に委ねる。

**標準（flatmate 常駐運転）**: レート判定は配線側の `UserPromptSubmit` rate-guard hook が
`[tick]` プロンプトの**発火前**に行う（SKIP はゼロトークン）。閾値は flatmate 側の環境変数
（`RATE_5H_MAX` / `RATE_5H_HEADROOM` / `RATE_7D_MAX` / `RATE_7D_HEADROOM`、デフォルト 70/20/85/10）が正。
この運転ではサイクル内での判定は不要で、**このステップはスキップされる前提**（hook が SKIP を返したサイクルはそもそも起動しない）。

**フォールバック（単独 /loop 運転・hook なし環境）**: 手元で `/loop` だけで数時間回す場合は発火前 hook が無いため、
サイクル冒頭で従来の判定を実行する。固定閾値ではなく**枠の経過率に連動した動的閾値**で判定する。同じ使用率でも、枠の序盤なら「行き過ぎ」としてスキップし、終盤ならハードキャップまで許容する。

- 判定式: `動的閾値 = min(ハードキャップ, 枠の経過率% + ヘッドルーム)`
  - 枠の経過率 = `(枠の長さ − (resets_at − 現在時刻)) ÷ 枠の長さ × 100`（0〜100 にクランプ。枠の長さ: 5時間枠 = 18000 秒、7日枠 = 604800 秒）
  - 消費ペースが時間経過ペースをヘッドルーム分を超えて上回っていたらスキップ。枠の開始直後はヘッドルームがそのまま下限の閾値になる
  - `resets_at` が無い（null）枠はハードキャップのみで判定する（従来動作へのフォールバック）

1. 以下のコマンドで判定する（決定論的作業のスクリプト化。LLM が暗算しない）。閾値はプレースホルダではなく環境変数
   （`RATE_5H_MAX` / `RATE_5H_HEADROOM` / `RATE_7D_MAX` / `RATE_7D_HEADROOM`、未設定時のデフォルト 70/20/85/10）で解決する:

   ```bash
   jq -r --argjson now "$(date +%s)" \
      --argjson cap5 "${RATE_5H_MAX:-70}"  --argjson head5 "${RATE_5H_HEADROOM:-20}" \
      --argjson cap7 "${RATE_7D_MAX:-85}"  --argjson head7 "${RATE_7D_HEADROOM:-10}" '
     def clamp: if . < 0 then 0 elif . > 100 then 100 else . end;
     def th(resets; win; cap; head):
       if resets == null then cap
       else [cap, ((100 * (win - (resets - $now)) / win) | clamp) + head] | min end;
     . as $s
     | th($s.five_hour_resets_at; 18000; $cap5; $head5) as $t5
     | th($s.seven_day_resets_at; 604800; $cap7; $head7) as $t7
     | "\(if ($s.five_hour_pct > $t5) or ($s.seven_day_pct > $t7) then "SKIP" else "GO" end) 5h=\($s.five_hour_pct)%(閾値\($t5|floor)%) 7d=\($s.seven_day_pct)%(閾値\($t7|floor)%) ts=\($s.ts)"
   ' "$HOME/.claude/.rate-limit-snapshot"
   ```

2. 出力が `SKIP` なら、このサイクルは**何もせずスキップ**し、出力（現在値と動的閾値）と復帰見込み（`*_resets_at`）を報告して終了する。
3. `ts` が現在時刻より2時間以上古い場合は「スナップショットが古い」と明記した上で続行してよい。
4. ファイルが存在しない・jq が失敗する場合はガードなしで続行し、その旨を報告に含める。

### Step 0.5: 朝ダイジェスト（報告のみ・手は止めない）

環境変数 `AGENT_DIGEST_HOUR`（デフォルト 7）時以降のその日最初のサイクルなら、通常のモード実行の**前に**以下を報告する:

- マージ待ち PR（`agent-review:passed`）の件数と最古の経過日数
- トリアージ待ち提案（`agent-proposed`）の件数
- 隔離中 issue（`agent-blocked`）の件数
- 直近1週間のレビュー検出率（レビューした PR のうち failed になった割合。`.agent-loop/log.md` から集計）

「その日最初」の判定は `.agent-loop/log.md` の最終行の日付が今日より前かどうかで行う。

### Step 0.8: Review Queue ボード同期（連携時のみ・毎サイクル）

Project にはフィールド変更のリアルタイム通知が無いため、人間のドラッグ操作を毎サイクル冒頭でラベルへ反映する。

1. `gh project item-list <番号> --owner <owner> --format json` から**このリポジトリの issue item** を抽出する。
2. State とラベルの食い違いを **State に合わせて**解消する:
   - State=着手可能 なのに `agent-proposed` / `needs-approval` / `agent-blocked` が付いている →
     それらを外して `agent-ready` を付け、issue に「Review Queue ボードから承認」とコメントする。
   - State=トリアージ なのに `agent-ready` が付いている → `agent-ready` を外して `agent-proposed` を付ける（承認の取り消し）。
3. 逆方向の反映: このリポジトリの open な `agent-ready` issue（`agent-wip` 無し）でボード未登録のものを
   State=着手可能 で登録する（着手可能列 = 実行待ちキューの一覧を常に完全に保つ）。
4. 同期の失敗はサイクルを止めない（警告のみ報告して次の Step へ進む）。

### Step 0.85: needs-approval の3軸ゲート（毎サイクル・最大1件）

`needs-approval` かつ `human-only` でない open issue を1件だけ選び、「needs-approval の解除判定（3軸ゲート）」に
かけて昇格可否を決める。**1サイクル1件**に絞るのは、ゲートの誤判定が一度に広がるのを防ぐため。

1. 候補を取る（`agent-wip` が付いているものは除く）:

   ```bash
   gh issue list --state open --label needs-approval --json number,labels \
     --jq '[.[] | select([.labels[].name] | (contains(["human-only"]) or contains(["agent-wip"])) | not)] | .[0].number'
   ```

2. 候補が無ければこの Step をスキップする。
3. 依存を先に確認する。1件でも open な blocking issue があれば昇格せず、その旨をコメントして次の Step へ:

   ```bash
   gh api repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by \
     --jq '[.[] | select(.state == "open")] | length'
   ```

4. issue 本文とコメントを読み、3軸それぞれを判定する。**迷ったら昇格しない**（保守側に倒す）。
5. 昇格する場合: 3軸の判定根拠をコメントしてから `needs-approval` を外して `agent-ready` を付け、
   Review Queue の State を「着手可能」に揃える（Step 0.8 と同じ手順）。
6. 昇格しない場合: どの軸で落ちたか・人間が何を決めれば通るかをコメントする。ラベルは変えない。
   **同じ issue に同じ理由のコメントを毎サイクル重ねない**（既存コメントに同趣旨のものがあればスキップする）。
7. このゲートで昇格した issue を、**同じサイクル内で Step 3 の実装対象にはしない**。昇格は次サイクル以降の
   対象選定（Step 0.9）に委ねる。承認と実装を別サイクルに分けることで、誤昇格を人間が挟み込める余地を残す。

### Step 0.9: 対象選定（決定論・LLM は目視で選ばない）

Step 1〜4 の「どのモードで・どの issue/PR 番号を対象にするか」は決定論的なので、**必ず選定スクリプトで決める**。
LLM が `gh` の一覧を目視して対象を選ぶことは禁止する（存在しない番号を対象に捏造する事故を構造的に防ぐため。
レートガード Step 0 を jq に閉じ込めたのと同じ理由）。

```bash
bash scripts/agent-loop-select.sh
```

出力は JSON 1 オブジェクト:

| フィールド | 意味 |
|---|---|
| `mode` | `respond` / `review` / `fix` / `implement` / `propose` / `skip` / `error` |
| `target` | 対象の issue/PR 番号（対象の無いモードは `null`） |
| `target_kind` | `pr` / `issue` / `null` |
| `comment_id` | `respond` モードのみ: 対応完了時に rocket を付ける宛先のコメント ID |
| `candidates` | respond モードは印の付いた issue/PR 番号のリスト。implement モードは実装可能 issue の昇順リスト |
| `reason` | 判定理由（そのまま報告に使う） |

モードの優先順位は **`respond` > `review` > `fix` > `implement` > `propose`/`skip`**。
`respond`（Step 0.9）を最優先に置くのは、人間が印を付けた用件は他のどの自動作業よりも先に
扱うべきだから。判定はラベルを書き換える処理より**前**に行う（印への応答だけをしたい tick で
無関係な issue/PR のラベルが動かないため）。

**絶対ルール**:

1. 実行するモードは `mode` に従う。`mode` が指すもの以外の Step を実行しない。
2. **`target`（および implement の `candidates`）に無い issue/PR 番号を対象にしてはならない。** 一覧を目視で足さない・言い換えない・想像で補わない。
3. `mode:"error"` はガード付きで扱う: `reason` を報告し、そのサイクルは対象作業をせず終了する（`gh`/`jq` の不調を握りつぶさない）。
4. スクリプトの出力（`mode` と `reason`）は最終報告にそのまま含める。
5. `mode:"respond"` の作業を委譲するときは **`comment_id` も必ず渡す**（対応完了時に rocket を付ける宛先。これが無いと同じ用件が毎サイクル再発火する）。

### Step 0.9b: 応答モード — `mode:"respond"`

対象は Step 0.9 の `target`（`target_kind` は `issue` / `pr`）と `comment_id`。目視で選び直さない。

人間が issue / PR にコメントを書いても、ラベルや Review Queue の State が動かなければループは
それを一生拾わない。このモードは人間が付けた**印**を拾って issue 内で応答する。

**判定に投稿者アカウントを使わない。** エージェントには人間の GitHub トークンも渡してあることが
多く、エージェントが人間のアカウントで書き込む運用は普通に起きるため、アカウント名が分かっても
「本当に人間本人が書いたか」は原理的に判別できない。代わりに**本文の印だけ**を見る:

| | |
|---|---|
| **未対応の定義** | コメント本文の**行頭**に `{{AGENT_MENTION}}` があり、**rocket 🚀 リアクションが付いていない** |
| **対応済みの記録** | そのコメントに rocket 🚀 を付ける（**これが唯一の状態**。ローカルの状態ファイルは持たない） |
| **検出** | `scripts/agent-loop-inbox.sh`（決定論・fail-open）。検索 API 1 回 → 対象のコメントだけ取得 |

- **行頭に限る理由（緩めてはならない）**: 単純な部分一致だと、引用返信（`> {{AGENT_MENTION}} …`）や
  **仕組みの説明で言及しただけ**（「`{{AGENT_MENTION}}` マーカーで判定する」等）でも発火し、
  返信が返信を呼ぶ無限ループになる（2026-08-06 実測: 本機能を説明した PR コメントが自分で未対応に入った）。
  行頭限定なら引用行は `>` が、地の文はバッククォート等が先に来るため一致しない。
- **返信は必ず `scripts/agent-loop-reply.sh` 経由で投稿する**（手で `gh api` を叩かない）:

  ```sh
  scripts/agent-loop-reply.sh <番号> <comment_id> <本文ファイル>
  ```

  このスクリプトが (1) 本文の行頭にマーカーが混ざっていないかを**投稿前に**機械検査し、
  (2) 投稿し、(3) 対象コメントに rocket を付けて実測確認する、までを 1 コマンドで行う。
  自己発火防止と「rocket の付け忘れ」を LLM の自己規律に委ねないための機構。
  引用したいときは行頭に `>` を付けるか、バッククォートで囲めば通る。
- 👍 / 👀 は対応済みと見なさない（人が気軽に付けるため、機械の状態には使わない）。
- 除外ラベルは `human-only`（ループは触らない）と `agent-wip`（着手中・二重着手防止）。
  **`agent-blocked` は除外しない**（人間のコメントこそ隔離を解く情報）。`needs-approval` /
  `agent-proposed` / `size:large` も除外しない（「会話してよいか」は「着手してよいか」と別の判断）。

手順:

1. 対象 issue / PR の**コメントだけ**を読む（他の issue を走査しない。全件一覧を引き直さない）。
2. 印の付いたコメントの内容に応答する。答えられない場合は「**何が分かれば進めるか**」を1点に絞って聞く。
   **相手のコメントに同意も反論もせず「承知しました」だけ返すのは禁止**（往復が増えるだけ）。必ず
   「答え」か「1点に絞った質問」か「行った更新の報告」のいずれかを含める。
3. 内容が実装方針・受け入れ条件の変更なら、issue 本文・ラベル・ボード State を憲法の既存手順で更新する。
4. 返信の投稿と「対応済み」化は `scripts/agent-loop-reply.sh <番号> <comment_id> <本文ファイル>` が
   まとめて行う（上記）。**別経路で `gh api` を直に叩かない** — rocket の付け忘れと
   行頭マーカーの混入という、どちらも再発火に直結する 2 つの事故を機械的に塞いでいるため。
5. **エージェント自身が返信本文の行頭に `{{AGENT_MENTION}}` を書いてはならない**（自己発火する）。
   検査は `agent-loop-reply.sh` が機械的に行うが、書かないことが第一の規律。

### Step 1: レビューモード — `mode:"review"`

対象は Step 0.9 の `target`（`target_kind:"pr"`）。目視で選び直さない。

1. PR ブランチを `{{WORKTREE_BASE}}` 配下の worktree に checkout する。
2. **main 追従**: `git fetch origin` → `origin/{{MAIN_BRANCH}}` をブランチにマージする（rebase + force-push は禁止）。
   - コンフリクトが軽微（機械的に解消可能）なら解消して続行し、解消内容を PR コメントに記録する。
   - 解消に実装判断が必要な規模なら `agent-review:failed` に付け替え、理由を PR コメントに書いて終了。
3. 最新化した状態で `{{TEST_CMD}}` / `{{LINT_CMD}}` / `{{BUILD_CMD}}` を**独立に再実行**する（実装エージェントの報告を信用しない）。
4. ブラウザ実機検証が「あり」の場合: `{{DEV_SERVER_CMD}}` で dev サーバーを起動し、元 issue の**受け入れ条件をブラウザ上で再現**する。実装者が想定していない操作経路・エッジケースを最低1つ試す。
5. ソースコードレビュー: 受け入れ条件を根拠に「落とせる欠陥を探す」姿勢で diff を読む（正しさ・エッジケース・既存コードとの整合）。実装者がやったことの追認ではなく、やっていない角度を突く。
6. 判定を PR コメントに書き、ラベルを付け替える:
   - 合格 → `agent-review:passed`（検証ログ・実機確認の内容を添える）
   - 不合格 → `agent-review:failed`（欠陥の再現手順と修正すべき点を具体的に書く）
7. Review Queue 連携（該当時）: 付け替え後のラベルに合わせて State を更新し、Blocked count を再計算する（「Review Queue 連携」参照）。
8. 更新したブランチは push する（feature ブランチへの push は許可されている）。

### Step 1.5: passed の鮮度チェック

`agent-review:passed` の PR のうち、`origin/{{MAIN_BRANCH}}` との間でコンフリクトが発生しているものがあれば、`agent-review:pending` に戻して次サイクル以降で再レビューさせる（Review Queue 連携時は State も レビュー中 に戻す）。これにより「passed = 今すぐコンフリクトなしでマージでき、直近の main で動作確認済み」が常に保たれる。

### Step 2: 修正モード — `mode:"fix"`

対象は Step 0.9 の `target`（`target_kind:"pr"`）。その PR ブランチの worktree でレビューコメントの指摘を修正する。

1. 修正後、`{{TEST_CMD}}` / `{{LINT_CMD}}` を実行し、証拠をターン内に表示する。
2. push して PR コメントに対応内容を書き、`agent-review:pending` に戻す（Review Queue 連携時は State も レビュー中 に戻す）。
3. 同一 PR で failed が2回付いたら、それ以上触らず PR コメントに経緯をまとめ、元 issue を `agent-blocked` にして人間へ引き渡す（Review Queue 連携時は元 issue を State=要介入 で登録し、PR の item は削除する）。

### Step 3: 実装モード — `mode:"implement"`

対象は Step 0.9 の `target`（＝ `candidates` の最小番号）。`candidates` は「open ∧ `agent-ready` ∧ ¬(`agent-wip`/`agent-blocked`/`size:large`) ∧ open PR 未紐付け ∧ open issue に blocked_by されていない」を満たす issue の昇順リストで、選定スクリプトが `gh pr list --search "<番号> in:body"` と `gh api .../dependencies/blocked_by` まで含めて算出済み。**この `candidates` に無い番号を対象にしない。**

1. 受け入れ条件が測定可能な形で書かれていない issue は拾わない。不足点を issue コメントで指摘し、**`candidates` の次の番号**へ（候補が尽きたら Step 4 = 提案モードへ）。
2. 着手宣言: `agent-wip` ラベルを付け、着手コメントを残す。Review Queue 連携（該当時）: この issue がボードに載っていれば（着手可能 など）item を削除する（着手した issue は実行待ちキューから消す）。
3. **開発の中身は `dev-workflow` プラグインの `develop` スキルに委譲する** — ただしサブエージェントに Skill ツールで起動させるのではなく、**メインが develop の本体（オーケストレータ）として W / R1 を `--unmanned` で spawn する**（`develop/SKILL.md` を Read し、対象 issue 番号・下で用意した worktree・`{{MAIN_BRANCH}}` を W に渡す。1 ループの (0)〜(3) を回し、(4) の G は起こさず Step 1（レビューモード）に委ねる）。W / R1 が以下を判定・実行する:
   - worktree はメインが用意して W に渡す（`{{WORKTREE_BASE}}` 配下、ブランチ名 `agent/issue-<番号>-<slug>`、起点は `origin/{{MAIN_BRANCH}}`。wt-setup は worktree プラグインの hooks が担う。W は自分で worktree を切らない）
   - 仕様として残すべき変更なら opsx（openspec）フロー、そうでなければコード直行
   - 仕様化判断を `仕様化判断: する|しない` の書式で issue に記録し、仕様化する場合は W の `/opsx:ff` の後に R1 が別コンテキストで仕様レビューし、APPROVE が記録されるまで実装に入らない（unmanned でも免除しない）
   - **単一 change で完結する場合**: W がそのまま TDD で実装する（テストを先に書く。大原則 6・7 を遵守）
   - **複数 change に割れる場合**: change 単位でサブ issue を作成し `blocked_by` で順序を付け、各サブ issue に `agent-ready` を付ける（親 issue の承認は既に済んでいるため個別承認は不要）。元 issue には分割結果（#a → #b → #c）をコメントし `agent-wip` を外して**このサイクルはここで終了**（次サイクル以降が各サブ issue を1つずつ拾い、それぞれ本 Step から同じスキルを通す）
   - **仕様化・分割の判断がつかないほど曖昧な場合**: Discord でユーザーに質問を送り、`agent-wip` を外して `needs-approval` を付け、経緯を issue にコメントしてこのサイクルは終了する（返信が来たら次サイクル以降で再開する）
4. （単一 change で実装まで完了した場合）`{{TEST_CMD}}` / `{{LINT_CMD}}` / `{{BUILD_CMD}}` を実行し、証拠をターン内に表示する。
5. 通ったら W が push して **Draft PR** を作成する（1 ループの (3) に含まれる）。本文は loops プラグインの `references/pr-body-format.md` の型（5 セクション + `Closes #<番号>` + 検証ログの折りたたみ。小変更は軽量モード可）に従って書き、`agent-review:pending` ラベルを付ける。Review Queue 連携（該当時）: PR を Project に登録し、State を レビュー中 に、Blocked count を算出して設定する（「Review Queue 連携」参照）。
6. issue に PR の URL と要約をコメントし、`agent-wip` と **`agent-ready` の両方を外す**（PR が open な間に別サイクルが同じ issue を再実装しないため。マージされれば `Closes` で自動クローズされ、PR がマージされずクローズされた場合は人間が再トリアージして `agent-ready` を付け直す）。
7. 行き詰まったら: worktree は残し、issue に失敗ログをコメントする。同一 issue の失敗コメントが2件になったら `agent-blocked` に切り替えて以後拾わない（Review Queue 連携時は State=要介入 で登録する）。教訓を `.agent-loop/GUARDRAILS.md` に追記する（大原則 4 のミラーも忘れずに）。

`size:large` ラベルは、develop の W が分割の是非すら判断できないほど曖昧なケースで、分割の方向性自体を人間の設計判断に委ねたい場合にのみ使う（着手中止・分割案をコメントするだけで、ラベルも人間が手動で付ける）。通常の複数 change 分割は上記 3. のサブ issue 化でループが自動処理するため、`size:large` を自動付与することはない。

#### 昇格トリップワイヤー（Step 3 の全経路に常時適用）

作業中に以下のいずれかを踏んだら、その場で手を止めて乗り換える。「あと少しで終わるから」は乗り換えない理由にならない。乗り換え・昇格の際、ここまでの成果（編集済みファイル・通ったテスト・判明した事実）は破棄せず引き継ぐ。閾値は初期値であり運用調整してよい（設計意図の詳細は dev-workflow プラグインの `templates/escalation-tripwires.md` を参照）。

1. **規模超過**: 編集対象ファイルが5個を超えた、または着手前の見積もりから作業項目が2回増えた → W は手を止めて本体（憲法のメイン）に return し、develop スキルの判定に従ってサブ issue 分割（上記 3.）に乗り換える。
2. **失敗ループ**: 同じテストが2連続で落ちた、または同じ箇所を2回書き直した → W は本体に return し、本体が W を1段昇格したモデルで再開する（Sonnet → Opus → Fable）。`FABLE_BUDGET_MODE=reserve` のときは **Opus を上限**とし、Opus でも2連続失敗が続く場合は `agent-blocked` ではなく `needs-approval` を付けて経緯をコメントし、このサイクルを終了する（Fable なら解けるかもしれない問題を人間が判断すべき状態のため）。既存の「失敗コメント2件 → `agent-blocked`」（上記 7.）はサイクル横断のセーフティネットとしてそのまま生きる。
3. **仕様の発明**: issue に書かれていない仕様上の決定を自分で埋めた回数が2回に達した → 埋めた決定を列挙して Discord でユーザーに質問し、`agent-wip` を外して `needs-approval` を付け、経緯を issue にコメントしてこのサイクルを終了する（上記 3. の曖昧ケースと同じ経路）。

**環境変数の前提**（RATE_* と同じく配線側が実行時に設定する。install ではヒアリングしない）:

- `LONGRUN_AUTOMATED=1` — 無人セッションであることの宣言。longrun の reserve 降格（`references/model-tiers.md`）がこれを参照する
- `FABLE_BUDGET_MODE` — 残量モード（`abundant` / `conserve` / `reserve` / `exhausted`。未設定 = usage snapshot からの自動導出、無ければ `conserve`）。定義は dev-workflow の develop スキル `references/decision-criteria.md`

### Step 4: 提案モード / スキップ — `mode:"propose"` / `mode:"skip"`

提案ストックの上限（{{PROPOSAL_CAP}} 件）判定は選定スクリプトが済ませており、`mode` に反映されている。

1. `mode:"skip"` の場合（未トリアージ提案が上限以上）: **新規起票せず**、`reason` を報告して終了する（承認待ちを溜めてラバースタンプ化させないため）。
2. `mode:"propose"` の場合（提案枠に空きがある）: コードベース・既存 issue・`.agent-loop/GUARDRAILS.md`・直近のログを調査し、価値のあるタスク案を**最大2件**、`agent-proposed` ラベルで起票する。各案には測定可能な受け入れ条件と、触るファイル・関数の見当を必ず書く。既存 issue との依存関係が明確なら、ネイティブの dependencies も張る（`gh api -X POST repos/<owner>/<repo>/issues/<後続>/dependencies/blocked_by -F issue_id=<前提のissue id>`）。Review Queue 連携（該当時）: 起票した issue を State=トリアージ で登録し、Blocked count を設定する。
3. **起票のみで終了する。実行しない。** 人間が `agent-ready` に昇格させるまで待つ。

## 実行ログ形式（.agent-loop/log.md）

`.agent-loop/` は git 管理外（.gitignore 対象）。ファイルが無ければテーブルヘッダごと作成する。
サイクルごとに1行、テーブルに追記する:

```
| 日時 | モード | 対象 | 結果 | 備考 |
|---|---|---|---|---|
| 2026-01-01 09:00 | review | PR #12 | passed | ブラウザ検証OK |
| 2026-01-01 10:00 | implement | #15 | PR #18 作成 | テスト 34 passed |
| 2026-01-01 11:00 | skip | - | rate guard | 5h 45%（閾値 38%） |
```

このログはレビュー段階の効果測定に使う。**レビュー検出率（failed / レビュー総数）が数週間ほぼ 0% なら、レビューモードの廃止を人間に提案すること。**
