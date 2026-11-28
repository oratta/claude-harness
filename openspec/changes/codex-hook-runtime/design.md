# Design

## Context

G003 は #1861 の一覧と #1862 の判定を使う。`codex-worker.py:220-236` は auth link と最小 config のみ、`:359-364` は通常の app-server 起動のみである。Codex 入口は `DEV_WORKFLOW_CODEX_GUARD_DIR` と既存 git/secret/ask script に依存する。秘密判定には隣接する `secret-guard.py` も要る。adapter の依存失敗は fail-open であり、配布の成功を exit 0 で判定できない。

根拠: [元の仕様化判断](https://github.com/oratta/claude-harness/issues/1858#issuecomment-7234062095)、[元の分割](https://github.com/oratta/claude-harness/issues/1858#issuecomment-7234092634)、[Hooks](https://learn.chatgpt.com/docs/hooks)、[Plugin の信頼](https://developers.openai.com/plugins/build/plugins)。公式文書上、管理 hook は policy による信頼、一時 bypass は当該 invocation の有効 hook の信頼を省略する手段である。文書は実行版の読込・継承の実測の代わりにはしない。

## Goals / Non-Goals

**Goals:** 起動前に既知の入口・依存を検証し、配布した hook が実際に拒否したかを対象別に確認する。信頼方式は下記の実機比較ゲートを経て確定する。

**Non-Goals:** hooks 配下や既存 guard の変更、未確認質問 tool の追加、兄弟 issue の実装、OS sandbox や account/profile の変更。実ホームへの導入の実行も含めない。

## Decisions

### 配布の入口を共有し、通常 profile の hook を流用しない

非聖域の新規 `scripts/codex-hook-runtime.py` を worker と本体向け手順の共通入口にする。明示した一時 target の未使用の hook 領域に `hooks.json` と選択方式に必要な設定を作る。worker が準備した auth link・最小 config は保持し、hook 部分だけ追加する。その他の既存設定がある target は上書きしない。実ホームや認証元を暗黙に編集しない。

repo 内の定義を配布し、adapter/依存は helper の実体から求めた repo の絶対パスで参照する（配置の別案は asset 全コピーだが、既存判定と複製がずれるため採らない）。子環境の `DEV_WORKFLOW_CODEX_GUARD_DIR` と git/secret/ask の絶対パスはその配置へ固定し、親の同名変数で別 script に向かわせない。bash/python3、各依存と secret の Python sibling の存在を起動前に検証する。欠落は worker の既存失敗 JSON・非ゼロ終了で返し、App Server を起動しない。adapter の既存 fail-open 契約は変えない。

`DEV_WORKFLOW_UNATTENDED` と既存 off 設定の意味は継承する。無効化された検査を有効と報告しない。auth/account 照合、role sandbox、TMPDIR/TMPPREFIX、元 profile の MCP 等を持ち込まない契約を保つ。runtime 内の hook 設定も既存の finally cleanup で除去する。

### 信頼方式は実機比較ゲートを最初の実装タスクにする

採用前に、実行版・help・公式文書で対応する読込方法を確認し、別々の一時 CODEX_HOME と repo で次を比較する。spec 段ではセッションを起動せず、どちらも成功済みとはしない。

1. 管理 hook: 実ホーム・システム領域に書かずに管理設定を読み込ませられるか、管理済み source の表示と実際の deny で確かめる。`CODEX_HOME/requirements.toml` を置くだけで読まれるとは仮定しない。隔離配置ができない場合は試せなかった理由を記録する。
2. invocation 限定の `--dangerously-bypass-hook-trust`: CLI 本体と worker が使う app-server の双方で引数が受理され、既知の hook の deny が実際に効くかを確かめる。引数受理だけでは合格にしない。

両方通れば信頼の範囲を絞れる管理方式を選ぶ。管理方式が隔離環境で使えず bypass が通れば、配布元・有効な hook source を事前確認した一時 runtime のみに bypass を使う。未確認の追加 source が混じる場合は使わず止める。実ホーム向け手順にはその bypass を自動付与せず、主の hook レビュー・信頼操作を明示する。両方使えない場合は接続を完成扱いせず、出力・理由と主の手順を返す。採用/不採用理由と再現コマンドを本 design と #1863 に追記してから起動接続を仕上げる。

### 実ホームへの導入はレビューできる手順として渡す

本体向けには導入対象・依存絶対パス・設定差分・信頼操作・版更新時の再確認と戻し方を記す。既存 Orca 等の hooks 登録を保って追加し、`config.toml`/`requirements.toml` を全置換しない。主が内容を承認して自ら（または明示承認後の担当者が）適用する。今回の確認に通常 profile の hooks や trust 記録を借用しない。

### 実機の証拠を5つの必須セルに分ける

git は本体/native subagent/worker、秘密表示は本体/worker が必須。無害な git status/feature push と秘密値を出さない利用も対照にする。worker は linked worktree 必須なので、一時 repo の feature worktree を起動先にする。native subagent は実際の子の起動と tool 要求を親子ログ等で結び、PreToolUse に agent_id があると仮定しない。親の拒否を子の成功に代用しない。

一覧の既存安全手順を使い、global/system git config と redirect/alias/include/hook 由来の外部作用を除いた環境でローカル bare remote の fetch/push 先を照合する。9種の既存 git 対象と代表変形を試す際もすべて捨ててよい履歴・ファイルだけを使う。表示対象はダミー変数とダミー `.env` のみ。実トークンや環境全体を表示しない。認証の初期化/更新による実ホームへの書込も許さず、指定 account を変えずに隔離した認証を安全に用意できない場合は未取得理由として主へ返す。認証内容をログや試験 fixture に複製しない。

拒否 tool 結果と前後の HEAD/status/ファイル hash/remote refs を照合する。秘密は tool 出力にダミー値が出ないことも確認する。記録は版・harness HEAD・対象/role・source/信頼方式・無人印/off の状態・入力・cwd・時刻・exit code・拒否理由と不変性を含み、ログは repo 外、共有は秘密を除いた #1863 コメントにする。未取得は対象と操作別の理由・試したこと・主の具体的再現コマンドを残し、AC の成功チェックを付けない。

## Risks / Trade-offs

- [hook error/timeout は実行を止めない] → 依存を前検証し、実際の deny と未実行の両方を見る。動的な失敗まで防ぐ保証はしない。
- [repo の移動/更新で絶対パスや信頼が古くなる] → 再配布・再信頼の手順を記し、通常利用前に隔離 probe を再実行する。
- [native subagent/質問の継承が不明] → 欠測を明示する。#1862 の未確認質問経路をこの子で対応済みにしない。印付き同期質問の配布確認と、経路追加の必要性は分ける。

## Migration Plan

R1 承認後に隔離 probe、方式の確定、helper/worker 接続、回帰検査、対象別実機記録の順で進める。主向け手順は適用前設定の退避と今回追加した登録のみを戻す方法を含める。worker は終了時に一時 runtime を片付ける。未実機の対象が残る場合は未確認のまま #1863・一覧・1858.md に揃え、実装/品質承認と混同しない。

## implement 試行1の実測と停止点（2026-11-28）

- codex-cli 0.163.0。一時 HOME/CODEX_HOME、空の環境で `codex --version`、`codex --help`、`codex app-server --help`、`codex --dangerously-bypass-hook-trust app-server --help` は各 exit 0。最後は引数の解析と help だけであり、server/turn/実 hook は起動していない。
- [公式 Hooks](https://learn.chatgpt.com/docs/hooks) の managed requirements と invocation bypass の説明を確認した。文書の存在はこの実行版での隔離読込・拒否の証拠ではない。
- 管理方式: この assignment は agent/Codex exec の起動を禁止し、実ホーム・システムへの書込も禁止している。隔離管理設定の読込元表示と実 deny は未取得。`CODEX_HOME/requirements.toml` が読まれるとは推定しない。
- bypass: help の引数受理だけを取得。CLI 本体と app-server の実 deny/無害な対照は未取得。native 子も起動禁止のため未取得。採用方式なし、有効 source も未検証。
- task 1.1 の準備手順は一覧に掲載し、親の Git 設定を注入した反例を含む unittest で repo 外だけに準備されることと status 対照の前後一致を確認した。Codex tool を経由した対照とは区別する。
- task 1.2 の「両候補未成立なら止める」に従い、2.1–2.3 の helper/worker 接続は未着手。3.1 の git 3対象・秘密2対象、印付き同期質問も未取得。後続担当は下記と一覧の手順で信頼ゲートから再開する。

再現: 一覧の preparation block を `/bin/sh -eu` で実行し、出力された一時領域内の環境を維持する。`codex --version` と `codex --help`、`codex app-server --help`、`codex --dangerously-bypass-hook-trust app-server --help` を一時 CODEX_HOME で比較する。実機実行権限を持つ担当が、同じ account/profile 指定のまま、実ホームへの認証更新を発生させずに隔離認証を用意できることを先に確かめる。管理候補は実行版で隔離管理設定を読ませる方法を確認してから配置し、bypass 候補は有効 source をレビューしてから別の一時 CODEX_HOME へ既存 hook と絶対依存パスを配置する。未導入 helper の存在や未検証の管理読込オプションは仮定しない。候補ごとに `codex --no-daemon --cd "$probe_dir/feature"`（bypass 候補だけ `--dangerously-bypass-hook-trust` を追加）と app-server の turn で `git reset --hard HEAD` / `git status --porcelain` を要求し、hook source・実 deny と snapshot 不変・対照を照合する。未成立なら接続を進めない。native 子の確認は起動許可のある coordinator が別途担当する。
