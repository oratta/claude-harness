## Context

`scripts/lint.sh`（88 行、POSIX sh）は、git 追跡下の `*.sh` を `git ls-files` で列挙して shellcheck にかける。引数はパスの部分一致フィルタ（OR）で、対象が 0 件なら exit 1、shellcheck が無ければ導入手順を出して exit 1 で終わる。CI（`.github/workflows/ci.yml` の lint ジョブ）は引数なしでこれを呼ぶ。

`claude plugin validate <path>` は、プラグインのディレクトリを渡すと plugin.json と `hooks/hooks.json` を、リポジトリ直下を渡すと `.claude-plugin/marketplace.json` と各プラグインの plugin.json を検証する。2026-10-07（claude 2.1.292）に確かめた終了コードは次のとおり。

| 状態 | 出力の末尾 | 終了コード |
|---|---|---|
| 警告だけ（version 未記載、引用符なし） | `Validation passed with warnings` | 0 |
| plugin.json の `name` を `claude-x` にした | `Validation failed` | 1 |
| hooks.json の command を `"\"${CLAUDE_PLUGIN_ROOT}/scripts/browser-guard.sh\""` にした | 引用符の警告が消える | 0 |

1 回の実行は約 1 秒で、14 対象（直下＋13 プラグイン）で十数秒になる。

hooks.json の command は現在 `"${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh"`（JSON の値としては引用符なしのシェル文字列）で、4 プラグインに 13 箇所ある。この文字列を完全一致で検査するテストが 4 本、`in` や部分一致で検査するテストが複数ある。

## Goals / Non-Goals

**Goals:**
- `claude` のある環境で `scripts/lint.sh` を走らせると、公式の検証のエラーで非 0 になる
- `claude` の無い環境（CI）で、これまでと同じ結果になり、検証を飛ばしたことが出力から分かる
- hooks.json の引用符なしの警告を 0 件にする

**Non-Goals:**
- CI のランナーに `claude` を入れて検証を CI の合否に加えること（別の判断。この変更では CI の設定を変えない）
- `--strict` で警告を失敗にすること（version 未記載は意図どおりなので、付けると全プラグインが落ちる）
- version 未記載と、telegram の author 未記載の警告を消すこと
- hooks.json の引用符以外の変更（整形、並べ替え、exec 形式への書き換え、timeout や matcher の見直し）
- `.github/workflows/ci.yml` のジョブ名やステップ名（`shellcheck`）の変更
- `agent-model-guard.sh` の動作を変えること（仕様の記述を実装に合わせるだけ。決定 8）

## Decisions

### 1. 引用符は「パス全体を二重引用符で囲む」形にする

`"command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh\""` とする。

検証の警告文は 2 つの直し方を挙げている。二重引用符で囲む形と、exec 形式（`{"command": "<実行ファイル>", "args": [...]}`）である。exec 形式は hooks.json の構造を変え、キーが増えて行の並びが変わるので、同じファイルを触る後続の issue（#710・#714・#715・#591）と衝突しやすい。主からの制約も「引用符で囲む修正だけ」なので、二重引用符を選ぶ。

囲む範囲は `${CLAUDE_PLUGIN_ROOT}` だけ（`"\"${CLAUDE_PLUGIN_ROOT}\"/scripts/x.sh"`）ではなくパス全体にする。シェルではどちらも同じ 1 語になるが、パス全体のほうが読んで分かりやすく、あとからスクリプト名に空白を含むものが増えても割れない。パス全体を囲んだ形で警告が消えることは確かめてある。

### 2. 検証は shellcheck のあとに走らせ、片方が落ちてももう片方を走らせる

lint.sh は「最初の指摘で止めない」方針（一括適用）なので、shellcheck が指摘を出しても検証を走らせ、最後に両方の結果をまとめて終了コードを決める（どちらかが非 0 なら 1）。shellcheck が無いときに先頭で exit 1 する動きは変えない。

### 3. 検証の対象は `git ls-files` で列挙する

プラグインは `git ls-files -- 'plugins/*/.claude-plugin/plugin.json'` から `plugins/<name>` を取り出して列挙する。名前を固定で書かないのは、shellcheck の対象と同じ理由（新しいプラグインを自動で拾う）による。`plugins/*/` のディレクトリを直接なめないのは、追跡されていない作業中のディレクトリを対象に入れないためである。

リポジトリ直下は、直下に置かれた marketplace の定義を検証する。直下の検証とプラグインごとの検証は plugin.json の検査が重なるが、hooks.json を検査するのはプラグインごとの検証だけなので、両方を走らせる（issue 本文の指定どおり）。

### 4. フィルタ引数は検証の対象にも同じ規則で効かせる

`scripts/lint.sh worktree` のように呼ばれたとき、次の 3 案があった。

| 案 | 動き | 捨てた理由 / 選んだ理由 |
|---|---|---|
| フィルタがあっても全対象を検証する | 毎回 14 対象 | 1 プラグインだけ見たいときに十数秒待つ。フィルタの意味（対象を絞る）と合わない |
| フィルタがあるときは検証しない | shellcheck だけ | プラグインを 1 つ直して確かめる、いちばん使う場面で検証が走らない |
| プラグインのパス `plugins/<name>/` にフィルタを部分一致（OR）させる（採用） | `worktree` なら `plugins/worktree` だけ | shellcheck と同じ規則なので覚えることが増えない |

リポジトリ直下は、フィルタに一致させるパスが無いので、フィルタ無しのときだけ検証する。フィルタに一致するプラグインが 1 つも無いとき（`scripts/lint.sh scripts`）は、検証の対象が無いことを 1 行出して検証を飛ばし、失敗にはしない（`*.sh` が 0 件のときに exit 1 する既存の動きは、shellcheck の対象についての判定のまま変えない）。

### 5. `claude` が無いときは飛ばして理由を出し、失敗にしない

`command -v claude` が失敗したら、検証を飛ばしたことと理由（`claude` コマンドが見つからない）を標準エラーに出し、終了コードには影響させない。shellcheck が無いときは exit 1 にしているのと扱いが違うのは、CI のランナーに `claude` が無く、失敗にすると CI が必ず落ちるためである（issue 本文の指定）。

受け入れることになる性質: CI では公式の検証が走らないので、開発機で `scripts/lint.sh` を走らせずに push した PR は、検証のエラーを持ったまま CI を通る。develop の実装工程は verify で `scripts/lint.sh` を走らせるので、その経路では拾える。

### 6. 出力は、通った対象は 1 行、落ちた対象は検証の出力をそのまま出す

14 対象すべての出力を流すと、version 未記載の警告が毎回 20 行以上並び、エラーが埋もれる。通った対象（終了コード 0）は対象名を 1 行だけ出し、落ちた対象は `claude plugin validate` の出力（標準出力と標準エラー）をそのまま出す。警告を見たいときは `claude plugin validate plugins/<name>` を直接走らせる。

### 7. lint.sh のテストは、偽の `claude` を PATH に置いた一時リポジトリで行う

`tests/lint-plugin-validate.bats` は、一時ディレクトリに git リポジトリを作って `scripts/lint.sh` を複製し、PATH の先頭に偽の `claude`（受け取った引数を記録し、指定された対象で非 0 を返すシェルスクリプト）を置いて走らせる。本物の `claude` を使わないのは、CI のランナーに無いことと、版によって検証の中身が変わるとテストが揺れることによる。本物での確認（`name` を `claude-x` にすると落ちる、引用符の警告が 0 件）は verify の手順で行い、結果を記録先に残す。

lint.sh は `$0` の位置からリポジトリの根を決めるので、複製を一時リポジトリの `scripts/` に置けば、本物のリポジトリに触らずに試せる。

### 8. hook の要件の記述は、hook ではなく仕様の側を実装に合わせる

仕様レビューで、要件「model 未指定の Agent spawn は hook が拒否する」に守備範囲の段落を足したところ、本番の仕様から写した本文（「共有枠モードは usage snapshot から導出」「snapshot が読めないときは fail-open」）が実装と食い違っていることが分かった。実装（`agent-model-guard.sh:59-85`）は fork のときだけ `usage_view.py` でセッション記録と snapshot を突き合わせた実効値を読み、値が求まらなければ `ok` とみなす。fork 以外の判定はどちらも読まない。

| 案 | 捨てた理由 / 選んだ理由 |
|---|---|
| hook の要件をこの change から外す | 主の判断（仕様と実物の乖離は不可）に反する。食い違いが本番の仕様に残る |
| hook を仕様の記述に合わせて変える | セッション記録を読む動きは別の仕様（usage-session-records）が決めたもので、この issue の範囲（lint.sh と引用符）を超える |
| 仕様の本文と Scenario を実装に合わせる（採用） | 動作は変わらず、既存のテスト（`agent-model-guard.bats`）がそのまま裏付けになる |

## Risks / Trade-offs

- **引用符を足した command が実際の hook の起動で動かない** → Claude Code は hook の command をシェルに渡して実行するので、二重引用符で囲んだパスは 1 語として解釈される見込みで、検証の警告文もこの形を勧めている。ただし検証を通ることと実際に起動することは別なので、verify で `claude -p --plugin-dir` を使い、引用符付きの hooks.json で SessionStart の hook（dev-workflow の `session-tripwires.sh`）が起動することを確かめる。起動しなければ、作業ツリーをそのままにして本体に return する（引用符の変更を自分の判断で取り消さない）
- **検証の出力や終了コードが Claude Code の版で変わる** → lint.sh は終了コードだけを見て、出力の文言には依存しない。警告で非 0 を返す版が出たら全対象が落ちるので、そのとき `--strict` 相当の動きを抑える方法を調べる（今は起きていない）
- **`scripts/lint.sh` が十数秒遅くなる** → 開発機でだけ起きる。フィルタ引数で 1 プラグインに絞れば約 1 秒
- **編集するファイルが 5 個を超える** → 触るファイルは lint.sh、hooks.json 4 本、既存テスト 4 本、新規テスト 1 本、変更の記録 4 本で、issue 本文の「触るファイル」（5 本）より多い。増えた分は期待値の文字列の置き換えと記録で、設計判断は増えない
