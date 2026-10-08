#!/usr/bin/env bash
# PreModelSwitch hook: モデル切替の直前に、会話を切替先のモデルで読み直すトークン数と、
# キャッシュ書き込みの推定費用を systemMessage で知らせる（issue #714）。
#
# 返すのは {"systemMessage": "..."} だけ。decision・hookSpecificOutput（permissionDecision）・
# continue は返さない（切替を止めず、本体の確認画面も飛ばさない）。
#
# この event では exit 2 と時間切れが切替を止め、0 と 2 以外の終了コードは標準エラーが画面に出る。
# だから、どの失敗でも無出力・exit 0・標準エラー空にする。待ちが発生しないよう、stdin だけを読み、
# ネットワークにもファイルにも触らない（入力の transcript_path は開かない）。
#
# 出さない条件: prompt_cache_warm が false／context_tokens が 0／伝える数字が無い／
# hook_event_name が PreModelSwitch でない／入力が読めない／python3 が無い。
# 仕様: openspec の dev-workflow-model-switch-recache-notice
set -uo pipefail

command -v python3 >/dev/null 2>&1 || exit 0

# Python 本体は fd 3 のヒアドキュメントで渡し、payload は stdin のまま読ませる
# （環境変数や引数に載せない）。
# -I（隔離モード）で起動し、PYTHONPATH などの PYTHON* の環境変数・ユーザー site・スクリプトの
# ディレクトリを検索パスに使わない（hook を起動した環境に置かれた json.py などを読み込まない）。
python3 -I /dev/fd/3 3<<'PY' 2>/dev/null || true
import json, math, sys


def number(v):
    # 真偽値は数値とみなさない。NaN・無限大も弾く。
    if isinstance(v, bool) or not isinstance(v, (int, float)):
        return None
    if not math.isfinite(v):
        return None
    return v


def clean(v):
    # 空でない文字列だけを通し、制御文字（U+0000〜U+001F と U+007F）を除く。
    if not isinstance(v, str):
        return ""
    return "".join(c for c in v if ord(c) > 0x1F and ord(c) != 0x7F)


PRICING = {
    "catalog": "定価",
    "configured": "組織の設定単価",
    "default": "単価が不明なため既定の単価で計算",
}


def build(d):
    if not isinstance(d, dict):
        return None
    if d.get("hook_event_name") != "PreModelSwitch":
        return None
    warm = d.get("prompt_cache_warm")
    if warm is False:
        return None

    tokens = number(d.get("context_tokens"))
    cost = number(d.get("estimated_cache_write_usd"))
    if tokens is not None and tokens == 0:
        return None
    tokens_ok = tokens is not None and tokens > 0
    cost_ok = cost is not None and cost >= 0
    if not tokens_ok and (not cost_ok or cost == 0):
        return None

    head = "モデル切替"
    src, dst = clean(d.get("from_model")), clean(d.get("to_model"))
    if src and dst:
        head += f"（{src} → {dst}）"
    parts = []
    if tokens_ok:
        parts.append(f"会話の約 {round(tokens):,} トークンを切替先のモデルで読み直します。")
    if cost_ok:
        amount = "$0.01 未満" if 0 < cost < 0.01 else f"${cost:.2f}"
        pricing = d.get("pricing")
        note = PRICING.get(pricing) if isinstance(pricing, str) else None
        if note:
            amount += f"（{note}）"
        parts.append(f"キャッシュ書き込みの推定費用は {amount}。")
    if warm is True:
        parts.append("切替前のモデルのキャッシュは、切り替えると使えなくなります。")
    return head + ": " + "".join(parts)


try:
    msg = build(json.loads(sys.stdin.buffer.read()))
    if msg:
        out = json.dumps({"systemMessage": msg}, ensure_ascii=False) + "\n"
        sys.stdout.buffer.write(out.encode("utf-8"))
        sys.stdout.buffer.flush()
except Exception:
    pass
PY
exit 0
