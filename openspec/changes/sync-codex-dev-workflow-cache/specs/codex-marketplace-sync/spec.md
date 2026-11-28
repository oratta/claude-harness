# Spec Delta

## Purpose

marketplace dir 側の sync.sh で Codex の Git marketplace と導入済みキャッシュを更新し、main 更新後も古い develop や変換済み command skill を読み続ける状態を解消する。

## ADDED Requirements

### Requirement: 登録済み Git marketplace の導入済みキャッシュを更新する

`scripts/sync.sh` は、実行元 manifest と同名の Codex Git marketplace が登録されている場合、その marketplace を更新し、設定済み dev-workflow のキャッシュも更新しなければならない（MUST）。既存の登録元・ref・プラグイン有効無効設定を保持し、未登録 marketplace の追加や未設定プラグインの有効化をしてはならない（MUST NOT）。Codex の格納先は `CODEX_HOME`、未設定なら `$HOME/.codex` に従う。

#### Scenario: 古い develop が main と一致する
- **WHEN** 同じリポジトリの main を指す Git 登録と enabled な dev-workflow の古いキャッシュがあり、main の更新後に marketplace dir 側の sync.sh を実行する
- **THEN** 終了コードは 0 で、snapshot とキャッシュの `skills/develop/SKILL.md` が更新後の main とバイト一致する

#### Scenario: 繰り返しても設定を変えない
- **WHEN** 更新済み状態で再実行する（対象と無関係な marketplace や disabled な設定も存在する）
- **THEN** 成功し、登録元・ref・有効無効設定が保たれ、無関係な marketplace を更新しない

### Requirement: 移行済み command skill も現行ソースから更新する

同期は `.codex-plugin/migrated-command-skills` を含む導入済み dev-workflow を現行ソースから再生成し、削除された command 由来の古い skill を残してはならない（MUST NOT）。キャッシュの version ディレクトリ名や plugin.json への version 追加を鮮度の根拠にしてはならない（MUST NOT）。

#### Scenario: command の変更と削除を反映する
- **WHEN** キャッシュに旧 command の移行スキルがあり、main でその command を削除し、別の command の本文を更新したあと sync.sh を実行する
- **THEN** 削除分の移行スキルは無く、残る command の移行スキルは更新後の本文を含み、native develop も main と一致する

### Requirement: 対象の選択と更新失敗を既存配線と両立する

CLI 未導入または対象の Git 登録が無い場合、Codex 更新を省略し既存配線を続けなければならない（MUST）。CLI がある場合の manifest/CLI JSON の読取・形式エラー、list/upgrade の失敗、upgrade 結果の errors 非空は警告し非0で終え、配線は可能な範囲で継続しなければならない（MUST）。`--no-pull` は実行元/overlay の pull を省略するが、Codex の別 snapshot の更新は省略しない（MUST）。

守備範囲: 入力は実行元 manifest と利用者が登録した marketplace を列挙・更新する CLI の JSON。拾う誤りは名前/種別の選択不能、JSON 不正と明示された更新失敗。正しい形式の local 登録や対象なしは省略として通す。Git ref の意図や skill 本文の意味は検査しない。入力のあらゆる穴を塞ぐことは完了条件にしない。

#### Scenario: Codex を使わない環境
- **WHEN** CLI が無い、または list が対象 Git 登録を含まない（local 登録だけの場合を含む）
- **THEN** Codex 設定やキャッシュを追加変更せず、配線に別のエラーが無ければ警告なしで終了コード 0

#### Scenario: 更新失敗を成功扱いしない
- **WHEN** list/upgrade が非0、JSON が不正、または upgrade が exit 0 でも errors が非空になる
- **THEN** 警告して終了コードを非0にし、公開 rules/output-styles の配線は行う

#### Scenario: pull 済みの呼出元からも Codex を更新する
- **WHEN** `sync.sh --no-pull` を対象 Git 登録がある環境で実行する
- **THEN** 実行元/overlay の git pull は呼ばず、Codex marketplace とキャッシュは更新する

### Requirement: main との一致を一時 HOME の bats で検証する

受け入れ検証は一時 HOME・CODEX_HOME・CLAUDE_CONFIG_DIR とローカル Git の main を用い、実ホームを書き換えてはならない（MUST NOT）。実 CLI で古いキャッシュを作ってから sync.sh を実行し、一致と移行スキル更新を確認しなければならない（MUST）。CLI が無く実 CLI 検証を skip した結果だけでは受け入れ完了としない（MUST NOT）。実ホームの一致の確認記録はマージ後に行う（MUST）。

#### Scenario: ネットワークも実ホームも不要な受け入れ検証
- **WHEN** 一時 HOME の Git 登録が指すローカル remote の main を進め、旧 snapshot/cache を残して、main を追う別 clone の sync.sh を実 CLI と実行する
- **THEN** main とのバイト一致と旧移行スキルの除去を確認でき、変更先は一時領域に収まる
