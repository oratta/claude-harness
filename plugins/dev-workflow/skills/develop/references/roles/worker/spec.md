# W（作業者）の指示書 — 仕様づくり（`段: spec`）

(1) 仕様化までと、R1 の `REQUEST_CHANGES` を受けた artifact の修正で読む。全段で要る規則は `worker/common.md`。

## 記録先の用意（Draft PR を記録先にする場合。仕様化判断より先）

本体から「issue が無いので Draft PR を記録先にする」と指示されたら、**仕様化判断より先に**次を行い、PR 番号を控える。記録先が無い状態で判定を進めない。

```bash
git commit --allow-empty -m "chore: init draft PR for <branch>"
git push -u origin <branch>
gh pr create --draft --head <branch> --base main --title "<依頼の要約>" --body "$(cat <<'EOF'
## 位置づけ
<この変更が何を解くか。依頼の要約>

## 受け入れ条件
- [ ] <測定可能な条件（実行コマンド + 期待値）>

## 動作確認ポイント
<レビュアーが何を見れば合格と分かるか>
EOF
)"
```

- **受け入れ条件は PR 本文に書く**（issue に書かない分の省略であって、受け入れ条件自体は省けない）
- PR 本文に `Closes #N` / `Fixes #N` / `Refs #N` の issue 参照を**書かない**（書くと pr-review-gate の照合先がその issue に移る。エピックの子は子 issue が記録先なので、その場合は `Closes #子` を書く）
- 以降、この PR が記録先。`gh issue comment` の代わりに `gh pr comment <PR番号>` でコメントする

issue が記録先のときはこの節は不要（PR は (3) で作る）。

## 仕様化判断（opsx / openspec の要否）と記録

まず `openspec --version` で CLI の有無を確認する。opsx コマンドがあっても openspec CLI が無ければ仕様化経路は発生せず、理由に「openspec 不在」と書いてコード直行する。

```bash
openspec --version
```
次に、この依頼を**仕様として残すべきか**を判定する（詳細は `skills/develop/references/decision-criteria.md` Step B）:

- **仕様化する**（一次基準: 設計判断・トレードオフを含むか）: 複数案からの選択・採用理由など「なぜこう作ったか」を決定履歴に残す価値のある設計判断を含む／外部から観測可能な振る舞いの変更のうち実装方針に選択肢が残るもの／既存 capability の要件や docs に触れる
- **仕様化しない（コード直行）**: typo・lint・コメント・フォーマットのみ／振る舞い不変の内部リファクタ・ワンライナー fix・依存バージョン上げのみ／**受け入れ条件が記録先に明記された機械的な振る舞い変更**（設計判断なし。記録先とテストが記録として十分）
- どの判定でも**テスト作成は必須**（テストはドキュメントであると同時に、昇格トリップワイヤーの信号源）
- 判定に迷ったら: interactive は return で本体に聞いてもらう（本体が AskUserQuestion）。unmanned は**仕様化する側に倒す**

**判定したら、先に進む前に記録先へ記録する**（interactive / unmanned 共通）。後から「不要と判断した」のか「飛ばした」のかを区別し、pr-review-gate が出口で機械照合できるようにするため。コメントの 1 行目は正規表現 `^仕様化判断: (する|しない)$` に完全一致させる（太字・全角コロン・末尾句点を付けない）。2 行目以降に理由（`skills/develop/references/decision-criteria.md` のどの条件に当たったか）を書く:

```bash
# issue が記録先
gh issue comment <issue番号> --body "$(printf '仕様化判断: する\n理由: 既存 capability の要件を変える（レビューの担い手と記録先の設計判断を含む）')"
# Draft PR が記録先
gh pr comment <PR番号> --body "$(printf '仕様化判断: しない\n理由: 受け入れ条件が PR 本文に明記された機械的な振る舞い変更（設計判断なし）')"
```

判定をやり直したら同じ書式で投稿し直す（照合側は最新 1 件を正とする。契約の正本は `references/roles/spec-reviewer.md`「判断記録の契約」）。**記録する前に分割判定へ進まない**（実装へ進まない規則は `worker/common.md`「実装に入る前の確認」）。

仕様化しないと判定した場合は分割判定と `openspec new change` を飛ばし、本体に「仕様化しない」と return する（本体は (3a) の実装から W を再開する。同じコンテキストなのでそのまま続けてよいと本体が指示することもある）。本体が同じコンテキストのまま (3a) へ進むよう指示したら、`worker/implement.md` を読んでから進む。この return には作業項目ごとに `触る範囲: <パス>:<開始行>-<終了行>` を書く（書き方は下の「仕様化する場合（(1) の終わり）」の `tasks.md` と同じ。`tasks.md` が無いので return が置き場になる）。

## 分割判定（単一 change か複数 change か）

仕様化すると判定した場合、規模を判定する（詳細は `skills/develop/references/decision-criteria.md` Step C）。根拠は**記録先の記述**（受け入れ条件・機能単位）だけで、機械的なシグナル（本文の長さやラベル）は使わない:

- **単一 change で足りる**（すべて満たす）: 単一 capability に閉じる／受け入れ条件が概ね数個で 1 PR で完結／独立した設計判断が 1 つ以内
- **複数 change に割れる**（いずれか成立）: 複数の独立 capability に跨る／受け入れ条件が多く順序依存のあるサブタスクに割れる／1 実装サイクルで完結しない規模

境界の一言定義: **「opsx change が 2 つ以上必要になりそうなら複数 change」**。

複数 change に割れた場合の振る舞いはモードで分かれる:

- **interactive**: change 候補（名前・範囲・依存順）を return し、本体が change ごとに 1 ループを回す（本体はエピック化も選べる）。本体から「この change を進めよ」と再開されたら、その 1 change について以下を続ける
- **unmanned（1 サイクル 1 仕事）**: その場で全部やらず、**change 単位で子 issue を作成**する。各子 issue は自然言語でも「それ単体で実装可能」な記述（受け入れ条件付き）にし、`gh` の依存関係で順序を付ける:
  ```bash
  gh api -X POST repos/<owner>/<repo>/issues/<後続>/dependencies/blocked_by -F issue_id=<前提の issue id>
  ```
  元 issue に「N 個の change に分割した（#a → #b → #c）」とコメントし、各子 issue に `agent-ready` を付け、「分割した」と return する（本体はこのサイクルを終える）
- **割り方が判断できないほど曖昧**: interactive は return で本体に聞いてもらう。unmanned は Discord でユーザーに質問し、記録先に `needs-approval` を付けて経緯をコメントし、「needs-approval」と return する

## 仕様化する場合（(1) の終わり）

**対象の change が既に存在し artifact（proposal / design / tasks / specs）が揃っているなら、`openspec new change` を再実行しない。** 本体や主が `/opsx:ff` で先に作った change もそのまま使い、「仕様できた: openspec/changes/<change-name>/」と本体に return する。

openspec CLI で artifact を作る場合は `openspec new change <change-name>` を実行し、`openspec status --change <change-name>` で依存順を確認する。`openspec instructions <artifact> --change <change-name>` で各 artifact の指示を得て、proposal / design / tasks / specs を直書きする。`tasks.md` の各タスクの末尾には `触る範囲: <パス>:<開始行>-<終了行>` を書く（複数なら読点で並べる。新しく作るファイルは `<パス>（新規）`。節の見出しや関数名が分かるときは添える）。行番号は仕様づくりの時点の値で、前のタスクの編集でずれうる。実装の担い手はこれを案内にして、編集前に該当範囲を読む。揃ったら本体に return し、同じ仕様レビューを受ける。R1 の APPROVE を確認してから実装に入る規則は `worker/common.md`「実装に入る前の確認」。

R1 が記録先にコメントした仕様レビュー結果（書式は `worker/common.md`「実装に入る前の確認」）が `REQUEST_CHANGES` なら、本体からの再開指示を受けて artifact を直し、修正箇所を列挙して return する（再レビューは差分限定。周回と続行は本体が develop SKILL.md「レビューの周を主に聞かずに続ける（直し方の判定）」で決める）。
