# prepare-reviewer — pr-review-gate

入口: 通常または補足の needs-reviewer の payload を組むときだけ読む。

## G として動くとき（develop）

### needs-reviewer の return（本体にレビュアーの spawn を委ねる）

G は手順 1（前提を揃える・HEAD SHA の固定）と手順 2-0（light / full の判定と `レビュー重量:` コメント）まで済ませてから、次の payload で本体に return する。本体はこれを読んでレビュアー（既定は `subagent_type: dev-workflow:reviewer` に `model: opus`。マージ条件・層間契約・課金/法務に触れれば `subagent_type: dev-workflow:decider` で spawn する。`general-purpose` に `model: fable` は付けない。聖域パスだけでは上げない）を spawn し、照合と振り分けの G を新しく起こしてその要約を渡す。adapter 経路（`レビュー経路: adapter`）では、本体が phase `review` で投げ先を選び直して dispatch 記録に残してからレビュアーを起動し（develop `SKILL.md` の (4)）、要約と選ばれた executor / model・dispatch 記録のコメント URL を G に渡す。adapter 経路の payload では証拠欄 5 つ（選んだ経路・実行コマンド・終了コード・出力の要点・実待ち時間）をすべて `未実行（adapter 経路）` と書き、Codex の証拠を作らない。`推奨モデル` は参考値で、実際の投げ先は本体の選び直しが決める。Codex 不可・Codex オフ・light 判定・adapter 経路による通常の初回レビュー依頼は下の基本 payload を使う。一周目の三表照合で不足が出た補足要求の場合に限り、同じ payload に固定 HEAD・元の三表・残差・`補足済み回数: 0` を加え、同じレビューの不足した項目だけを補わせる（adapter 経路では補足要求も本体の選び直しを通る）。

```markdown
## needs-reviewer
- 判定: light | full（Codex 不可） | full（Codex オフ） | full（adapter 経路）
- 根拠: <2-0 の判定材料（変更ファイル一覧・行数・挙動定義ファイルの有無）、full なら Codex が使えなかった理由、Codex オフなら `Codex オフ（設定）`>
- PR 番号: #<N>
- HEAD SHA: <40 桁フル SHA（手順 1 で固定したもの）>
- 区画: <なし（二周目以降・差分限定・全体レビューの周は常に なし） | review-partitions.sh の出力の区画の一覧>
- 選んだ経路: <full: exec / companion / バイナリ探索で不在、light: 未実行、adapter 経路: 未実行（adapter 経路）、Codex オフ: 未実行（Codex オフ）>
- 実行コマンド: <full: 実際の探索・起動・待機コマンド、adapter 経路: 未実行（adapter 経路）、Codex オフ: python3 <plugin>/scripts/usage_view.py --codex-enabled → off>
- 終了コード: <取得できた値 | 未取得 | 未実行（adapter 経路） | 未実行（Codex オフ）>
- 出力の要点: <full: 実測した不可条件と応答、adapter 経路: 未実行（adapter 経路）、Codex オフ: Codex オフの設定により Codex を試していない>
- 実待ち時間: <タイムアウト時の実測値、完了未確認、adapter 経路: 未実行（adapter 経路）、Codex オフ: 未実行（Codex オフ）>
- 推奨モデル: opus（種別は dev-workflow:reviewer） | dev-workflow:decider（種別で指定する。`general-purpose` に `model: fable` は付けない）
- 推奨モデルの根拠: <マージ条件・層間契約・課金/法務への接触の有無、usage snapshot の残量>
- 受け入れ条件の所在: <issue #N 本文 | PR #N 本文>
- レビュアーに渡す範囲: <diff の範囲（`gh pr diff N`）、再レビューなら前回指摘の一覧>
- 周回: <周回の値>（説明の整合の取り直しなら取り直し行を添え、区画は なし、周回 1 でも再レビューで三表は要らないと書く）
- レビュアーに渡す指示: `skills/pr-review-gate/stages/reviewer-brief.md` の手順 2-1 のレビュアー向け指示ブロック（三表と固定書式）をそのまま貼る
- 補足 payload（一周目照合の補足要求の場合だけ）: 固定 HEAD: <SHA> / 一周目の区画: <なし | n> / 元の三表: <変更点の一覧・照合表・ハンク被覆> / 残差: <不足項目を補足先の区画ごとに分ける> / 補足済み回数: 0
- 補足指示（一周目照合の補足要求の場合だけ）: 元の三表を置き換えず、残差に挙げた不足した項目だけを補う
```

本体は executor が claude のときだけ区画ごとに起こす（`gate-result.md` の needs-reviewer）。補足は `一周目の区画:` の構成を使い、区画を計算し直さない。

レビュー要約は照合と振り分けの G が受け取る。レビュー実行者を記録する PR コメントの投稿と、そのあとの分岐は `stages/triage.md` の「G として動くとき（develop）」節と `stages/gate-triage.md` の「段ごとの起動と入力」の「レビュアーの要約受領」に従う。

出口: 本文の payload で return する。本体がレビューのあとに新しい照合と振り分けの G を起こす。
