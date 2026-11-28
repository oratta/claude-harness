## Purpose
Claude の dev-workflow と capability-registry に登録された hook が Codex でどの責務を担い、何が未対応かを利用者と後続の実装者が確認できるよう、分類の根拠・対象別の状態・一覧の完全性を保つ。

## ADDED Requirements

### Requirement: 登録ごとの Codex 向け分類を根拠とともに公開する
一覧は両 plugin の全 hook 登録を plugin・event・matcher・command で識別し、分類方針、現状、理由、入力・出力依存、ソース根拠、載せ替え先または後続担当を記さなければならない（MUST）。matcher 未指定は空文字として扱う。同じ script の別 event 登録を統合してはならない（MUST NOT）。分類方針は「Codex で動く」「載せ替える」「Codex では持たない」とし、持たない場合は残る不足と理由も明示しなければならない（MUST）。

#### Scenario: 現 HEAD の全登録が見える
- **WHEN** 指定 HEAD の両 hooks.json と一覧を読む
- **THEN** dev-workflow 17 件と capability-registry 2 件がそれぞれ根拠付きで記され、context-tripwire と epic-child-state の複数 event も別々に追跡できる

### Requirement: 移植方針と確認済みの状態を区別する
一覧は Codex 本体・native subagent・codex-worker.py の役ごとの確認状態を示し、未実装の予定を「載せ替えた」と記してはならない（MUST NOT）。実装・配布・信頼・実機証跡を区別し、未取得は未確認と記さなければならない（MUST）。Codex で Claude の役を起こす経路の証拠を、Codex 自身への適用の証拠に代用してはならない（MUST NOT）。

#### Scenario: 後続の拒否判定や配布が未実装
- **WHEN** G001 で一覧を作成し #1862 の移植や #1863 の配布・実機確認がまだない
- **THEN** 載せ替え方針と後続 issue が分かり、現在未実装・未配布・未確認であることが対象別に分かる
#### Scenario: 後続が実装結果を追記する
- **WHEN** G002/G003 が判定・配布・対象別の実機証跡を取得する
- **THEN** 同じ登録行の移植先・達成状態・証跡を更新でき、未確認の対象が確認済みへ巻き込まれない

### Requirement: 独立した一覧を Codex の手順から参照する
一覧の正本を `plugins/dev-workflow/docs/codex-hook-inventory.md` に置き、既存 `docs/codex-develop.md` から参照しなければならない（MUST）。#1856 の Codex 用ファイルが作られるときはこの一覧を参照し複製しないという接続契約を一覧に記さなければならない（MUST）。この変更は #1856 のファイル構成や操作対応表を新設してはならない（MUST NOT）。

#### Scenario: #1856 の Codex 用ファイルがまだない
- **WHEN** 利用者が既存の Codex 案内を読む
- **THEN** 一覧へ辿れ、将来の #1856 側の参照契約が分かり、未作成の参照元への壊れたリンクはない

### Requirement: 一覧の分類漏れを自動検出する
テストは欠落・古い行・重複・識別情報の変更・未知の分類・空の必須列で失敗しなければならない（MUST）。固定件数だけで合格させず、反例は repo 外の一時コピーで作り、実 hook の実行・実環境の変更をしてはならない（MUST NOT）。

守備範囲: 入力元は `plugins/dev-workflow/hooks/hooks.json`、`plugins/capability-registry/hooks/hooks.json`、Markdown 一覧 `plugins/dev-workflow/docs/codex-hook-inventory.md`。登録キー `(plugin, event, matcher, command)` の対応・重複、分類の許容値、理由・根拠を含む必須列の充足を検査する。

保証しない範囲: 構造が正しくても理由や根拠の意味の誤りは通り得る。分類の妥当性・根拠の意味・実機の有効性は保証せず、レビューと後続の証拠で確認する。これらの穴を機械検査で塞ぎ切ることを本 change の完了条件にしてはならない（MUST NOT）。

#### Scenario: 現状が完全に対応する
- **WHEN** 各登録に有効な分類・理由・根拠のある行が一つずつ存在する
- **THEN** 検査は exit 0 となる
#### Scenario: 構造上は正しいが理由の意味が誤っている
- **WHEN** 一時コピーの一覧で登録キー・必須列・許容分類・空でない理由と根拠を保ち、理由だけを当該 hook に当てはまらない説明へ変更する
- **THEN** 機械検査は exit 0 となり、意味の誤りはレビューの対象として残り、機械検査の合格を分類の妥当性の証明にはしない
#### Scenario: 同じ command の別 event の行が欠ける
- **WHEN** context-tripwire の一方の event の行だけを削除する
- **THEN** スクリプト名が一覧に残っていても検査は非 0 となり、欠けた登録を示す
#### Scenario: 登録と一覧がずれる
- **WHEN** 一時コピーで登録を追加・削除するか event/matcher/command を変更し一覧を更新しない、または一覧を重複させる
- **THEN** それぞれ検査は非 0 となり、不一致または重複の識別情報を示す
#### Scenario: 分類や根拠が不正
- **WHEN** 一時コピーで分類を未知の値にする、理由を空にする、または根拠を空にする
- **THEN** それぞれ検査は非 0 となり対象行の不備を示す

### Requirement: 安全な実機確認手順と共用の変更記録を残す
一覧は、後続 G003 が行う確認を一時 git repo・ローカル bare remote・ダミーの秘密だけで実施する手順と、対象別の拒否および未実行の証拠の記録方法を示さなければならない（MUST）。本 change で実機成功を宣言してはならない（MUST NOT）。`plugins/dev-workflow/changes/1858.md` を開始し、G001 の成果と後続の未完了項目を区別しなければならない（MUST）。

#### Scenario: 後続の担当者が安全な確認を準備する
- **WHEN** 後続の担当者が一覧の確認手順を読む
- **THEN** 捨ててよいローカル repo と remote の検証、ダミー秘密の作成、拒否前後の状態比較、本体・native subagent・worker ごとの証跡または未取得理由の残し方が分かる
