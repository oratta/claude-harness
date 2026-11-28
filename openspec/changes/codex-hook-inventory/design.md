## Context
動機・編集境界は proposal.md を参照。指定 HEAD の hooks.json は dev-workflow 17 登録と capability-registry 2 登録。context-tripwire.sh と epic-child-state.sh はそれぞれ 2 event に登録されており、スクリプト名の重複排除では漏れが生じる。
既存 hook には Claude の transcript・agent_id・file_path、専用 event/tool、CLAUDE_PLUGIN_ROOT への依存がある。codex-worker.py:220–236 は一時 CODEX_HOME に認証リンクと最小 config.toml を置くが hook は配布していない。この実物と、元 #1858 の調査結果を分けて出典にする。

## Goals / Non-Goals
目標は各登録の意味・現状・欠落が追跡できる一覧を作ること。実装がない／対象でないという理由を、動作確認済みと取り違えない形で残す。
移植コード、hook のインストール・信頼設定、実機試験、#1856 の本体別操作の実装は別の子が扱う。本体が Codex でも Claude の役を起こす場合は、その Claude 経路への適用と Codex 自身への適用を区別する。

## Decisions
1. **独立した Markdown 一覧を正本とする。** `plugins/dev-workflow/docs/codex-hook-inventory.md` を既存 `docs/codex-develop.md` から相対リンクする。元 #1858 の判断を継承する。共通手順書への埋め込みは兄弟との競合・読取増を招き、別 JSON 正本との二重管理は不要なので採らない。#1856 A1 の Codex 用ファイルは未存在のため作成せず、「作成時にこの一覧を参照し複製しない」という接続点を一覧に明記する。将来の参照元パスを推測してリンクしない。
2. **登録単位で照合する。** 両 hooks.json の各 event → matcher group → hooks の command を列挙し、`(plugin, event, matcher, command)` の多重集合で Markdown の行と一致させる。matcher 未指定は空文字として扱い、順序は同一性に含めない。重複行を拒否し、将来同じキーが複数登録された場合も曖昧な重複として失敗させる。command は全体を保持し、timeout 等の追加属性も一覧の根拠欄に記す。Markdown の event/matcher/command をインラインコードにし、セル内の `|` を `&#124;` と表記して検査時に復元する（単純な行分割による見落としを防ぐ）。
3. **方針と達成状態を分ける。** 方針は「Codex で動く／載せ替える／Codex では持たない」。完了した移植だけを「載せ替えた」と表示する。各行には現状、入力・出力依存、理由、ソース相対パス＋行範囲、載せ替え先または後続 issue、対象別の確認状態を持たせる。実機の記録がない対象は「未確認」とする。ソース・fixture での確認と実機は別の証拠であり、「hook コマンドが exit 0」「worker が completed」だけで有効とは記さない。
4. **分類時の根拠と担当境界。** 実装者は登録先本体を読んで全行を分類する。session/prompt/compact/subagent の注入・モデル選択は #1856 の該当子への接続、epic-child-state の 2 event は #1855 の責務への接続として記録する。git・秘密・無人質問は #1862 の判定／#1863 の配布・実機へ接続する。context 計測は Claude JSONL/token/agent_id の依存を明記し、Codex ログを同形と仮定しない。base-write・rm permission・browser・model switch・team warning も固有の入力/event/責務を根拠に分類し、「対応 event がない」だけで目的まで不要と結論しない。代替がない場合は「Codex では持たない」に残る不足・理由を明示し、黙って範囲外へ落とさない。
5. **副作用のない検査と反例。** 新規 `plugins/dev-workflow/tests/test_codex_hook_inventory.py` に Python 標準 unittest で一覧の読み取り・照合と反例をまとめる。実 hook は実行しない。両 plugin を含む基準一致、行削除、登録追加・削除、event/matcher/command 変更、重複、空の理由・根拠、不正分類で失敗することを一時コピー上で検証する。19 という固定値だけ、スクリプト名だけ、表と同じ固定配列だけの検査は採らない。変更記録の存在・既存案内からのリンクと接続契約も確かめる。

## Risks / Trade-offs
- [不完全な Codex 対応が一覧で既成事実になる] → 本体／native subagent／codex-worker.py の役ごとに確認状態を記す。G001 では未配布・未確認を明記し、#1862/#1863 が同じ行の移植先・証跡を更新する。
- [未作成の #1856 との接続が曖昧になる] → A1 の最小契約の所有権を #1856 側に残し、本 change は既存案内からの発見可能性を確保する。#1856 関連の open PR は調査時点では見つからなかった。新たに現れた場合は読取だけで整合させる。
- [完全性テストが機能保証と誤認される] → 一覧の漏れを保証する範囲を記す。deny・信頼・継承の機能検証は #1862/#1863 の証拠を待つ。

## Migration Plan
R1 APPROVE 後に一覧・テスト・既存案内リンク・共用 changes/1858.md を追加する。変更記録は G001 の実施内容と後続の残作業を区別し、後続が追記する。版変更・設定変更はしない。取り消しはこれらの文書・テストの変更を戻すだけで、実行環境への変更は生じない。
一覧内の実機確認手順には、repo 外の mktemp 作業領域内に検査用 repo と bare remote を作り、origin がそのローカルパスであると照合してから、捨ててよい commit／変更だけで破壊的 git 操作を試す段取りを記す。秘密試験は専用のダミー変数と .env のみを使い、環境全体の printenv や実 profile の秘密表示は行わない。拒否ログと前後の worktree/remote 状態で未実行を検証し、対象・版・HEAD・入力・exit code・理由・未取得理由を記録する。ここで実行はせず、G003 が本体／native subagent／worker の対象別に行う。
