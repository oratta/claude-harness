## ADDED Requirements

### Requirement: カタログ正本の存在と構成

`plugins/casting/catalog/catalog.md` は観点カタログの唯一の正本として存在しなければならない (MUST)。front matter に `version`（整数、初期値 1）を持ち、本文に①列定義（凡例: 観点／この観点が要る論点の条件／判断基準の出どころ／移譲に必要な文書／既定の担い手 の5列の意味）②3グループ14観点の表（グループA 守り6観点・グループB 前進6観点・グループC 主に固有2観点。内容は oratta/claude-harness#112 の表と一致）③横断軸2つ（可逆性・影響範囲＝乗数、能力・権限の借用＝手の借用）④変更手続き⑤変更記録（追記型: 日付・何を・なぜ・きっかけの判例）の5節を含まなければならない (MUST)。

#### Scenario: カタログに version と14観点が入っている

- **WHEN** `plugins/casting/catalog/catalog.md` を読む
- **THEN** front matter に `version: 1` があり、観点の表の行数が全グループ合計で14である

#### Scenario: 列定義がカタログ内に存在する

- **WHEN** catalog.md の凡例節を読む
- **THEN** 5列すべての名前と意味の定義が本文に含まれている

### Requirement: 観点語彙の固定

配役表（project.md / local.md）と判例台帳（precedents.md）に書く観点名は、catalog.md に存在する観点名、または「カタログ外」のいずれかでなければならない (MUST)。それ以外の語彙は `casting-check.sh` が未知語彙として検出しなければならない (MUST)。

#### Scenario: 未知の観点語彙が検出される

- **WHEN** カタログに存在しない観点名を含む配役表フィクスチャに対して `casting-check.sh` を実行する
- **THEN** 当該の語彙とファイルが一覧表示され、exit code が 1 になる

### Requirement: カタログの変更手続き

catalog.md は変更手続きとして、軽量ルート（配役の変更＝担い手・移譲に必要な文書の中身。エージェント→主へ戻す方向は即時、主→エージェントへ移す方向は文書整備＋主承認）と重量ルート（構造の変更＝観点の追加・削除・統合・分割・列定義変更。version 増加＋変更記録追記＋主承認必須）の2ルートを明記しなければならない (MUST)。

#### Scenario: 変更手続きの2ルートが明記されている

- **WHEN** catalog.md の変更手続き節を読む
- **THEN** 軽量ルートと重量ルートの区別、および重量ルートの3条件（version 増加・変更記録・主承認）が読み取れる

### Requirement: 常時ロード層の返信前チェック rule

`rules/perspective-casting.md` は返信前チェック5手順（①聖域か→無条件人間承認 ②論点に必要な観点の特定 ③担い手は主か ④主でないなら送らず自走で決め直す ⑤結果を判例台帳に記録）と正本（catalog.md・casting スキル）へのポインタを持たなければならない (MUST)。ファイルは30行以内でなければならず (MUST)、カタログ本文を複製してはならない (MUST NOT)。`rules/README.md` のファイル一覧に掲載されなければならない (MUST)。

#### Scenario: rule が薄く保たれている

- **WHEN** `rules/perspective-casting.md` の行数を数える
- **THEN** 30行以内であり、5手順と正本へのパスが含まれている

#### Scenario: README の一覧に載っている

- **WHEN** `rules/README.md` のファイル一覧表を読む
- **THEN** `perspective-casting.md` の行が存在する
