## Context

初回の `/dev-workflow:develop --executor codex --account NAME --model MODEL` は `$ARGUMENTS` から設定を読み、`run-dir` に account/model/cwd/worker-state を固定する。一方、同じ会話の追加依頼にはそのオプションがなく、現在の command/provider adapter は継続設定を検索する状態を持たない。既存の手動 Codex change は transport と品質工程の分離を定めているため、この change は継続状態の復元だけを扱う。

## Goals / Non-Goals

**Goals:**

- issue または Draft PR に保存した継続記録から初回の executor・account・model・run-dir を復元する。
- 復元した run の account/model/worker-state/cwd の整合性を検証し、追加依頼を同じ担当へ送る。
- 記録を復元できない場合に Claude 経路へ黙って落とさず停止する。
- 追加依頼を含む設定復元・停止・委譲先固定の回帰テストを持つ。

**Non-Goals:**

- 役割ごとの executor/model/account 配分、消費計測、自動配分。
- 新しい Codex 専用の仕様必須・承認台帳・check/archive ゲート。
- GitHub API の実装や、本体が担当するコメント・push・commit の代理操作の移管。
- 会話全文や秘密情報の保存。

## Decisions

1. **継続設定の正本は、既存 develop が選んだ記録先にある最新の機械可読記録にする。** 記録先の選択は issue を優先し、issue が無い場合だけ Draft PR とする。一度選択した後に別の記録先を横断検索しない。記録は次の 1 行を固定形式とする（キーの順序・空白・マーカーは固定、未知のキーと重複キーは不正）。値は UTF-8 の各バイトを RFC 3986 の unreserved 文字以外について `%HH` 大文字でエンコードし、空値を許さない。

   `<!-- codex-develop-continuation:v1 executor=codex account=<value> model=<value> run-dir=<value> worker-state=<value> cwd=<value> -->`

   必須キーは `executor`、`account`、`model`、`run-dir`、`worker-state`、`cwd` であり、`executor` は `codex` に限る。coordinator は初回確定時と継続可能な run 更新時にこの行を記録する。記録先内の候補はコメント ID の降順（同一プラットフォームの作成順）で走査し、最新候補が正確に 1 行の形式不正なら停止する。最新候補が正しい場合はそれだけを採用し、古い候補は無視する。issue と Draft PR の両方に候補が存在しても、選択済みの記録先以外は競合候補に数えない。ローカル run は transport の整合性検証に使うが、記録先を探索する代替正本にはしない。

2. **復元は fail-closed にする。** executor が未指定の追加依頼では、記録が一意に見つかり、executor が codex で、全パスと run の account/model/worker-state が一致した場合だけ Codex adapter を再利用する。欠落、形式不正、複数候補の不一致、run 不在、整合性不一致は停止して指定を求める。Claude 経路への暗黙 fallback は、依頼が別実行先で処理される危険があるため採用しない。

3. **既存 develop の工程判断を再利用する。** 継続記録は transport の復元にだけ使い、仕様要否、分割、レビュー、verify、finish/G の判定は既存 develop と roles の正本に委譲する。これにより 89764a8 で撤去した adapter 独自ゲートを再導入しない。

4. **責務を coordinator と担当者に分ける。** coordinator は記録先の選択、GitHub コメントの取得・保存、LLM ログの取得、run の整合性検証、GitHub 操作および worker が実行できない場合の commit/push の代理を担う。担当者は割り当てられた executor/account/model/run-dir を使う調査・修正・レビューを行い、結果と検証証跡を返す。coordinator は担当者の調査・修正・レビューを代行せず、担当者は coordinator の GitHub 操作やログ取得を代行しない。

## Risks / Trade-offs

- [Risk] コメントが編集・削除されると復元できない → 書式不正・候補不在として停止し、指定の再入力を求める。別の run を推測しない。
- [Risk] issue と Draft PR に異なる記録がある → 既存 develop の記録先選択（issue 優先、無ければ Draft PR）を適用し、未選択の記録先は探索しない。
- [Risk] run-dir の絶対パスが別環境で無効になる → run の存在・所有権・cwd・固定 account/model/worker-state を検証し、失敗時は停止する。
- [Trade-off] GitHub コメント取得が必要になる → worker は network 操作を行わず、既存の本体の GitHub 代理操作で取得・記録する。
- [Risk] コメント値の空白・改行・`=`・`%` が解析を壊す → 固定キー順と UTF-8 パーセントエンコードを適用し、fixture で予約文字を検証する。
