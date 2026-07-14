---
name: genetta-mail-setup
description: 新サービスのサポート窓口メール（support-<slug>@genetta.jp）をセットアップする。Cloudflare Email Routing の個別ルーティングルール作成、Gmail のラベル・フィルタ作成、対象サービス docs への窓口追記、到達テストまでを一気通貫で進める。「メール窓口を作って」「サポートアドレス追加」「genetta-mail」「窓口メールをセットアップ」で起動。
version: 0.1.0
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
---

# genetta-mail-setup — サービス窓口メールのセットアップ

genetta.jp ドメイン配下の新サービス向けサポート窓口（`support-<slug>@genetta.jp`）を、既存のドメイン設定を壊さずに追加する。設計の正本は genetta-inc/suimei の `docs/ops/genetta-mail-skill-design.md`（個別ルーティングルール方式に改訂済み）。

**スコープ**: 窓口を「使える状態にする」ところまで。問い合わせの分類・自動返信等の CS エージェント本体は扱わない（対象サービス側の `docs/ops/cs-agent-design.md` 相当が別途担当）。

## 前提

- genetta.jp は Cloudflare Email Routing 設定済み（MX/SPF 確認済み）
- **catch-all は使わない**（2026-07-13 オーナー判断で撤回。ドメイン宛のランダム送信攻撃を全受信してしまいスパムの攻撃面が広すぎるため。存在しないアドレス宛は 550 で拒否する運用を維持する）。そのためサービスごとに個別ルーティングルールを1件作成する
- 命名は必ずハイフン区切り（`support-<slug>@`）。`+` サブアドレス方式は不採用: Cloudflare Email Routing が `+` サフィックスを既存ルールに解決せず `550 5.1.1 Address does not exist` で不達になることが実弾で判明している。加えて `+` 入りアドレスは Web フォームの email バリデーションで弾かれることがある

## 手順

### 1. ヒアリング

AskUserQuestion で以下を確定する:

| 項目 | 備考 |
|---|---|
| `<slug>` | プロダクトスラッグ（例: `uranai`）。既存スラッグと重複しないか後続手順で確認する |
| ドメイン | 既定 `genetta.jp`。別ドメイン運用の場合のみ変更 |
| 集約先メールアドレス | 既定 `oratta@gmail.com` |
| 対象サービスの GitHub リポジトリ | `owner/repo` 形式。docs 追記（手順4）で使う |

### 2. Cloudflare Email Routing に個別ルールを作成する

まず重複確認と `CLOUDFLARE_API_TOKEN` の有無を確認する:

```bash
echo "${CLOUDFLARE_API_TOKEN:+set}"
```

**`CLOUDFLARE_API_TOKEN` がある場合（Email Routing の Zone 編集権限が必要）**: API で確認と作成を行う。

```bash
# zone_id を取得
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=<domain>" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" | jq -r '.result[0].id')

# 既存ルール一覧を確認し、support-<slug>@ が未登録であることを確認する（読み取り）
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/email/routing/rules" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" | jq '.result[] | {matchers, actions, enabled}'
```

未登録であることを確認できたら、作成するルールの内容（マッチ条件 `support-<slug>@<domain>` → 転送先 `<集約先メール>`）をユーザーに提示し、AskUserQuestion で承認を得てから作成する:

```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/email/routing/rules" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{
    "matchers": [{"type": "literal", "field": "to", "value": "support-<slug>@<domain>"}],
    "actions": [{"type": "forward", "value": ["<集約先メール>"]}],
    "enabled": true,
    "name": "support-<slug>"
  }'
```

作成後、GET で一覧に反映されていることを確認する。

**`CLOUDFLARE_API_TOKEN` がない場合**: 以下の手動手順を提示し、人間に依頼する。

1. Cloudflare ダッシュボード → 対象ドメイン → 「メール」→「メールルーティング」
2. 「ルーティングルールを作成」
3. パターン: `support-<slug>` @ `<domain>`
4. アクション: 「メールに送信」→ 集約先アドレス（`<集約先メール>`）
5. 有効化して保存

いずれの経路でも、**既存の `support-<slug>@<domain>` が既に使用中の場合は上書きせず、ユーザーに確認する**。ドメインの catch-all は無効のまま維持する（本手順で有効化しない）。

### 3. Gmail にラベル・フィルタを作成する

以下の内容をユーザーに提示し、AskUserQuestion で承認を得てから進める:

- ラベル: `support/<slug>` を新規作成
- フィルタ: `to:support-<slug>@<domain>` に一致するメールに `support/<slug>` ラベルを付与（受信トレイはスキップしない。見落とし防止のため主受信トレイにも残す）

Gmail はブラウザ操作が必要なため、以下いずれかで進める:

- **人間に依頼**: Gmail の設定 →「フィルタとブロック中のアドレス」→「新しいフィルタを作成」の手順を提示し、作成を依頼する
- **claude-in-chrome スキルで自動操作**: ブラウザ経由の操作が許可されている環境であれば、`claude-in-chrome` スキルを使って Gmail の設定画面を操作しラベル・フィルタを作成する（実行前に作成内容をユーザーに提示し承認を得る）

### 4. 対象サービス docs に窓口を追記する

対象リポジトリに `docs/ops/support-desk.md` 相当のファイルがあるか確認する:

```bash
gh api repos/<owner>/<repo>/contents/docs/ops/support-desk.md --jq .content 2>/dev/null | base64 -d
```

- **既存ファイルがある場合**: 「窓口」節を `${CLAUDE_PLUGIN_ROOT}/templates/support-desk-snippet.md` の内容で更新する（`{{SLUG}}` `{{DOMAIN}}` `{{AGGREGATE_EMAIL}}` `{{PRIMARY_OWNER}}` をヒアリング結果で置換）。既存の権限マトリクスや SLA など他の節は変更しない
- **ファイルがない場合**: `${CLAUDE_PLUGIN_ROOT}/templates/support-desk-snippet.md` を土台に、対象サービスの `docs/ops/support-desk.md` として新規作成することを提案する（このスニペットは窓口節のみであり、権限マトリクスや SLA は対象サービス側で別途定義が必要であることを伝える）

追記・作成した diff をユーザーに提示する。

### 5. 到達テストを行う

- 人間に `support-<slug>@<domain>` 宛のテストメール送信を依頼する
- 確認する内容:
  1. 集約先メールアドレスに着信すること
  2. 作成した Gmail フィルタが発火し `support/<slug>` ラベルが付くこと
- **550 エラーが返った場合のトラブルシュート**:
  - ルールのマッチ条件のタイポ（`support-<slug>` のスペル、ドメイン名）を確認する
  - Cloudflare 側のルールが `enabled: true` になっているか確認する
  - 宛先アドレス（転送先）が Cloudflare Email Routing 側で認証済み（destination address が verified）か確認する。未認証の場合、転送先アドレスに確認メールが届いているはずなのでその承認を促す

### 6. 完了報告

作成した Cloudflare ルール内容・Gmail ラベル/フィルタ・docs 追記箇所・到達テスト結果をまとめて提示する。

## 安全原則

- Cloudflare・Gmail いずれも**書き込み操作の実行前に内容をユーザーに提示し、承認を得る**
- 既存の `support-<slug>@<domain>` が使用中の場合は上書きせず確認を求める
- ドメインの catch-all は有効化しない
- 既存の他サービスのルーティングルール・Gmail フィルタを変更・削除しない

## してはならないこと

- ドメイン全体の catch-all 設定を有効にすること
- 既存の他サービスのルーティングルールやラベル・フィルタを上書き・削除すること
- 問い合わせの分類・自動返信など CS エージェント本体の機能を実装すること（スコープ外）
- Cloudflare・Gmail への書き込み操作をユーザー承認なしに実行すること

## 自己検証

完了宣言の前に、以下を確認する:

- Cloudflare 側: `CLOUDFLARE_API_TOKEN` 経由で作成した場合は GET で一覧に反映されていることを確認済みであること。ダッシュボード経由の場合は人間から作成完了の確認を得ていること
- Gmail 側: ラベル・フィルタの作成完了を人間から確認していること（または claude-in-chrome で作成後にスクリーンショット等で確認していること）
- docs 追記の diff を提示済みであること
- 到達テストの結果（着信・ラベル付与の成否、550 の場合はトラブルシュート内容）を報告していること
