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
#   本スクリプトはその2点セットを冪等な1コマンドにする。定期実行の足は
#   flatmate 住人の起動ルーティン（boot.sh）が担い、鮮度のPC横断可視化は
#   flatmate の agent-status ハートビートが担う。
#
# 使い方:
#   scripts/sync.sh            # git pull（ff-only）→ symlink 張り直し
#   scripts/sync.sh --no-pull  # symlink のみ（pull を呼び出し側 repo-sync が済ませている場合）
#
# 挙動:
#   - pull は ff-only。tracked ファイルが dirty ならスキップする（作業を壊さない。
#     flatmate の repo-sync.sh と同じ思想）。pull 失敗・dirty スキップでも symlink 配線は続行
#   - rules/*.md → ~/.claude/rules/、output-styles/*.md → ~/.claude/output-styles/ に symlink
#   - 同名の「実ファイル」が既にある場合: 内容が同一なら symlink に置き換え（正本の一本化）、
#     異なるなら触らず警告して非0（ローカル版を勝手に潰さない）
#   - この harness を指す壊れた symlink は削除する（rename/削除されたファイルの掃除。
#     ローカル実ファイルと他所を指す symlink には触らない）
#   - Output Style の有効化（settings の outputStyle）は書き換えない。ファイルを届けるまでが
#     本スクリプトの仕事で、どのスタイルを使うかは PC ごとの主の設定に残す
#   - テスト用に CLAUDE_CONFIG_DIR で ~/.claude を差し替え可能
#
# 終了コード: 0=配線完了 / 非0=pull 失敗 or 実ファイル衝突あり（配線自体は可能な範囲で完了）
# ─────────────────────────────────────────────────────────────
set -u

HARNESS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
rc=0

if [ "${1:-}" != "--no-pull" ]; then
  # dirty 判定は「追跡ファイルの変更のみ」（--untracked-files=no。repo-sync.sh と同じ理由:
  # marketplace dir には untracked の実行時ファイルが常駐しうるため、untracked を dirty 扱いすると
  # pull が恒久スキップされる）。untracked が pull で上書きされる心配は不要 — merge/checkout は
  # 未追跡（非 ignored）ファイルを上書きせず "Aborting" で止まる（2026-08-17 実測済み）。
  # git コマンド自体の失敗（clone 破損等）は dirty と区別して非0で知らせる。
  if dirty="$(git -C "$HARNESS_DIR" status --porcelain --untracked-files=no 2>/dev/null)"; then
    if [ -n "$dirty" ]; then
      echo "[harness-sync] tracked ファイルが dirty のため pull をスキップしました（作業保護。symlink 配線は続行）" >&2
    elif ! git -C "$HARNESS_DIR" pull --ff-only >/dev/null; then
      echo "[harness-sync] pull（ff-only）に失敗しました。clone が origin と分岐しているかネットワーク断です（symlink 配線は続行）" >&2
      rc=1
    fi
  else
    echo "[harness-sync] git 状態を取得できません（clone 破損の可能性）。pull をスキップします（symlink 配線は続行）" >&2
    rc=1
  fi
fi

link_dir() {
  # $1=正本ディレクトリ $2=配線先ディレクトリ
  src="$1"; dst="$2"
  [ -d "$src" ] || return 0
  if ! mkdir -p "$dst" 2>/dev/null; then
    echo "[harness-sync] 配線先を作成できません: $dst" >&2
    rc=1
    return 0
  fi

  # この harness を指す壊れた symlink を掃除する
  for l in "$dst"/*.md; do
    [ -L "$l" ] || continue
    case "$(readlink "$l")" in
      "$HARNESS_DIR"/*) [ -e "$l" ] || rm -f "$l" || rc=1 ;;
    esac
  done

  for f in "$src"/*.md; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    [ "$base" = "README.md" ] && continue
    t="$dst/$base"
    if [ -L "$t" ]; then
      cur="$(readlink "$t")"
      if [ "$cur" != "$f" ]; then
        case "$cur" in
          "$HARNESS_DIR"/*)
            # この harness 内の旧パスを指す symlink だけ張り替える
            ln -sfn "$f" "$t" || { echo "[harness-sync] symlink を更新できません: $t" >&2; rc=1; } ;;
          *)
            # harness と無関係な symlink には触らない（README の約束）
            echo "[harness-sync] $t は harness 外（${cur}）を指す symlink のため触りません（手動で統合してください）" >&2
            rc=1 ;;
        esac
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

link_dir "$HARNESS_DIR/rules" "$CLAUDE_DIR/rules"
link_dir "$HARNESS_DIR/output-styles" "$CLAUDE_DIR/output-styles"

exit "$rc"
