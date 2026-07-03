# Design: infra-fixes

## Context

`plugins/infra/` は `/infra-setup` スキルが Phase 1〜5 の Agent を順に呼び出し、Vercel + Supabase + GitHub Actions の 4 環境（local/staging/prod + CI）を構築するプラグイン。2026-07-03 の全面レビューで、実装が部分的にしか同期していない箇所（付録 A finding 1）、Secrets 名の不一致（finding 2）、文書間の矛盾（finding 5〜9）が指摘された。本 change は plan.md 付録 A の 9 件と、spec 作成時に実施した実地検証（`gh api` によるバージョン確認、`vercel help` によるサブコマンド確認、grep によるファイル内容の突合）を一次ソースとする。

## Goals / Non-Goals

**Goals:**

- Phase 5 の `.env.local` 検証を Phase 2/3 の実装（`.env.production.local` 分離方式）に追随させ、誤検出による自動修正の暴発を止める
- テンプレが参照する `secrets.*` と Phase 4 の投入リストを 1:1 一致させる
- Actions バージョンピンを実在確認済みの最新へ揃える
- Vercel Token CLI 化の実現可能性を検証し、結果を文書に残す
- Preview deploy 方針・Step 番号・`vercel link` 用法・アーキ図・version drift・個人パスの文書矛盾を解消する

**Non-Goals:**

- Phase 2/3 のロジック変更（既に新方式で実装済みのため対象外）
- `.env.production.local` 方式自体の設計変更（正として扱う）
- Vercel Token 取得の自動化実装（CLI 化不可と判明したため、フォールバック方式の実装変更はしない）
- README.md の書き換え（実装と整合済みと確認したため対象外。念のため他ファイル修正後に diff が生じないことだけ確認する）

## Decisions

### D1: Phase 5 の検証は `.env.production.local` の存在確認 + `.env.local` の dev 値確認に置き換える

- 現状（`agents/infra-phase-5-finalize.md:13,39-60,225`）は「`.env.local` に prod 値がコメントアウト保存されている」ことを期待して検証している。しかし Phase 2 Step 11/11.5（`agents/infra-phase-2-supabase.md:207-254`）は既に prod 値を `.env.local` には一切書かず、別ファイル `.env.production.local` に active な値として書き込む方式に変更済み（Phase 2 Step 11.5 のコメント: 「以前はコメントアウト保存だったが脆すぎた」）。Phase 3（`agents/infra-phase-3-vercel.md:35-42`）も既に `.env.production.local` から値を読む新方式。Phase 5 だけが取り残されている
- 採用: Phase 5 Step 2 の検証項目を「`.env.local` の `NEXT_PUBLIC_SUPABASE_URL`/`ANON_KEY` が dev 値であること」＋「`.env.production.local` が存在し `NEXT_PUBLIC_SUPABASE_URL`/`ANON_KEY` が prod 値で active に書かれていること」の 2 ファイル確認に変更する。「prod 側がコメントアウトで保存されている」という期待は削除する
- Step 1 のゴール記述、Step 6 完了サマリー、「重要な注意事項」節（:225 付近）の「prod系がコメントアウトで保存されている前提」も同時に書き換える

### D2: Secrets 投入リストはテンプレ参照名を正として拡張し、`SERVICE_ROLE_KEY` は Phase 2 に取得手順を追加する

- `grep -rho 'secrets\.[A-Z_]*' plugins/infra/templates/ | sort -u` の実行結果（実地確認済み）:
  `EDGE_CONFIG_ID` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` / `NEXT_PUBLIC_SUPABASE_URL` / `PROD_SUPABASE_ANON_KEY` / `PROD_SUPABASE_DB_URL` / `PROD_SUPABASE_PROJECT_REF` / `PROD_SUPABASE_SERVICE_ROLE_KEY` / `PROD_SUPABASE_URL` / `SUPABASE_ACCESS_TOKEN` / `SUPABASE_SERVICE_ROLE_KEY`（ci.yml.template のコメントアウト E2E ブロック内のみ、非アクティブなので対象外）/ `VERCEL_ORG_ID` / `VERCEL_PROJECT_ID` / `VERCEL_TOKEN`
- Phase 4 Step 7 の現行投入リスト: `VERCEL_TOKEN` / `VERCEL_ORG_ID` / `VERCEL_PROJECT_ID` / `SUPABASE_ACCESS_TOKEN` / `PROD_SUPABASE_PROJECT_REF` / `PROD_SUPABASE_DB_URL`
- 不足: `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY`（ci.yml.template の型チェック用。dev プロジェクトの値を投入する。CI の `next build` は型チェックのみが目的で実データ疎通は不要なため、prod ではなく dev の値で十分かつ安全）、`PROD_SUPABASE_URL` / `PROD_SUPABASE_ANON_KEY`（deploy-staging.yml.template が prod DB へ差し替えるための値。`.env.production.local` と同じ値を投入する）、`PROD_SUPABASE_SERVICE_ROLE_KEY`
- `EDGE_CONFIG_ID` は Phase 4 Step 7 に既に「オプション」として `gh secret set EDGE_CONFIG_ID` の文言込みで説明済み（メンテナンスモードを使う場合のみ、別途アプリ側 middleware 実装とセットで案内）。これは受け入れ条件 5 の「テンプレ参照名が投入リストに存在する」を文言レベルで満たしており、無条件の自動投入対象には含めない（config.yaml rule には EDGE_CONFIG_ID の言及がなく、finding 2 も SERVICE_ROLE_KEY のみを名指ししているため、現状の「オプション扱い」の記述を維持する）
- `PROD_SUPABASE_SERVICE_ROLE_KEY`: config.yaml rule「使うなら Phase 2 に取得手順を追加、使わないならテンプレから参照を除去」に従い判定。`deploy-staging.yml.template:52,66,85,95` でビルド時 sed 置換とランタイム `-e` 注入の両方に実使用されており、staging がステークホルダー/QA 向けに本番相当のサーバー権限で動作する設計の一部（README.md/Phase4 Step4 コメントに明記）。よって「テンプレから除去」ではなく「Phase 2 に取得を追加」を採用
  - Phase 2 Step 9（`agents/infra-phase-2-supabase.md:177-188`）は現状 `anon` key のみ抽出している。ここに `npx supabase projects api-keys --project-ref {PROD_REF}` の出力から `service_role` key も抽出し `PROD_SERVICE_ROLE_KEY` として保持する手順を追加する
  - **重要な設計判断**: `service_role` key は RLS を完全にバイパスする最強権限のため、Phase 2 の「機密値は state に書かない」原則を維持しつつ、`.env.production.local` に追記する（`.env.local` には書かない。dev 側では service_role を使わない設計のため dev 用の取得は行わない）
- Phase 4 Step 7 に `gh secret set PROD_SUPABASE_URL` / `PROD_SUPABASE_ANON_KEY` / `PROD_SUPABASE_SERVICE_ROLE_KEY`（`.env.production.local` から取得）と `gh secret set NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY`（`.env.local` の dev 値から取得）を追加する

### D3: Actions バージョンは実地確認済みの最新メジャータグへ揃える（finding 4 の想定より広い）

- `gh api /repos/actions/checkout/tags` → 最新メジャー `v7`（finding 4 は `v6` を想定していたが、確認時点で `v7` が存在）
- `gh api /repos/actions/setup-node/tags` → 最新メジャー `v6`（finding 4 の想定と一致）
- `gh api /repos/actions/upload-artifact/tags` → 最新メジャー `v7`（finding 4 は「現行のまま(v4)」としていたが、実際は v4 は 3 世代古い）
- `gh api /repos/actions/github-script/tags` → 最新メジャー `v9`（finding 4 は「現行のまま(v7)」としていたが、実際は v7 は 2 世代古い）
- `gh api /repos/supabase/setup-cli/tags` → 最新メジャー `v2`（finding 4 に記載なし。5 テンプレート中 `deploy-production.yml.template` / `migrate-production.yml.template` が `@v1` を使用しており、同じ「鮮度」軸の見落としと判断しスコープに含める）
- 採用: 5 種類全てのピンを上記の実地確認済み最新メジャータグへ更新する。config.yaml rule「実在を確認してから適用する（確認できなければ現行維持 + 注記）」を満たすため、builder は実装着手時に同じ `gh api` コマンドで再確認し、本 design.md の記載日（2026-07-03）から日数が経っている場合はその時点の最新へ合わせる（本 design.md のタグ名はハードコードでなく「実装時点の確認結果」を正とする）

### D4: Vercel Token CLI 化は不可と判定し、現状維持 + 注記で決着する

- Vercel CLI 48.12.0 の `vercel help` 出力を実地確認した結果、`tokens` / `token` サブコマンドは存在しない（`Basic`/`Advanced` コマンド一覧に含まれず、`vercel tokens --help` はトップレベル `deploy` のヘルプにフォールバックする）
- Vercel の Access Token は歴史的にダッシュボード UI 経由の生成のみをサポートしており、CLI/REST API から「最初の」トークンを作る手段は存在しない（トークンで認証しないと呼べない REST API はこの用途に使えない、鶏と卵の制約）
- 採用: `agents/infra-phase-4-github-actions.md` Step 5 と `skills/infra-setup/SKILL.md` 技術メモ（「Vercel Token: ダッシュボード手動生成のみ」）は変更しない。ただし finding 3 が要求する「検証した」という事実を残すため、両ファイルに「2026-07-03 時点で Vercel CLI 48.x に `tokens` サブコマンドは存在せず、CLI 化不可と確認済み」という注記を追加する

### D5: Preview deploy 方針の矛盾は実装（`deploy-preview.yml.template`）を正とし、`SKILL.md` と `infra-phase-5-finalize.md` を修正する

- 実装（`deploy-preview.yml.template:4-5,22-23`）: `pull_request` の `ready_for_review` で発火し、`draft == false` になった時点で実際に Preview deploy が実行される
- `README.md:31`「PR は Draft + Ready for review 方式（Draft 中は CI・Preview deploy を skip、Ready for review で発火）」は実装と整合している。**変更しない**
- 矛盾していたのは `skills/infra-setup/SKILL.md:40`「PR時は CI のみで自動 preview deploy は行わない（個人開発前提）」と `agents/infra-phase-5-finalize.md:179`「PR 時は CI（test/lint/type-check）のみ実行されます。自動 Preview deploy は行われません。」の 2 箇所。付録 A finding 5 は矛盾側に README.md を挙げていたが、実地確認の結果 README.md は正しい記述だったため対象から外し、`SKILL.md` と `infra-phase-5-finalize.md` を「Draft 中は skip、Ready for review で Preview deploy が実行される」という表現に統一する

### D6: `vercel link` 用法は Step 3 本文（対話フロー案内）を正とし、トラブルシューティング節を整合させる

- `agents/infra-phase-3-vercel.md` Step 3（:61-67）: 「`--project` フラグは既存プロジェクト指定用で、新規作成には使えない」→ 新規作成時は対話フロー `vercel link`（フラグなし）を使う設計
- 同ファイルのトラブルシューティング節（:286）: 「`vercel link` が対話型で止まる → `--yes --project {project_name}` を使う」
- 採用: 両者は実は矛盾ではなく「新規作成時（対話必須）」と「既存プロジェクトへの再リンク時（`--yes --project` で確定可能）」という別ケースの説明だが、現状の文面では使い分けが明示されておらず読み手が混同する。トラブルシューティング節の先頭に「（既存プロジェクトへの再リンク時のみ。新規作成は Step 3 の対話フローに従うこと）」を追記して曖昧さを解消する

### D7: SKILL.md の version / 個人パスは plugin.json 基準・環境非依存に揃える

- `skills/infra-setup/SKILL.md:4` の `version: 0.1.0` を `plugins/infra/.claude-plugin/plugin.json` の実バージョン（bump 後の値）と一致させる
- `skills/infra-setup/SKILL.md:261` の `/Users/oratta/Dropbox/WorkSpace/10_BusinessProject/Kajino/pre-demo` ハードコード参照は「参考: 関連ドキュメント」節の1行のみで、他プロジェクトで使う開発者にとって意味を持たない個人パス。行ごと削除する（参考元プロジェクトの説明価値は低く、代替情報を追加する必要はない）

## Risks / Trade-offs

- [Phase 2 への service_role key 取得追加] 新たに最強権限キーを扱うステップが増える → Mitigation: 既存の「機密値は state に書かない」原則をそのまま適用し、`.env.production.local`（gitignore 済み）にのみ保存。ログ・state・完了報告メッセージに実値を出力しない
- [Actions バージョンの陳腐化] design.md 記載のタグ名は執筆時点のスナップショットで、実装着手時にはさらに新しいメジャーが出ている可能性がある → Mitigation: D3 の通り、builder は実装時に同じ `gh api` コマンドで再確認して最新値を採用する
- [Vercel Token CLI 化「検証のみで実装なし」という結論] finding 3 は「動けば置換」を期待していたが調査の結果不可と判明 → Mitigation: config.yaml rule 自体が「動かなければ現状維持 + 調査結果を注記」を明示的に許容しているため、後退ではなく想定内の結論

## Migration Plan

1. worktree 内で Phase 5 → Phase 2/4（secrets）→ Actions バージョン → Vercel Token 注記 → 文書整合性（Preview/Step番号/vercel link/アーキ図/version drift）の順に実装する（Phase 5 の検証ロジック変更が最も実害が大きいため最優先）
2. 各修正後、対応する受け入れ条件（5, 6）の grep コマンドをその場で実行して PASS を確認しながら進める
3. ロールバック: 単一 change のため PR クローズ（または revert）で復帰可能。実行中の `/infra-setup` セットアップへの影響はない（Agent の instruction ファイルのみの変更で、既存の `.env.local` 等生成済みファイルには影響しない）

## Open Questions

なし（付録 A の 9 件および実地検証で判明した追加事項は全て本 design.md の Decisions で解消済み）
