# Spec Delta

## ADDED Requirements

### Requirement: develop の開始はセッションの役割によらず idle compaction を切る
Claude Code で develop を開始する本体は、役割別工程や返事待ちより前に、現在の worktree の `.claude/settings.local.json` の idleCompaction を boolean false にしなければならない（MUST）。親・子・単発、interactive・unmanned によってこの方針を分岐しない。ホームの settings.json・共有設定・通常の自動 compact を止める設定は変えてはならない（MUST NOT）。子の既存の起動オプションは維持する。委譲先 Codex worker に Claude の実設定を変更させない。

#### Scenario: 親と子と単発で同じ入口を使う
- **WHEN** 親エピック、別セッションの子、単発 interactive のそれぞれで develop を開始する
- **THEN** SKILL.md の同じ入口で local 設定を確認・適用し、親か子かの判定で適用を省略しない
- **AND** 新セッションでの引き継ぎや compact 後の再読でも同じ確認を行い、既に false なら何も書かない

#### Scenario: 通常の自動 compact の指定を維持する
- **WHEN** 開始時の設定・子の起動コマンドの差分を調べる
- **THEN** DISABLE_AUTO_COMPACT など通常の自動 compact を止める指定を追加せず、既存の compact 後の手順書再読み込み hook を残す

### Requirement: idle compaction の設定操作は既存設定と承認規則を保つ
設定部品は check と apply を分け、既存 JSON object の idleCompaction 以外の値を保たなければならない（MUST）。false 済みは無変更とする。apply は対象 worktree と単一キーの変更に既存の明示承認があると本体が確認してから実行し、無ければ具体的な差分を示して既存の承認経路に戻す（MUST）。権限・hooks を変えて承認を迂回してはならない（MUST NOT）。設定は worktree 内に残り、他セッションにも効くことと戻し方を案内する。

#### Scenario: 他キーを保持し false 済みを変更しない
- **WHEN** permissions、hooks、任意の未知キーを持つ正常な設定に apply する
- **THEN** idleCompaction だけが false となり、他キーの値が保存される
- **AND** 再適用では内容と mtime が変わらず、ホームや共有設定に書き込みが無い

#### Scenario: 書き込み承認が無い
- **WHEN** check が false 未設定を返し、対象 worktree の当該キーの書き込みに既存の明示承認が無い
- **THEN** 本体は apply を行わず、差分を示して承認を待つ。既に同じ操作を承認済みなら聞き直さない

#### Scenario: 新規ファイルを承認後に作る
- **WHEN** local 設定が無く、対象と差分に承認がある
- **THEN** apply は idleCompaction false だけの JSON object を作り、共有設定やユーザー設定を複製しない

### Requirement: idle compaction の設定を確かめられなければ成功にしない
設定部品は、読めない・壊れた・object でない・重複キーのある JSON、不正な worktree、対象への symlink を検出したら書かず exit 1 にしなければならない（MUST）。check は disk 上で false なら exit 0、false への変更が必要なら exit 2 とする（MUST）。本体は disk 上の成功だけで live 反映を断定せず、反映しなければ記録から新セッションで再確認し、それでも off でなければ開始を止める（MUST）。

#### Scenario: 不正な入力を上書きしない
- **WHEN** 壊れた JSON、配列、重複キー、読めないファイル、worktree でないパス、.claude または settings.local.json の symlink を渡す
- **THEN** exit 1 で対象パスと原因を出し、設定全体を出さず、ファイルとリンク先を変更しない

#### Scenario: ファイルが false でも反映していない
- **WHEN** disk 上は false だが、実機の /config では Idle compaction が on のままである
- **THEN** live 反映済みとは報告せず、issue の記録から同じ worktree の新セッションで再確認する。再起動でも off を確認できなければ開始を止めて報告する

この検査の入力元は利用者の worktree の通常の設定ファイルとパスである。拾う誤りは設定破損・他キー消失・別パスへの書き込み・未反映を成功と呼ぶこと。未知の正常な設定キーや同じ worktree の別セッションへの設定の持続は通してよい。同時書き換えの完全な排他、悪意あるファイル差し替え、将来の Claude 設定形式のすべてを防ぐ検査ではない。穴を塞ぎ切ることを完了条件にしない。

### Requirement: idle compaction 無効化の実機結果はマージ後に記録する
実装担当は #1385 に実機チェックリストを残し、主はマージ・plugin 更新後の最初の親・子で設定が off になる手順と結果を記録しなければならない（MUST）。idle の対象となる会話量、スリープなし、リクエストなしで 60 分以上の待機区間を親・子それぞれ観測し、新しい compact_boundary が無いことを記録する（MUST）。通常の上限近くでの自動 compact の発生は別区間で確認する。完了前は未検証とし、Bats の合格を代用にしない。

#### Scenario: 有効な待機観測を記録する
- **WHEN** 主が更新済み plugin の親・子を各 60 分以上待機させる
- **THEN** 版、commit、off の確認方法・結果、会話量と適用中の idle 閾値、最後のリクエスト時刻、観測開始位置、経過秒、スリープ・追加リクエスト無し、新規 compact_boundary が 0 件である結果を #1385 にコメントする
- **AND** 単発の設定確認結果、親の live 反映または再起動の要否も記録する

#### Scenario: 観測条件不足は未検証とする
- **WHEN** 待機中に PC が寝た、会話量が idle の対象に達していない、API リクエストや別種の compact が発生した、または off を確かめていない
- **THEN** 印が無くても合格にせず未検証としてやり直す。ログの文章中に含む compact_boundary という単語をイベントとして数えない

#### Scenario: 通常の自動 compact を別に確認する
- **WHEN** 主が別区間で会話の上限近くに達した通常利用を観測する
- **THEN** 自動 compact が発生し、既存 hook が develop の手順書再読み込みを案内する結果を記録する

## MODIFIED Requirements

### Requirement: 時間がたった子への返事は 60 分を境にそのまま送るか起動し直すかを決める
時間がたった子・親への返事の規則は `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` に置き、子について次を書かなければならない（MUST）: すべての develop セッションは開始時の worktree-local 設定でアイドル時のコンパクトを切り、子は補助として `launch` が `--settings '{"idleCompaction":false}'` を付けてアイドル時のコンパクトを切ること（そのプロセスだけに効き通常の自動コンパクトは止めない・v2.1.290 以降が要る・ホームの `~/.claude/settings.json` に置かない（worktree の `.claude/settings.local.json` だけを使う））。子の表は上から、端末が無ければ起動し直す、会話量 N が `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS`（既定 150000）以上なら経過時間と compact の有無によらず起動し直す、最後のリクエストから 60 分未満ならそのまま送る、60 分以上なら compact の有無と会話量によらず起動し直す、と書く。会話量条件が時間条件に優先するよう並べる。根拠は、コンパクトされた子は `SKILL.md` の中身を持たずに進むことと、費用の差の小ささ。

#### Scenario: 規則のファイルに子の切り方と分ける条件と根拠が書かれている
- **WHEN** `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` を読む
- **THEN** 子は `launch` が `--settings '{"idleCompaction":false}'` を付けてアイドル時のコンパクトを切ること、ホームの `~/.claude/settings.json` に置かず、worktree の `.claude/settings.local.json` だけを使うこと、子は端末が無い・会話量が新閾値以上・60 分以上のいずれかなら起動し直し、会話量が閾値未満か不明で 60 分未満ならそのまま送ること、新閾値の変数名と既定値 150000、子を起動し直す根拠（コンパクトされた子は `SKILL.md` の中身を持たない）と #1039 の決定を #1323 で覆したこと、判定に使う事実（端末の有無は `epic-dispatch.sh reply` が確かめること・最後のリクエストの時刻はトランスクリプトから読むこと・会話量は同じファイルを `subagent-context.sh --file` で測ること）が書かれている

根拠には、2026-10-23 の子のログで、コンパクトのあとに残ったのが `SKILL.md` のファイル名と `/develop` の入口だけで、再開したあとも読み直さずにゲートの実行まで進んでいたことと、起動し直しとの費用の差（1 回あたり Opus 5.5 で約 $0.5）、1 時間以上たってから返事が来る子の割合（3.2%）を書く（SHALL）。判定に使う事実は、子の端末の有無（`orca` のコマンドは書かず、要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」に従う。端末の有無は `epic-dispatch.sh reply` が確かめ、端末が無ければ起動し直す。要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」）と、子のセッションのトランスクリプト（`~/.claude/projects/` 配下の jsonl）の最後のリクエストの時刻、および同じファイルを `plugins/dev-workflow/scripts/subagent-context.sh --file <トランスクリプト>` で測った会話量 N である。事実を読めない場合は、上の自動判定の要件と同じく確認できた条件だけで決め、どちらも真と確認できなければそのまま送ると書く（MUST）。送り方と起動し直し方の手順本体はこのファイルに書かない（SHALL NOT。止まった子を親が解決する手順（develop の `references/epic.md` の Orca 経路と `epic-dispatch.sh reply`）が書き、このファイルを参照する）。

この分類は、`epic-dispatch.sh wait --resolve` が親の代わりに通す返事を除き、スクリプトではなく本体が規則のファイルを読んで行う。`wait --resolve` が通す返事は、要件「wait --resolve は通す返事を送る前に起動し直すかを表で決める」のとおり `resolve_stopped` が同じ子の表で分類する（例外）。拾いたい誤りは、60 分以上止まった子（コンパクトされて `SKILL.md` の中身を持たない子と、この変更より前に起動されてコンパクトされうる子を含む）にそのまま返事を送り、子が手順を外れて進むこと、大きい会話の子に時間だけを見て返事を送り続けること、会話量が閾値未満か不明で 60 分未満の子を不要に起動し直して、子が積んだ判断と起動し直しの費用を無駄にすることである。次は通してよく、この分類では止めない: 経過時間がちょうど 60 分前後で、時刻の読み方によって扱いが分かれる子／トランスクリプトが複数あってどれが子のセッションか分からず、そのまま送った子。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

#### Scenario: 子の会話量の行が短時間の行に優先する
- **WHEN** 子の表を上から読む
- **THEN** 端末が無い行の次で、`EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS` と既定値 150000 が明記された会話量の行により、60 分未満でも閾値以上なら起動し直すと分かる

#### Scenario: 閾値を選んだ根拠と限りが分かる
- **WHEN** 規則のファイルの子の説明を読む
- **THEN** #1046 の再集計の結論に合わせて 150000 を採用したことと、その集計はキャッシュ有効中の新条件の最適値を実証したものではないこと、時間条件は #1323 のまま残ることが書かれている

### Requirement: 親が長く待ったあとは親の表で続けるか起動し直すかを決める
`plugins/dev-workflow/skills/develop/references/reply-after-idle.md` は、親も子・単発と同じくアイドル時のコンパクトを切ること、親が最後のリクエストから 60 分以上待ったら compact の有無や会話量によらずエピックの記録から起動し直すこと、60 分未満なら続けることを規定しなければならない（MUST）。親だけの 120,000 の設定・compact 後なら続ける分岐・監視が続くから残す説明は現行の規則に残さない（MUST NOT）。

#### Scenario: 規則のファイルに親の値と表と復元元が書かれている
- **WHEN** 規則のファイルを読む
- **THEN** 親にも idleCompaction false を適用し、60 分未満は続け、60 分以上は起動し直すと分かり、compact や N による継続の例外・親だけの閾値が無い
- **AND** 回し方、終わった子、外した子エピック、残した worktree、親が通した判断、主の返事待ち、残りの子の復元元が記録されている

親の状態はエピックと子 issue のコメント・依存グラフ・子の状態記録から復元できると書く（SHALL）。`回し方:`、`子 #N マージ → 残り k 件` / `子 #N 見送り`、`後で別に起動するエピック:`、`子 #N のワークツリーを残した`、`親の判断: 子 #N 通した` と停止記録 URL の対応、`pending-owner` の確認を残す。比較する相手は手順書と引き継ぎを読む新セッションであり、要約と手順書再読み込みを二重に払う親の方針を #1385 で覆したと書く（SHALL）。監視停止が compact のせいだったとは断定しない。古い集計のリンクは履歴として残せるが、親の idle 閾値の再集計を現行の宿題にしない。

この規則の入力は、親のトランスクリプトの最後のリクエスト時刻と、エピックの復元記録である。拾う誤りは、compact 済み・会話量が小さいことを理由に 60 分以上止まった親を続けること。境界の時刻が曖昧で 60 分前後の扱いが揺れる場合は続けてよく、時刻不明から長時間経過を捏造しない。復元元の記録自体の誤りや欠落はこの時間分類だけでは防がない。穴の追加封鎖を完了条件にしない。

#### Scenario: 親が compact 済みでも長く待ったら起動し直す
- **WHEN** 親の最後のリクエストから 60 分以上たち、compact_boundary がある場合と無い場合を比較する
- **THEN** どちらも会話量によらず起動し直し、エピックのコメントから親が通した判断を含め復元する

#### Scenario: 短時間の親は続ける
- **WHEN** 親の最後のリクエストから 60 分未満である
- **THEN** 親はそのまま続け、この規則を理由に短い wait のやり直しを止めない

### Requirement: epic.md の回し方は子の起動コマンドの指定と返事の規則のファイルを指す
`references/epic.md` の回し方は、すべての develop セッションが開始時に worktree-local の idleCompaction を false にすること、子は既存の起動オプションでも切ること、時間がたった子・親は `references/reply-after-idle.md` に従うことを書かなければならない（MUST）。親だけの閾値の付け方を案内してはならない（MUST NOT）。子の起動コマンドの `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` や `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` も案内しない。対応する Bats はこの記述を確かめる（MUST）。

#### Scenario: epic.md の回し方が起動コマンドの指定と規則のファイルを指す
- **WHEN** references/epic.md の回し方を読む
- **THEN** 親・子を分けない開始時の設定と、子の --settings '{"idleCompaction":false}'、長時間待機後の共通方針が分かり、親だけの閾値の付け方を参照していない

この要件は、要件「エピックの条件・作り方・回し方・完了条件を規定する」の回し方の段落のうち、epic-dispatch.sh が足すのは --model だけとする部分に優先する（足すのは --settings '{"idleCompaction":false}' と --model）。既存の子の起動・返事の動作は変えない。
