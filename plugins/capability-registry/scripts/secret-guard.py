#!/usr/bin/env python3
"""secret-guard — シークレットが transcript に出る形のコマンドを実行前に止める PreToolUse hook。

背景:
  PostToolUse では出力を書き換えられない（値はもう transcript に載っている）ので、
  防げる場所は「実行前」しかない。

方針:
  値が **画面に出る形** だけを止める。トークンを使うこと自体は止めない。
    NG: echo "$GH_TOKEN" / printenv / cat .env / op read op://... （素で実行）
    OK: GH_TOKEN="$(<値を返すコマンド>)" gh api ...  （コマンド置換で変数に入れる）
    OK: echo "${GH_TOKEN:+SET}"                      （存在確認だけで値は出ない）

  壊れたときは素通りさせる（fail-open）。ガードのバグで全作業が止まるほうが害が大きい。

無効化: hook プロセスの環境変数 CAPABILITY_REGISTRY_SECRET_GUARD=off（判定は secret-guard.sh）。
守備範囲の正本: openspec/specs/capability-registry-secret-guard/spec.md の要件「検査の守備範囲」。
"""
from __future__ import annotations  # macOS 同梱の python3 は 3.9 系。`str | None` を動かすため

import json
import re
import sys

# ── シークレットらしい環境変数名 ───────────────────────────────────────────
SECRET_VAR = re.compile(
    r"^[A-Z0-9_]*(TOKEN|SECRET|PASSWORD|PASSWD|API_?KEY|CREDENTIAL|PRIVATE_KEY|_PAT|_KEY)[A-Z0-9_]*$"
)

# ── シークレットらしいファイル ─────────────────────────────────────────────
SECRET_FILE = re.compile(
    r"(\.token\b|\.env\b|\.env\.[a-z]+|credentials?\b|\.pem\b|id_rsa\b|id_ed25519\b"
    r"|\.netrc\b|\.npmrc\b|\.pgpass\b|service[-_]account[^\s]*\.json)",
    re.IGNORECASE,
)
# 中身がダミーのテンプレート類は対象外
SAFE_FILE = re.compile(r"\.(example|sample|template|dist)\b|\.env\.example", re.IGNORECASE)

# 引数や変数を標準出力に吐くコマンド（チェック1: シークレット変数の露出）
DUMPERS = {
    "echo", "print", "printf", "say", "cat", "head", "tail", "less", "more",
    "bat", "xxd", "od", "strings", "base64", "open", "pbcopy", "tee",
}

# ファイルを読んで中身を出すコマンド（チェック3: 機密ファイルの表示）。
# echo / printf をここに入れると `echo "--- .env:"` のようなラベル出力を誤検出するため分けている。
FILE_READERS = {
    "cat", "head", "tail", "less", "more", "bat", "xxd", "od", "strings",
    "base64", "open", "pbcopy",
}

HINT = (
    "値を画面に出さずに使うこと:\n"
    '  VAR="$(<値を返すコマンド>)" cmd ...   # コマンド置換で変数へ\n'
    '  echo "${VAR:+SET}"                    # 存在確認だけなら :+ を使う'
)


def deny(reason: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": f"[secret-guard] {reason}\n\n{HINT}",
        }
    }))
    sys.exit(0)


def split_segments(cmd: str):
    """パイプ・リスト演算子・改行でざっくり分割する。クォートは厳密に見ない
    （誤って分割しても、先頭トークンが既知の危険コマンドでなければ何も起きない）。"""
    return [s.strip() for s in re.split(r"\|\||&&|[;|\n&]", cmd) if s.strip()]


def head_cmd(segment: str) -> str:
    """セグメントの実行コマンド名。VAR=value の前置きと $( の残骸は読み飛ばす。"""
    for tok in segment.split():
        tok = tok.lstrip("$({`")
        if not tok or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", tok):
            continue
        return tok.rsplit("/", 1)[-1]
    return ""


def secret_refs_exposed(segment: str) -> str | None:
    """セグメント内でシークレット変数が「値が出る形」で参照されていれば、その名前を返す。"""
    # ${VAR...} 形式
    for m in re.finditer(r"\$\{([^}]*)\}", segment):
        body = m.group(1)
        if body.startswith("#"):          # ${#VAR} = 長さ。値は出ない
            continue
        name = re.split(r"[:\-+?#%/\[]", body)[0]
        if not SECRET_VAR.match(name):
            continue
        if re.match(rf"^{re.escape(name)}:\+", body):   # ${VAR:+SET} = 値は出ない
            continue
        return name
    # $VAR 形式（波括弧なし）は常に値が出る
    for m in re.finditer(r"\$([A-Za-z_][A-Za-z0-9_]*)", segment):
        if SECRET_VAR.match(m.group(1)):
            return m.group(1)
    return None


def inside_substitution(cmd: str, pos: int) -> bool:
    """pos が $( ... ) の内側か（＝出力が変数に取り込まれ、画面には出ない）。"""
    before = cmd[:pos]
    return before.count("$(") > before.count(")") or before.count("`") % 2 == 1


def check_bash(cmd: str) -> None:
    # 1) 値を出すコマンドにシークレット変数を渡している
    for seg in split_segments(cmd):
        if head_cmd(seg) in DUMPERS:
            name = secret_refs_exposed(seg)
            if name:
                deny(f"${name} の値が画面（transcript）に出ます: {seg[:80]}")

    # 2) 環境変数の一覧表示
    for seg in split_segments(cmd):
        h = head_cmd(seg)
        if h == "printenv":
            deny("printenv は環境変数の値を画面に出します。")
        if h == "env":
            rest = seg.split()[1:]
            runs_command = False
            skip = False
            for tok in rest:
                if skip:
                    skip = False
                    continue
                if tok in ("-u", "--unset"):
                    skip = True
                    continue
                if tok.startswith("-") or "=" in tok:
                    continue
                runs_command = True
                break
            if not runs_command:
                deny("env の裸実行は環境変数の値を画面に出します。")

    # 3) 機密ファイルの表示。リダイレクト先（`> file`）は書き込みなので対象外
    for seg in split_segments(cmd):
        if head_cmd(seg) not in FILE_READERS:
            continue
        toks = seg.split()[1:]
        for i, tok in enumerate(toks):
            prev = toks[i - 1] if i else ""
            if tok.startswith(">") or prev.endswith(">"):
                continue
            if SECRET_FILE.search(tok) and not SAFE_FILE.search(tok):
                deny(f"機密ファイルの中身を画面に出そうとしています: {tok}")

    # 4) Keychain から値を取り出す
    if re.search(r"security\s+find-(generic|internet)-password[^|;&]*\s-(w|g)\b", cmd):
        deny("security の -w / -g は Keychain の値を画面に出します。")

    # 5) 1Password の値取得が、コマンド置換の外にある
    #    実行コマンド名で判定する（`ls .../op` を実行と誤読しないため）。
    #    ssh 越しのリモート実行までは追わない（head_cmd が ssh になり検査対象外）。
    for seg in split_segments(cmd):
        pos = cmd.find(seg)
        if pos < 0 or inside_substitution(cmd, pos):
            continue  # $( ) の中なら出力は変数に入るので安全
        toks = seg.split()
        h = head_cmd(seg)
        if h == "op" and len(toks) > 1:
            if toks[1] == "read":
                deny("op read の出力がそのまま画面に出ます。")
            if toks[1:3] == ["item", "get"] and ("--fields" in seg or "--reveal" in seg):
                deny("op item get --fields / --reveal の出力がそのまま画面に出ます。")


def check_read(path: str) -> None:
    if SECRET_FILE.search(path) and not SAFE_FILE.search(path):
        deny(
            f"機密ファイルを Read すると中身が transcript に載ります: {path}\n"
            "値を含まないファイルの誤検知なら、利用者に hook の環境変数 CAPABILITY_REGISTRY_SECRET_GUARD=off を相談する。"
        )


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # 入力が読めないなら素通り

    tool = data.get("tool_name", "")
    ti = data.get("tool_input", {}) or {}
    try:
        if tool == "Bash":
            check_bash(ti.get("command", "") or "")
        elif tool in ("Read", "NotebookRead"):
            check_read(ti.get("file_path", "") or "")
    except SystemExit:
        raise
    except Exception as e:  # ガードのバグで作業を止めない
        print(f"[secret-guard] 検査に失敗（素通りします）: {e}", file=sys.stderr)

    sys.exit(0)


if __name__ == "__main__":
    main()
