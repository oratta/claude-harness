# Design

## Context

動機は proposal.md の Why を参照。今の子の起動コマンドは `EPIC_DISPATCH_PARENT_EPIC=<epic> CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=<値> <cmd> --model '<model>'` で、`<値>` は `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS`（既定 120000）。起動コマンドは `epic-dispatch.sh` の `agent_setup` が 1 か所で組み立て、`launch`・`reply`（端末が無い子の起動し直しと `--relaunch`）・`wait --resolve` が共用する。起動部品（Orca・tmux）はこの文字列をそのまま端末に打ち込む。

`wait --resolve` の起動し直しの判定（`decide_relaunch`）は、今の `reply-after-idle.md` の表をそのまま実装している（60 分以上・コンパクトなし・会話量 150,000 以上で起動し直す）。

主の起動コマンド `cld` は、`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` が未設定なら 120000 を入れてから、残りの引数を `"$@"` でそのまま `claude` に渡す。

### 設定キーの確かめ（2026-10-26、Claude Code 2.1.310）

手元の本体を `strings` で読んで確かめた（記録: https://github.com/oratta/claude-harness/issues/1323#issuecomment-6409563111 ）。

- 設定の型定義に `idleCompaction`（boolean・省略可）があり、説明は「Set to false to stop Claude Code from compacting a long conversation while the session is idle. Setting it to true does not turn idle compaction on.」
- アイドル時のコンパクトの発火判定は、`autoCompactEnabled` を見たあとに別に `idleCompaction` を見て、false なら `idle_compaction_off` で止まる。通常の自動コンパクトの判定は `idleCompaction` を見ない
- 設定は userSettings → projectSettings → localSettings → flagSettings → policySettings の順に重ねて後ろが勝つ。`--settings <file-or-json>` は flagSettings で、起動したプロセスだけに効く
- 同梱の変更履歴に「`"idleCompaction": false` in settings.json turns it off. Both need v2.1.290 or later」

## Goals / Non-Goals

**Goals**
- 子のプロセスだけでアイドル時のコンパクトを切り、通常の自動コンパクトは残す
- 子の返事の前の判定（本体が表を読む判定と、`wait --resolve` の判定）を同じ規則にそろえる

**Non-Goals**
- 親（主が起動するセッション）と主の手元のセッションの設定は変えない。親の返事の分け方も変えない
- `scripts/develop-compact-reread.sh`（コンパクトのあとに `SKILL.md` の読み直しを差し込む hook）は変えない。通常の自動コンパクトと親で引き続き要る
- #1324 の範囲（返事待ちの子へのキャッシュ維持の声かけ・親の `wait` の短い待ち直し）には触れない

## Decisions

### 1. 切り方は `--settings '{"idleCompaction":false}'` を起動コマンドに付ける

採る: `<cmd> --settings '{"idleCompaction":false}' --model '<model>'`。JSON は単一引用符で囲んだ固定の文字列で、`--model` の前に置く。

比べた案:
- `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` に十分大きな値（例: 1000000000）を入れる: 環境変数だけで済むが、「切る」ではなく「当たらない閾値」で、意図が読み取りにくい。採らない
- `DISABLE_AUTO_COMPACT=1`: 通常の自動コンパクトまで止まり、子の会話が上限を越えて失敗する。採らない
- 子のワークツリーの `.claude/settings.local.json` に書く: そのワークツリーで開く別のセッション（主が手で開くものを含む）にも効き、ワークツリーに未追跡のファイルが残る。採らない

`--settings` は flagSettings で、起動したプロセスだけに効き `~/.claude/settings.json` を書き換えない。flagSettings は userSettings・projectSettings・localSettings より後ろに重なるので、主の設定に `idleCompaction` があっても子では false が勝つ。

### 2. `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` を子の起動コマンドに付けない

アイドル時のコンパクトを切った子では閾値が意味を持たない。完了条件どおり起動コマンドから外す。主の起動コマンド `cld` は未設定のときに 120000 を入れるので、子のプロセスの環境には `cld` 由来の値が入るが、`idleCompaction` の判定が先に止めるので効かない（`cld` は変えない）。

### 3. `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` は消す

残す案（アイドル時のコンパクトを子で戻すための切り替えに読み替える）は、使う場面が無く、名前と意味が合わなくなる。残すだけの案は「設定したのに効かない」変数になる。消して、設定されていても無視する（値の検査もしない。古い値が環境に残っていて `launch` が止まるほうが害が大きい）。

### 4. 子の表と親の表を分ける

子は「端末が無い → 起動し直す / 60 分未満 → そのまま送る / 60 分以上 → 起動し直す」。親は今の 5 行（端末の行は親に当たらない）のまま、「親への適用」の節に親の表として置く。親を残す理由は、親の監視ツール（`wait`）はコンパクトのあとも動き続けて通知を受けた親はそのまま作業を続けられ、起動し直すと監視が途切れること（#1323 の経緯）。

60 分以上の子は、この変更より前に起動されてコンパクトが走った子でも起動し直す（コンパクトされた子が `SKILL.md` の中身を持たないことは前置きの有無によらない）。

### 5. `wait --resolve` の判定を子の表に合わせ、`EPIC_DISPATCH_RELAUNCH_MIN_TOKENS` を消す

`decide_relaunch` は、トランスクリプトがちょうど 1 本・最後の assistant の時刻が読める・その時刻から `EPIC_DISPATCH_RELAUNCH_IDLE_SEC`（既定 3600）秒以上、のすべてで起動し直す。`compact_boundary` の有無と `subagent-context.sh` による会話量は見なくなる。会話量の閾値の変数は使い道が無くなるので、決定 3 と同じ理由で消して無視する。事実を読めないとき・トランスクリプトが 0 本か 2 本以上のときにそのまま送る扱いは残す（どれが子のものか分からないまま起動し直すと、生きている子の判断を捨てうる）。

### 6. `references/epic.md` の文を直す（`SKILL.md` は直さない）

issue は「SKILL.md の該当する 1 文」を挙げるが、今の `SKILL.md` に子の起動コマンドや返事の前の判定の文は無い（#1219 で `references/epic.md` に移っている）。`references/epic.md` の `nested` の説明（起動コマンドの形）、起動コマンドの説明（閾値の前置きと上書きの変数）、`epic-dispatch.sh` が足す引数の説明（今は「足すのは `--model` だけ」）を直す。

## Risks / Trade-offs

- [Claude Code が v2.1.290 より古いと `idleCompaction` が効かない（未知のキーとして無視されるか、設定の誤りとして警告される）] → 主の手元は 2.1.310。変更の記録と `reply-after-idle.md` に必要な版を書く
- [60 分以上でコンパクト済みの子を起動し直す分だけ費用が増える（1 回あたり約 $0.5、子の 3.2%）] → #1039 の実測の範囲で小さい。手順を守れない費用のほうが大きいと主と決めた（#1323 の経緯）
- [子の会話が大きいまま 1 時間以上止まると、返事のときにキャッシュが切れて書き込み直しになる] → 60 分以上は起動し直すので、そのまま送る経路に乗らない。60 分未満はキャッシュが生きている
- [終わったのに端末が開いたままの子で、アイドル時のコンパクトの費用が無駄になる件（issue-1220・issue-1222）] → コンパクト自体が走らなくなるので無くなる
- [`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` / `EPIC_DISPATCH_RELAUNCH_MIN_TOKENS` を設定していた呼び出し元が黙って無視される] → 変更の記録に書く。手元で設定している箇所は無い（リポジトリ内はテストだけ）

## Migration Plan

マージ後に起動した子から新しい起動コマンドになる。動いている子はそのまま（従来の閾値で動く）。戻すときはこの PR を revert する。マージ後に実機で確かめる方法: 54 分以上止まった子のトランスクリプトに `Compacted while idle` の行（と、そのあとの `compact_boundary`）が出ないこと。子のセッションの `/config` に Idle compaction が off と出るかは確かめていない（表示は機能フラグで出し分けられている）ので、補助の候補にとどめる。
