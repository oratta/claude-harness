#!/usr/bin/env bash
# 使い捨ての git repo を作業ディレクトリ直下に作る。notes.txt に未コミットの変更を残す。
set -euo pipefail
git init -q .
git config user.email eval@example.com
git config user.name eval
git config commit.gpgsign false
echo "committed line" > notes.txt
git add notes.txt
git commit -q -m "initial"
echo "UNCOMMITTED-WORK" >> notes.txt
