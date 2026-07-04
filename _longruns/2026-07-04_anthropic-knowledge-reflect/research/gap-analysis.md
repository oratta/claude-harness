# ギャップ分析: 公式推奨 × 素の Claude Code × 既存ハーネス

作成日: 2026-07-04
目的: Anthropic 公式ナレッジ（`anthropic-agent-knowledge.md` / `claude-code-official.md`）の各推奨について、「素の Claude Code を普通に使うだけで実現できるか」「このリポジトリの既存ハーネスでカバー済みか」を判定し、**ハーネスとして新規追加すべき機構**を特定する。

判定記号: ✅=実現できる / △=機構はあるが自分で組む必要がある / ✗=存在しない

| # | 公式推奨 | 出典 | 素のCC | 既存ハーネス | 判定 |
|---|---|---|---|---|---|
| 1 | **外側セッションループ**: compaction だけでは不十分。fresh context のセッションを外側ループで回し、状態は feature-list JSON（`passes:false`）+ progress notes + git で持ち回る。1セッション1機能。セッション開始時 smoke check。テスト後にのみ passing | harnesses論文 | ✗（/loop・cron は再実行のみ。「コンテキストを捨てて外部状態から再開する長期駆動」の設計は全て自前） | ✗（longrun は in-session Workflow のみ。resumeFromRunId は same-session 制約） | **新機構 → change-1** |
| 2 | **eval 駆動開発**: ドキュメントを書く前に評価を3シナリオ作る → ベースライン測定 → 反復。~20ケースの LLM-as-judge ルーブリック評価。Claude A/B 法（設計役とフレッシュ実使用役を交互） | multi-agent / skill-authoring | ✗（機構なし。手動でやるしかない） | ✗ | **新機構 → change-2** |
| 3 | **自己改善ループ**: 失敗トランスクリプトを Claude 自身に診断させ、ツール/スキルの description・指示文を書き換えさせる（公式事例: 完了時間40%短縮） | multi-agent / writing-tools | ✗ | △（e2s は「経験→新スキル蒸留」のみ。既存スキルを実使用ログで改善するループは無い） | **新機構 → change-3** |
| 4 | **決定論的検証ゲート**: 「CLAUDE.md は助言、hook は保証」。テスト通過なしに停止させない等のゲートを hook で強制 | CC best practices | △（hooks 機構はあるが、ゲートは全て自分で書く） | ✗（hook を配布するプラグインが無い） | **新機構 → change-4** |
| 5 | **validator → fix → repeat**: validator（スクリプト or STYLE_GUIDE.md）を与え、通るまで修正させる汎用フィードバックループ | skill-authoring | △（プロンプト次第で不安定） | △（longrun の verify ループは build 専用） | change-2/4 に統合 |
| 6 | verify 三層（rules-based / visual / LLM-judge）+ evidence 提示 | Agent SDK / CC best practices | △ | ✅（longrun verifier + browser-verifier が実装済み。語彙の明文化のみ残） | 既存監査（別トラック） |
| 7 | 委譲契約4点（objective / output format / tool guidance / task boundaries）・fan-out スケーリングルール | multi-agent | —（プロンプト内容の問題） | △（一部 agent 定義に欠け） | 既存監査（別トラック） |
| 8 | description 三人称・「何を＋いつ」・500行制限・1階層参照 | skill-authoring | —（コンテンツ品質の問題） | △ | 既存監査（別トラック） |
| 9 | defer_loading / Tool Search Tool / Tool Use Examples | advanced tool use | ✅（API・CC 本体が提供済み） | — | 対応不要 |
| 10 | compaction / auto memory / subagents / worktree 隔離 / plan mode | 各種 | ✅（本体提供済み） | — | 対応不要 |
| 11 | 構造化出力契約（サブエージェント返却を schema で強制） | multi-agent | △（Workflow の opts.schema はあるが設計は自前） | ✅（longrun schemas/）、✗（infra 等未適用） | 既存監査（別トラック） |
| 12 | プロンプト調律（強語調の overtrigger 対策・early-stop 抑制） | prompting | —（コンテンツ品質の問題） | △ | 既存監査（別トラック） |

## 結論

**ハーネスとして新規追加すべきは #1〜#4 の 4 機構**。いずれも「公式が『こうすべき』と明言しているが、素の Claude Code の標準機能を普通に使うだけでは手に入らず、毎回自前で組むことになる」もの。

- **#1 外側セッションループ** が最大の目玉。harnesses 論文が示すリファレンスアーキテクチャ（init agent + coding agent、外部状態、1セッション1機能）そのものをlongrun の新モードとして機構化する。longrun の弱点H（resumeFromRunId の same-session 制約）もこれが実質的な解になる。
- **#2 eval 駆動開発** は「スキルを書く前に評価を作れ」という公式の開発プロセス自体の機構化。このリポジトリは skill を量産するリポジトリなので適用面が広い。
- **#3 自己改善ループ** は e2s の隣接拡張として実装コストが低い。
- **#4 検証ゲート hook pack** は「hook は保証」という公式の役割定義を配布可能な形にする。

#6〜#8、#11〜#12（既存資産のコンテンツ品質監査）は `plan-b-existing-audit.md`（旧 plan.md）として別トラックに分離。
