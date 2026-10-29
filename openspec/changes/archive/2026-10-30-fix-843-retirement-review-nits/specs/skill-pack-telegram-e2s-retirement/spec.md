## MODIFIED Requirements

### Requirement: 3 プラグインへの参照を掃除する
`plugins/skill-pack`・`plugins/telegram`・`plugins/experience-to-skill`・`skill-pack@oratta-claude-harness`・`telegram@oratta-claude-harness`・`experience-to-skill@oratta-claude-harness`・`experience-to-skill-jsonl-distillation` の 7 文字列は、次の許容場所を除く git 追跡ファイルに現れてはならない（MUST NOT）。許容場所は (a) 過去の記録である `openspec/changes/archive/` と `_longruns/`、(b) 作業中の change ディレクトリ `openspec/changes/retire-skill-pack-telegram-e2s/`、(c) 解散の記録と切り替え手順を書くルート `README.md`、(d) この解散を検査する bats 自身、(e) archive で生成されるこの解散の capability の正本 `openspec/specs/skill-pack-telegram-e2s-retirement/`、とする。許容場所はパスの列挙で書き、文字列の一致で許容してはならない（MUST NOT）。

守備範囲: この検査の入力は git 追跡ファイルで、拾いたい誤りは 3 プラグインのパス（`plugins/<name>`）とインストール ID（`<name>@oratta-claude-harness`）、廃止した capability 名の消し忘れだけである。次の入力は検査を通ってよく、通ることを欠陥として扱わない: (1) `plugins/` を付けない素のプラグイン名（`plugins/dev-workflow/CHANGELOG.md`・`plugins/*/changes/` の版履歴）、(2) `/e2s:distill` などコマンド名だけの版履歴（`plugins/daily-report/README.md`）、(3) 代替として書く `telegram@claude-plugins-official`、(4) 7 文字列以外の言い換え。これらの穴を塞ぎ切ることをこの要件の完了条件にしない。

#### Scenario: 許容場所の外に参照が無い
- **WHEN** 7 文字列を `git grep` で探し、許容場所 (a)〜(e) の一致を除く
- **THEN** 一致は 0 件である
