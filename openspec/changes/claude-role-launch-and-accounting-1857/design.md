# Design

## Context

動機と範囲は proposal.md を参照。固定 HEAD は `59d50d326ccb258b3722a05f5c7ccfc87d38ff4e`。G001 は `DEVELOP_ROLE` がある agent_id なしのセッションを自身の transcript へ向ける。`subagent-context.sh --file` は既に存在する。一方、PR 集計の Claude 探索は subagent meta だけで、Codex は終了後のコメントの数値または `-` の rollout だけを使う。`pr-token-budget.md` は本体自身を対象外と明記している。

## Goals / Non-Goals

**Goals:** 起動時に役の制限と session の帰属を確定し、既存の hook・閾値・計測式を再利用する。起動、工程の成果、後片付けの成否を本体が別々に確認できるようにする。

**Non-Goals:** 新たな工程管理、provider 選択、永続ジョブ管理、Codex hook、Orca 統合は作らない。Claude 本体の Agent / SendMessage 経路を置換しない。G001 の git 常時 deny や注入予算の変更も行わない。

## Decisions

### 1. 一つの前景 launcher で解決済みの依頼を受ける

`plugins/dev-workflow/scripts/claude-role-launch.py` を追加する。Python 標準機能で argv を組み立て、シェル評価を通さず起動する。入力は担当種別、profile role、解決済み model、cwd、指示ファイル、正整数 max-turns、リポジトリ外の session 登録ファイルとする。再開時は session ID と自身の transcript を指定する。開発検証には marketplace 外の plugin ディレクトリを指定できる。CLI の汎用追加引数で model / agent / tools / max-turns を上書きさせない。account は現在の Claude ログイン環境を使い、別 account や provider へ切り替えない。

`tier_caps.py` と同じ場所の対応表で上限を検査し、許可された解決済み model を明示する。launcher は未知 model・読めない表で起動しない。Agent hook の歴史的な fail-open をここへコピーすると、検査していない model を起動できるため採らない。profile の格や残量モードの再計算もしない。

担当種別と profile role は別入力として照合し、不整合を拒否する。役の対応は次のとおり。phase の名前だけからレビュアーと G を混同しない。

| 担当 | profile role / 用途 | 定義とツール集合 |
|---|---|---|
| W | spec-write、implement（finish も implement） | `agents/worker.md`: Read, Edit, Write, Bash, Grep, Glob, TaskStop |
| G | implement（gate の実行） | `agents/gate-runner.md`: Read, Bash, Grep, Glob, TaskStop |
| 独立 PR レビュアー | impl-review / review | `agents/reviewer.md`: Read, Bash, Grep, Glob, TaskStop、ファイル編集・投稿禁止の本文 |
| R1 | spec-review | `roles/spec-reviewer.md` の本文、Read, Bash, Grep, Glob, TaskStop。ファイル編集禁止、正本で許可された記録は Bash で行う |
| decider | decider（事前分類で切り替わったレビューも含む） | `agents/decider.md`: Read, Grep, Glob のみ |

ここにない担当は黙って汎用エージェントへ落とさず起動不可とする。`--agent dev-workflow:<定義名>` が実際に `-p` で読める版だけその経路を使う。R1 のように専用 plugin agent がない担当、または定義を読めない版では、対応する本文と明示 `--tools`、`--disallowedTools Agent` を使う。定義経路でも Agent の禁止を明示する。いずれも「孫を起こさない」「不足した独立役は本体へ要求する」を本文に含める。decider の読取専用を prompt だけに依存させない。

### 2. 未確認 CLI の通常起動を通さない

実装工程で launcher の検証モードを用意する。これはリポジトリ外の一時 repo、開発用 plugin、無害な少数の逐次ツール呼出し、有限の監視時間を用い、小さい `--max-turns` の実停止と役定義の読込を確かめる。上限が効かない probe は監視側が所有グループを回収し、不合格にする。CLI のパス・版と検証した plugin 内容に紐付く検証結果をリポジトリ外に保存し、通常起動は一致する合格結果を要求する。CLI / plugin が変われば再検証する。検証モード自身も max-turns を省略しない。

agent 定義読込の不合格はツールと本文の明示経路へ切り替えて同じ検証をする。max-turns の不合格は代替起動を持たず blocked とする。`--help` に載るか、終了コードが 0 かだけでは合格にしない。役の選んだ model と実効 model が同じことも確認し、定義の既定 model が優先される版はその経路を使わない。

### 3. session とログの帰属を起動前から保持する

新規は ID を生成し CLI に明示し、子専用 env に `DEVELOP_ROLE=<profile role>` を設定する。session と cwd に対応する provider の自身ログの絶対パスを確定して登録する。stdout の最終 JSON に session ID・transcript_path を必ず含め、起動後に利用できなければ欠測の理由を残す。起動失敗でも既知の実行を消さない。ログ探索は指定した設定 root と session に限定し、別の最新ログへ逃げない。

同じ session の再開では、既存の格・model の再解決と再開可否の判断は本体に残し、launcher は起動直前に `subagent-context.sh --file` を呼ぶ。exit 2 と exit 1 では再開しない。fresh session への手渡しは本体が正本の停止確認と完了宣言を判定して依頼する。launcher は自分で fresh へ変更しない。

会話ログをコピーして repo に保存しない。provider の既存のリポジトリ外ログを参照する。新たな持続的ログの保存先が必要なら `LLM_LOG_DIR` の規約に従い、未設定時に個人用の既定パスを発明しない。一時 repo / fixture / probe の出力は `$TMPDIR` または `mktemp -d` に置く。

### 4. グループ回収が終わってから工程結果を返す

役を launcher / 本体と異なる session / process group に起こし、起動直後に PID・PGID と所有情報を保持する。通常終了でも残った同一グループの子へ TERM、有限の猶予後に KILL を送り、生存がなくなるまで確認する。INT / TERM は launcher が捕捉し同じ後片付けを通る。強制停止の検証は子 CLI の強制終了と hook 拒否を対象にし、launcher の後片付け経路を残す。無関係な対照プロセスの生存を検証する。名前検索や `pkill claude`、本体の PGID への signal は使わない。所有を確認できない ID へ signal を送らず回収失敗として報告する。

結果 JSON は `session_id`、`transcript_path`、役・model、CLI exit code / termination reason、役の return 本文、cleanup の成否、工程宣言を分ける。正常な CLI 終了だけで品質合格にしない。W / G の正本どおりの完了宣言と正常な終了・回収を揃えたときだけ工程完了を伝え、それ以外は理由を付けて工程中断とする。R1 / reviewer / decider の成果形式は各役の正本を保持し、輸送層が APPROVE を発明しない。launcher の exit code は 0=正常な輸送と回収、1=起動不可、2=起動後の中断とする。役自身が中断した場合も 2。起動前の context 拒否は 2 とし、CLI は呼ばない。

### 5. 明示登録を既存集計への追加入力にする

`--session-records <file>` を集計と薄いラッパーへ足す。JSONL の各登録は schema version、provider、記録先番号の配列、正規化した repo の git common dir、cwd、session_id または thread_id、ログの絶対パスを持つ。Codex 本体は kind=coordinator と実際の CODEX_HOME、Claude は kind=role と役・model を持つ。進行中の更新も同じ ID に紐付ける。登録は起動や計測のための帰属情報だけで、job 状態や再送キューにはしない。

Codex 本体は最初の計測前に自身の thread と実際の rollout / home を登録し、Claude の launcher は起動前に自分の session を同ファイルへ追記する。書込みは不完全な行を読ませないようにし、失敗時には起動不可を返す。G002 の起動・再開手順では毎回 `pr-token-measure.sh --session-records <file>` を使う。共通本体の分離は #1856 に残し、ここでは launcher 専用 reference と既存 PR トークン手順書にこの呼出し契約を記す。

Claude は既存の usage 四項・request ID 重複排除を再利用する。独立 session ごとに一回だけ測り、同じログを既存 meta 探索でも見つけた場合は実体パスで重複排除する。Codex の明示登録は毎回 rollout の有効な累計の最大値を取り、同じ thread のコメントと合算せず最大値へ統合する。これで数値付きの古いコメントが進行中の本体を過少計上する問題を避ける。既存コメントだけの委譲の解釈は変更しない。

明示登録の欠測は `session_unresolved` と理由を返す。既知合計が cap を超えれば exit 2、超えておらず欠測があれば exit 1 とする。既存の exit 1 の本体方針は変えないが「計測できない」を「0 消費・上限以内」とは書かない。登録を指定しない legacy の未起動 0 と、登録済みの既知の実行の欠測を区別する。明示登録ファイルが空、または対象 Codex 本体の登録がない場合も欠測とする。上限値・上書きの優先順位・モデル別閾値の解決は既存の共通処理を使う。

### 6. Bats の子環境を fixture の入口で整える

G001 レビューの [P4-F3 / P5-F1](https://github.com/oratta/claude-harness/pull/1876#issuecomment-7237026083) を踏まえ、テスト用 subprocess と実際の役の環境を区別する。`scripts/test.sh` が起動する Bats の子環境でだけ `DEVELOP_ROLE` を解除し、通常 fixture の基準を安定させる。役 fixture は各 fixture で明示設定する。Bats を直接起動する追加スイートも setup で同じ基準を作る。launcher や役全体から印を消す案は G001 を無効化するため採らない。

外側を `DEVELOP_ROLE=implement` にしたテストで、runner 経由の通常 fixture、明示した役 fixture、テスト後の外側の印と git deny がすべて成立することを確認する。テスト runner の発見・shard・残留検査は維持する。

## Risks / Trade-offs

- [CLI の隠し option と plugin agent の版依存] → 小さい実機検証と版・plugin の照合を通常起動の条件にし、未検証を成功扱いしない。実機不可なら実装工程は blocked を返す。
- [launcher 自身の SIGKILL / OS 停止やグループを離脱したプロセス] → signal trap での回収保証の外。結果を確認できない場合は工程完了にしない。本体へ保持済みの所有情報を渡し、無関係なプロセスを探索して止めない。
- [ログの遅延と欠測] → 別 session を代用せず診断する。計測成功を主張せず、本体の既存の exit 1 方針で扱う。
- [役本文のツール制限と hook の適用漏れ] → plugin を実際に読み込んだログ・実効ツール・孫試行と destructive git の deny を確認する。fixture 合格と実機合格を区別する。

## Migration Plan

まず fixture で launcher と集計・runner 境界を実装検証する。次に開発用 plugin と外部一時 repo で AC1（model / 孫 / 再開計測）、AC4（max-turns / 回収）、AC5（本体 + 役の手計算照合）、AC6（実行前 git deny）を観測する。issue #1857 にコマンド・版・期待値・観測値・終了コード・外部証跡の所在を記録し、`changes/1857.md` に G002 とその記録先を追記する。生の会話ログや個人環境パスは tracked ファイルに入れない。

失敗時は通常起動を許可せず実装工程の中断として返す。配布後に戻す場合は追加 launcher / reference と集計の追加入力・runner 差分を戻す。G001 の保護を外す復旧は行わない。
