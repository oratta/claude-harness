## REMOVED Requirements

### Requirement: 継続依頼は初回の Codex 設定を復元する
**Reason**: 前景委譲は run directory と worker state を持たず、各 role を fresh thread として解決するため v1/v2 継続記録を廃止する。

**Migration**: issue または Draft PR と worktree の現状を入力に、該当工程を最初からやり直す。profile/account mapping は委譲時に再解決する。

#### Scenario: 前景実行の途中でセッションが終わる
- **WHEN** 前景実行が結果を返す前にセッションとともに終了する
- **THEN** 継続マーカーを保存・検索せず、記録先と worktree から fresh phase を開始する

### Requirement: 復元不能時は安全に停止する
**Reason**: 復元対象となる run と継続記録を廃止するため、復元エラーという状態自体が存在しなくなる。

**Migration**: 新しい委譲に必要な profile または account/model と account-home mapping が不足していれば `request` が fail closed し、別 provider/account へ fallback しない。

#### Scenario: 再委譲の設定が不足する
- **WHEN** fresh phase の request に必要な profile または account mapping がない
- **THEN** request を作らずに停止し、Claude や別 account へ暗黙 fallback しない

### Requirement: 継続復元は既存 develop の品質工程を変えない
**Reason**: 継続復元を廃止し、品質工程の不変条件は `manual-codex-develop` の provider-neutral 要件だけに残す。

**Migration**: 仕様判断、独立 review、verify、archive、finish/G は executor に関係なく canonical develop の正本を使う。

#### Scenario: fresh phase がレビューへ到達する
- **WHEN** やり直した工程が通常のレビューまたは finish/G に到達する
- **THEN** canonical develop のレビュー・ゲート条件を適用し、transport 完了を品質承認として扱わない

### Requirement: 継続復元の回帰を検証する
**Reason**: v1/v2 解析、run 整合性、同一 run への復元を実装ごと削除するため、それらの回帰試験も廃止する。

**Migration**: 前景 request/run、fresh phase の再委譲、no-fallback、profile role routing の回帰試験で置き換える。

#### Scenario: 継続記録の fixture を実行しない
- **WHEN** dev-workflow のテストスイートを実行する
- **THEN** v1/v2 fixture を要求せず、foreground-only の契約を検証する

### Requirement: coordinator と担当者の責務境界を守る
**Reason**: この requirement は run/継続整合性と一般の役割境界を混在させている。run/継続部分を廃止し、一般の役割境界は `manual-codex-develop` と canonical develop に一元化する。

**Migration**: coordinator は記録先選択・role routing・read-only verdict の代理投稿を担い、workspace-write role は GitHub 操作と commit/push を自分で行う。担当者は LLM ログを取得しない。

#### Scenario: 担当者へ fresh phase を委譲する
- **WHEN** coordinator が調査、修正、またはレビューを委譲する
- **THEN** canonical role の責務と権限境界を適用し、run 整合性や継続記録の操作を行わない
