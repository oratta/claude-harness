# Tasks: model-allocation

## 1. ティアリファレンスドキュメント

- [x] 1.1 `plugins/longrun/references/model-tiers.md` を新設し、haiku / sonnet ティアの `opts.model` 渡し値と inherit のセマンティクス（`opts.model` キーを出力しない。agent 定義 frontmatter → 親セッションの順で解決される）を記載する
- [x] 1.2 change-2 の `workflow-tool-reference.md` を参照し、`opts.model` が受け付ける値形式（エイリアス / フルモデル ID）を確認して 1.1 の解決値を確定する
- [x] 1.3 bats テスト: `references/model-tiers.md` が存在し、haiku / sonnet / inherit の 3 ティアが定義されていることを検証する

## 2. plan テンプレート拡張

- [x] 2.1 `plugins/longrun/templates/plan-template.md` に「モデル割り当て」セクションを追加する（ヘッダ行 `| change | ロール | ティア(haiku/sonnet/inherit) | 理由 | 上書き |` の表 + ユーザー直接編集可・上書き欄優先の説明文）
- [x] 2.2 bats テスト: テンプレートにセクションと表ヘッダが存在すること、`claude-` で始まるモデル ID がハードコードされていないことを grep で検証する

## 3. longrun-plan スキルの推奨生成ステップ

- [x] 3.1 `plugins/longrun/skills/longrun-plan/SKILL.md` の Step 5（Synthesis）に推奨生成手順を追加する（change × agent ロールごとに 1 行、3 ヒューリスティクス + 「迷ったら inherit」の保守的デフォルトを明記、ティア解決は `references/model-tiers.md` 参照と記載しモデル ID は書かない）
- [x] 3.2 Step 6（Validation）のセクション存在チェックリストに「モデル割り当て」を追加する（欠落時は保存前に修復する GATE セマンティクス）
- [x] 3.3 Step 8（ユーザー確認）に、モデル割り当て表はユーザーが直接編集して上書きできる旨の案内を追記する（編集後の値を巻き戻さない）
- [x] 3.4 bats テスト: SKILL.md に 3 ヒューリスティクスの文言・「迷ったら inherit」・Validation チェック項目が存在することを grep で検証する

## 4. exec のモデル割り当て消費

- [x] 4.1 `/longrun:exec`（change-2 の workflow スクリプト生成ロジック）に plan.md の「モデル割り当て」表のパース処理を追加する（上書き欄非空なら上書き欄、空ならティア欄を採用）
- [x] 4.2 採用ティアを `references/model-tiers.md` で解決し、該当 change × ロールの agent 呼び出しに `opts.model` を設定する。inherit はキー自体を出力しない
- [x] 4.3 fail-soft 分岐を実装する: 未知ティア値・パース不能行は inherit 扱い + 警告表示（中断・AskUserQuestion なし）。「モデル割り当て」セクションが無い旧 plan.md は全ロール inherit にフォールバックする
- [x] 4.4 bats テスト: fixture plan.md（sonnet 指定 / inherit 指定 / 上書き欄あり / 未知ティア / セクション無し）の 5 ケースで、生成される workflow スクリプトの `opts.model` 有無・値が仕様どおりであることを検証する

## 5. ドキュメント・バージョン同期・統合確認

- [x] 5.1 `plugins/longrun/README.md` にモデル割り当て機構の説明を追記する（表形式・ヒューリスティクス概要・`references/model-tiers.md` へのリンク・旧 plan.md フォールバック）
- [x] 5.2 version を longrun 6.1.0 → 6.2.0 に bump し、3 箇所（`plugins/longrun/.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json` top-level / 同 plugins[] エントリ）を同期する（lr プラグインは変更なし）
- [x] 5.3 `jq . plugins/longrun/.claude-plugin/plugin.json` と `jq . .claude-plugin/marketplace.json` の構文検証、および `bats plugins/longrun/tests/` の全 PASS を確認する
- [x] 5.4 受け入れ条件 14 の確認: モデル割り当て表入り plan.md で exec が `opts.model` を反映すること、表の無い旧 plan.md で全 inherit で動くことをログ付きで確認する
