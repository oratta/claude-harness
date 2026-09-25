## Context

`worker.md` は LLM エージェント（W）向けのプロンプトであり、決定論的なスクリプトではない。(3a) 手順 5 は「テスト・lint・ビルドを実行し」とだけ書かれ、何を流すかを W の裁量に委ねている。このリポジトリでは `.github/workflows/ci.yml` に `lint`（`scripts/lint.sh`）と `test`（`scripts/test.sh` と `scripts/test-auto-merge-workflow.sh` の 2 ステップ）の 2 ジョブがあり、W は `scripts/test.sh` だけ流して shellcheck 相当の検査を素通りしていた（PR #489）。develop は他リポジトリでも使うため、`scripts/test.sh` のようなコマンド名をこのリポジトリに固定できない。

## Goals / Non-Goals

**Goals:**
- W が (3a) の実装後、そのリポジトリの CI が実際に流す検査コマンドを、リポジトリ固有の知識なしに `.github/workflows/*.yml` から拾えるようにする
- 拾った検査コマンドをすべて実行し、return に一覧と exit code を載せる指示を worker.md に追加する

**Non-Goals:**
- `gate-runner.md`（G）側に、W の return の検査コマンド一覧を CI 定義と突き合わせる機械照合を追加すること。issue #508 の受け入れ条件はいずれも W 側（return に何を載せるか）で閉じており、G 側の照合を追加すると「W の自己申告した一覧が正しいか」を検証する別の設計判断（どこまで機械的に照合するか、誤検知をどう扱うか）が新たに生まれる。範囲をこの change の外に置く（必要になれば別 issue で扱う）
- workflow YAML の完全な構文解析（`yq` 等の導入）。W は LLM であり、ファイルを読んで判断できるため、専用パーサは要らない

## Decisions

### 検査コマンドの拾い方: LLM の判断に委ねる自然文指示にする（機械的な grep パーサは書かない）

worker.md は W（LLM エージェント）向けの指示書であり、W はシェルスクリプトではなく `.github/workflows/*.yml` を読んで内容を理解できる。したがって「`run:` の中身を列挙し、環境セットアップ（`actions/checkout` の後処理、パッケージインストール、依存解決など）を除いた検査コマンド（lint・test・ビルド・静的検査）をすべて実行する」という自然文の指示にする。

検討した代替案:
- **`run:` 行を機械的に正規表現で抽出するヘルパースクリプトを書く**: 却下。このリポジトリの `test` ジョブは `sudo apt-get install` のような環境セットアップの `run:` ステップと、`scripts/test.sh` / `scripts/test-auto-merge-workflow.sh` という 2 つの検査 `run:` ステップが同じジョブに混在する。ジョブ内の「最後の `run:` ステップだけ拾う」ヒューリスティックはこのリポジトリで `scripts/test-auto-merge-workflow.sh` しか拾えず 1 件を取りこぼす。「パッケージマネージャの動詞（`apt-get` / `brew` / `pip install` 等）を含む行を除外する」ヒューリスティックは正規表現の脆さ（他リポジトリの命名慣習に追随できない）を抱える。W は毎回 workflow ファイルを直接読むので、機械パーサより LLM の読解に委ねる方が汎用的かつ実装コストが低い
- **`scripts/test.sh` / `scripts/lint.sh` のような慣例コマンド名をそのまま develop に埋め込む**: 却下。issue #508 が問題にしている「コマンド名をリポジトリ固有に固定している」状態そのもので、他リポジトリで動かない

### フォールバック: workflow が無い／検査コマンドを判別できないときは慣例コマンドを許容する

`.github/workflows/*.yml` が存在しない、または `run:` から検査コマンドを判別できないリポジトリでは、W は `scripts/test.sh` 等の慣例コマンドへフォールバックしてよい（MAY。MUST にはしない）。CI 定義が存在しないリポジトリで W の手が止まらないようにするため。

## Risks / Trade-offs

- [LLM の判断が誤って環境セットアップの `run:` ステップ（例: `npm ci`）を検査コマンドとして実行してしまう] → 実行しても大半は副作用がテスト実行の前提を整えるだけで害は小さい。害が大きいケース（`sudo apt-get install` のような特権操作）は worker.md の指示文で明示的に除外例として書く
- [LLM の判断が実際の検査ステップを見落とす] → 既存の昇格トリップワイヤー（失敗ループ検知）と G 側の CI 結果確認（メモリ「G は passed の前に CI を確認」）が最終防波堤として残る。この change は W 側の一次防波堤を厚くするものであり、唯一の防波堤にはしない
