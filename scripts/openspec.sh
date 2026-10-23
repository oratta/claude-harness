#!/usr/bin/env bash
# openspec.sh — このリポジトリで検証に使う openspec CLI の版を固定して呼ぶ（issue #1273）。
# 版の正本は openspec/CLI_VERSION の 1 か所。1.13 以降の CLI は既存 spec を strict 検証で
# 落とすため、手元に入っている版ではなくこの版を npx で一時実行する（グローバル install はしない）。
# 使い方: scripts/openspec.sh validate --specs --strict
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ver="$(tr -d '[:space:]' < "$root/openspec/CLI_VERSION")"
exec npx --yes "@fission-ai/openspec@${ver}" "$@"
