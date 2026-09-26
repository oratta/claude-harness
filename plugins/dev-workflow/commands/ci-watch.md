---
name: ci-watch
description: 指定した PR の CI をメインセッションが見張り、落ちたらやり直すか直す。--merge を付けたときだけ、通ったらゲートを経てマージへ進む
argument-hint: "<PR の URL | PR番号> [--merge]"
allowed-tools: Read, Glob, Grep, Bash, Agent, Skill
---

ゲートを通っていない PR も含めて、オーナーが指定した PR の CI をメインセッションが見張る入口。見張りの手順の正本は `references/ci-watch.md` の 1 箇所で、この入口は見張る PR とマージ依頼の有無を決め、`ready` を受けたあとの扱いを決めるだけ。待ち方・`--unrelated` の基準・一手ごとの動き・直し方は言い換えずに reference に従う。

見張るのはメインセッション自身で、サブエージェントに見張らせない（背景タスクの完了で起こされないため。reference の「1. 見張りを始めるのは本体（メインセッション）だけ」）。

## ファイル特定

```bash
for dir in \
  "${CLAUDE_PLUGIN_ROOT:-}" \
  ~/.claude/plugins/marketplaces/*/plugins/dev-workflow \
  ~/.claude/plugins/installed/*/dev-workflow; do
  [ -n "$dir" ] && [ -f "$dir/references/ci-watch.md" ] && echo "$dir" && break
done
```

見つかったディレクトリの `references/ci-watch.md` を Read で読み、`scripts/ci-watch.sh` をそのディレクトリからの絶対パスで呼ぶ。

## 1. 見張る PR とマージ依頼を決める

`$ARGUMENTS` をそのまま渡して `ci-watch.sh target $ARGUMENTS` を実行する。出力は `{"repo","number","url","merge"}` の 1 行 JSON。

- 非 0 なら見張りを始めず、何が解決できなかったか（標準エラーの 1 行）を添えて、対象の PR の URL か番号を確かめるようオーナーに伝える
- マージ依頼の有無は `--merge` の有無だけで決め、`target` が出す `merge` をそのまま使う。会話の文面からマージ依頼を推定しない（「良さそうならマージかな」のような言い方の取り違えで承認の無いマージを起こさないため）。`--merge` 以外の引数を付けると `target` は非 0 で止まるので、そのときも見張りを始めずにオーナーに伝える

## 2. 見張る

reference の手順どおりに進める。ここで独自の待ち方や仕分けを足さない。

1. reference の「2. 1 つの PR を見張るのは 1 セッションだけ」で始めてよいかを判定し、1 行目が `CI 見張り開始:` のコメントを PR に投稿する
2. `ci-watch.sh wait <repo> <number>` を `run_in_background` で起動し、完了通知を受けてから結果を 1 回読む（reference の「3. 待ち方」「4. `wait` の結果ごとの動き」）
3. `settled` なら reference の「5. `--unrelated` を渡す基準」で、落ちた run のログの末尾と PR の変更ファイルを見て、2 条件を両方満たすチェックだけを `ci-watch.sh next <repo> <number> --unrelated <チェック名>` に渡す。どちらかが判断できなければ `--unrelated` を渡さず、そのまま `fix` に回す。やり直しは同じ HEAD で 1 回までで、その判定は `next` が持つ
4. `next` の `act` ごとに reference の「6. `next` の一手ごとの動き」に従い、実行した一手と結果を PR にコメントする。`ready` だけは下の 3 で扱う

`fix` の直しは、メインセッションが実装者のサブエージェント（model は sonnet）を起こし、reference の「7. 直し方」で直させる。メインセッションは自分で直さない（見張りと直しを別のコンテキストに保つため）。実装者が PR の差分と関係ない失敗だと返したら、push せずに `ci-watch.sh next <owner/repo> <PR番号> --unrelated <チェック名> --after-fix` を 1 回だけ実行し、その一手に従う。直しの push のあとは同じ見張りの続きとして `wait` から始め直す。

## 3. `ready` を受けたら

`ready` のあとは `merge` で分かれる。

**`merge` が `false` の見張りで `ready` を受けたら、ゲートを実施しない。** ラベルも付け外ししない。1 行目が `CI 見張り終了:` のコメントを、理由「CI が通った。マージ依頼が無いのでゲートとマージには進まない」を添えて PR に投稿し、PR の URL を添えて CI が通ったことをオーナーに伝えて見張りを終える。ゲートやマージへ進めたいときは、オーナーが改めて頼む。ラベルを付け外ししないのは `ready` を受けたときだけの規定で、`fix` のときは reference の「7. 直し方」に従って `agent-review:passed` を外す（付いていた PR のとき）。

**`merge` が `true` の見張りで `ready` を受けたら、`pr-review-gate` スキルでゲートを実施する。** CI が通ったことはゲート合格の代わりにならず、ゲートの合格が確定するまでマージ待ち・マージ依頼に進まない。ゲートが failed なら、ゲートの通常の周回で直し（直しは上の 2 の実装者が担う）、push したら同じ見張りの続きとして `wait` から続け、`ready` になってから取り直す。保留になるか 2 周で合格が確定しなければ、PR の URL を添えてオーナーに上げる。合格したら reference の「`ready` を受けたあと」の 1 から進む（マージを止めるラベルの確認・自動マージの見届け・人間へのマージ依頼）。

## `--merge` の承認範囲

オーナー本人が当該 PR に `--merge` を付けたことは、その PR が CI の成功と既存ゲート・リポジトリ運用の条件を満たした後にマージへ進める意思として扱う。次のものは承認したことにならない: ゲート省略、別の PR のマージ、別の HEAD のリスク許容、main への直接 push、rebase・force-push、LLM による `gh pr merge` や merge API の実行。自動マージが使えないか、マージを止めるラベルがあるときは、PR の URL を添えて人間にマージを頼む。
