## Context

Dispatch HEAD は `d22b82c1dc5b48ac517cdb05e703ab3605589117`。仕様化する・分割しない判断は coordinator が確定済み。worker → develop の順で一つの change を実装する。

現行 worker は request を正規化して payload_hash を保存し、turn/start 直前に turn_submitted を立てる。develop は単一 account/model と request.json を保存し、retry は run の値を照合する。継続記録 v1 は executor/account/model/run-dir/worker-state/cwd の6キー固定である。

coordinator 実測（codex-cli 0.153.4）をプロトコル前提とする。effort は turn/start のみのパラメータ。ReasoningEffort は非空文字列であり、model/list の supportedReasoningEfforts は reasoningEffort/description のオブジェクト配列。luna は ultra 非対応で、固定 enum 検証はできない。

## Goals / Non-Goals

**Goals:** 役割に応じた固定設定、開始前拒否、旧 pending の無変更再送、監査可能な要求/実効記録、v1 継続互換を一つの PR で実現する。

**Non-Goals:** Claude Agent 混在の実行、残量ルーティング、使用量集計、別の品質工程、バーンのスケジューラ実装、永続 worker の send/steer。executor フィールドは将来の Claude Agent を表現できるが、この版で受理する値は codex のみ。

## Decisions

### 1. 名前・構文・設定の正本

手動入口は `/develop --executor codex --profile codex-standard <依頼>` または `--profile codex-economy`。CLI は `codex-develop.py init --profile NAME --cwd DIR [--profile-file PATH] [--worker-state DIR]`。旧入口 `init --account NAME --model MODEL --cwd DIR` は維持する。profile と旧フラグのどちらか一つでも併用した場合は拒否する。profile-file 単独も拒否する。暗黙の優先順位を設けると意図した account を失うためである。

配布する `references/codex-role-profiles.json` を組み込み設定の機械可読な正本とし、`model-tiers.md` から参照して役割/ティアとの対応を説明する。外部 profile-file 指定時はそのファイルだけを読み、組み込みとの merge/不足補完はしない。形式は `{ "version": 1, "profiles": { "NAME": { "roles": { "ROLE": { "executor": "codex", "account": "current", "model": "gpt-5.6-sol", "effort": "high" } } } } }`。重複 JSON キー、未知キー/版/役割、欠落役割、空文字、codex 以外の executor は拒否する。全 entry の account は登録名であり、組み込みは current を明示する。current 未登録なら拒否し、ログイン中の別 account を探さない。ユーザーは設定例をコピーして各役割の account を変更できる。

| canonical worker role | 標準 codex-standard | 節約 codex-economy |
|---|---|---|
| spec-write | gpt-5.6-sol / high | gpt-5.6-luna / medium |
| spec-review, impl-review, review, decider | gpt-6-astra / high | gpt-6-astra / high |
| implement | gpt-5.6-sol / medium | gpt-5.6-luna / medium |
| explore, summarize | gpt-5.6-luna / low | gpt-5.6-luna / low |

既存 PHASES の spec→spec-write、review→impl-review、finish/gate→implement を維持する。review は worker 既存の汎用レビュー役として impl-review と同値を必須にする。explore/summarize は既存正本の探索/要約用途を明示する read-only transport role/phase として追加するだけで、必須工程にはしない。roles と model-tiers の品質判断/役割責務を複製しない。Claude の残量モードで固定済み Codex entry を黙って変えない。

手動と将来のバーンは同じ設定 loader/init/役割 resolver を使う。今回の共通入口は上記 CLI と版付き JSON であり、バーン用に別の表や origin=burn の worker 経路を作らない。呼び出し側の窓判定や自動配分は対象外。

### 2. init と pending の不変境界

profile run の run.json に `execution_config: {version: 1, profile: NAME, roles: <解決済み全entry>}` と `execution_config_hash` を保存する。hash は UTF-8、ensure_ascii=False、sort_keys=True、separators=(',', ':') の JSON を SHA-256 に通した値。cwd/worker_state は従来どおり固定。外部ファイルのパスは補助情報に留め、dispatch/retry/継続時には再読込しない。版不明または snapshot/hash 不一致は停止する。

旧 run は execution_config が無いことで判別し、account/model を全役割へ適用する読み取りアダプタだけを使う。旧 run の自動書換えや profile 化はしない。effort は absent のまま扱う。

新規 profile dispatch は役割を解決して worker 用 request を生成し、request_id とともに `pending_execution: {role, executor, account, model, effort}` および `pending_payload_hash` を run に保存してから submit する。request に executor を足す必要はなく、transport の executor は pending 側で固定する。worker payload hash は現行 `json.dumps(payload, sort_keys=True)` の規則を変えない（execution_config_hash の規則とは別）。

retry は pending の role、固定 entry、cwd、request_id、保存 payload hash を照合し、保存 request.json をそのまま渡す。run 全体の account/model や現在の外部設定を照合対象にしない。pending_execution 自体も snapshot の当該 role と一致させる。不一致は拒否し新しい job を作らない。pending がある dispatch も保存済み role/phase/HEAD/prompt/設定一致のときだけ同じ request を再利用し、更新した prompt テンプレートで再送しない。旧版 prompt で確実に再送する入口は retry とする。

旧 pending は旧 request_id/account/model/cwd の検証に加えて既存 role の妥当性を確認し、executor=codex、effort=absent と読み取る。effort、executor、設定版などを request に追記しない。既存の request のハッシュ対象キー/値、worker payload/hash、request_id は変えない。旧 job の冪等な再取得に model/list を要求しない。unknown は従来どおり ack/新規実行で迂回できない。

### 3. 二段階の検証と RPC

第1段階は submit の validate_request と登録台帳照合。許可フィールドに optional effort を追加し、指定時は非空文字列であることを検査する。未定義 role と未登録 account を job 投入前に拒否する（台帳を validate_request に渡すか隣接した検証関数で行う）。init でも全 profile entry の静的形式/登録 account を検査する。account identity/認証の既存チェックは残す。固定 effort enum やモデル一覧を組み込まない。

第2段階は worker の initialize/initialized と account 照合の後、thread/start より前。指定 account の model/list(includeHidden=true) を全ページ取得し、model フィールドへの完全一致でモデルを選ぶ（id は診断用。id と model が違っても id を暗黙 alias にしない）。該当モデルが一意でなくても拒否する。effort があれば supportedReasoningEfforts[*].reasoningEffort に完全一致させる。旧 request で省略時は検証可能な model だけ照合し、effort は送らない。defaultReasoningEffort を要求値に後付けしない。hidden でも明示指定かつ広告されたモデルは受理する。

不正モデル/非対応 effort/一覧取得不能は turn_submitted=false のまま failed + 区別できる error_kind として記録する。thread/turn を作らず、unknown や別モデルへの fallback にしない。正しい model は thread/start と turn/start の双方へ、指定された effort は turn/start だけへ渡す。thread/start の effort/config への二重注入はしない。

### 4. 要求値と実効値を別に記録する

worker 台帳に payload 外の nullable execution JSON を追加し、既存 payload/hash を再計算しない。公開 status/result および ack 時に取り込む run.history.result が同じ記録を含む。

形式は `execution: {version: 1, role, requested: {executor, account, model, effort}, effective: {executor, account, model, effort}, evidence: {executor, account, model, effort}}` とし、既存トップレベル job_id/thread_id/turn_id と結び付ける。requested.effort は省略要求なら null。これは公開 metadata の表現であり payload に null を追記する意味ではない。executor は実際の transport、account は account/read と既存 identity 照合で確認した登録名。model/effort は RPC 応答や通知が明示した値のみ実効値として採用し、取れないものは null、evidence は unavailable とする。evidence の取得元は RPC method/notification と値の所在を持つ。thread 由来と turn 由来を識別し、turn の観測を優先する。model/list の default/対応表や単なる送信値を実効値と呼ばない。

requested と effective に差があれば記録に残して設定一致の受け入れを失敗とする。自動再送や別実行先への変更はしない。既存行の metadata 不在は unavailable として公開し、payload や ID を補完改変しない。

実機受け入れは各セットで spec→独立 spec-review→implement→独立 review を1件ずつ行い、job/thread/turn ID、要求値、取得できた実効値、観測元、HEAD、コマンド/終了コードを残す。応答から実効 model/effort が取れない場合は未観測を正直に記録し、該当受け入れ条件は未達として coordinator に観測手段の追加を依頼する。要求の送信成功だけでは「実モデルの確認済み」にしない。

### 5. 継続記録は v1 を壊さず v2 を足す

旧 run は従来の v1 を読み書きし、6キー契約を維持する。profile run は `<!-- codex-develop-continuation:v2 executor=codex profile=NAME config-version=1 config-hash=HEX run-dir=PATH worker-state=PATH cwd=PATH -->` を使う。7キーの順序はこの例で固定し、値の UTF-8 RFC3986 %HH エンコード/空値・未知キー・重複キー拒否は v1 と同じ。

v2 は profile/config-version/config-hash を private run の execution_config と照合し、run-dir/worker-state/cwd の正規化、所有者/0700 を維持する。名前だけで外部設定を再ロードしない。v1 を profile run に、v2 を旧 run に合わせる読み替えは拒否する。候補選択は版を問わず既存マーカーで最新コメントを選び、不正/未知版の最新候補から古い v1 に戻らない。記録先の issue 優先と coordinator による取得/投稿、追加依頼の品質工程は変えない。

v1 の必須 account/model を任意にする案は曖昧な部分復元を許すので採用しない。全 snapshot を公開コメントへ埋め込む案も避け、private run を正本として digest で結ぶ。

## Risks / Trade-offs

- モデル一覧取得が必要になる → 起動ごとに指定 account で照合する。取得不能時は失敗とし、旧 request でも新規実行時は黙って省略しない。
- 実効 effort を API が返さない可能性 → null/観測元を区別し、受け入れ未達を隠さない。
- 全件 bats が Python 回帰を拾っていない → statusline の先例と同じ薄い bats ラッパーを追加する。約51秒の既存80 tests を含む実行時間増より互換破壊の検出を優先する。ラッパーは fixture の Python tests だけを呼び、実モデル課金テストは含めない。
- 設定形式や v2 は旧バイナリで読めない → v1 は維持、profile run は対応版に固定し停止/確認終了まで downgrade しない。
- 常時注入予算 → description/rules の増加を避け詳細は references に置く。予算値を自動変更しない。

## Migration Plan

worker の optional effort と追加 metadata を先行実装し、次に develop snapshot/retry、v2、入口/docs を接続する。既存 DB は nullable 列を追加するだけ。旧 run/pending は自動移行しない。既存 manual-codex-develop change も今回の同名 spec と同期し、後日の archive で単一 account 契約へ戻らないようにする。

dev-workflow plugin は 2.13.8 から適切な次版へ bump（実装時の HEAD で確認）。rollback は未開始の新規 profile run を止め、稼働/unknown を既存終了確認の手続きで扱う。payload/所有権台帳を削除して旧版へ戻すことは禁止。

## Open Questions

設計上の未決定事項なし。実効 model/effort の観測可能性は実機受け入れで検証する項目であり、確認できなければ未達として返す。
