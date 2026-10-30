#!/usr/bin/env bash
# PreToolUse hook: シークレットの値が画面（transcript）に出る形の Bash と Read を実行前に止める。
# 判定の本体は隣の secret-guard.py。ここは無効化のスイッチと python3 の有無を見て起動するだけ。
#
# 無効化: hook プロセスの環境変数 CAPABILITY_REGISTRY_SECRET_GUARD=off
# （settings.json の env か起動時の環境で設定する。コマンド文字列の前置きでは効かない）。
#
# 全経路 fail-open で exit 0。python3 が本体を開けないと exit 2 になり、
# hook の exit 2 はツール呼び出しを止めてしまうので、exec せずに終了コードを捨てる。
# 拒否は stdout の JSON で伝わるので、終了コードに頼らない。

[ "${CAPABILITY_REGISTRY_SECRET_GUARD:-}" = "off" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0

python3 -I "${0%/*}/secret-guard.py"
exit 0
