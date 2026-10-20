# capability-registry-skill Specification

## Purpose
外部サービス操作前に発火する発見層スキル。CLI の有無・認証確認・トークンの在処を索引で返し、CLAUDE.md 無編集でインストールだけで機能する。
## Requirements
### Requirement: 外部サービス操作前にスキルが発火する（CLAUDE.md 無編集）
プラグインは `skills/capability-registry/SKILL.md` を提供し、その frontmatter の description は「外部サービスを操作する前に」を明示するトリガー文でなければならない（SHALL）。スキルの name+description は全セッションに自動注入されるため、ルート CLAUDE.md への追記なしで発火すること。トリガーの分岐点は「ブラウザを開く前」ではなく「外部サービスに触ろうとした瞬間」とする。

#### Scenario: インストールだけで発火する
- **WHEN** `/plugin install capability-registry@oratta-claude-harness` 後、CLAUDE.md を編集せずにエージェントが外部サービス（例: GitHub、Supabase）を操作しようとする
- **THEN** description のトリガー文により capability-registry スキルが参照され、索引から CLI とトークンの在処が得られる

#### Scenario: description がトリガー文になっている
- **WHEN** SKILL.md の frontmatter を検査する
- **THEN** description に「外部サービスを操作する前に」相当のトリガー文言が含まれている

### Requirement: 索引は 1 サービス 1 行で 1 画面以内を維持する
SKILL.md の索引は公開版に残すサービス(GitHub・Supabase・Vercel・Stripe)について 1 サービス 1 行で、各行に CLI 名 / 認証確認コマンド / トークン（CLI が読む環境変数名またはログイン状態）/ ブラウザ必須の例外操作を記載しなければならない（SHALL）。トークンの値の在処はオーナーの環境の索引があればそちらを見る旨を、索引の各行ではなく原則の節に 1 か所で書き、特定のトークン取得ツールの呼び出しを索引の行に書かない。個人版に移る部品(1Password の行と `1password.md` への案内)は公開版の索引に載せない。認証状態は記述を信じず verify コマンドを実行して確かめる旨を明記する。詳細はサービス別ファイル（`<service>.md`）への遅延ロードとし、索引は 1 画面以内（約 50 行以内）を維持する。

#### Scenario: 初期エントリは実績のあるサービスのみ
- **WHEN** SKILL.md の索引を確認する
- **THEN** GitHub(gh) / Supabase / Vercel / Stripe の実績のあるサービスのエントリが存在し、1Password の行は無く、各行に認証確認コマンドとトークン（環境変数名またはログイン状態）が記載されている

#### Scenario: 詳細はサービス別ファイルに遅延ロード
- **WHEN** 索引のあるサービスの詳細（セットアップ手順、例外操作の具体例など）が必要になる
- **THEN** `skills/capability-registry/<service>.md` が存在し、索引からファイル名で参照できる。索引が参照するサービス別ファイルは現時点では公開版に残る 4 つ(`github.md`・`supabase.md`・`vercel.md`・`stripe.md`)で、個人版に移る `1password.md` は参照しない(公開版のサービスを将来足すことは妨げない)

#### Scenario: 公開版の索引とサービス別ファイルは個人版の道具を呼ばない
- **WHEN** SKILL.md の description・原則の節・索引の節と `github.md`・`stripe.md`・`supabase.md`・`vercel.md` を検査する
- **THEN** `fmtoken` の文字列は含まれず、原則の節にトークンの在処はオーナーの環境の索引を見る旨が書かれている

### Requirement: 「CLI が無い」ネガティブエントリを記載する
索引には CLI が存在しない・使えないサービスのネガティブエントリも記載しなければならない（SHALL）。無い CLI を探し回るコストが最も高いため、「無い」という情報自体をレジストリの一級エントリとする。

#### Scenario: ネガティブエントリの参照
- **WHEN** エージェントが CLI の無いサービスを操作しようとして索引を参照する
- **THEN** 「CLI なし」のエントリと代替手段（ブラウザ操作が正当である旨、または API 直叩き等）が明記されている

