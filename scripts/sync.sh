#!/bin/sh
# ─────────────────────────────────────────────────────────────
# sync.sh — harness の正本（rules/ と output-styles/）をこの PC の ~/.claude に配線する
#
# なぜ存在するか（flatmate#362）:
#   rules/ と output-styles/ はプラグインではないため、plugin install/update の
#   配布機構に乗らない。従来の配布は「clone を手で pull ＋ ~/.claude/rules/ へ
#   手で symlink」の手作業2点セットで、実行されなかった PC には正本が一切届かず、
#   古びても誰も気づかなかった（2026-08-17 実測: Air は rules/ ディレクトリ誕生前の
#   clone のまま約30 PR 遅れ、~/.claude/rules 自体が存在しなかった）。
#   本スクリプトはその2点セットを冪等な1コマンドにする。定期実行は
#   利用者の環境が担い（cron など）、鮮度のPC横断可視化も利用者の環境の見張りに任せる。
#
# 使い方:
#   scripts/sync.sh            # git pull（ff-only）→ symlink 張り直し
#   scripts/sync.sh --no-pull  # symlink のみ（pull を呼び出し側 repo-sync が済ませている場合）
#
# 挙動:
#   - pull は ff-only。tracked ファイルが dirty ならスキップする（作業を壊さない。
#     定期実行の repo-sync と同じ思想）。pull 失敗・dirty スキップでも symlink 配線は続行
#   - rules/*.md → ~/.claude/rules/claude-harness/（出どころごとのサブディレクトリ。#1130）、
#     output-styles/*.md → ~/.claude/output-styles/ に symlink。旧位置（~/.claude/rules/ 直下）の
#     この harness を指す symlink は、新位置に張ったあとで消す
#   - overlay（この harness に重ねる別の harness）: ~/.claude/plugins/marketplaces/*/ の直下に
#     .harness-overlay（1 行目がサブディレクトリ名。[a-z0-9][a-z0-9-]*）を持つディレクトリ。
#     その rules/*.md は ~/.claude/rules/claude-harness/<名前>/ に、output-styles/*.md は
#     ~/.claude/output-styles/ 直下（同名は公開側優先で、重なる側を警告）に symlink する。
#     名前が不正・重複・同名の実ファイルとぶつかる overlay は警告して飛ばす。無ければ何も出さない
#   - 同名の「実ファイル」が既にある場合: 内容が同一なら symlink に置き換え（正本の一本化）、
#     異なるなら触らず警告して非0（ローカル版を勝手に潰さない）
#   - 壊れた symlink のうち、行き先がこの harness か ~/.claude/plugins/marketplaces/ の下のものは
#     削除する（rename/削除されたファイルや外した overlay の掃除。ローカル実ファイルと
#     他所を指す symlink には触らない）
#   - Output Style の有効化（settings の outputStyle）は書き換えない。ファイルを届けるまでが
#     本スクリプトの仕事で、どのスタイルを使うかは PC ごとの主の設定に残す
#   - テスト用に CLAUDE_CONFIG_DIR で ~/.claude を差し替え可能
#
# 終了コード: 0=配線完了 / 非0=pull 失敗 or 実ファイル衝突あり（配線自体は可能な範囲で完了）
# ─────────────────────────────────────────────────────────────
set -u

HARNESS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
MP_DIR="$CLAUDE_DIR/plugins/marketplaces"
PUB_DST="$CLAUDE_DIR/rules/claude-harness"
rc=0

# dirty 判定は「追跡ファイルの変更のみ」（--untracked-files=no。repo-sync.sh と同じ理由:
# marketplace dir には untracked の実行時ファイルが常駐しうるため、untracked を dirty 扱いすると
# pull が恒久スキップされる）。untracked が pull で上書きされる心配は不要 — merge/checkout は
# 未追跡（非 ignored）ファイルを上書きせず "Aborting" で止まる（2026-08-17 実測済み）。
# git コマンド自体の失敗（clone 破損等）は dirty と区別して非0で知らせる。
pull_repo() {
  if dirty="$(git -C "$1" status --porcelain --untracked-files=no 2>/dev/null)"; then
    if [ -n "$dirty" ]; then
      echo "[harness-sync] tracked ファイルが dirty のため pull をスキップしました（作業保護。symlink 配線は続行）: $1" >&2
    elif ! git -C "$1" pull --ff-only >/dev/null; then
      echo "[harness-sync] pull（ff-only）に失敗しました。clone が origin と分岐しているかネットワーク断です（symlink 配線は続行）: $1" >&2
      rc=1
    fi
  else
    echo "[harness-sync] git 状態を取得できません（clone 破損の可能性）。pull をスキップします（symlink 配線は続行）: $1" >&2
    rc=1
  fi
}

if [ "${1:-}" != "--no-pull" ]; then
  pull_repo "$HARNESS_DIR"
fi

# 行き先がこの harness か marketplace の下の壊れた symlink を消す。$1=ディレクトリ
# 消したら PRUNED=1。overlay を外すと印のファイルも消えるので、所有元は行き先の文字列で決める
prune_dangling() {
  PRUNED=0
  for l in "$1"/*.md; do
    [ -L "$l" ] || continue
    [ -e "$l" ] && continue
    case "$(readlink "$l")" in
      "$HARNESS_DIR"/*|"$MP_DIR"/*) rm -f "$l" && PRUNED=1 || rc=1 ;;
    esac
  done
}

link_dir() {
  # $1=正本ディレクトリ $2=配線先ディレクトリ $3=この正本の根（旧パスの張り替え対象）
  # $4=1 のとき、行き先が marketplace の下（別の harness）の symlink も張り替える（公開側の優先）
  src="$1"; dst="$2"; own="$3"; displace="${4:-0}"
  [ -d "$src" ] || return 0
  if ! mkdir -p "$dst" 2>/dev/null; then
    echo "[harness-sync] 配線先を作成できません: $dst" >&2
    rc=1
    return 0
  fi

  for f in "$src"/*.md; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    [ "$base" = "README.md" ] && continue
    t="$dst/$base"
    if [ -L "$t" ]; then
      cur="$(readlink "$t")"
      if [ "$cur" != "$f" ]; then
        replace=0
        case "$cur" in
          "$own"/*) replace=1 ;;
          "$MP_DIR"/*) [ "$displace" = 1 ] && replace=1 ;;
        esac
        if [ "$replace" = 1 ]; then
          ln -sfn "$f" "$t" || { echo "[harness-sync] symlink を更新できません: $t" >&2; rc=1; }
        else
          # harness と無関係な symlink には触らない（README の約束）。重なる側の同名もここ
          echo "[harness-sync] $t は ${cur} を指す別の symlink のため触りません（同名の重なりか手動の symlink。手動で統合してください）" >&2
          rc=1
        fi
      fi
    elif [ -e "$t" ]; then
      if cmp -s "$f" "$t"; then
        # 内容同一の実ファイルは symlink 化する（コピー運用から正本一本化への移行）
        ln -sfn "$f" "$t" || { echo "[harness-sync] symlink 化に失敗しました: $t" >&2; rc=1; }
      else
        echo "[harness-sync] $t は harness と内容の異なる実ファイルのため触りません（手動で統合してください）" >&2
        rc=1
      fi
    else
      ln -s "$f" "$t" || { echo "[harness-sync] symlink を作成できません: $t" >&2; rc=1; }
    fi
  done
}

# 公開側（rules は出どころごとのサブディレクトリ、output style は直下）
link_dir "$HARNESS_DIR/rules" "$PUB_DST" "$HARNESS_DIR" 1
link_dir "$HARNESS_DIR/output-styles" "$CLAUDE_DIR/output-styles" "$HARNESS_DIR" 1

# 旧位置（rules 直下）の、この harness の rules を指す symlink を、新位置に張ったあとで消す
for f in "$HARNESS_DIR"/rules/*.md; do
  [ -f "$f" ] || continue
  t="$CLAUDE_DIR/rules/$(basename "$f")"
  if [ -L "$t" ] && [ "$(readlink "$t")" = "$f" ]; then
    rm -f "$t" || rc=1
  fi
done

# overlay を重ねる
seen=" "
for d in "$MP_DIR"/*/; do
  d="${d%/}"
  [ -f "$d/.harness-overlay" ] || continue
  [ "$d" = "$HARNESS_DIR" ] && continue
  oname="$(head -n 1 "$d/.harness-overlay" 2>/dev/null | tr -d '\r')"
  if ! printf '%s\n' "$oname" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
    echo "[harness-sync] overlay の名前が空か不正のため飛ばします（$d/.harness-overlay の 1 行目は [a-z0-9][a-z0-9-]*）" >&2
    rc=1
    continue
  fi
  case "$seen" in
    *" $oname "*)
      echo "[harness-sync] overlay の名前 $oname が重複しているため飛ばします: $d" >&2
      rc=1
      continue ;;
  esac
  seen="$seen$oname "
  if [ -e "$PUB_DST/$oname" ] && { [ -L "$PUB_DST/$oname" ] || [ ! -d "$PUB_DST/$oname" ]; }; then
    echo "[harness-sync] $PUB_DST/$oname が実ファイルか symlink のため overlay を飛ばします: $d" >&2
    rc=1
    continue
  fi
  if [ "${1:-}" != "--no-pull" ]; then
    pull_repo "$d"
  fi
  link_dir "$d/rules" "$PUB_DST/$oname" "$d" 0
  link_dir "$d/output-styles" "$CLAUDE_DIR/output-styles" "$d" 0
done

# 掃除（外した overlay の壊れた symlink と、空になったサブディレクトリ）
prune_dangling "$CLAUDE_DIR/rules"
prune_dangling "$PUB_DST"
for sub in "$PUB_DST"/*/; do
  sub="${sub%/}"
  [ -d "$sub" ] && [ ! -L "$sub" ] || continue
  prune_dangling "$sub"
  [ "$PRUNED" = 1 ] && rmdir "$sub" 2>/dev/null
done
prune_dangling "$CLAUDE_DIR/output-styles"

exit "$rc"
