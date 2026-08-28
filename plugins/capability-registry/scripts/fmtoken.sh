#!/usr/bin/env bash
# fmtoken — 1Password agents 保管庫のトークン取得・登録ラッパー
#
# エージェントが「このプロジェクトのセッションです」と名乗る代わりに、
# origin remote のリポ名からプロジェクトを機械的に導出し、1Password の
# agents 保管庫（read-only Service Account 経由）から正しいトークンだけを返す。
#
# 使い方（トークンを transcript に出さないため、必ずコマンド置換で使う）:
#   GITHUB_TOKEN="$(fmtoken.sh github)" gh api ...
#   SUPABASE_ACCESS_TOKEN="$(fmtoken.sh supabase)" supabase projects list
#
# 存在確認だけしたい時:
#   fmtoken.sh --check <service>   # 値を出力せず 0/44 で返す
#   fmtoken.sh --list              # このプロジェクトに登録済みのサービス一覧
#
# 明示名での参照（エージェント名接頭辞 <agent>--<SERVICE> はプロジェクト導出で
# 引けないため、アイテム名をそのまま渡す。プロジェクト名接頭辞のアイテムにも使える）:
#   TRELLO_TOKEN="$(fmtoken.sh --name moko--TRELLO_TOKEN)"
#   fmtoken.sh --check --name moko--TRELLO_TOKEN
#
# 登録（正規手順は CLI 代行。read = claude-agents-ro / register = claude-agents-rw の
# 役割分担。値は argv でなく stdin で渡す — transcript / ps への露出を避けるため。
# 内部で起動する op へも JSON テンプレートを stdin で渡す。assignment statement
# 形式（credential[password]=...）に戻すと op プロセスの argv 経由で ps に露出する。
# 値はシェル変数にも載せない — stdin を読むのは python 1 か所だけで、そこから op まで
# パイプで直行する）:
#   printf '%s' "$VALUE" | fmtoken.sh --register <project|agent>--<service>
#
# exit code: 0 成功 / 43 SA トークン未配布 / 44 未登録 / 45 プロジェクト導出不能 /
#            46 命名規約違反・入力不正（stdin が tty・空・非 UTF-8・閉じられている）/
#            47 登録済みアイテムへの二重登録 /
#            48 二重登録判定の不能（読み取り用 SA が解決できない・op item list 失敗 — fail-closed）/
#            49 環境障害（値を運ぶ producer が起動できない・値を書き終える前に異常終了 — fail-closed。
#               46 と分けるのは「入力を直せ」と「このマシンを直せ」を呼び出し側が区別するため。issue #181）
set -euo pipefail

OP_VAULT="agents"
KEYCHAIN_SERVICE_RO="op-sa-claude-agents-ro"
KEYCHAIN_SERVICE_RW="op-sa-claude-agents-rw"

# ── 秘密を扱う区間だけ xtrace を落とす（issue #159）──
# `bash -x fmtoken.sh --register ...` や SHELLOPTS=xtrace を継承した起動では、秘密を代入する行が
# `+ rw=<SA トークン>` として**呼び出し側自身の stderr** に出る。#130 が塞いだのは `ps`（他プロセスからの
# 観測）で、こちらは脅威モデルが別（自プロセスの stderr）だが、CI ログや tee したファイルに
# 残ると回収できない。
#
# 登録する値そのものはもうシェル変数を通らない（issue #170。stdin → python → op のパイプだけ）ので、
# この抑止が要るのは SA トークンを変数に載せる resolve_ro_token / resolve_rw_token の区間だけ。
#
# 常時 off にはしない。呼び出し側が `-x` でデバッグする手段を丸ごと奪うことになるので、
# 秘密の代入区間に入る前に落とし、抜けたら**元の状態に戻す**（起動時に off だったなら off のまま）。
# 早期 exit する経路でも、秘密の参照が終わった時点で戻してから message / exit に進む。
XTRACE_WAS_ON=""
case "$-" in *x*) XTRACE_WAS_ON=1 ;; esac
# 末尾の `return 0` は必須。`[[ ... ]] && set +x` は条件が偽のとき 1 を返し、
# それが関数の終了ステータスになると errexit でスクリプトごと落ちる。
secret_begin() { [[ -n "$XTRACE_WAS_ON" ]] && set +x; return 0; }
secret_end() { [[ -n "$XTRACE_WAS_ON" ]] && set -x; return 0; }
USAGE="usage: fmtoken.sh [--check] <service> | fmtoken.sh --list | fmtoken.sh [--check] --name <item> | fmtoken.sh --register <item> (value via stdin)"

mode="read"
if [[ "${1:-}" == "--check" ]]; then mode="check"; shift; fi
if [[ "${1:-}" == "--list" ]]; then mode="list"; fi
if [[ "${1:-}" == "--register" ]]; then mode="register"; shift; fi

explicit_name=""
if [[ "${1:-}" == "--name" ]]; then
  explicit_name="${2:?${USAGE}}"
elif [[ "$mode" == "register" ]]; then
  explicit_name="${1:?${USAGE}}"
fi

# 命名規約の機械検証: <prefix>--<service>。prefix はプロジェクト名（プロダクトの秘密）
# またはエージェント名（身元）で小文字、区切りの -- はちょうど 1 回。
# 人間の手作業登録が規約逸脱の源になるため、CLI 登録側で機械的に弾く（issue #63）。
validate_item_name() {
  local name="$1" prefix suffix
  prefix="${name%%--*}"
  suffix="${name#*--}"
  if [[ "$name" != *--* || "$suffix" == *--* ]] ||
     ! [[ "$prefix" =~ ^[a-z0-9][a-z0-9._-]*$ ]] ||
     ! [[ "$suffix" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "fmtoken: アイテム名が命名規約に反しています: ${name}" >&2
    echo "→ 規約は <project>--<service>（プロダクトの秘密。例: shukan--SUPABASE_ACCESS_TOKEN）または <agent>--<SERVICE>（エージェントの身元。例: moko--TRELLO_TOKEN）。prefix は小文字英数、区切りは -- を 1 回だけ" >&2
    exit 46
  fi
}

# 読み取り用 SA トークンの取得順: env → 600権限ファイル → Keychain
# 無人経路（cron・常駐・SSH）を優先する順序。Keychain は ACL 次第で読み出しごとに
# 生体認証ダイアログを出し、無人文脈ではそこでブロックする（GUI が無ければ即失敗）ため、
# 対話マシン用の最終フォールバックに置く。ファイル未配布のマシンだけが Keychain に落ちる。
# `--optional` 付きの呼び出しは、解決できない時に exit せず非 0 を返す
# （呼び出し側が fail-closed の文脈に合ったエラーを出すため。--register の二重登録ガードが使う）。
#
# 外部コマンド（tr / security）に付けている `3<&-` は、--register の区間から呼ばれたときに
# 値の JSON が待っているパイプ（fd 3）をこの子プロセスへ渡さないため（PR #177 レビュー指摘）。
# 詳細は --register 側のコメントを参照。fd 3 が開いていない他の経路から呼ばれた場合、
# 開いていない fd を閉じる指定は bash では無害な no-op なので、条件分岐は要らない。
resolve_ro_token() {
  local optional=""
  if [[ "${1:-}" == "--optional" ]]; then optional=1; fi
  local token_file="$HOME/.config/op-sa/claude-agents-ro.token"
  if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
    # SA トークンを変数に代入する区間。xtrace 下では代入行がそのまま値を吐く（issue #159）
    secret_begin
    if [[ -r "$token_file" ]]; then
      OP_SERVICE_ACCOUNT_TOKEN="$(tr -d '\n' < "$token_file" 3<&-)"
    elif OP_SERVICE_ACCOUNT_TOKEN="$(security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE_RO" -w 3<&- 2>/dev/null)"; then
      :
    else
      secret_end
      if [[ -n "$optional" ]]; then return 1; fi
      echo "fmtoken: SA トークンが見つかりません（ファイル: ${token_file} / Keychain: ${KEYCHAIN_SERVICE_RO}）。このマシンは未セットアップです。" >&2
      echo "→ 主に『SA トークンをこのマシンに配布して』と依頼すること（ブラウザでのログイン代行は不要）" >&2
      exit 43
    fi
    export OP_SERVICE_ACCOUNT_TOKEN
    secret_end
  fi
  return 0
}

# 書き込み用 SA トークン（claude-agents-rw）の取得順: env → 600権限ファイル → Keychain。
# 環境の OP_SERVICE_ACCOUNT_TOKEN は多くのマシンで ro トークンなので、登録では参照しない
# （ro のまま op item create すると権限エラーになるだけで、どのトークンで失敗したか
# 分からない。rw を明示的に解決してから OP_SERVICE_ACCOUNT_TOKEN を差し替える）。
#
# `3<&-` の理由は resolve_ro_token と同じ（--register の値のパイプをこの子プロセスへ渡さない）。
resolve_rw_token() {
  local rw_file="$HOME/.config/op-sa/claude-agents-rw.token" rw=""
  # ro 側と同じ理由で、rw トークンの代入区間も xtrace から隠す（issue #159）
  secret_begin
  if [[ -n "${OP_SERVICE_ACCOUNT_TOKEN_RW:-}" ]]; then
    rw="$OP_SERVICE_ACCOUNT_TOKEN_RW"
  elif [[ -r "$rw_file" ]]; then
    rw="$(tr -d '\n' < "$rw_file" 3<&-)"
  elif rw="$(security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE_RW" -w 3<&- 2>/dev/null)"; then
    :
  else
    secret_end
    echo "fmtoken: 書き込み用 SA トークン（claude-agents-rw）が見つかりません（env: OP_SERVICE_ACCOUNT_TOKEN_RW / ファイル: ${rw_file} / Keychain: ${KEYCHAIN_SERVICE_RW}）。" >&2
    echo "→ 主に『rw SA トークンをこのマシンに配布して』と依頼すること（読み取り用の ro トークンでは登録できない）" >&2
    exit 43
  fi
  export OP_SERVICE_ACCOUNT_TOKEN="$rw"
  secret_end
}

# --register: 明示名アイテムを agents 保管庫に作成する（rw SA 経由）
if [[ "$mode" == "register" ]]; then
  validate_item_name "$explicit_name"
  if [[ -t 0 ]]; then
    echo "fmtoken: 登録する値を stdin から渡してください（例: printf '%s' \"\$VALUE\" | fmtoken.sh --register ${explicit_name}）。値を引数で渡さないのは transcript / ps への露出を避けるため" >&2
    exit 46
  fi
  # ── 値をシェル変数に一切載せない（issue #170）─────────────────────────────
  # 以前は cat の出力を一度 bash 変数（`value`）に載せてから python に渡していた。
  # 変数を通すこと自体が 2 つの欠陥の根になっていた:
  #   (1) 変数は `secret_end` の後も残るので、呼び出し側が `PS4` にその変数名の展開を
  #       含む値を設定していると、以降のトレース行のプレフィックスとして値が stderr に出る。
  #   (2) bash 変数は NUL バイトを保持できないので、NUL を含む値が黙って縮む
  #       （`printf 'A\0B\n'` の 4 バイトが 3 バイトで登録される）。
  # どちらも「秘密がシェルを通る」ことが原因なので、stdin を読むのは python 1 か所だけにし、
  # 値は「python → op item create」のパイプの中だけを通す（argv にも環境変数にも載せない
  # ＝ issue #130 の性質は維持）。sys.stdin.buffer で読むのでバイト列がそのまま JSON になり、
  # 末尾改行（issue #159）も NUL も CRLF も変換されない。
  #
  # 空判定は「二重登録ガードより前」でなければならない（exit 46 が ro トークン解決・
  # op item list・op item create のどれよりも先に来る、が既存の受け入れ条件）。一方 stdin は
  # 一度しか読めないので、python には最初に stdin を読み切らせ、判定結果だけを 1 行目の
  # ステータス（ready / empty / notutf8）として先に流させる。JSON 本体は同じパイプの
  # 2 行目以降に続き、`op item create - <&3` がそれを読む。
  # ※ fd 3 はここから create まで「JSON が待っているパイプ」なので、途中で読まないこと。
  #
  # producer の終了は `wait` では検査できない（bash 3.2 は process substitution の PID を
  # wait できない — "not a child of this shell"）。代わりに完了ファイルで見る（issue #181-2）:
  # producer は payload を書き終えた**あと**に completed ファイルへ書き込むので、
  # `op item create` が戻ったあと producer の終了を待ってからファイルが空なら、producer は
  # 値を書き終える前に死んでいる（op が exit 0 でも成功を報告してはいけない）。
  # 逆方向（完走したのに空と誤判定）の race は create 直後のポーリング待ちで塞ぐ —
  # 途中で死んだ producer は completed に永遠に書かないので、終了後の判定は安定する。
  producer_completed="$(mktemp "${TMPDIR:-/tmp}/fmtoken-producer-completed.XXXXXX")"
  trap 'rm -f "$producer_completed"' EXIT
  # 先頭の SIGPIPE の既定化（issue #181-1）: 早期 exit（46/47/48）で bash が先に抜けると、
  # payload を書いている途中の producer は SIGPIPE を受ける。CPython は SIGPIPE を SIG_IGN に
  # して起動するため、放置すると BrokenPipeError の Traceback が呼び出し側の stderr に出て、
  # 「登録済みなので止めた」という正常系がクラッシュに見える。SIG_DFL に戻せば黙って死ぬ。
  #
  # 起動する python は FMTOKEN_TEST_PYTHON3 で差し替えられる（テスト専用の口。
  # 「producer が起動できない」経路は本物の /usr/bin/python3 を消さないと再現できないため。
  # 秘密は通らない設定名なので、呼び出し側が誤って設定しても値の露出には繋がらない）。
  exec 3< <("${FMTOKEN_TEST_PYTHON3:-/usr/bin/python3}" -c 'import json,signal,sys
signal.signal(signal.SIGPIPE, signal.SIG_DFL)
try:
    data = sys.stdin.buffer.read()
except Exception:
    # stdin が閉じられている（fmtoken.sh --register x <&-）と sys.stdin は None になる。
    # Traceback ではなくステータスとして呼び出し側に返す（issue #181-1）。
    sys.stdout.buffer.write(b"nostdin\n"); sys.stdout.buffer.flush(); sys.exit(0)
out = sys.stdout.buffer
if not data:
    out.write(b"empty\n"); out.flush(); sys.exit(0)
try:
    text = data.decode("utf-8")
except UnicodeDecodeError:
    out.write(b"notutf8\n"); out.flush(); sys.exit(0)
payload = json.dumps({"title": sys.argv[1], "category": "API_CREDENTIAL",
                      "fields": [{"id": "credential", "type": "CONCEALED",
                                  "label": "credential", "value": text}]}).encode("utf-8")
out.write(b"ready\n"); out.flush()
out.write(payload); out.flush()
with open(sys.argv[2], "w") as f:
    f.write("completed\n")' "$explicit_name" "$producer_completed")
  producer_pid=$!
  # ステータス行が読めない＝python が起動できなかった等。値が渡らない以上 create してはいけない。
  stdin_status=""
  if ! read -r stdin_status <&3; then stdin_status=""; fi
  case "$stdin_status" in
    ready) ;;
    empty)
      # 改行だけの値（`printf '\n'`）は空ではない。python 側もバイト列が空のときだけ empty を返す。
      echo "fmtoken: stdin が空です。登録する値を stdin から渡してください" >&2
      exit 46
      ;;
    notutf8)
      echo "fmtoken: stdin の値を UTF-8 として解釈できませんでした。1Password の credential フィールドはテキストなので、バイナリを登録するなら base64 等でテキスト化してから渡すこと" >&2
      exit 46
      ;;
    nostdin)
      echo "fmtoken: stdin が閉じられていて値を読めません。登録する値を stdin から渡してください（例: printf '%s' \"\$VALUE\" | fmtoken.sh --register ${explicit_name}）" >&2
      exit 46
      ;;
    *)
      # 46（入力不正）と分ける: これは入力の問題ではなく、このマシンで /usr/bin/python3 が
      # 起動できない環境障害（issue #181-3）。呼び出し側が「入力を直す」か「マシンを直す」かを
      # exit code で区別できるようにする。
      echo "fmtoken: 値を読み取る python3 を起動できませんでした（環境障害。/usr/bin/python3 を確認すること）。登録を中止します（fail-closed）" >&2
      exit 49
      ;;
  esac
  # ── fd 3 は create までの間、他のどの子プロセスにも渡さない（PR #177 レビュー指摘）──
  # fd 3 は exec で開いた時点から `op item create` まで開きっぱなしで、その間に起動する
  # 子プロセスは**すべてその fd を継承する**（close-on-exec が付かない）。ここには
  # ro/rw トークンを読む `tr` と Keychain 読み出し、二重登録ガードの `op item list` と
  # その解析 python が挟まるので、放置すると「値をパイプの中だけに閉じ込める」という
  # この経路の前提が崩れる:
  #   - 平文の JSON を読める（旧実装の値は非 export の bash 変数で、macOS には
  #     /proc が無いので子プロセスからは原理的に読めなかった＝**退行**になる）
  #   - 先に吸われると `op item create` が 0 バイトを受け取り、それでも「OK: … 登録した」で
  #     exit 0 する（無言の fail-open。--register は上書き禁止なので人力復旧待ちになる）
  # 閉じ方は「この区間で起動する外部コマンド 1 つずつに `3<&-` を付ける」形にする
  # （resolve_ro_token / resolve_rw_token の tr・security も含む）。
  #
  # 区間全体を `{ …; } 3<&-` のグループで囲む書き方は使えない。bash は複合コマンドの
  # リダイレクトを「あとで元に戻す」ために、適用前に fd 3 を fd 10 へ複製する。
  # bash 3.2（macOS 標準）はこの退避コピーに close-on-exec を付けないので、
  # グループ内で起動した子プロセスは全員 fd 10 で同じパイプを読めてしまう
  # （実測: `op item list` から見える open fd が `0 1 2 3 4 10` になり、fd 10 から
  # 平文の JSON が読めた上に create の受け取りが 0 バイトになる）。
  # 単純コマンドのリダイレクトは fork した子の側で適用されるので退避が起きない。
  #
  # 「区間にコマンドを足した人が `3<&-` を忘れたら同じ穴が開く」問題は、構文ではなく
  # テストで守る: fmtoken.bats の fd 総当たりスキャン（fd 3〜63 のどれからも 1 バイトも
  # 読めないこと）が、fd 番号にも書き方にも依存せずこの性質を固定する。

  # 判定不能（exit 48）で共通して出す案内。1Password 側の権限変更は人間の GUI 作業なので、
  # スクリプトは選択肢の提示までで止まる。
  GUARD_HINT="→ ro SA トークンをこのマシンに配布する（env OP_SERVICE_ACCOUNT_TOKEN / ~/.config/op-sa/claude-agents-ro.token / Keychain ${KEYCHAIN_SERVICE_RO}）か、rw SA に agents 保管庫の read 権を付けて OP_SERVICE_ACCOUNT_TOKEN に設定すること（1Password 側の権限変更は人間の GUI 作業）"
  # 二重登録ガード（issue #131）: 判定は読み取り用 SA（claude-agents-ro）で行い、
  # rw SA の read 権には依存しない。rw で `op read` して判定すると、rw に read 権が無い構成で
  # 判定が常に「未登録」側に倒れ（fail-open）、1Password は同名アイテムの作成を許すため
  # 重複アイテムができる。ro SA はこのスクリプトの読み取り経路全体が依存している＝定義上
  # read 可能なので、存在判定はそちらに寄せる。判定は title 完全一致（op item list）で行い、
  # credential フィールドの有無に依存しない（フィールド欠落アイテムを「未登録」と誤判定して
  # 同名重複を作らないため）。判定できない時は create せず止まる（fail-closed / exit 48）。
  if ! resolve_ro_token --optional; then
    echo "fmtoken: 二重登録の判定に使える読み取り用 SA トークン（claude-agents-ro）が解決できません。判定できないまま登録すると同名アイテムの重複を作りうるため、登録を中止します（fail-closed）" >&2
    echo "${GUARD_HINT}" >&2
    exit 48
  fi
  if ! existing_items="$(op item list --vault "$OP_VAULT" --format json 3<&- 2>/dev/null)"; then
    echo "fmtoken: 二重登録の判定（op item list --vault ${OP_VAULT}）に失敗しました。判定できないまま登録すると同名アイテムの重複を作りうるため、登録を中止します（fail-closed）" >&2
    echo "${GUARD_HINT}" >&2
    exit 48
  fi
  # 一致（found）/ 不一致（notfound）/ 解析不能（unparsable）を区別する。JSON が壊れている・
  # 想定の形でない場合を「不一致」に混ぜると、判定できていないのに create に進んでしまう
  # （fail-open）。
  #
  # 判定は exit code でなく**印字した結果文字列**で受け取る（issue #181-5 の検出テストで発覚）:
  # bash 3.2 は、呼び出し側の PS4 にコマンド置換が含まれると「直前のコマンドが非 0 の状態で
  # 代入文をトレースした」瞬間に errexit を誤発火してスクリプトごと落ちる。
  # `… || guard_rc=$?` も `if …; then :; else guard_rc=$?; fi` も同じ条件で落ちるため、
  # 「非 0 の直後に代入する」形そのものを避け、python には常に exit 0 で結果を印字させる。
  # fmtoken は「呼び出し側がどんな PS4 を設定していても正しく動く」を性質として
  # 固定しているので、この書き分けは好みではなく要件。
  # `|| true` は python 自体が起動できない場合の保険（guard_result が空のまま下の case の
  # `*)` に落ち、判定不能として exit 48 — fail-closed）。
  guard_result="$(printf '%s' "$existing_items" 3<&- |
    /usr/bin/python3 -c 'import json,sys
try:
    items = json.load(sys.stdin)
    titles = [i["title"] for i in items]
except Exception:
    print("unparsable"); sys.exit(0)
print("found" if sys.argv[1] in titles else "notfound")' "$explicit_name" 3<&-)" || true
  case "$guard_result" in
    found)
      echo "fmtoken: ${explicit_name} は既に登録済みです → 上書きしない（更新が必要なら主の判断を経て op item edit を使う。無断上書き防止）" >&2
      exit 47
      ;;
    notfound) ;;
    *)
      echo "fmtoken: 二重登録の判定に使う ${OP_VAULT} 保管庫のアイテム一覧を解析できませんでした（op item list --format json の出力が想定の形ではありません）。判定できないまま登録すると同名アイテムの重複を作りうるため、登録を中止します（fail-closed）" >&2
      echo "${GUARD_HINT}" >&2
      exit 48
      ;;
  esac
  resolve_rw_token
  # 値は op の argv に載せない（issue #130）。assignment statement
  # （`credential[password]=<値>`）で渡すと op プロセスの実行中に ps から値が見え、
  # 「stdin で受けるので ps に出ない」という文書の主張が実装で担保されない。
  # op 公式も `op item create --help` で assignment statement による秘密の受け渡しを
  # 警告し、JSON テンプレートを推奨している。ここではその JSON をパイプで渡す
  # （`op item create --vault <v> -` が stdin から JSON を読む形）。
  #
  # JSON の組み立ては /usr/bin/python3（--list と同じ既存依存）。printf で手組みすると
  # 値に含まれる " \ 改行 でクレデンシャルが黙って壊れる。argv に渡してよいのは
  # アイテム名（秘密でない）だけで、値はパイプの中だけを通す（環境変数も不可 —
  # 同一ユーザーからは argv と同程度に見えるため塞いだことにならない）。
  # JSON は上流の python が fd 3 のパイプで待っているので、それをそのまま op に読ませる。
  #
  # 失敗時は fail-closed: assignment statement へのフォールバックを書かないこと
  # （例外時にだけ argv 経路が開く穴になり、しかも例外時こそ気づかれない）。
  # set -euo pipefail により op が落ちれば非 0 で即死する。
  #
  # ここに xtrace の抑止（secret_begin）は不要になった（issue #170）。値はシェルの
  # 変数にも argv にも現れないので、トレースされるのは `op item create --vault agents -` だけ。
  op item create --vault "$OP_VAULT" - <&3 >/dev/null
  # fd 3 を閉じる。producer がまだ書き込み待ちで残っていれば、ここで SIGPIPE を受けて終わる
  # （SIG_DFL に戻してあるので Traceback は出ない）。
  exec 3<&-
  # 完了ファイルを見る前に producer の終了を待つ。op が EOF まで読む consumer なら
  # producer は既に終わっている（EOF は producer の exit でしか発生しない）が、
  # JSON を読み終えた時点で EOF を待たずに戻る consumer だと「payload の write は
  # 返ったが完了ファイルはまだ」という一瞬に検査が走りうる（偽陽性）。bash 3.2 は
  # process substitution の PID を wait できないので kill -0 でポーリングする
  # （fd 3 は閉じたので、生きているとしても SIGPIPE で即終わる。上限 5 秒は保険で、
  # 万一残っていても検査は空ファイル＝失敗側に倒れる — fail-closed）。
  producer_wait=0
  while kill -0 "$producer_pid" 2>/dev/null && [[ "$producer_wait" -lt 100 ]]; do
    sleep 0.05
    producer_wait=$((producer_wait + 1))
  done
  # producer の完了検査（issue #181-2）: `set -o pipefail` がパイプ全段の失敗を拾うのと
  # 同じ役割。op が exit 0 でも、producer が値を書き終えていなければ成功を報告しない。
  # op 側が stdin を読み切らずに成功を返した（パイプが途中で吸われた・詰まった）ケースが
  # これに落ちる。上書き禁止（exit 47）のため自動リトライはできず、人力確認に振る。
  if [[ ! -s "$producer_completed" ]]; then
    echo "fmtoken: 値を op に送る producer が値を書き終える前に異常終了しました。op item create は実行済みのため、${explicit_name} が不完全な値で作られていないか確認すること（不完全なら主の判断を経て op item delete → 再登録。fail-closed）" >&2
    exit 49
  fi
  echo "OK: ${explicit_name} を ${OP_VAULT} 保管庫に登録した（フィールド: credential）"
  exit 0
fi

# --name: 明示名アイテムの参照（プロジェクト導出をスキップ。origin remote 不要）
if [[ -n "$explicit_name" ]]; then
  validate_item_name "$explicit_name"
  resolve_ro_token
  ref="op://${OP_VAULT}/${explicit_name}/credential"
  if [[ "$mode" == "check" ]]; then
    if op read "$ref" >/dev/null 2>&1; then
      echo "OK: ${explicit_name} は登録済み"
      exit 0
    fi
  else
    if op read "$ref" 2>/dev/null; then
      exit 0
    fi
  fi
  echo "fmtoken: 未登録 → ${ref}" >&2
  echo "→ 値が手元にあるなら printf '%s' \"\$VALUE\" | fmtoken.sh --register ${explicit_name} で登録できる（rw SA 経由）。値が無ければ主に発行と登録を依頼する" >&2
  exit 44
fi

# プロジェクト名: origin remote のリポ名（末尾 .git 除去 → 最終パス要素 → 小文字化）。
# 例: https://github.com/genetta-inc/suimei.git / git@github.com:genetta-inc/suimei.git → suimei
# dir 名導出は flatmate 住人の workspace/<住人>/repo 構造（basename が一律 repo）で破綻し、
# 登録済みトークンに登録依頼を飛ばす誤誘導を生んだため廃止（oratta/claude-harness#56）。
# メイン repo・worktree・住人 dir のどこで実行しても同じ名前に解決される。
if ! remote_url="$(git remote get-url origin 2>/dev/null)"; then
  echo "fmtoken: origin remote が無いためプロジェクトを特定できません（git リポジトリ外か remote 未設定）。" >&2
  echo "→ プロジェクトの正式リポジトリ（origin 設定済み）の中で実行すること。主への依頼は不要（トークンが無いのではなく実行場所の問題）" >&2
  exit 45
fi
remote_url="${remote_url%/}"
remote_url="${remote_url%.git}"
project="${remote_url##*/}"
project="${project##*:}"  # scp 形式で org が無い場合（git@host:name）の保険
project="$(printf '%s' "$project" | tr '[:upper:]' '[:lower:]')"
if [[ -z "$project" ]]; then
  echo "fmtoken: origin remote の URL からプロジェクト名を導出できません: $(git remote get-url origin)" >&2
  exit 45
fi

resolve_ro_token

if [[ "$mode" == "list" ]]; then
  op item list --vault "$OP_VAULT" --format json |
    /usr/bin/python3 -c "import json,sys; [print(t.split('--',1)[1]) for i in json.load(sys.stdin) if (t:=i['title']).startswith('${project}--')]"
  exit 0
fi

service="${1:?${USAGE}}"
ref="op://${OP_VAULT}/${project}--${service}/credential"

if [[ "$mode" == "check" ]]; then
  if op read "$ref" >/dev/null 2>&1; then
    echo "OK: ${project}--${service} は登録済み"
    exit 0
  fi
else
  if op read "$ref" 2>/dev/null; then
    exit 0
  fi
fi

echo "fmtoken: 未登録 → ${ref}" >&2
echo "→ ブラウザに行かず、値が手元にあるなら printf '%s' \"\$VALUE\" | fmtoken.sh --register ${project}--${service} で登録する（rw SA 経由）。値が無ければ主に『1Password の ${OP_VAULT} 保管庫に ${project}--${service}（フィールド: credential）を登録して』と依頼すること" >&2
exit 44
