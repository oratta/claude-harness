## MODIFIED Requirements

### Requirement: coordinator と担当者の責務境界を守る
coordinator は記録先の選択、継続記録の生成・解析、GitHub コメントの取得・保存、LLM ログの取得、run の整合性検証を担わなければならない（MUST）。GitHub 操作と commit/push は、その権限を持つ役（workspace-write role の担当者）が worker の中で自分で完了しなければならない（MUST）。coordinator がこれらを代理してよいのは、capability `codex-worker` の「揃えられなかった項目を項目ごとに記録する」で記録された項目に限る（MUST）。担当者は固定された executor/account/model/run-dir による調査・修正・レビューを行い、結果とテスト証跡を返さなければならない（MUST）。coordinator は担当者の調査・修正・レビューを代行してはならない（MUST NOT）。read-only role の担当者は GitHub へ書き込んではならず（MUST NOT）、そのレビュー結果は coordinator が既存書式で代理投稿しなければならない（MUST）。担当者は LLM ログの取得を行ってはならない（MUST NOT）。この境界は Codex 専用の仕様必須・承認台帳・check/archive ゲートを追加してはならない（MUST NOT）。

#### Scenario: 担当者への調査・修正・レビュー委譲
- **WHEN** 初回または追加依頼が調査、修正、レビューを要求する
- **THEN** coordinator は記録された同じ担当へ依頼し、担当者の返却した判断・変更・テスト証跡を受け取る。coordinator 自身はその調査・修正・レビューを実行しない

#### Scenario: 本体が記録と run の整合性を担う
- **WHEN** 継続記録の生成・解析、LLM ログの取得、または run の整合性検証が必要になる
- **THEN** coordinator が許可された範囲で実行する。transport の完了だけでは品質承認・finish/G 合格と扱わない

#### Scenario: 書く役が GitHub 操作と commit/push を自分で行う
- **WHEN** workspace-write role の担当者が commit、push、Draft PR 作成、または記録先へのコメントを必要とする
- **THEN** 担当者が worker の中で自分で完了し、coordinator は代理しない。代理が入るのは、揃えられなかった項目として記録済みの操作だけである

#### Scenario: 読む役のレビュー結果を投稿する
- **WHEN** read-only role の担当者がレビュー結果を返す
- **THEN** 担当者は GitHub へ書き込まず、coordinator が既存書式で代理投稿する。投稿成功前に後続実装・完了扱いとしない
