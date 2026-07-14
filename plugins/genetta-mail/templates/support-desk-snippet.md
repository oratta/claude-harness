<!--
genetta-mail-setup が生成する窓口追記スニペット。
{{SLUG}} / {{DOMAIN}} / {{AGGREGATE_EMAIL}} / {{PRIMARY_OWNER}} をヒアリング結果で置換したうえで、
対象サービスの docs/ops/support-desk.md 相当ファイルの「窓口」節に追記または新規作成する。
このスニペット単体は完全なサポート運用設計書ではない（権限マトリクス・SLA等は対象サービス側で別途定義する）。
-->

## 窓口

- チャネル: メール1本（`support-{{SLUG}}@{{DOMAIN}}`。{{DOMAIN}} の Cloudflare Email Routing で `{{AGGREGATE_EMAIL}}` へ転送、返信名義は `support@{{DOMAIN}}`。全サービス共通の `support-<slug>@` 命名規約に従う）
- 命名はハイフン区切り（`support-{{SLUG}}@`）。`+` サブアドレス方式は Cloudflare Email Routing が解決せず 550 で不達になるため不採用
- ルーティング方式: 個別ルール（catch-all は不採用。`{{DOMAIN}}` 宛の未登録アドレスは 550 で拒否される）
- 一次対応: {{PRIMARY_OWNER}}
