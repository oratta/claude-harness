# Design

## Context

動機と範囲は proposal.md を参照。現在の途中計測と停止ガードは Bash の前段と Python の対象判定の両方で `agent_id` のない呼び出しを除外する。SessionStart は親用 JSON、`TRIPWIRES_SCOPE=subagent-budget` は呼び出し元が包む本文テキストを出す。Stop には停止ガードが未登録である。git ガードの主は ask を返し得る一方、子は agent_id に結び付く permit を一度使える。

## Goals / Non-Goals

- 既存の計測式・モデル別閾値・二段停止・背景タスクの所有判定を再利用し、独立した役セッションへの適用経路を足す。
- G001 は hook の入出力 fixture で検証する。実機の起動・集計契約は本 change に追加しない。
- マーカーは同一 uid の起動環境にある運用上の識別情報であり、悪意あるプロセスからのセキュリティ境界にはしない。

## Decisions

### 1. 実在する agent_id を優先し、独立セッションだけをマーカーで選ぶ

有効な agent_id は既存どおり「空でない文字列」。これがあれば `DEVELOP_ROLE` を継承していても従来の subagent 経路を使う。それがなく、環境の `DEVELOP_ROLE` が空でなければ役セッションとする。役名の allowlist は作らない。未設定・空の印は従来の主である。payload や command の同名文字列は入力にしない。

代案の agent_id 捏造は permit の権限・背景タスクの帰属・ログ探索を混同するため採らない。マーカーを subagent より優先する案も、将来の継承で既存の子を主ログに向けるため採らない。既存 subagent の ID 検査を通らない値を役経路へ救済しない。

### 2. 途中計測はログの選択だけを分岐させる

`context-tripwire.sh` の前段は印があるとき早期 exit を避ける。Python で対象を選び、既存 subagent は現行の導出・探索、役は payload の `transcript_path` 自身を使う。役のログ欠損時に別ログを探さない。測定後は同じ末尾 256KB・最新 assistant usage の三項合算・model に基づく共通閾値解決・診断・通知 / deny の処理へ合流させる。

役向けに別の計測器・閾値・通知文を作る案は二重管理になるため採らない。cap / hard の厳密な超過比較、Read / Grep / Glob の非拒否、hard 超の全 Bash 拒否、return 宣言・cwd・本体が commit する案内を維持する。欠測や無出力 exit 0 は成功の証拠ではない。

### 3. 役向け本文と SessionStart の配送形式を分ける

`session-tripwires.sh` で本文の scope と出力形式を分ける。明示 `TRIPWIRES_SCOPE=subagent-budget` は最優先で既存の本文テキストを返す。通常呼び出しに `DEVELOP_ROLE` があれば同じ scope の本文を作り、SessionStart の `hookSpecificOutput.additionalContext` に包む。それ以外は既存の親向け経路を保つ。

hooks.json の command を単に `TRIPWIRES_SCOPE=subagent-budget` に置き換える案は、JSON でない本文が役の文脈に届かず、親の挙動も変えるため採らない。役では usage-probe・memory-tripwire・親向けテンプレートを使わず、既存 usage_view の式をそのまま使う。SubagentStart の呼び出し元と matcher は変えない。

### 4. Stop に同じ停止ガードを追加し、役の回数を session ごとに分ける

`hooks/hooks.json` の Stop に `subagent-stop-guard.sh` を追加し、既存の `epic-child-state.sh` を保つ。ガードの前段と対象判定を拡張し、役の所有ログは自身の `transcript_path` だけとする。tool_result 本文の起動 ID と payload の running ID の積集合、TaskStop 案内、MAX_BLOCKS と fail-open を既存処理へ合流させる。`stop_hook_active` は免除に使わない。

役のカウンタは既存ディレクトリの `role-sessions/<session_id>.count` に置く。session_id は既存の空・区切り・`.` / `..` 検査を通す。別 session や subagent のカウンタと混ざらず、役名の変更や同名役の同時起動にも左右されない。削除・見送り・上限到達の規則は既存と同じ。別ガードを作る案は所有判定と上限を重複させるため採らない。

### 5. 役の git は permit を扱う前に拒否する

既存の検出器は維持し、破壊的 git または既存の self-permit / permit-store に当たったマーカー付き役を、主の ask と子の permit 処理に入る前に deny する。子の拒否記録・回数・許可には触れない。役は ID を捏造せず、再実行せず、コマンド全文・対象・必要な理由を本体へ返す。承認を得た操作は主が実行する。

本体指定の「マーカー付き git 経路は常に deny」を、FORCE・NO_ASK・UNATTENDED・permit・`DEV_WORKFLOW_GIT_GUARD=off` より優先させる。既存の off の早期終了は印のない主と既存 subagent に残す。`git-guard-base-write-guard.sh` にも同じ役の選択と off の例外を適用し、既存の正規化・symlink 判定を保つ。役の既知の自己許可経路を通さないためであり、検出範囲の完全封鎖は求めない。

## Risks / Trade-offs

- [既存の主を誤って役とみなす] → 主の起動環境に空でない `DEVELOP_ROLE` が実際に誤継承され、有効な agent_id がなければ、その主も役として扱う。この過剰適用は許容する入力であり、印なし・空・本文中だけの印の対照では検証できない。各 hook の fixture で、主を表す agent_id なしの同一 payload に実際の env 印を付け、自身ログの二段制約・役向け開始 JSON・Stop の所有タスク拒否・git の off より優先する deny へ切り替わることを固定する。対照 fixture の setup では継承 env を明示解除する。印の認証機構・起動スクリプトの追加や誤継承の完全防止は G001 の完了条件にしない。
- [既存の子へ印が継承される] → 同じ実在 agent_id の payload に印あり / なしを与え、ログ選択・permit・出力・回数を比較する。
- [Stop payload に台帳がない版では判定できない] → 既存の fail-open と stderr 診断を保ち、fixture 合格を実機での作動記録とは扱わない。
- [git の明示 off でも役を通せない] → 意図した制限として仕様・テスト・変更記録に明記する。印のない主と既存 subagent は既存の off を維持する。

## Migration Plan

実装は tasks.md の順で回帰テストを追加する。閾値表・注入予算・バージョンは変更せず、G001 の変更記録だけを追加する。配布前の問題は本 change の hook と配線を戻すことで取り消せる。運用中の役から印を外して制約を回避する手順は用意しない。

実装後の検証は対象 Bats、既存 subagent の開始注入、git permit / base 保護、注入予算と OpenSpec strict を含む。実機 `claude -p` は G001 の検証コマンドに含めない。
