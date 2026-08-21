# 正フィクスチャ: インストール先を明示した絶対パス表記

プラグイン内のディレクトリ名を含むが、チルダ始まりの絶対パスなので生成先 repo からも解決できる。

観点カタログ（`~/.claude/plugins/marketplaces/*/plugins/casting/catalog/catalog.md`）が正本。
合成は `~/.claude/plugins/marketplaces/*/plugins/casting/scripts/casting-check.sh resolve <repoルート>` で確認できる。
