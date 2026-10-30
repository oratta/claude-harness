# Proposal

## Why

トークンの値を transcript に出す形のコマンドを実行前に止める secret-guard フックは、オーナーの端末の `~/.claude/hooks/` に手で置かれ、`~/.claude/settings.json` へ手で配線されている。casting の `catalog/injection.md` はこれを常時効く安全装置として挙げているのに、harness のプラグインを全部入れても入らない。2026-10-23 に新しい端末をセットアップしてこの抜けが分かった（#1233。エピック #1237 の子）。

## What Changes

- capability-registry プラグインに secret-guard の検査スクリプトを足し、`hooks/hooks.json` の PreToolUse で `Bash` と `Read` に配線する。`settings.json` は触らない
- 検査の判定は今の挙動のまま移す。値が画面に出る形（`echo "$GH_TOKEN"`、`printenv`、機密ファイルの表示など）を止め、コマンド置換で変数に入れて使う形は止めない
- 公開リポジトリに入れるので、個人の道具の名前・個人のパス・個人の経緯を外す。個人の道具 1 本に専用だった検査は公開版に持ち込まない
- 手で配線を外すと無効化の手段が無くなるので、プラグインの他の機能を残したまま止められる環境変数を足す
- `plugins/casting/catalog/injection.md` の配線場所をプラグイン側に更新し、README の導入の案内と `docs/public-private-split.md` の仕分けの表に足す
- 手で配線した環境から外す手順を変更の記録に書く（二重に走らないように）

## Capabilities

### New Capabilities

- `capability-registry-secret-guard`: シークレットが transcript に出る形の Bash と Read を実行前に止める、capability-registry 同梱の PreToolUse hook

### Modified Capabilities

なし（`casting-injection-map` の要件は配線場所の文言を定めていない。`injection.md` の更新は新しい capability の要件として書く）

## Impact

- `plugins/capability-registry/`: `hooks/hooks.json`、`scripts/` に 2 本追加、`tests/` に 1 本追加、`.claude-plugin/plugin.json` の keywords、`changes/1233.md`
- `plugins/casting/`: `catalog/injection.md`、`changes/1233.md`
- `tests/hook-python-isolation.bats`: 新しい hook の python3 の隔離を検査する
- `README.md`・`docs/public-private-split.md`
- capability-registry を入れたすべての環境で、Bash と Read の実行前に hook が走り、機密ファイルの Read と値の表示が拒否されるようになる
- 依存: python3（無ければ検査せず通す）
- 主の端末の `~/.claude/settings.json` と `~/.claude/hooks/` はこの変更では触らない。外すのは主の手順
