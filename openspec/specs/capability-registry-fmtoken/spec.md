# capability-registry-fmtoken Specification

## Purpose
プロジェクトスコープのトークン取得ラッパー fmtoken.sh。1Password vault agents から read-only SA 経由でトークンを引き、未登録・未配布時は人間への依頼文を返す。

## Requirements
### Requirement: fmtoken.sh がプラグイン内から動作する
プラグインは `scripts/fmtoken.sh` を同梱し、flatmate リポの実装（コミット fb21df1 時点）と同等の振る舞いを提供しなければならない（SHALL）: cwd の git root 名からプロジェクト名を機械導出（小文字化・先頭 `_` 除去・`_ver.X.Y` 接尾辞除去の正規化）し、1Password vault `agents` のアイテム `<project>--<service>`（フィールド `credential`）を read-only Service Account 経由で読む。スキルや hook からは `${CLAUDE_PLUGIN_ROOT}/scripts/fmtoken.sh` で参照できること。

#### Scenario: トークンの取得
- **WHEN** 登録済みプロジェクトで `fmtoken.sh <service>` を実行する
- **THEN** `op://agents/<project>--<service>/credential` の値が標準出力に返り exit 0 となる

#### Scenario: プロジェクト名の正規化
- **WHEN** git root のディレクトリ名が `Buffon_ver.0.4.0` のようなバージョン付き・大文字混じりで `fmtoken.sh` を実行する
- **THEN** プロジェクト名は `buffon` に正規化されてアイテム参照が組み立てられる

### Requirement: SA トークンは env → 600 ファイル → Keychain の順で解決する（無人経路優先）
fmtoken.sh は `OP_SERVICE_ACCOUNT_TOKEN` 環境変数 → `~/.config/op-sa/claude-agents-ro.token`（600 権限ファイル）→ macOS Keychain `op-sa-claude-agents-ro` の順で SA トークンを解決しなければならない（SHALL）。Keychain は ACL 次第で読み出しごとに生体認証ダイアログを出し、無人文脈（cron・常駐・SSH）ではそこでブロックするため、対話マシン用の最終フォールバックに置く。ファイルが配布済みのマシンでは Keychain に一切触れないこと。どこにも無い場合は exit 43 で「主に SA トークンの配布を依頼する」案内を stderr に返し、ブラウザでのログイン代行に誘導しない。

#### Scenario: 600 ファイルが Keychain より優先される
- **WHEN** Keychain にも 600 ファイルにも SA トークンがあるマシンで `fmtoken.sh <service>` を実行する
- **THEN** ファイルのトークンが使われ、Keychain（`security find-generic-password`）は呼ばれない

#### Scenario: 未セットアップマシン
- **WHEN** SA トークンが env にも Keychain にもファイルにも無いマシンで `fmtoken.sh <service>` を実行する
- **THEN** exit 43 となり、stderr に「主に『SA トークンをこのマシンに配布して』と依頼すること」の案内が出る

### Requirement: 未登録サービスは exit 44 で登録依頼を返す
要求されたサービスが vault に未登録の場合、fmtoken.sh は exit 44 で終了し、stderr に「ブラウザに行かず、主に 1Password の agents 保管庫への登録を依頼する」案内を返さなければならない（SHALL）。

#### Scenario: 未登録サービスの要求
- **WHEN** vault に `<project>--<service>` が存在しない状態で `fmtoken.sh <service>` を実行する
- **THEN** exit 44 となり、stderr に登録依頼の案内（アイテム名とフィールド名を含む）が出る

#### Scenario: 存在確認モード
- **WHEN** `fmtoken.sh --check <service>` を実行する
- **THEN** トークン値を出力せず、登録済みなら exit 0、未登録なら exit 44 で返る
