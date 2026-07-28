# capability-registry-skill

## ADDED Requirements

### Requirement: 外部サービス操作前にスキルが発火する（CLAUDE.md 無編集）
プラグインは `skills/capability-registry/SKILL.md` を提供し、その frontmatter の description は「外部サービスを操作する前に」を明示するトリガー文でなければならない（SHALL）。スキルの name+description は全セッションに自動注入されるため、ルート CLAUDE.md への追記なしで発火すること。トリガーの分岐点は「ブラウザを開く前」ではなく「外部サービスに触ろうとした瞬間」とする。

#### Scenario: インストールだけで発火する
- **WHEN** `/plugin install capability-registry@oratta-claude-harness` 後、CLAUDE.md を編集せずにエージェントが外部サービス（例: GitHub、Supabase）を操作しようとする
- **THEN** description のトリガー文により capability-registry スキルが参照され、索引から CLI とトークンの在処が得られる

#### Scenario: description がトリガー文になっている
- **WHEN** SKILL.md の frontmatter を検査する
- **THEN** description に「外部サービスを操作する前に」相当のトリガー文言が含まれている

### Requirement: 索引は 1 サービス 1 行で 1 画面以内を維持する
SKILL.md の索引は 1 サービス 1 行で、各行に CLI 名 / 認証確認コマンド / トークン取得方法（`fmtoken.sh <service>`）/ ブラウザ必須の例外操作を記載しなければならない（SHALL）。認証状態は記述を信じず verify コマンドを実行して確かめる旨を明記する。詳細はサービス別ファイル（`<service>.md`）への遅延ロードとし、索引は 1 画面以内（約 50 行以内）を維持する。

#### Scenario: 初期エントリは実績のあるサービスのみ
- **WHEN** SKILL.md の索引を確認する
- **THEN** 1Password(op) / GitHub(gh) / Supabase / Vercel / Stripe など実際に使った実績のあるサービスのエントリが存在し、各行に認証確認コマンドとトークン取得方法が記載されている

#### Scenario: 詳細はサービス別ファイルに遅延ロード
- **WHEN** 索引のあるサービスの詳細（セットアップ手順、例外操作の具体例など）が必要になる
- **THEN** `skills/capability-registry/<service>.md` が存在し、索引からファイル名で参照できる

### Requirement: 「CLI が無い」ネガティブエントリを記載する
索引には CLI が存在しない・使えないサービスのネガティブエントリも記載しなければならない（SHALL）。無い CLI を探し回るコストが最も高いため、「無い」という情報自体をレジストリの一級エントリとする。

#### Scenario: ネガティブエントリの参照
- **WHEN** エージェントが CLI の無いサービスを操作しようとして索引を参照する
- **THEN** 「CLI なし」のエントリと代替手段（ブラウザ操作が正当である旨、または API 直叩き等）が明記されている
