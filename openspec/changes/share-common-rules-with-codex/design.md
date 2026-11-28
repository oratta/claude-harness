# Design

## Context

動機と範囲は [proposal.md](proposal.md) を参照する。本 design は [issue #1853 の裁定](https://github.com/oratta/claude-harness/issues/1853#issuecomment-7234163109) を具体化する。仕様化判断「する」と単一 change の分割判定は記録済みであり、裁定の方式を再選択しない。

- `scripts/sync.sh` は公開 rules と許可済み overlay を Claude ホームへリンクする。許可は `harness-overlays` と `.harness-overlay` で判定し、README は除外する。Codex 配布はまだない。
- `codex-worker.py` は選択済み account home の認証リンクと新規 config を持つ runtime を毎回作る。親 config を継承しないため MCP の隔離は保てるが、共通指示と容量設定が入らない。
- `codex-develop.py` には登録ホームの入力検証がある。起動側の登録機構は別 issue の責務で、本 change は同じ表を受け取る側だけを追加する。
- `rules/communication-style.md` は readable の要点版として既に維持されている。新しい意味要約は必要ない。

## Goals / Non-Goals

**Goals:** 公開・許可済み個人 rules の同一正本を指揮役と全 worker role に届け、既存ホーム指示と設定を保持する。生成物の鮮度、指示全体の容量、実機の回答内容を別々に確認できるようにする。

**Non-Goals:** 自動メモリの移植、任意ホームの探索、登録台帳の新設、起動コマンドや hook の追加、#1850 の develop 手順移植、flatmate 側の生成・配置（genetta-inc/flatmate#2160）は行わない。`tests/injection-budget.txt` は変更しない。仕様化工程では実装と実ホームへの書込みを行わず、実装・自動テストも一時ホームで完結させる。

## Decisions

### 1. 正本の全文を機械的に生成する

公開版と許可済み個人版の `rules/*.md` を README を除いて全文連結する。公開ファイル名順、既存同期が採用する overlay の marketplace 名順と各ファイル名順を使い、ロケールや許可ファイルの行順に左右されない生成にする。出典見出しと区切りを付け、readable の要点には `communication-style.md` をそのまま使う。ルールの例外条件を落とさず、一行の正本変更も再生成との比較で検出できることが理由である。

生成・一致検査と配布の共通処理を `scripts/codex-shared-instructions.py` に置き、公開分の生成物を `generated/codex/AGENTS.md` として追跡する。これらのパスとマーカーの綴りは実装の配置であり、追加の仕様上の選択ではない。生成物に手編集を加えず、公開生成は個人 overlay に依存させない。配布時だけ許可された個人ルールを加えてローカルで生成する。許可を外した overlay は次の同期で管理区画から除く。既存リンク先を無差別に走査して許可外本文を拾わない。

別案の手書き短縮版は二重正本と例外の脱落を生む。リンク・案内だけを置く方式や必要時の都度読込は、新規セッションへの供給と容量検査を保証しにくいため採らない。

### 2. 自動メモリを取り込まない

Claude の `~/.claude/projects/*/memory/` は探索・コピー・リンクしない。プロジェクトや住人ごとの記憶を全ホームに混ぜないためである。必要な知識を依頼文や明示された資料で渡すことは妨げない。

別案のプロジェクト照合による自動取込は、新しい記憶の帰属と探索の契約を要し、本 issue の共通 rules 配布を超える。

### 3. 共通最低容量を128 KiBにする

ホームの `project_doc_max_bytes` は131072を最低値にする。未設定または小さい値を更新し、大きい値は維持する。profile 等の容量上書きも確認し、小さい有効値を残して成功にしない。関係する容量キーだけを更新し、認証・MCP・他の設定を保持する。worker runtime は親 config をコピーせず、トップレベルに毎回131072を生成する。

裁定に記録された2026-11-28の UTF-8 実測は以下のとおり。これは容量選択の根拠であり、完成後の生成物の合格証拠ではない。

| 入力 | bytes |
| --- | ---: |
| 公開 rules | 18,201 |
| 個人 rules | 3,910 |
| 既存ホーム指示（7行） | 1,054 |
| harness AGENTS | 4,126 |
| flatmate 共通 CLAUDE | 19,471 |
| ponta の CLAUDE | 26,107 |
| 合計（生成見出し・区切りを含まない） | 72,869 |

生成見出し・区切り・区画外指示まで含めて検査する余裕を128 KiBで確保し、将来の増加は容量テストで検知する。既定32 KiBの維持は現在の入力に不足する。要約による削減は決定1の利点を失い、無制限な拡張は増加の検知を失うため採らない。

### 4. ホーム配布は sync の明示操作に限定する

`scripts/sync.sh --codex` を入口とし、`--no-pull` との併用を可能にする。従来の引数だけでは Codex ホームに書き込まない。対象は `~/.codex`、設定されている現在の `CODEX_HOME`、明示された登録ホームの和集合で、実体パスで重複を除く。

登録表は既存 `codex-develop.py` と同じく、反復する `--account-home NAME=PATH` または `--account-home-file PATH` の平坦な JSON オブジェクトで受ける。併用・重複名（JSON 内も含む）・空/非文字列の名前や値・相対パス・存在しない登録先を拒否する。起動コマンド側がこの表を渡す責任を持つ。本 change は別の登録台帳を作らず、認証情報を手がかりにホームを探索しない。

別案の自動実行は既存利用者のホームを暗黙に変える。ホーム探索や別台帳は登録元と不整合になりうるため採らない。

### 5. 既存 AGENTS と config を保持する

共通区画を `AGENTS.md` の先頭に置く。開始マーカーを `<!-- claude-harness:shared-instructions:start -->`、終了マーカーを `<!-- claude-harness:shared-instructions:end -->` とし、初回は元のバイト列の前に区画を追加、再同期はこの区画だけを置換する。既存7行を削除・並べ替え・意味変更せず、区画外の改行を含むバイト列を保持する。

片側だけ・逆順・重複などのマーカー破損、管理外のリンク、非空の `AGENTS.override.md` がある場合は、問題の対象を上書きせず非0で報告する。config は構造を確認して容量キーだけを更新する。読込優先順位によりホームの override が AGENTS より優先されるため、単なる AGENTS 配置を成功としない（根拠は裁定が参照した[公式の指示探索仕様](https://learn.chatgpt.com/docs/agent-configuration/agents-md)）。

harness `AGENTS.md` 全文は「この節は harness 配布元リポジトリを変更するときだけ適用する」という範囲説明で囲み、相対参照の基準は供給元の harness と示す。個人の絶対パスを公開生成物に固定しない。一般 repo や flatmate に開発場所・PR 運用を拡張しない。Claude 固有の hook・Agent・Skill の言及を、Codex で実行された証拠とは扱わない。

別案のホームファイル丸ごとの置換は主の指示と設定を失う。無条件の追記は同期のたびに重複し、リンクの追跡更新は管理外のファイルを変えるため採らない。harness の抜粋だけを配る案は全文配布の裁定に合わない。

### 6. worker は配布済みの共通区画だけを継承する

worker は既存の account 選択後、その account home の管理区画を読み取り、runtime の `AGENTS.md` に区画だけをコピーする。親の区画外の一時指示と親 config 全体は引き継がない。runtime の認証リンク、0700 のディレクトリ、既存の認証・隔離設定、TMPDIR/TMPPREFIX 継承は維持し、容量設定だけを追加する。

未配布・破損区画の場合は同期が必要だと知らせ、ターン開始前に非0で止める。検証では fake app-server が観測した runtime 本文と config を比較し、選択していない account の指示や親 MCP が入らないことを確認する。

別案の親 AGENTS/config の丸ごとコピーは一時指示や MCP を混入させる。worker 起動時の正本からの再生成は、同期済み指揮役と違う世代のルールで動く可能性を作る。区画無しでも動かす案は issue の供給保証を満たさない。

### 7. ponta の固定入力と実物検査を分ける

固定入力は flatmate の ponta を使う。`tests/fixtures/codex-shared-instructions/manifest.json` に、非公開入力の相対ファイル名・UTF-8 実測バイト数・SHA-256・測定元を残す。個人ルールや人格本文は転載せず、記録したサイズと一致する決定的な UTF-8 ダミー本文と末尾マーカーをテスト時に生成する。公開 rules・harness AGENTS・生成見出しと区切りは実際の生成物を測る。日本語、上限ちょうど、1バイト超過、区画外の既存指示を検査に含める。

ローカル実物検査は別経路として用意し、不在を実物成功と報告しない。裁定時点では flatmate ルート AGENTS 16,917 bytes と ponta AGENTS 25,289 bytes も存在した。実物検査はホームから作業ディレクトリまでの探索順で実際に選ばれるファイルを測り、同じ階層の AGENTS と CLAUDE を両方足さない。CLAUDE が存在するだけでは Codex が読む証拠にせず、選択されるファイルまたは fallback 設定を確認する。flatmate の配置は変更しない。

別案の非公開本文を fixture として保存する方式は公開範囲を越える。固定入力だけの合格では実物の変化・探索順・回答の切断を検知できず、実物だけに依存するテストは非公開 repo の無い環境で再現できない。

## Risks / Trade-offs

- 全文生成と容量引上げで注入量が増える → 実際の生成物と固定入力・実物の容量を測り、Claude 側の予算値は変更しない。
- marker や override によって配布を拒否しうる → 対象と原因を報告し、既存バイト列を保持して復旧手順を docs に書く。
- 同期前の account では既存 worker の起動も止まる → 自動テストの account fixture を配布済みに揃え、明示 sync と起動前エラーを案内する。無指示での続行はしない。
- 固定入力は本文の意味と実機の読込を証明しない → 三規則、人格末尾、日本語 commit の実機証拠を別々に正本と照合する。
- 実物の選択ファイルは CLAUDE の計測と異なりうる → 実際の探索結果を記録し、不在や未読込を合格に置き換えない。

## Migration Plan

1. R1 の APPROVE 後、生成・同期・worker・容量検査・docs を実装し、全自動テストを使い捨てホームで実行する。個人生成物・scratch・ログは repo に入れない。
2. 実機検証前に本体が対象ホームの集合、AGENTS の具体差分、容量キーの具体差分と復旧方法を提示して適用権限を確認する。主または承認された本体だけが sync 経由で適用する。
3. 復旧は適用前に保存した AGENTS/config のバイト列を戻すか、管理区画だけを除き容量キーを元に戻す。認証・MCP 等の無関係な設定を巻き戻さない。復旧情報はローカルに保存する。
4. 新規セッションの三規則、flatmate/ponta の実際の人格末尾、worker の日本語 commit を内容で評価し、対象 HEAD・コマンド・出力・exit code とともに issue #1853 に記録する。通信完走と品質判定を分ける。

実装後の検査は新設 `tests/codex-shared-instructions.bats` を含む Bats、`python3 -B plugins/dev-workflow/tests/test_codex_worker.py`、`openspec validate share-common-rules-with-codex --type change --strict`、`git diff --check` とする。変更記録はプラグイン単位でない配布基盤の変更として `docs/changes/1853.md` に置く。
