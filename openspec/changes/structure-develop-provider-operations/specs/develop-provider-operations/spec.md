## Purpose
develop の共通手順を本体によらず一つに保ち、操作の契約と Claude/Codex ごとの実行方法を分離する。対象の取りこぼし、専用構文の再混入、片側の操作欠落を検出し、既存の品質工程と実機確認の証拠を維持する。
## ADDED Requirements
### Requirement: 共通手順は操作を名前で参照する
共有手順は操作の意味を一つの台帳で定め、実行方法を Claude 用と Codex 用の二つのファイルへ分離しなければならない（MUST）。各使用箇所は操作名と局所の引数・条件を参照し、工程順・独立レビュー・承認・消費上限は既存正本を維持する（SHALL）。host と役の executor を混同してはならない（MUST NOT）。
#### Scenario: 同じ工程を異なる本体で読む
- **WHEN** Claude と Codex がそれぞれ develop の同じ工程を実行する
- **THEN** 共通の手順を読み、同じ操作名をそれぞれの対応で解決し、利用できない操作は理由付きで止める。#1857 の transport をこの変更で代替実装せず、実行されなかった hook を実行済みと報告しない
### Requirement: 対象一覧と禁止表現を検査する
対象一覧は develop 配下・役指示・gate stages・escalation template・develop command・hook の理由文と注入文・生成依頼文とその取り込み正本を含む固定一覧でなければならない（MUST）。一覧外の手順ファイル追加、本文への Claude 専用表現の追加を検査で拒否しなければならない（MUST）。対応二ファイル以外の本文は禁止表現を持ってはならない（MUST NOT）。
#### Scenario: 本文への Agent 呼出し追加と対象外ファイル追加
- **WHEN** 正常な fixture に `Agent(subagent_type: dev-workflow:worker)` の一行を加える、または対象一覧外の手順ファイルを加えて検査する
- **THEN** どちらも非0となる。語集合は少なくとも Agent ツール・subagent_type・SendMessage・AskUserQuestion・isolation:・TaskStop・run_in_background・~/.claude/projects・/wt-setup と design の追加語を含む
#### Scenario: 動的な出力にも検査が届く
- **WHEN** hook の注入・拒否・警告の各出力分岐と全 phase の生成依頼を fixture で出す
- **THEN** 表示される本文と取り込まれる正本を同じ禁止表現検査に通し、イベント名等の機械構文を本文から区別し、script 全体の除外で回避しない
### Requirement: 操作の参照と両方の対応は一致する
検査は本文が使用する操作 ID の存在・一意性・参照先を確かめ、台帳の登録操作集合と両本体ファイルの集合を一致させなければならない（MUST）。
#### Scenario: 片側の操作削除
- **WHEN** 正常な fixture で Claude または Codex の対応から操作 ID を一つ削除する
- **THEN** 本文で使用中かにかかわらず非0となり、未知の参照・重複 ID・壊れたリンクも失敗する
### Requirement: 段階移行は対象を減らさず完了を証明する
移行中は未移行本文を固定 revision の hash で凍結し、担当が移行するときだけ本文検査へ切り替えなければならない（MUST）。最終完了は全対象の未移行ゼロ、既存 bats と test_codex_develop.py の exit 0、Claude 本体の実機 1 件の Draft PR 作成とゲート通過記録、changes/1856.md の変更記録を必要とする（SHALL）。
#### Scenario: 回帰と実機の証拠が揃う
- **WHEN** 全 group の実装が終わったとして #1856 の条件を照合する
- **THEN** 正常検査の exit 0 と負例の非0、全回帰のコマンド・exit、実機の HEAD・工程・Draft PR・ゲート記録 URL、変更した文面 assertion の内容を変更記録で確認でき、輸送完了だけで合格にしない
#### Scenario: 未移行を隠して完了しようとする
- **WHEN** 未移行本文の編集・台帳からの対象削除・移行済みからの後退、または未移行を残して最終検査する
- **THEN** 非0となり、凍結対象を検査対象外として新しい禁止表現を追加できない
