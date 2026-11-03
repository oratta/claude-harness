# infra-ci-selfhosted-cleanup Specification

## Purpose
TBD - created by archiving change infra-selfhosted-job-cleanup. Update Purpose after archive.
## Requirements
### Requirement: CI 雛形のジョブはセルフホストのとき、終了時に作業ディレクトリ配下のプロセスを止めなければならない

`plugins/infra/templates/workflows/ci.yml.template` の `test` ジョブと `plugins/infra/templates/workflows/weekly-full.yml.template` の `full` ジョブは、そのジョブの最後の手順として、ジョブの作業ディレクトリ（`$GITHUB_WORKSPACE`）の下に cwd を持つプロセスを止める手順を持たなければならない。その手順の `if` は `always()` と `runner.environment == 'self-hosted'` を含み、ジョブが成功・失敗・キャンセル・上限超過のどれで終わっても、セルフホストのときだけ走らなければならない。手順は、自分自身とその祖先のプロセスを止めず、プロセス名での絞り込み（`pkill` / `killall`）を使わず、失敗を隠す指定（`continue-on-error` と `|| true`）を付けてはならない。This requirement MUST be satisfied.

止める手順は TERM を送り、5 秒待ち、まだ生きている対象へ KILL を送らなければならない。対象の PID の消滅を `ps -p` で確認できた場合だけ正常とし、KILL のあとも生きている対象があるとき、および `kill` が権限拒否などで失敗して消滅を確認できないときは、その PID を出力して非 0 で終わらなければならない（`kill -0` の失敗を消滅とみなさない）。止める対象が無いときは 0 で終わらなければならない。

**守備範囲**: 対象を選ぶ入力は `lsof -a -d cwd -F pn` が返す、全プロセスの PID と cwd のパスだけである。拾うのは、cwd のパスが `$GITHUB_WORKSPACE` と等しいか、`$GITHUB_WORKSPACE/` で始まるプロセスで、そこから自分自身とその祖先を除いたものとする。次は対象にしない: (a) cwd が作業ディレクトリの外にあるプロセス、(b) 名前が前方一致するだけの隣のディレクトリ（`<作業ディレクトリ>-other` など）が cwd のプロセス、(c) 起動後に cwd を作業ディレクトリの外へ移したプロセス。(c) のような止め漏れを塞ぎ続けることは、この要件の完了条件にしない（足りない実例が出たら別の change で扱う）。This requirement MUST be satisfied.

#### Scenario: 手順が最後に置かれ、条件が付いている

- **WHEN** 両雛形の対象ジョブの `steps` を YAML として読む
- **THEN** 最後の手順の `if` は `always()` と `runner.environment == 'self-hosted'` を含まなければならない
- **AND** その手順の `run` は `GITHUB_WORKSPACE` を含み、`pkill` と `killall` を含まず、手順に `continue-on-error` を持たず、`|| true` を含まない

#### Scenario: 作業ディレクトリ配下のプロセスだけが止まる

- **WHEN** 作業ディレクトリの下に cwd を持つ偽のプロセスと、作業ディレクトリの外（名前が前方一致する隣のディレクトリを含む）に cwd を持つ偽のプロセスがある状態で、手順の `run` を作業ディレクトリを `GITHUB_WORKSPACE` にして実行する
- **THEN** 作業ディレクトリの下のプロセスは止まり、外のプロセスと前方一致する隣のディレクトリのプロセスは生きていなければならない
- **AND** 手順を実行したシェルは自分では止まらず、止めるプロセスが無いときは 0 で終わらなければならない
- **AND** 起動後に cwd を作業ディレクトリの外へ移した偽のプロセスは止まらなくてよい（守備範囲外）

#### Scenario: TERM を無視するプロセスも止まる

- **WHEN** 作業ディレクトリの下に cwd を持ち、TERM を無視する偽のプロセスがある状態で手順の `run` を実行する
- **THEN** そのプロセスは KILL で止まり、手順は 0 で終わらなければならない

#### Scenario: 止められない対象は赤になる

- **WHEN** TERM と KILL のあとも生きている対象がある（`kill` を差し替えて失敗させる）状態で手順の `run` を実行する
- **THEN** 手順は生き残った PID を出力して非 0 で終わらなければならない

#### Scenario: 権限拒否で `kill` が失敗する対象は赤になる

- **WHEN** 対象は存在しているが `kill`（`kill -0` を含む）が権限拒否で失敗する（`kill` を差し替え、`ps -p` は成功する）状態で手順の `run` を実行する
- **THEN** 手順は消滅とみなさず、その PID を出力して非 0 で終わらなければならない

#### Scenario: 待つ間に消えた対象は正常

- **WHEN** 対象が TERM で止まり、KILL を送る時点で `ps -p` が失敗する（既に存在しない）
- **THEN** 手順は 0 で終わらなければならない

#### Scenario: 両雛形の手順が同じ文面である

- **WHEN** 両雛形の最後の手順の `run` を比べる
- **THEN** 2 つの文面は一致しなければならない

### Requirement: infra-setup の SKILL.md はセルフホスト時の掃除の意味と既存リポジトリへの反映のしかたを書かなければならない

`plugins/infra/skills/infra-setup/SKILL.md` は、セルフホストのランナーに切り替えるときの注意として、ジョブ終了時の掃除が作業ディレクトリ配下のプロセスだけを止めること（同じ Mac のほかのジョブは止めない。作業ディレクトリの外へ cwd を移したプロセスは止まらない）を書き、既に雛形から CI を入れたリポジトリへの反映のしかたとして、`ci.yml` の `test` ジョブと `weekly-full.yml` の `full` ジョブの両方の最後の手順に、雛形と同じ手順を手で書き足すことを勧める内容でなければならない。This requirement MUST be satisfied.

#### Scenario: SKILL.md に掃除の意味と反映のしかたがある

- **WHEN** `SKILL.md` の「ジョブ終了時の掃除」を含む節を読む
- **THEN** その節に、`self-hosted`、`作業ディレクトリ`、`ci.yml` と `weekly-full.yml` の両方へ手で書き足すことを勧める文、作業ディレクトリの外へ移ったプロセスは止まらない旨の文がなければならない

