# Design

## Context

移す元は主の端末の `~/.claude/hooks/secret-guard.py`（205 行。Python 標準ライブラリだけで動く単体のスクリプト）で、`~/.claude/settings.json` の PreToolUse に `matcher: "Bash|Read"`、`timeout: 10`、`/usr/bin/python3 <絶対パス>` で配線されている。

このリポジトリは公開で、次の制約がかかる。

- 個人版の道具の名前は公開版の部品に書けない。`fmtoken` は個人版の `check-public-leak.sh` の辞書に載り、`plugins/` の配下（`tests/` と `changes/` を除く）に現れると落ちる。`capability-registry-browser-guard` の仕様も hook の出力に `fmtoken` を含めないと定めている
- `tests/hook-python-isolation.bats` は hooks.json に登録された `.sh` の python3 が `-I` で起動することを検査する。`.py` を直に登録するとこの検査の範囲に入らない
- `tests/public-private-split.bats` は、プラグインのファイルが `docs/public-private-split.md` の部品の行に覆われていることを検査する
- `tests/lint-plugin-validate.bats` は hooks.json の `${CLAUDE_PLUGIN_ROOT}` を含むパスが二重引用符で囲まれていることを検査する
- `plugins/capability-registry/tests/browser-guard.bats` は `hooks.PreToolUse[0]` を browser-guard として読む

## Goals / Non-Goals

**Goals:**

- 個人専用の検査の除外と明示的な無効化を除いて判定を変えずに、配線の場所をプラグインへ移す
- 公開版に個人の固有記述を持ち込まない

**Non-Goals:**

- 判定の改善。既知の誤検知（ヒアドキュメントや複数行の引用符の中の行をコマンドとして読む、`credentials.ts` のようなファイル名の Read を止める）と、見逃しは今の挙動のまま残す。見逃しを許す境界の正本は spec の要件「検査の守備範囲」
- 個人情報の移動・外部送信の検査（`injection.md` の部分実装の記述のまま。#126 の論点）
- Codex など Claude Code 以外の実行環境への配布
- 主の端末の `settings.json` と `~/.claude/hooks/` の変更

## Decisions

### 置き場所は capability-registry

issue の方針案どおりにする。トークンと認証を扱うプラグインで、`hooks/hooks.json` が既にあり、`bundle:all` にも含まれる。

- 選ばなかった案: dev-workflow。README のクイックスタートで入るので届く範囲は広いが、dev-workflow の hook は開発の流れを守るもので、シークレットの扱いとは関心が違う。capability-registry を入れない人には入らない点は、README の案内で補う

### スクリプトは薄い `.sh` と本体の `.py` の 2 本

hooks.json には `"${CLAUDE_PLUGIN_ROOT}/scripts/secret-guard.sh"` を登録する。`.sh` は無効化のスイッチと python3 の有無を見て、`python3 -I` で隣の `secret-guard.py` を実行し、`exit 0` で終える。`exec` にしないのは、本体の `.py` が無いと python3 が exit 2 で終わり、hook の exit 2 が全 Bash と Read を止めるためである（fail-open の要件に反する）。

- `.sh` なら python3 の隔離の検査（`tests/hook-python-isolation.bats`）の範囲に自動で入る
- python3 が無い環境で、起動の失敗を hook のエラーとして出さず、黙って通せる
- 選ばなかった案 1: hooks.json に `python3 -I "...py"` を直に書く。部品は 1 本減るが、隔離の検査の範囲から外れ、python3 が無い環境で毎回 hook のエラーが出る
- 選ばなかった案 2: Python の本文を `.sh` の中に `python3 -I -c` で書く（dev-workflow の git-destructive-guard の形）。元の `.py` との差分を確かめにくくなる

起動は元の `/usr/bin/python3` ではなく PATH の `python3` にする。`/usr/bin/python3` は macOS の配置で、他の環境に無い。`from __future__ import annotations` を残すので、3.9 系でも動く。

### 判定の中身は例外の 2 つを除いてそのまま移す

例外は `fmtoken.sh` の分岐の除外と、`CAPABILITY_REGISTRY_SECRET_GUARD=off` の無効化の 2 つだけである。`SECRET_VAR`・`SECRET_FILE`・`SAFE_FILE`・`DUMPERS`・`FILE_READERS` と検査の 1〜4、検査 5 の `op` の部分は変えない。`op` は公開の CLI なので個人の固有記述に当たらない。実装の段では、元のファイルとの差分が下の固有記述の除去と無効化の説明だけであることを diff で確かめる。

matcher は元の `Bash|Read` のまま。

拒否の理由に入力のコマンドやパスを引用する動きも残す。理由の文言の中で固有記述を除くのは固定の案内文（`HINT` など）で、入力の引用は加工しない。引用を加工すると、利用者がどの入力で止まったかを読めなくなり、値が transcript に載るのを防ぐ効果も無い（引用するのはエージェントが書いたコマンドやパスで、hook が読み出した値ではない）。

### 個人の固有記述の除去

| 元の行 | 中身 | 扱い |
|---|---|---|
| 4-7 | 個人の経緯 | 経緯を外し、実行前に止める理由だけを残す |
| 11-12 | 例の `~/.config/op-sa/*.token`・`fmtoken.sh` | 一般の例に置き換える |
| 17 | 無効化の手順（settings.json のエントリを外す） | 環境変数の説明に置き換える |
| 52-57 | `HINT` の `fmtoken.sh` の 3 行 | 道具を名指ししない 2 行にする。`--check` の行は外す |
| 160-162、174-175 | 検査 5 の `fmtoken.sh` の分岐とコメント | 分岐を外す |

### fmtoken.sh の検査は公開版に持ち込まない

`fmtoken.sh` は個人版のプラグイン `capability-registry-oratta` の部品で、それを裸で実行する形を止める検査はその道具と一緒に置くのが筋である。公開版からは分岐を外す。主の端末では、手の配線を外すと `fmtoken.sh` の裸実行が止まらなくなる。個人版に代替の検査を足すのは別リポジトリの作業で、この change の範囲の外である。手の配線を外してよい条件は下の移行の手順で決める。

- 選ばなかった案 1: 公開版のまま `fmtoken.sh` の分岐を残す。個人版の `check-public-leak.sh` が落ち、#1164 で外した方針に反する
- 選ばなかった案 2: 値を返すコマンド名を環境変数で足せるようにする。公開版に設定項目が増え、`--check` `--list` を除外する規則まで一般化する必要がある。使うのが主 1 人の道具のために公開版を複雑にしない

### 無効化は環境変数 `CAPABILITY_REGISTRY_SECRET_GUARD=off`

元の無効化の手順は `settings.json` のエントリを外すことだった。プラグインの hook には外すエントリが無く、プラグインを無効にするとスキルと browser-guard も止まる。誤検知のファイル名を持つリポジトリの利用者には、止める手段が要る。

- 形は dev-workflow の `DEV_WORKFLOW_GIT_GUARD=off` に合わせる
- 判定は hook のプロセスの環境変数を見るので、コマンドの前に `CAPABILITY_REGISTRY_SECRET_GUARD=off echo ...` と書いても効かない。`settings.json` の `env` か起動時の環境で設定する

### `statusMessage` は持ち込まない

元の配線の「シークレット露出を検査中」は表示だけで判定に関わらず、このリポジトリの hooks.json に使用例が無い。すべての Bash と Read で表示が出るだけなので外す。`timeout: 10` は残す。

### hooks.json の配列の末尾に足す

`browser-guard.bats` が先頭の要素を読むので、secret-guard は `PreToolUse` の 2 番目に足す。matcher が重ならないので順序は挙動に関わらない。dev-workflow の hook と同じ Bash で走っても、Claude Code は拒否を優先するので、他の hook の `allow` で secret-guard の拒否が消えることはない。

## Risks / Trade-offs

- [他の利用者の環境で、機密らしい名前のファイルの Read が止まる。頻度は `credentials.*` などのファイルを持つリポジトリで起きる] → 拒否の理由に代わりの書き方を出す。止める必要があれば `CAPABILITY_REGISTRY_SECRET_GUARD=off`
- [主の端末で移行中は、手の配線とプラグインの hook が二重に走る] → どちらも読み取りだけで、拒否は片方で足りる。被害は同じ拒否の理由が 2 回出ることと、Bash と Read ごとの python3 の起動が 1 回増えること。変更の記録の手順で外す
- [`fmtoken.sh` の裸実行が、手の配線を外したあと主の端末で止まらなくなる] → 移行の手順の条件を満たすまで手の配線を残す。条件を変更の記録に書く
- [capability-registry を入れない環境には入らない] → README に案内を書く。`bundle:all` なら入る

## Migration Plan

1. この change をマージし、プラグインの更新が端末に届くのを待つ
2. 主の端末で、公開の hook が動いていることを確かめる（`echo "$GH_TOKEN"` 相当が止まる）
3. 次のどちらかが成り立つまで、手の配線を残す。個人版の代替の検査が有効になったことを確かめた、または `fmtoken.sh` の裸実行を止める保護を廃止すると本人が判断した
4. 3 が成り立ったあとで、`~/.claude/settings.json` の PreToolUse から secret-guard のエントリを外し、`~/.claude/hooks/secret-guard.py` を消す

戻すときは手の配線を戻す。プラグインの hook だけを止めるなら `CAPABILITY_REGISTRY_SECRET_GUARD=off` を設定する。
