# OpenSpec CLI 実機検証記録（change-1: openspec-degradation）

このドキュメントは change-1（openspec-degradation）のタスク 1.1 / 1.2 の成果物であり、
**preflight 判定スクリプト（`scripts/openspec-preflight.sh`）と orchestrator / exec の
OpenSpec 関連手順の一次ソース**である。design.md の Decision「検出基準は npx openspec
解決可能を正とする」「カスタムスキーマの出所」は本ファイルへの参照のみを持つ。確定値は
ここに一本化する（design.md には確定値を書かない）。

検証日: 2026-06-12
検証環境: macOS (darwin 25.5.0) / volta 管理の node + npx

---

## 1. バージョン乖離の確定（ギャップ 2 の解消）

この環境には openspec が 2 系統存在する:

| 系統 | バージョン | 解決パス | 検出コマンド |
|------|-----------|----------|-------------|
| volta グローバル | **1.2.0** | `/Users/oratta/.volta/bin/openspec` | `which openspec` / `command -v openspec` |
| npx ローカルキャッシュ | **0.23.0** | `~/.npm/_npx/<hash>/node_modules/.bin/openspec` | `npx --no-install openspec` |

### エビデンス（実コマンド出力）

```text
$ which openspec
/Users/oratta/.volta/bin/openspec
$ openspec --version
1.2.0

$ npx --no-install openspec --version
0.23.0   (exit 0)
```

`which openspec` はグローバル 1.2.0 を、`npx --no-install openspec` はキャッシュ済み
0.23.0 を返す。major が異なる（0.x vs 1.x）が、後述のとおり **本 change に関係する
サブコマンド構成は両系統で実質同等**（`apply` 不在・`instructions`/`new`/`schema fork`
あり）であった。

---

## 2. `openspec init --tools claude` の実機検証

素の repo（`/tmp/openspec-init-probe` に `git init` した一時ディレクトリ）で
グローバル 1.2.0 を使って検証した。

### エビデンス

```text
$ mkdir /tmp/openspec-init-probe && cd /tmp/openspec-init-probe && git init -q
$ openspec init --tools claude
- Creating OpenSpec structure...
▌ OpenSpec structure created
- Setting up Claude Code...
✔ Setup complete for Claude Code

OpenSpec Setup Complete
Created: Claude Code
10 skills and 10 commands in .claude/
Config: skipped (non-interactive mode)
(exit 0)

$ find openspec -type d
openspec
openspec/changes
openspec/changes/archive
openspec/specs

$ ls openspec/schemas
NO openspec/schemas dir
```

### 確定事項

- `openspec init --tools claude` は `openspec/{changes,changes/archive,specs}` と
  `.claude/`（10 skills + 10 commands）を生成する。**`openspec/config.yaml` は
  非対話モードでは生成されない**（"Config: skipped (non-interactive mode)"）。
- **`openspec/schemas/` は init では作られない。** カスタムスキーマ `longrun-tdd` は
  init の成果物ではない（ギャップ 2 の確定回答）。

---

## 3. カスタムスキーマ `longrun-tdd` の出所（ギャップ 2 の確定回答）

`longrun-tdd` スキーマは **init では入らず、`openspec schema fork` でのみ生まれる**。
claude-harness 固有の手順である。

### エビデンス

```text
$ openspec schema fork spec-driven longrun-tdd
Note: Schema commands are experimental and may change.
- Forking 'spec-driven' to 'longrun-tdd'...
✔ Forked 'spec-driven' to 'longrun-tdd'
Destination: /private/tmp/openspec-init-probe/openspec/schemas/longrun-tdd
(exit 0)

$ find openspec/schemas
openspec/schemas/longrun-tdd
openspec/schemas/longrun-tdd/schema.yaml
openspec/schemas/longrun-tdd/templates/design.md
openspec/schemas/longrun-tdd/templates/proposal.md
openspec/schemas/longrun-tdd/templates/spec.md
openspec/schemas/longrun-tdd/templates/tasks.md
```

### 確定事項

- `longrun-tdd` の生成には `openspec schema fork spec-driven longrun-tdd` が必須。
  fork 後、claude-harness 固有の `templates/longrun-tdd-schema/{apply.md,propose.md}`
  を `openspec/schemas/longrun-tdd/templates/` にコピーするのが orchestrator SKILL.md
  L129-135 の従来手順。fork が作る `templates/` には `apply.md` / `propose.md` は
  含まれない（design/proposal/spec/tasks の 4 本のみ）ため、コピー手順は引き続き必要。
- `schema fork` / `schemas` / `schema init` 等は両系統で `[experimental]` 扱い。

---

## 4. `openspec apply` の不在（重要な乖離の確定）

**1.2.0・0.23.0 のどちらにも `openspec apply` コマンドは存在しない。**
`openspec apply` を叩くとルートヘルプにフォールスルーし（apply は未知のサブコマンド扱い）、
TDD 適用は `openspec instructions tasks` 系に置き換わっている。

### エビデンス（1.2.0 サブコマンド一覧）

```text
$ openspec --help | sed -n '/Commands:/,$p'
  init / update / list / view / change / archive / spec / config /
  schema / validate / show / feedback / completion / status /
  instructions [artifact]  Output enriched instructions for creating an
                           artifact or applying tasks
  templates / schemas / new / help
（apply は無い）

$ openspec apply --help   # → ルートヘルプにフォールスルー（apply 未定義）
```

### エビデンス（0.23.0 サブコマンド一覧）

```text
$ npx --no-install openspec --help | sed -n '/Commands:/,$p'
  init / update / list / view / change / archive / spec / config /
  schema / validate / show / feedback / completion /
  status [Experimental] / instructions [Experimental] /
  templates / schemas / new / artifact-experimental-setup / help
（apply は無い）
```

### 確定事項（実装方針への帰結）

- orchestrator / builder の従来手順にある `openspec apply <change-name>` は
  **現行 CLI に存在しない**。通常モードでも `apply` の代替は `openspec instructions
  tasks --change <id>` で得た指示に従って TDD を回す形になる。本 change（change-1）は
  「通常モードの従来挙動を変えない（回帰なし）」が制約のため、**通常モードフローの
  apply→instructions 置換は本 change のスコープに含めない**（change-2 の exec 全面
  書き換えで扱う）。本 change が新設するのは縮退モードであり、縮退モードは CLI を
  一切呼ばないため apply 不在の影響を受けない。

---

## 5. preflight 検出コマンド系列の確定（タスク 1.2）

design.md の暫定決定（B: `npx openspec` 解決可能を正とする）を実機検証で最終確定する。

### 確定した検出系列（`scripts/openspec-preflight.sh` が実装する）

1. **CLI 解決チェック**: 以下のいずれかが成功すれば CLI 解決可能とみなす（OR 条件）:
   ```sh
   command -v openspec >/dev/null 2>&1      # volta グローバル等 PATH 上の openspec
   npx --no-install openspec --version       # repo node_modules / npx キャッシュ
   ```
   - plan.md 受け入れ条件 5 は「`npx openspec` が解決できない環境で」と明示するため
     **npx 解決可能性を一次基準**とするが、グローバル `openspec` が PATH にある環境
     （この環境の volta 1.2.0）も正として扱う。両方失敗したときのみ `NO_CLI`。
   - `npx --no-install` を使う理由: ネットワークアクセスやインストール待ちを発生させず、
     **既に解決できる openspec があるか**だけを判定するため（CI / オフラインでも安全）。
   - bats では PATH を空にして `command -v` を失敗させ、`OPENSPEC_PREFLIGHT_NPX_CMD`
     環境変数で npx 呼び出しを stub する（実 npx を叩かない）ことでシミュレートする。

2. **init 済みチェック**: git root 直下に `openspec/` ディレクトリが存在するか:
   ```sh
   test -d "$(git rev-parse --show-toplevel)/openspec"
   ```

### 判定値（標準出力 + exit code）

| 標準出力 | exit code | 条件 |
|----------|-----------|------|
| `OK`      | 0 | CLI 解決可能 **かつ** `openspec/` 存在 |
| `NO_CLI`  | 0 | CLI が解決できない（init 判定より優先） |
| `NO_INIT` | 0 | CLI は解決可能だが `openspec/` が無い |

判定値は標準出力で返し、判定の成否（スクリプト自体が正常終了したか）は exit 0 で表す。
対話（AskUserQuestion による縮退提案）は exec.md 側が標準出力の値を見て行う
（スクリプトからは対話しない）。

### 未インストール環境への導入案内文言（確定）

`NO_CLI` 時に exec.md が「中断」を選んだユーザーに提示する案内:

```text
OpenSpec CLI が解決できませんでした。通常モードで使うには、以下のいずれかでセットアップしてください:

  # グローバル（volta 管理）
  volta install @fission-ai/openspec
  # または npm グローバル
  npm install -g @fission-ai/openspec

その後 repo で:
  openspec init --tools claude
  openspec schema fork spec-driven longrun-tdd   # カスタムスキーマ longrun-tdd を用意

セットアップ後に再度 /lr:e を実行してください。
（OpenSpec を使わずに進める場合は、再実行時に「縮退モード」を選択してください）
```

`NO_INIT` 時（CLI はあるが未 init）の案内:

```text
このリポジトリは openspec が未初期化です。通常モードで続行するには:
  openspec init --tools claude
  openspec schema fork spec-driven longrun-tdd

「openspec init して通常続行」を選ぶとこの初期化を実行します。
「縮退モード」を選ぶと openspec/ を作らずに run を進めます。
```

---

## 6. まとめ（実装が依存する確定事項）

1. preflight の正系統は **「`command -v openspec` または `npx --no-install openspec`
   のいずれかが解決可能」**。両方失敗で `NO_CLI`。
2. `longrun-tdd` スキーマは **init では入らない**。`schema fork` + テンプレートコピーが
   必須（claude-harness 固有手順）。
3. **`openspec apply` は現行 CLI に存在しない**（1.2.0 / 0.23.0 とも）。縮退モードは CLI を
   呼ばないため影響なし。通常モードの apply→instructions 置換は change-2 のスコープ。
4. 縮退モードは上記いずれの CLI 仕様にも依存しない（CLI を一切呼ばない）ため、
   バージョン乖離の影響を受けない。これが「一級の動作モード」として縮退を定義する
   設計の頑健性の根拠でもある。
