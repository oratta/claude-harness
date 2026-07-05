# Anthropic 公式エージェント構築ナレッジ 統合設計資料

調査日: 2026-07-04（research-agents エージェントによる調査結果）。全 URL は WebFetch で本文取得・実在確認済み（`docs.claude.com` 系は `platform.claude.com` へ 302 リダイレクトするため最終 URL を記載）。

## 収録ソース一覧（時系列）

| # | タイトル | URL | 公開 | 層 |
|---|---|---|---|---|
| 1 | Building Effective AI Agents | https://www.anthropic.com/engineering/building-effective-agents | 2024-12-19 | アーキ基礎 |
| 2 | How we built our multi-agent research system | https://www.anthropic.com/engineering/multi-agent-research-system | 2025-06-13 | 実装事例 |
| 3 | Writing effective tools for agents — with agents | https://www.anthropic.com/engineering/writing-tools-for-agents | 2025-09-11 | ツール設計 |
| 4 | Building agents with the Claude Agent SDK | https://claude.com/blog/building-agents-with-the-claude-agent-sdk | 2025-09-29 | SDK/骨格 |
| 5 | Effective context engineering for AI agents | https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents | 2025-09-29 | 一般理論 |
| 6 | Equipping agents for the real world with Agent Skills | https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills | 2025-10-16 | Skills |
| 7 | Code execution with MCP | https://www.anthropic.com/engineering/code-execution-with-mcp | 2025-11-04 | ツール効率 |
| 8 | Introducing advanced tool use | https://www.anthropic.com/engineering/advanced-tool-use | 2025-11-24 | ツール効率 |
| 9 | Best practices for Claude Code | https://code.claude.com/docs/en/best-practices | 2025-04（継続更新） | 実務運用 |
| 10 | Skill authoring best practices | https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices | 継続更新 | Skills仕様 |
| 11 | Prompting best practices（docs） | https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices | 継続更新 | プロンプト |

---

## ソース1: Building Effective AI Agents（2024-12-19）
アーキテクチャ層の基礎。「いつ何を使うか」の判断枠組み。

**主要原則**
- **Workflow と Agent を区別せよ**。Workflow=LLM とツールが「定義済みコードパス」で統制される（制御はコード側）。Agent=LLM が「自分のプロセスとツール利用を動的に指揮」する（制御は LLM 側）。
- **5つの Workflow パターンと使いどころ**: ①Prompt Chaining（固定サブタスクへクリーンに分解でき、途中に gate を挟める場合）②Routing（別扱いすべき明確なカテゴリがあり分類が正確な場合）③Parallelization（Sectioning=独立分割で速度、Voting=多試行で確信度）④Orchestrator-Workers（サブタスクを事前予測できず入力次第で動的分解する場合）⑤Evaluator-Optimizer（明確な評価基準があり反復洗練が測定可能な価値を生む場合）。
- **Agent を使うべきは**「ステップ数を予測できずパスをハードコードできないオープンエンド問題」のみ。自律性はコスト増と誤りの複利的蓄積（compounding errors）を伴う。
- **シンプルさ第一**: シンプルなプロンプトから始め、包括的評価で最適化し、単純解が不十分なときだけ多段エージェントを足す。
- **3つのコア原則**: Simplicity / Transparency（計画ステップを明示）/ ACI を丁寧に作る。
- **ACI（Agent-Computer Interface）設計**: 「モデルの立場に立つ」、書く前に考えるトークンを与える、自然なフォーマットに寄せる、ジュニア開発者向け docstring のように使用例・エッジケース・境界を書く、**Poka-yoke**（引数を間違えにくく＝相対パスを絶対パスにする等）。ツール定義には本体プロンプトと同等の労力をかける。

**ハーネス開発者への含意**: スキルは「決定的にできる部分ほど Workflow 側に寄せる」ほど安定。サブエージェント委譲は Orchestrator-Workers そのもので、予測できないタスクにのみ使う。並列サブエージェントは Sectioning/Voting のどちらの目的かを明示して起動。verifier 系は Evaluator-Optimizer の適用可否基準で導入判断。「必ず絶対パス」ルールは Poka-yoke の実装例。

## ソース2: How we built our multi-agent research system（2025-06-13）

**主要原則**
- **定量**: マルチエージェント（Opus 4 リード＋Sonnet 4 サブ）が単一 Opus 4 を内部評価で 90.2% 上回る。**エージェントはチャットの約4倍、マルチエージェント構成は約15倍のトークンを消費**。BrowseComp では**トークン使用量が性能分散の80%を説明**。並列ツール呼び出しでリサーチ時間を最大90%短縮。
- **委譲フレームワークを明示せよ**: 各サブエージェントに **objective / output format / tool guidance / task boundaries** を具体的に与える。曖昧だと同じ領域を重複探索する。
- **努力量をスケールさせるルールを埋め込む**: 単純クエリ=1エージェント+3〜10呼び出し、複雑=10+サブエージェント。初期版は単純クエリに50サブエージェント生成の暴走をした → スキル内にスケーリングルールを明記して防ぐ。
- **自己改善**: Claude 自身に失敗を診断させツール説明を書き換えさせ、完了時間40%短縮を達成。
- **広く始めて狭める**: 短い初期クエリから徐々に焦点を絞る。
- **extended thinking をスクラッチパッドに**: 計画に thinking、ツール結果評価に interleaved thinking。
- **並列実行**: 3〜5サブエージェント同時＋各々3+の並列ツール呼び出し。
- **評価は約20クエリの小規模から**。LLM-as-judge（ルーブリック=factual accuracy/citation/completeness/source quality/tool efficiency）＋人間評価。
- **プロダクション**: resumable checkpoint による durable execution、rainbow deployment、「the last mile often becomes most of the journey」。

**ハーネス開発者への含意**: サブエージェント定義には objective/output format/使えるツール/タスク境界を必ず明記。サブエージェント分割は15倍コストを正当化できる高価値・並列探索タスクに限定し、過剰 fan-out を設計で防ぐ。スキル評価は20ケースの小規模セットから。

## ソース3: Writing effective tools for agents — with agents（2025-09-11）

**主要原則**
- **Consolidation（統合）**: 全 API エンドポイントを個別ツール化せず高インパクトなワークフロー単位に統合。
- **Namespacing**: 関連ツールを共通プレフィックスでグルーピング。境界明示が選択精度に直結。
- **Meaningful Context を返す**: 高シグナル情報のみ返す。不透明な UUID を避け意味的な名前に変換するだけで検索精度が大幅向上。`response_format` の enum で粒度を選ばせトークン節約。
- **Token Efficiency**: pagination/range selection/filtering/truncation を妥当なデフォルト付きで実装。
- **エラーメッセージ**: 不透明コードでなく「具体的で実行可能な改善」を伝える。
- **Systematic Evaluation**: 実ユースケースの評価タスクを作り、Agent をプログラム的に走らせて粗を発見。Agent 自身に評価トランスクリプトを分析させ改善提案させる。
- **説明のプロンプトエンジニアリング**: 「新入社員にどう説明するか」。`user` でなく `user_id`。

**ハーネス開発者への含意**: 機械的な1:1スキル化でなくワークフロー単位に統合。プレフィックスは Namespacing そのもの。サブエージェント返り値は「高シグナルのみ・structured output schema で制御・生ログを親に返さない」。検証スクリプトは失敗時に「次に何をすべきか」を返すと自己修復率が上がる。

## ソース4: Building agents with the Claude Agent SDK（2025-09-29）

**主要原則**
- **エージェントループ = gather context → take action → verify work → repeat**。
- **設計の根幹は「エージェントにコンピュータを与える」**（ファイルシステム＋ターミナル）。
- **コンテキスト収集の3手段**: Agentic Search / Subagents（並列・隔離）/ Compaction。
- **アクション手段**: Tools / Bash・スクリプト / Code Generation / MCP。
- **検証の3戦略**: ①Rules-based（出力規則＋lint の多層）②Visual Feedback（スクショ・レンダー）③LLM as Judge（別モデル評価、計算コスト高）。

**ハーネス開発者への含意**: 「gather→act→verify→repeat」がカスタムワークフロー設計の骨格。**verify を rules-based＋visual＋LLM-judge の三層で明示的に持たせる**。

## ソース5: Effective context engineering for AI agents（2025-09-29）

**主要原則**
- **中心原則**: 「望む結果の尤度を最大化する、最小の高シグナルなトークン集合」を探す。
- **コンテキストは有限リソース**: **context rot**（トークン量増で想起精度低下）。attention budget が逓減する限界収益をもたらす。
- **System Prompt は適切な "altitude"（Goldilocks zone）**: if-else ハードコードでも高レベルすぎでもなく中間。XML タグ/Markdown 見出しで構造化。「最小 ≠ 短い」。
- **ツール設計**: token-efficient/self-contained/エラー耐性/用途が極めて明確/機能重複なし。判定基準=**「人間のエンジニアがどのツールを使うか断定できないなら AI にそれ以上を期待できない」**。
- **Few-shot は正典的（canonical）な例を厳選**。
- **Just-In-Time コンテキスト取得**: 軽量識別子を保持し実行時に動的ロード＝progressive disclosure。**ハイブリッド例が Claude Code**（CLAUDE.md 事前投入＋grep/glob で JIT ナビゲート）。
- **長期タスクの3技法**: ①Compaction ②Structured note-taking（コンテキスト外にノート永続化）③Sub-agent（クリーンなコンテキストで **1,000〜2,000トークンの凝縮サマリ**を返す関心の分離）。
- **使い分け**: 往復多い対話→compaction / マイルストーン型反復開発→note-taking / 並列探索型→multi-agent。

**ハーネス開発者への含意**: スキル description とシステムプロンプトは「適切な altitude」で見直す。トリガー条件が重複するスキルは bloated tool set 問題を起こす。**サブエージェントは「親のコンテキストを汚さない関心の分離装置」と定義**。

## ソース6: Equipping agents for the real world with Agent Skills（2025-10-16）

**主要原則**
- **Agent Skills = 指示・スクリプト・リソースを整理したフォルダ**。
- **SKILL.md 構造**: YAML frontmatter 必須（**name / description**）＋本文＋バンドル参照ファイル＋実行スクリプト。
- **Progressive Disclosure（3層）**: Level1=メタデータ / Level2=SKILL.md 全文 / Level3+=補助ファイルへオンデマンド。**バンドルできるコンテキスト量は事実上無制限**（読まれるまでコスト0）。
- **特性**: Composability / Portability / Code execution（決定論的処理をスクリプトで）。
- **オーサリング**: 評価から始めギャップ特定 → 構造化 → Claude 視点で name/description を実使用ログで磨く → Claude と反復。
- **セキュリティ**: 信頼できるソースからのみ導入、コード依存と外部ネットワーク接続を監査。

**ハーネス開発者への含意**: progressive disclosure の3層が物理レイアウトの指針。「SKILL.md + phases/ + schemas/ + templates/」構成の理論的裏付け。重い参照資料・スキーマは遠慮なく同梱してよい。

## ソース7: Code execution with MCP（2025-11-04）

**主要原則**
- **課題**: 数百〜数千ツールの全定義事前ロードと中間結果の通過でエージェントが遅く高コストに。
- **ツールをファイルシステム上のコードとして提示**しモデルがオンデマンドで定義を読む。
- **劇的削減**: あるワークフローで **約150,000 → 約2,000トークン（98.7%削減）**。
- **コンテキスト効率的なツール結果**: 実行環境側でフィルタしてから返す。
- **プライバシー**: 中間結果はデフォルトで実行環境に留まり、明示的に log/return したものだけモデルが見る。
- **状態永続化と Skills**: 動くコードを `./skills/` に再利用関数として保存。

**ハーネス開発者への含意**: 「全定義を常時ロード」しない。中間データをコンテキストに載せずファイル/実行環境に留める。

## ソース8: Introducing advanced tool use（2025-11-24）

**主要原則**
- **Tool Search Tool**: 全定義を事前ロードせず動的発見。~500トークンで従来 ~72K に対し **85%削減**、精度も改善。`defer_loading: true` でオンデマンド化。**目安: ツール定義 >10K トークン or ツール10個以上で使う**。
- **Programmatic Tool Calling**: コードでオーケストレーション。平均37%削減、並列実行可。
- **Tool Use Examples**: JSON スキーマを超えた具体例で正しいパラメータ使用を提示。複雑パラメータで精度72%→90%。

**ハーネス開発者への含意**: 「ツールは遅延ロードが基本」の API レベル裏付け。ツール定義に schema だけでなく利用例を添えるとパラメータ誤りが激減。

## ソース9: Best practices for Claude Code（2025-04、継続更新）

**主要原則**
- **第一原理: コンテキストウィンドウは埋まるのが速く、埋まるほど性能劣化**。
- **自己検証手段を必ず与えよ**: テスト/ビルド exit code/linter/diff/スクショ比較。ゲート強度4段階（プロンプト指示 / `/goal` 条件 / Stop フックで決定論的ブロック / 検証サブエージェント）。「成功した」と主張させず**エビデンス提示**させる。
- **Explore → Plan → Code → Commit**。「diff を1文で説明できるなら plan 不要」。
- **CLAUDE.md の書き方**: 「広く常時適用」だけ書く。各行に「消したら Claude がミスするか？」を問う。肥大化すると**実際の指示が無視される**。
- **CLAUDE.md と skill の使い分け**: 「たまにしか関係しないドメイン知識・ワークフローは CLAUDE.md でなく **skill に置け**」。
- **拡張機能の責務**: hooks=毎回例外なく起きる決定論的アクション（CLAUDE.md は助言的、hook は保証）/ skills=ドメイン知識・再利用ワークフロー / subagents=独自コンテキスト・独自ツールで隔離タスク / plugins=配布単位。
- **セッション管理**: 無関係タスク間で `/clear` 頻繁に。同一問題で2回以上修正したら `/clear` して再開。調査はサブエージェントに委譲。
- **スケール**: 非対話モード `claude -p`、worktree 並列、Writer-Reviewer パターン、**敵対的レビュー**（フレッシュ subagent が diff と基準だけ見てギャップ報告。ただし「ギャップを探せ」と言われたレビュアーは健全でも何か報告するので **correctness/要件に関わるものだけ flag** させ過剰エンジニアリングを避ける）。

**ハーネス開発者への含意**: skill/subagent/hook/plugin の責務境界が公式定義済み。longrun の verifier 分離は「検証サブエージェント/evidence 提示」の実装形。敵対的レビュー agent のプロンプトには「correctness/要件に関わるギャップのみ報告せよ」を明示。

## ソース10: Skill authoring best practices（docs、継続更新）

**主要原則**
- **Concise is key**: コンテキストは公共財。前提「Claude は既に非常に賢い」＝既知のことは書くな。良い例≈50トークン、悪い例≈150トークン。
- **Degrees of freedom をタスクの脆さに合わせる**: 高自由度（テキスト命令、例:コードレビュー）/ 中自由度（パラメータ付き擬似コード）/ 低自由度（具体スクリプト、例:DBマイグレーション「このコマンドを正確に、フラグ追加禁止」）。
- **計画するモデル全てでテスト**: Haiku（十分な誘導があるか）/ Sonnet（明確で効率的か）/ Opus（説明過剰でないか）。
- **YAML 規則**: `name` 最大64文字・小文字数字ハイフン。`description` 最大1024文字・「何をするか＋いつ使うか」。
- **命名は gerund 形（動詞+ing）推奨**。`helper`/`utils`/`tools` 等の曖昧名を避ける。
- **description はトリガー精度を決める最重要フィールド**: **必ず三人称**（システムプロンプトに注入されるため）。具体的キーワード＋「何を＋いつ」両方。
- **Progressive disclosure 実践**: SKILL.md 本文は**500行未満**。**参照は SKILL.md から1階層のみ**（ネストは部分読みで不完全になる）。**100行超の参照ファイルには目次**。
- **ワークフロー**: 複雑タスクはチェックリスト化。**validator → fix → repeat** のフィードバックループ。
- **コンテンツ**: 時限情報を避ける / 用語統一 / 選択肢の与えすぎ回避（デフォルト1つ＋エスケープハッチ）。
- **評価駆動開発**: **広範なドキュメントを書く前に評価を作れ**。3シナリオ評価 → ベースライン測定 → 最小限の命令 → 反復。**Claude A/B 法**（設計役 A とフレッシュ実使用役 B を交互）。
- **実行コード付き skill**: **Solve, don't punt**（スクリプトはエラーを明示処理、Claude に丸投げしない）/ voodoo constants 排除 / 実行意図を明示（execute vs read）/ plan-validate-execute（破壊的・高リスク操作に）/ MCP は完全修飾名。

**ハーネス開発者への含意**: description を「三人称/何をする+いつ使う/キーワード具体化」で監査する明確基準。degrees of freedom は低自由度（逐次ステップ）と高自由度（探索）を意図的に使い分ける根拠。「評価を先に3つ」はハーネス肥大化の防波堤。1階層参照・500行上限・目次は構造健全性チェック。

## ソース11: Prompting best practices（docs、継続更新）

**主要原則**
- **General**: 明確・具体的に / 指示の"なぜ"を添えると汎化 / 例示3〜5個を `<example>` で包む / XML タグで構造化。
- **Long context**: 20k+ 入力では**長文データをプロンプト先頭に置く**（末尾クエリで最大30%改善）。回答前に**関連箇所を引用させて**ノイズを切る。
- **Tool use**: 最新モデルは字義通りの指示追従。**Opus 4.5/4.6 以降は system prompt への反応が強く、旧来の「CRITICAL: You MUST…」は overtrigger するので通常語調に落とす**。独立ツール呼び出しは並列化。
- **Thinking**: 最新モデルは adaptive thinking。**細かい手順指示より "think thoroughly" のような一般的指示の方が良い推論**。「終える前に基準に照らして検証せよ」で自己チェック。
- **Agentic/長期タスク**: 増分進捗に集中させ状態保存→新コンテキストで継続。**「トークン残量を理由に早期終了するな、限界前に progress を保存せよ」と明示**。`tests.json` で構造化テスト管理（テスト削除禁止を明記）、`init.sh` 等の QOL ツール、**状態追跡は git**。
- **Subagent orchestration**: 最新モデルは自発利用するが多用しすぎの傾向。過剰時は「並列・隔離・独立ワークストリームのときだけサブエージェント、単純/逐次/単一ファイル編集は直接やれ」と明示。
- **落とし穴対策**: overengineering 抑制 / テスト通過のハードコード回避 / 一時ファイルはタスク末に掃除。

**ハーネス開発者への含意**: **旧世代向けの「CRITICAL/You MUST」系の強語調は現行モデルで overtrigger を招くので弱める**——既存プラグイン/スキルの指示文リファクタの最優先項目。longrun/worktree 系の中核設計（progress ファイル・tests.json・git 状態追跡・init.sh・early-stop 抑制・Playwright 検証）が公式列挙されており設計チェックリストに転記可。

---

## 全ソース横断の設計原則（ハーネス開発の芯）

1. **最小の高シグナルトークン集合**が全ドキュメントを貫く目標関数。ツールもスキルも指示も「盛る」より「絞る」。context rot と attention budget が根拠。
2. **Progressive Disclosure が多ツール・多スキル環境の共通解**: Agent Skills の3層 / Tool Search Tool（defer_loading）/ code-execution のオンデマンドロード。バンドル資料は読まれるまでコスト0。
3. **gather → act → verify → repeat が自律ワークフローの骨格**。verify は rules-based（lint/test）＋visual（スクショ）＋LLM-judge の三層で明示的に持たせる。「成功した」でなく evidence を提示させる。
4. **役割分担の公式定義**: CLAUDE.md（広く常時）/ skill（たまに・ドメイン）/ hook（決定論的強制）/ subagent（隔離・1,000〜2,000トークンのサマリを返す関心分離）/ plugin（配布単位）。
5. **サブエージェント委譲は無料でない**（トークン15倍）。高価値・並列探索タスクに限定し、スケーリングルールを埋め込んで過剰 fan-out を防ぐ。委譲時は objective/output format/tool guidance/task boundaries を明示。
6. **description の name/description メタデータがトリガー精度を決定**。三人称・「何をする＋いつ使う」・具体キーワード。評価駆動（先に3シナリオ）で磨く。
7. **長期タスクは状態を外部化**（NOTES.md/tests.json/git/init.sh/compaction/memory ツール）してコンテキスト外に逃がす。往復多い=compaction、マイルストーン型=note-taking、並列探索型=multi-agent で使い分け。
8. **degrees of freedom をタスクの脆さに合わせる**: 脆く一貫性 critical なものは低自由度で厳密なガードレール、複数の有効アプローチがあるものは高自由度で方向性だけ。
9. **最新モデルでは強語調の over-prompting を弱める**（overtrigger 対策）。「CRITICAL/You MUST」の乱用は逆効果。

読みの順序: 5（context engineering）を土台に据え、並列探索が要る局面でのみ 2（multi-agent、15倍コスト織り込み）を適用、個々のツール/スキルは 3・10 で磨き、9・11 で最新モデル向けに調律。
