## Context

`worker.md` は LLM エージェント（W）向けのプロンプトであり、決定論的なスクリプトではない。「テスト・lint・ビルドを実行し」という指示は (3a)「コード直行する場合」手順 5 にしかなく、opsx 経路（`/opsx:apply` → `/opsx:verify`）と openspec CLI 経路（`tasks.md` 直叩き → `openspec validate --strict`）には検査コマンドを流す指示自体が無い。このリポジトリでは `.github/workflows/ci.yml` に `lint`（`scripts/lint.sh`）と `test`（`scripts/test.sh` と `scripts/test-auto-merge-workflow.sh` の 2 ステップ）の 2 ジョブがあり、W は `scripts/test.sh` だけ流して shellcheck 相当の検査を素通りしていた（PR #489）。develop は他リポジトリでも使うため、`scripts/test.sh` のようなコマンド名をこのリポジトリに固定できない。

## Goals / Non-Goals

**Goals:**
- W が (3a) の実装後、そのリポジトリの CI が実際に流す検査コマンドを、リポジトリ固有の知識なしに `.github/workflows/*.yml` から拾えるようにする
- 拾った検査コマンドをすべて実行し、return に一覧と exit code を載せる指示を worker.md に追加する

**Non-Goals:**
- `gate-runner.md`（G）側に、W の return の検査コマンド一覧を CI 定義と突き合わせる機械照合を追加すること。issue #508 の受け入れ条件はいずれも W 側（return に何を載せるか）で閉じており、G 側の照合を追加すると「W の自己申告した一覧が正しいか」を検証する別の設計判断（どこまで機械的に照合するか、誤検知をどう扱うか）が新たに生まれる。範囲をこの change の外に置く（必要になれば別 issue で扱う）
- workflow YAML の完全な構文解析（`yq` 等の導入）。W は LLM であり、ファイルを読んで判断できるため、専用パーサは要らない

## Decisions

### 指示を置く場所: 3 経路共通の「全経路共通の大原則」に置く（(3a) 手順 5 だけに書かない）

opsx 経路・openspec CLI 経路・コード直行の 3 経路は、実装後に何をするかの記述がそれぞれ別々にある（`/opsx:apply`＋`/opsx:verify`、`tasks.md` 直叩き＋`openspec validate --strict`、TDD の 5 手順）。検査コマンドの実行はこの 3 経路すべてで必要な作業であり、「コード直行する場合」の手順 5 にだけ書くと opsx / openspec CLI 経路が対象から漏れる。worker.md には既に 3 経路共通の指示を集める「全経路共通の大原則」という節があるため、そこに 1 箇所だけ書き、経路ごとに重複させない。

### 検査コマンドの拾い方: LLM の判断に委ねる自然文指示にする（機械的な grep パーサは書かない）

worker.md は W（LLM エージェント）向けの指示書であり、W はシェルスクリプトではなく `.github/workflows/*.yml` / `*.yaml` を読んで内容を理解できる。したがって「`run:` の中身を列挙し、環境セットアップ（`actions/checkout` の後処理、パッケージインストール、依存解決など）を除いた検査コマンド（lint・test・ビルド・静的検査）をすべて実行する」という自然文の指示にする（「機械的に収集する」とは書かない。パーサではなく W の読解に委ねる決定と矛盾するため）。

検討した代替案:
- **`run:` 行を機械的に正規表現で抽出するヘルパースクリプトを書く**: 却下。このリポジトリの `test` ジョブは `sudo apt-get install` のような環境セットアップの `run:` ステップと、`scripts/test.sh` / `scripts/test-auto-merge-workflow.sh` という 2 つの検査 `run:` ステップが同じジョブに混在する。ジョブ内の「最後の `run:` ステップだけ拾う」ヒューリスティックはこのリポジトリで `scripts/test-auto-merge-workflow.sh` しか拾えず 1 件を取りこぼす。「パッケージマネージャの動詞（`apt-get` / `brew` / `pip install` 等）を含む行を除外する」ヒューリスティックは正規表現の脆さ（他リポジトリの命名慣習に追随できない）を抱える。W は毎回 workflow ファイルを直接読むので、機械パーサより LLM の読解に委ねる方が汎用的かつ実装コストが低い
- **`scripts/test.sh` / `scripts/lint.sh` のような慣例コマンド名をそのまま develop に埋め込む**: 却下。issue #508 が問題にしている「コマンド名をリポジトリ固有に固定している」状態そのもので、他リポジトリで動かない

worker.md の指示文には、除外例として `sudo apt-get install` のような特権を伴うパッケージインストールを明示する（Risks 参照）。

### 対象 workflow の範囲: PR・push で起動する検査ジョブに限る

`.github/workflows/` には検査以外の運用系ワークフロー（例: `auto-merge.yml`、`revert-pr.yml`）が混在し、これらは `pull_request` / `push` 以外のイベント（`workflow_dispatch` / `schedule` / `pull_request_target` 等）で起動する。W の作業は PR の変更が CI を通すかどうかの確認であり、運用系ワークフローを検査コマンドとして拾うと目的外の実行になる。対象を「PR・push で起動するジョブの `run:` ステップ」に限定し、拡張子は `.yml` に加え `.yaml` も含める。

### ツール未導入の扱い: 「未導入」と「違反あり」を区別し、未導入を合格扱いしない

CI ランナーには `shellcheck` のように apt でプリインストール済みのツールがあり、手元の開発環境には無いことがある。検査コマンドが「ツールが無くて実行できない」ときにこれを黙って飛ばすと、CI で落ちる検査を W が合格扱いで return してしまう（issue #508 が問題にした再発そのもの）。W は return で「未導入のため未実行」と「実行して exit code N」を書き分け、未導入を合格として扱わない。

### フォールバック: workflow が無い／検査コマンドを判別できないときは慣例コマンドを許容する

`.github/workflows/*.yml` / `*.yaml` が存在しない、または `run:` から検査コマンドを判別できないリポジトリでは、W は `scripts/test.sh` 等の慣例コマンドへフォールバックしてよい（MAY。MUST にはしない）。CI 定義が存在しないリポジトリで W の手が止まらないようにするため。

## Risks / Trade-offs

- [LLM の判断が誤って環境セットアップの `run:` ステップ（例: `npm ci`、`sudo apt-get install`）を検査コマンドとして実行してしまう] → 大半は副作用がテスト実行の前提を整えるだけで害は小さいが、`sudo apt-get install` のような特権操作は worker.md の指示文で明示的に除外例として書く
- [LLM の判断が実際の検査ステップを見落とす、または matrix・services・env・if: 条件のような CI 固有の実行環境の違いで手元の結果が CI と食い違う] → 取りこぼしをこの change だけで塞ぎ切ることは狙わない。既存の昇格トリップワイヤー（失敗ループ検知）と G 側の CI 結果確認（メモリ「G は passed の前に CI を確認」）が最終防波堤として残る。この change は W 側の一次防波堤を厚くするものであり、唯一の防波堤にはしない
