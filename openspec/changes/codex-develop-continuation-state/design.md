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

1. **継続設定の正本は issue/Draft PR の最新の機械可読記録にする。** 初回の実行先設定と既存の記録先契約を同じ場所で追跡でき、会話コンテキストやローカル最新 run の推測に依存しないためである。既存の `executor codex / account ... / model ... / run-dir ... / worker-state ...` 形式を正規化し、coordinator が初回確定時と継続可能な run 更新時に記録する。ローカル run は transport の整合性検証に使うが、記録先を探索する代替正本にはしない。

2. **復元は fail-closed にする。** executor が未指定の追加依頼では、記録が一意に見つかり、executor が codex で、全パスと run の account/model/worker-state が一致した場合だけ Codex adapter を再利用する。欠落、形式不正、複数候補の不一致、run 不在、整合性不一致は停止して指定を求める。Claude 経路への暗黙 fallback は、依頼が別実行先で処理される危険があるため採用しない。

3. **既存 develop の工程判断を再利用する。** 継続記録は transport の復元にだけ使い、仕様要否、分割、レビュー、verify、finish/G の判定は既存 develop と roles の正本に委譲する。これにより 89764a8 で撤去した adapter 独自ゲートを再導入しない。

## Risks / Trade-offs

- [Risk] コメントが編集・削除されると復元できない → 書式不正・候補不在として停止し、指定の再入力を求める。別の run を推測しない。
- [Risk] issue と Draft PR に異なる記録がある → 一意性検証で停止し、coordinator に競合する記録を提示させる。
- [Risk] run-dir の絶対パスが別環境で無効になる → run の存在・所有権・cwd・固定 account/model/worker-state を検証し、失敗時は停止する。
- [Trade-off] GitHub コメント取得が必要になる → worker は network 操作を行わず、既存の本体の GitHub 代理操作で取得・記録する。
