# Gate contract correspondence (#1687)

Fixed main: `0e7bf3f80d0241bd9582f7b89e5ec3f529f2139f`. Expectations: blocks.json (verbatim fences), prose.json (commands and complete paragraphs selected by stop/scope vocabulary). Only the listed Markdown section references are normalized; commands and fenced templates are exact.

The parent-fetch paragraph at triage:106 is preserved as three original fragments across triage-nonblocking and triage-epic. The repeated model paragraph gate-runner:123 becomes references to decision-criteria / pre-classification; develop-roles.bats checks that contract. Text presence permits relocation, unreachable text and inverse instructions alongside a retained rule; links, byte budgets and review cover different errors.

| Kind | Fixed source:line | Current files containing the fixed text |
|---|---|---|
| fence | skills/develop/references/roles/gate-runner.md:60 | skills/develop/references/roles/gate-runner.md |
| fence | skills/pr-review-gate/declarations.md:39 | skills/pr-review-gate/declarations.md |
| fence | skills/pr-review-gate/declarations.md:48 | skills/pr-review-gate/declarations.md |
| fence | skills/pr-review-gate/declarations.md:111 | skills/pr-review-gate/stages/issue-approved.md |
| fence | skills/pr-review-gate/declarations.md:129 | skills/pr-review-gate/declarations.md |
| fence | skills/pr-review-gate/declarations.md:137 | skills/pr-review-gate/declarations.md |
| fence | skills/pr-review-gate/declarations.md:147 | skills/pr-review-gate/declarations.md |
| fence | skills/pr-review-gate/stages/hold.md:27 | skills/pr-review-gate/stages/carryover.md |
| fence | skills/pr-review-gate/stages/hold.md:56 | skills/pr-review-gate/stages/carryover.md |
| fence | skills/pr-review-gate/stages/hold.md:83 | skills/pr-review-gate/stages/carryover-judge.md |
| fence | skills/pr-review-gate/stages/hold.md:107 | skills/pr-review-gate/stages/no-point-check.md |
| fence | skills/pr-review-gate/stages/hold.md:114 | skills/pr-review-gate/stages/no-point-check.md |
| fence | skills/pr-review-gate/stages/hold.md:171 | skills/pr-review-gate/stages/hold.md |
| fence | skills/pr-review-gate/stages/pass.md:21 | skills/pr-review-gate/stages/pass.md |
| fence | skills/pr-review-gate/stages/pass.md:54 | skills/pr-review-gate/stages/pass.md |
| fence | skills/pr-review-gate/stages/pass.md:91 | skills/pr-review-gate/stages/authenticity.md |
| fence | skills/pr-review-gate/stages/pass.md:100 | skills/pr-review-gate/stages/authenticity-conversation.md |
| fence | skills/pr-review-gate/stages/pass.md:106 | skills/pr-review-gate/stages/authenticity-conversation.md |
| fence | skills/pr-review-gate/stages/pass.md:123 | skills/pr-review-gate/stages/authenticity-relayed.md |
| fence | skills/pr-review-gate/stages/pass.md:132 | skills/pr-review-gate/stages/authenticity-relayed.md |
| fence | skills/pr-review-gate/stages/pass.md:148 | skills/pr-review-gate/stages/authenticity-delegated.md |
| fence | skills/pr-review-gate/stages/pass.md:159 | skills/pr-review-gate/stages/authenticity-delegated.md |
| fence | skills/pr-review-gate/stages/pass.md:172 | skills/pr-review-gate/stages/issue-approved.md |
| fence | skills/pr-review-gate/stages/pass.md:186 | skills/pr-review-gate/stages/pass.md |
| fence | skills/pr-review-gate/stages/pass.md:197 | skills/pr-review-gate/stages/pass.md |
| fence | skills/pr-review-gate/stages/pass.md:211 | skills/pr-review-gate/stages/pass-wording.md |
| fence | skills/pr-review-gate/stages/pass.md:241 | skills/pr-review-gate/stages/pass.md |
| fence | skills/pr-review-gate/stages/pass.md:295 | skills/pr-review-gate/stages/pass.md |
| fence | skills/pr-review-gate/stages/prepare.md:28 | skills/pr-review-gate/stages/prepare.md |
| fence | skills/pr-review-gate/stages/prepare.md:35 | skills/pr-review-gate/stages/prepare.md |
| fence | skills/pr-review-gate/stages/prepare.md:41 | skills/pr-review-gate/stages/prepare.md |
| fence | skills/pr-review-gate/stages/prepare.md:47 | skills/pr-review-gate/stages/prepare-light.md |
| fence | skills/pr-review-gate/stages/prepare.md:100 | skills/pr-review-gate/stages/prepare.md |
| fence | skills/pr-review-gate/stages/prepare.md:121 | skills/pr-review-gate/stages/prepare.md |
| fence | skills/pr-review-gate/stages/prepare.md:131 | skills/pr-review-gate/stages/prepare.md |
| fence | skills/pr-review-gate/stages/prepare.md:150 | skills/pr-review-gate/stages/prepare-reviewer.md |
| fence | skills/pr-review-gate/stages/review-run.md:40 | skills/pr-review-gate/stages/review-run.md |
| fence | skills/pr-review-gate/stages/review-run.md:76 | skills/pr-review-gate/stages/review-run.md |
| fence | skills/pr-review-gate/stages/reviewer-brief.md:25 | skills/pr-review-gate/stages/reviewer-brief.md |
| fence | skills/pr-review-gate/stages/triage.md:166 | skills/pr-review-gate/stages/triage-escalation.md |
| fence | skills/pr-review-gate/stages/triage.md:181 | skills/pr-review-gate/stages/triage.md |
| fence | skills/pr-review-gate/stages/triage.md:235 | skills/pr-review-gate/stages/comment-parts.md |
| prose | skills/develop/references/roles/gate-runner.md:54 | skills/pr-review-gate/stages/gate-triage.md |
| prose | skills/develop/references/roles/gate-runner.md:77 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:78 | skills/pr-review-gate/declarations.md, skills/pr-review-gate/SKILL.md, skills/pr-review-gate/stages/comment-parts.md, skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/triage-escalation.md, skills/pr-review-gate/stages/hold-categories.md, skills/pr-review-gate/stages/reviewer-brief.md, skills/pr-review-gate/stages/pass.md, skills/pr-review-gate/stages/triage-epic.md, skills/pr-review-gate/stages/triage-nonblocking.md, skills/pr-review-gate/stages/hold-resume.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/parent-pass-criteria.md, skills/develop/references/epic.md, skills/develop/references/fix-check.md, skills/develop/references/decision-criteria.md, skills/develop/references/pre-classification.md, skills/develop/references/parent-merge-criteria.md, skills/develop/references/reply-after-idle.md, skills/develop/references/handover.md, skills/develop/references/roles/gate-runner.md, skills/develop/references/roles/spec-reviewer.md, skills/develop/references/roles/worker.md |
| prose | skills/develop/references/roles/gate-runner.md:79 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:80 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:81 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:82 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:83 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:84 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:85 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:91 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:93 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:94 | skills/pr-review-gate/SKILL.md, skills/pr-review-gate/stages/comment-parts.md, skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/hold-categories.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/epic.md, skills/develop/references/decision-criteria.md, skills/develop/references/roles/gate-runner.md, skills/develop/references/roles/worker.md |
| prose | skills/develop/references/roles/gate-runner.md:95 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:96 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:97 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:98 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:110 | skills/pr-review-gate/stages/gate-triage.md |
| prose | skills/develop/references/roles/gate-runner.md:111 | skills/pr-review-gate/stages/gate-triage.md |
| prose | skills/develop/references/roles/gate-runner.md:115 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:119 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:125 | skills/develop/references/roles/gate-runner.md |
| prose | skills/pr-review-gate/declarations.md:9 | skills/pr-review-gate/declarations.md |
| prose | skills/pr-review-gate/declarations.md:13 | skills/pr-review-gate/declarations.md |
| prose | skills/pr-review-gate/declarations.md:14 | skills/pr-review-gate/declarations.md |
| prose | skills/pr-review-gate/declarations.md:119 | skills/pr-review-gate/stages/issue-approved.md |
| prose | skills/pr-review-gate/stages/hold.md:5 | skills/pr-review-gate/stages/hold.md |
| prose | skills/pr-review-gate/stages/hold.md:45 | skills/pr-review-gate/stages/carryover.md |
| prose | skills/pr-review-gate/stages/hold.md:46 | skills/pr-review-gate/stages/carryover.md |
| prose | skills/pr-review-gate/stages/hold.md:47 | skills/pr-review-gate/stages/carryover.md |
| prose | skills/pr-review-gate/stages/hold.md:48 | skills/pr-review-gate/stages/carryover.md |
| prose | skills/pr-review-gate/stages/hold.md:49 | skills/pr-review-gate/stages/carryover.md |
| prose | skills/pr-review-gate/stages/hold.md:50 | skills/pr-review-gate/stages/carryover.md |
| prose | skills/pr-review-gate/stages/hold.md:51 | skills/pr-review-gate/stages/carryover.md |
| prose | skills/pr-review-gate/stages/hold.md:52 | skills/pr-review-gate/stages/carryover.md |
| prose | skills/pr-review-gate/stages/hold.md:63 | skills/pr-review-gate/stages/carryover.md |
| prose | skills/pr-review-gate/stages/hold.md:94 | skills/pr-review-gate/stages/carryover-judge.md |
| prose | skills/pr-review-gate/stages/hold.md:95 | skills/pr-review-gate/stages/carryover-judge.md |
| prose | skills/pr-review-gate/stages/hold.md:132 | skills/pr-review-gate/stages/hold-resume.md |
| prose | skills/pr-review-gate/stages/hold.md:133 | skills/pr-review-gate/declarations.md, skills/pr-review-gate/SKILL.md, skills/pr-review-gate/stages/comment-parts.md, skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/hold-categories.md, skills/pr-review-gate/stages/reviewer-brief.md, skills/pr-review-gate/stages/pass.md, skills/pr-review-gate/stages/triage-nonblocking.md, skills/pr-review-gate/stages/hold-resume.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/parent-pass-criteria.md, skills/develop/references/epic.md, skills/develop/references/decision-criteria.md, skills/develop/references/pre-classification.md, skills/develop/references/parent-merge-criteria.md, skills/develop/references/reply-after-idle.md, skills/develop/references/roles/gate-runner.md, skills/develop/references/roles/worker.md |
| prose | skills/pr-review-gate/stages/hold.md:134 | skills/pr-review-gate/stages/hold-resume.md |
| prose | skills/pr-review-gate/stages/hold.md:135 | skills/pr-review-gate/stages/hold-resume.md |
| prose | skills/pr-review-gate/stages/hold.md:136 | skills/pr-review-gate/stages/hold-resume.md |
| prose | skills/pr-review-gate/stages/hold.md:137 | skills/pr-review-gate/stages/hold-resume.md |
| prose | skills/pr-review-gate/stages/hold.md:138 | skills/pr-review-gate/stages/hold-resume.md |
| prose | skills/pr-review-gate/stages/hold.md:139 | skills/pr-review-gate/stages/hold-resume.md |
| prose | skills/pr-review-gate/stages/hold.md:195 | skills/pr-review-gate/stages/hold.md |
| prose | skills/pr-review-gate/stages/hold.md:196 | skills/pr-review-gate/stages/hold.md |
| prose | skills/pr-review-gate/stages/pass.md:5 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:13 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:36 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:37 | skills/pr-review-gate/declarations.md, skills/pr-review-gate/SKILL.md, skills/pr-review-gate/stages/comment-parts.md, skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/triage-escalation.md, skills/pr-review-gate/stages/hold-categories.md, skills/pr-review-gate/stages/reviewer-brief.md, skills/pr-review-gate/stages/pass.md, skills/pr-review-gate/stages/triage-epic.md, skills/pr-review-gate/stages/triage-nonblocking.md, skills/pr-review-gate/stages/hold-resume.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/parent-pass-criteria.md, skills/develop/references/epic.md, skills/develop/references/fix-check.md, skills/develop/references/decision-criteria.md, skills/develop/references/pre-classification.md, skills/develop/references/parent-merge-criteria.md, skills/develop/references/reply-after-idle.md, skills/develop/references/handover.md, skills/develop/references/roles/gate-runner.md, skills/develop/references/roles/spec-reviewer.md, skills/develop/references/roles/worker.md |
| prose | skills/pr-review-gate/stages/pass.md:38 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:39 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:40 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:67 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:69 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:70 | skills/pr-review-gate/declarations.md, skills/pr-review-gate/SKILL.md, skills/pr-review-gate/stages/comment-parts.md, skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/triage-escalation.md, skills/pr-review-gate/stages/hold-categories.md, skills/pr-review-gate/stages/reviewer-brief.md, skills/pr-review-gate/stages/pass.md, skills/pr-review-gate/stages/triage-epic.md, skills/pr-review-gate/stages/triage-nonblocking.md, skills/pr-review-gate/stages/hold-resume.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/parent-pass-criteria.md, skills/develop/references/epic.md, skills/develop/references/fix-check.md, skills/develop/references/decision-criteria.md, skills/develop/references/pre-classification.md, skills/develop/references/parent-merge-criteria.md, skills/develop/references/reply-after-idle.md, skills/develop/references/handover.md, skills/develop/references/roles/gate-runner.md, skills/develop/references/roles/spec-reviewer.md, skills/develop/references/roles/worker.md |
| prose | skills/pr-review-gate/stages/pass.md:71 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:72 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:73 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:74 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:75 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:76 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:77 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:78 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:79 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:119 | skills/pr-review-gate/stages/authenticity-conversation.md |
| prose | skills/pr-review-gate/stages/pass.md:121 | skills/pr-review-gate/stages/authenticity-relayed.md |
| prose | skills/pr-review-gate/stages/pass.md:129 | skills/pr-review-gate/stages/authenticity-relayed.md |
| prose | skills/pr-review-gate/stages/pass.md:130 | skills/pr-review-gate/stages/authenticity-relayed.md |
| prose | skills/pr-review-gate/stages/pass.md:132 | skills/pr-review-gate/stages/authenticity-relayed.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/prepare-light.md, skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:133 | skills/pr-review-gate/stages/authenticity-relayed.md |
| prose | skills/pr-review-gate/stages/pass.md:134 | skills/pr-review-gate/stages/authenticity-relayed.md, skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:135 | skills/pr-review-gate/stages/authenticity-relayed.md, skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:136 | skills/pr-review-gate/stages/authenticity-relayed.md |
| prose | skills/pr-review-gate/stages/pass.md:137 | skills/pr-review-gate/stages/authenticity-relayed.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/prepare-light.md, skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:144 | skills/pr-review-gate/stages/authenticity-relayed.md |
| prose | skills/pr-review-gate/stages/pass.md:146 | skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:152 | skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:154 | skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:155 | skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:156 | skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:157 | skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:159 | skills/pr-review-gate/stages/authenticity-relayed.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/prepare-light.md, skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:160 | skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:161 | skills/pr-review-gate/stages/authenticity-relayed.md, skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:162 | skills/pr-review-gate/stages/authenticity-relayed.md, skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:163 | skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:164 | skills/pr-review-gate/stages/authenticity-relayed.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/prepare-light.md, skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:166 | skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:168 | skills/pr-review-gate/stages/authenticity-delegated.md |
| prose | skills/pr-review-gate/stages/pass.md:285 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/prepare.md:5 | skills/pr-review-gate/stages/prepare.md |
| prose | skills/pr-review-gate/stages/prepare.md:19 | skills/pr-review-gate/stages/prepare.md |
| prose | skills/pr-review-gate/stages/prepare.md:84 | skills/pr-review-gate/stages/prepare-light.md |
| prose | skills/pr-review-gate/stages/prepare.md:90 | skills/pr-review-gate/stages/prepare-light.md |
| prose | skills/pr-review-gate/stages/prepare.md:127 | skills/pr-review-gate/stages/prepare.md |
| prose | skills/pr-review-gate/stages/prepare.md:144 | skills/pr-review-gate/stages/prepare-light.md |
| prose | skills/pr-review-gate/stages/review-run.md:5 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:24 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:32 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:33 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:34 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:58 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:59 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:60 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:61 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:62 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:63 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:64 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:65 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:66 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:67 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:96 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:97 | skills/pr-review-gate/declarations.md, skills/pr-review-gate/SKILL.md, skills/pr-review-gate/stages/comment-parts.md, skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/hold-categories.md, skills/pr-review-gate/stages/reviewer-brief.md, skills/pr-review-gate/stages/pass.md, skills/pr-review-gate/stages/triage-nonblocking.md, skills/pr-review-gate/stages/hold-resume.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/parent-pass-criteria.md, skills/develop/references/epic.md, skills/develop/references/decision-criteria.md, skills/develop/references/pre-classification.md, skills/develop/references/parent-merge-criteria.md, skills/develop/references/reply-after-idle.md, skills/develop/references/roles/gate-runner.md, skills/develop/references/roles/worker.md |
| prose | skills/pr-review-gate/stages/review-run.md:98 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:99 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:100 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:101 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:103 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:105 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:113 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:115 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/reviewer-brief.md:5 | skills/pr-review-gate/stages/reviewer-brief.md |
| prose | skills/pr-review-gate/stages/reviewer-brief.md:21 | skills/pr-review-gate/stages/reviewer-brief.md |
| prose | skills/pr-review-gate/stages/reviewer-brief.md:63 | skills/pr-review-gate/stages/reviewer-brief.md |
| prose | skills/pr-review-gate/stages/reviewer-brief.md:64 | skills/pr-review-gate/declarations.md, skills/pr-review-gate/SKILL.md, skills/pr-review-gate/stages/comment-parts.md, skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/hold-categories.md, skills/pr-review-gate/stages/reviewer-brief.md, skills/pr-review-gate/stages/pass.md, skills/pr-review-gate/stages/triage-nonblocking.md, skills/pr-review-gate/stages/hold-resume.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/parent-pass-criteria.md, skills/develop/references/epic.md, skills/develop/references/decision-criteria.md, skills/develop/references/pre-classification.md, skills/develop/references/parent-merge-criteria.md, skills/develop/references/reply-after-idle.md, skills/develop/references/roles/gate-runner.md, skills/develop/references/roles/worker.md |
| prose | skills/pr-review-gate/stages/reviewer-brief.md:65 | skills/pr-review-gate/stages/reviewer-brief.md |
| prose | skills/pr-review-gate/stages/reviewer-brief.md:66 | skills/pr-review-gate/stages/reviewer-brief.md |
| prose | skills/pr-review-gate/stages/reviewer-brief.md:67 | skills/pr-review-gate/stages/reviewer-brief.md |
| prose | skills/pr-review-gate/stages/reviewer-brief.md:68 | skills/pr-review-gate/stages/reviewer-brief.md |
| prose | skills/pr-review-gate/stages/reviewer-brief.md:69 | skills/pr-review-gate/stages/reviewer-brief.md |
| prose | skills/pr-review-gate/stages/triage.md:13 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:15 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:17 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:19 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:21 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:23 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:24 | skills/pr-review-gate/SKILL.md, skills/pr-review-gate/stages/comment-parts.md, skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/hold-categories.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/epic.md, skills/develop/references/decision-criteria.md, skills/develop/references/roles/gate-runner.md, skills/develop/references/roles/worker.md |
| prose | skills/pr-review-gate/stages/triage.md:25 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:26 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:27 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:28 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:29 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:30 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:32 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:34 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:47 | skills/pr-review-gate/stages/triage-row3.md |
| prose | skills/pr-review-gate/stages/triage.md:48 | skills/pr-review-gate/stages/triage-row3.md |
| prose | skills/pr-review-gate/stages/triage.md:49 | skills/pr-review-gate/stages/triage-row3.md |
| prose | skills/pr-review-gate/stages/triage.md:50 | skills/pr-review-gate/stages/triage-row3.md |
| prose | skills/pr-review-gate/stages/triage.md:51 | skills/pr-review-gate/stages/triage-row3.md |
| prose | skills/pr-review-gate/stages/triage.md:52 | skills/pr-review-gate/stages/triage-row3.md |
| prose | skills/pr-review-gate/stages/triage.md:53 | skills/pr-review-gate/stages/triage-row3.md |
| prose | skills/pr-review-gate/stages/triage.md:54 | skills/pr-review-gate/stages/triage-row3.md |
| prose | skills/pr-review-gate/stages/triage.md:60 | skills/pr-review-gate/stages/triage-row3.md |
| prose | skills/pr-review-gate/stages/triage.md:62 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:66 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:68 | skills/pr-review-gate/stages/triage-nonblocking.md |
| prose | skills/pr-review-gate/stages/triage.md:79 | skills/pr-review-gate/stages/triage-nonblocking.md |
| prose | skills/pr-review-gate/stages/triage.md:81 | skills/pr-review-gate/stages/triage-nonblocking.md |
| prose | skills/pr-review-gate/stages/triage.md:106 | skills/pr-review-gate/stages/triage-nonblocking.md |
| prose | skills/pr-review-gate/stages/triage.md:106 | skills/pr-review-gate/stages/triage-epic.md |
| prose | skills/pr-review-gate/stages/triage.md:106 | skills/pr-review-gate/stages/triage-epic.md |
| prose | skills/pr-review-gate/stages/triage.md:125 | skills/pr-review-gate/stages/triage-nonblocking.md |
| prose | skills/pr-review-gate/stages/triage.md:129 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:130 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:131 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:132 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:136 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:137 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:138 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:140 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:146 | skills/pr-review-gate/stages/triage-escalation.md |
| prose | skills/pr-review-gate/stages/triage.md:147 | skills/pr-review-gate/declarations.md, skills/pr-review-gate/SKILL.md, skills/pr-review-gate/stages/comment-parts.md, skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/triage-escalation.md, skills/pr-review-gate/stages/hold-categories.md, skills/pr-review-gate/stages/reviewer-brief.md, skills/pr-review-gate/stages/pass.md, skills/pr-review-gate/stages/triage-epic.md, skills/pr-review-gate/stages/triage-nonblocking.md, skills/pr-review-gate/stages/hold-resume.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/parent-pass-criteria.md, skills/develop/references/epic.md, skills/develop/references/fix-check.md, skills/develop/references/decision-criteria.md, skills/develop/references/pre-classification.md, skills/develop/references/parent-merge-criteria.md, skills/develop/references/reply-after-idle.md, skills/develop/references/handover.md, skills/develop/references/roles/gate-runner.md, skills/develop/references/roles/spec-reviewer.md, skills/develop/references/roles/worker.md |
| prose | skills/pr-review-gate/stages/triage.md:148 | skills/pr-review-gate/stages/triage-escalation.md |
| prose | skills/pr-review-gate/stages/triage.md:149 | skills/pr-review-gate/stages/triage-escalation.md |
| prose | skills/pr-review-gate/stages/triage.md:150 | skills/pr-review-gate/stages/triage-escalation.md |
| prose | skills/pr-review-gate/stages/triage.md:154 | skills/pr-review-gate/stages/triage-escalation.md |
| prose | skills/pr-review-gate/stages/triage.md:158 | skills/pr-review-gate/stages/triage-escalation.md |
| prose | skills/pr-review-gate/stages/triage.md:202 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:203 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:204 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:208 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:209 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:210 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:212 | skills/pr-review-gate/stages/comment-parts.md |
| prose | skills/pr-review-gate/stages/triage.md:214 | skills/pr-review-gate/stages/comment-parts.md |
| prose | skills/pr-review-gate/stages/triage.md:216 | skills/pr-review-gate/stages/comment-parts.md |
| prose | skills/pr-review-gate/stages/triage.md:255 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:256 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:257 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:258 | skills/pr-review-gate/stages/triage.md |
| command | skills/develop/references/roles/gate-runner.md:33 | skills/pr-review-gate/stages/reviewer-brief.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/roles/gate-runner.md |
| command | skills/develop/references/roles/gate-runner.md:43 | skills/pr-review-gate/stages/gate-triage.md |
| command | skills/develop/references/roles/gate-runner.md:91 | skills/develop/references/roles/gate-runner.md |
| command | skills/develop/references/roles/gate-runner.md:125 | skills/pr-review-gate/stages/comment-parts.md, skills/develop/references/epic.md, skills/develop/references/return-declaration.md, skills/develop/references/roles/gate-runner.md, skills/develop/references/roles/spec-reviewer.md, skills/develop/references/roles/worker/spec.md |
| command | skills/develop/references/roles/gate-runner.md:125 | skills/develop/references/epic.md, skills/develop/references/roles/gate-runner.md |
| command | skills/pr-review-gate/declarations.md:37 | skills/pr-review-gate/declarations.md |
| command | skills/pr-review-gate/declarations.md:92 | skills/pr-review-gate/stages/issue-approved.md |
| command | skills/pr-review-gate/declarations.md:95 | skills/pr-review-gate/stages/authenticity-conversation.md, skills/pr-review-gate/stages/issue-approved.md |
| command | skills/pr-review-gate/declarations.md:99 | skills/pr-review-gate/stages/issue-approved.md |
| command | skills/pr-review-gate/declarations.md:99 | skills/pr-review-gate/stages/issue-approved.md |
| command | skills/pr-review-gate/declarations.md:99 | skills/pr-review-gate/stages/triage-epic.md, skills/pr-review-gate/stages/issue-approved.md |
| command | skills/pr-review-gate/declarations.md:101 | skills/pr-review-gate/stages/issue-approved.md |
| command | skills/pr-review-gate/stages/hold.md:51 | skills/pr-review-gate/stages/authenticity-relayed.md, skills/pr-review-gate/stages/hold-resume.md, skills/pr-review-gate/stages/carryover.md, skills/pr-review-gate/stages/authenticity-delegated.md, skills/develop/references/epic-child-stop.md |
| command | skills/pr-review-gate/stages/hold.md:51 | skills/pr-review-gate/stages/hold-resume.md, skills/pr-review-gate/stages/carryover.md, skills/pr-review-gate/stages/authenticity-delegated.md, skills/develop/references/epic-child-stop.md |
| command | skills/pr-review-gate/stages/hold.md:77 | skills/pr-review-gate/stages/carryover-judge.md |
| command | skills/pr-review-gate/stages/hold.md:104 | skills/pr-review-gate/stages/prepare-light.md, skills/pr-review-gate/stages/no-point-check.md |
| command | skills/pr-review-gate/stages/hold.md:126 | skills/pr-review-gate/stages/hold.md |
| command | skills/pr-review-gate/stages/hold.md:134 | skills/pr-review-gate/stages/authenticity-relayed.md, skills/pr-review-gate/stages/hold-resume.md, skills/pr-review-gate/stages/carryover.md, skills/pr-review-gate/stages/authenticity-delegated.md, skills/develop/references/epic-child-stop.md |
| command | skills/pr-review-gate/stages/hold.md:134 | skills/pr-review-gate/stages/hold-resume.md, skills/pr-review-gate/stages/carryover.md, skills/pr-review-gate/stages/authenticity-delegated.md, skills/develop/references/epic-child-stop.md |
| command | skills/pr-review-gate/stages/pass.md:13 | skills/pr-review-gate/stages/pass.md, skills/develop/references/epic.md |
| command | skills/pr-review-gate/stages/pass.md:34 | skills/pr-review-gate/stages/pass.md |
| command | skills/pr-review-gate/stages/pass.md:34 | skills/pr-review-gate/stages/pass.md |
| command | skills/pr-review-gate/stages/pass.md:44 | skills/pr-review-gate/stages/pass.md, skills/develop/references/epic.md, skills/develop/references/reply-after-idle.md |
| command | skills/pr-review-gate/stages/pass.md:112 | skills/pr-review-gate/stages/authenticity-conversation.md |
| command | skills/pr-review-gate/stages/pass.md:121 | skills/pr-review-gate/stages/authenticity-relayed.md, skills/develop/references/epic.md |
| command | skills/pr-review-gate/stages/pass.md:121 | skills/pr-review-gate/stages/authenticity-relayed.md, skills/pr-review-gate/stages/hold-resume.md, skills/pr-review-gate/stages/carryover.md, skills/pr-review-gate/stages/authenticity-delegated.md, skills/develop/references/epic-child-stop.md |
| command | skills/pr-review-gate/stages/pass.md:129 | skills/pr-review-gate/stages/authenticity-relayed.md |
| command | skills/pr-review-gate/stages/pass.md:129 | skills/pr-review-gate/stages/authenticity-relayed.md |
| command | skills/pr-review-gate/stages/pass.md:146 | skills/pr-review-gate/stages/hold-resume.md, skills/pr-review-gate/stages/carryover.md, skills/pr-review-gate/stages/authenticity-delegated.md, skills/develop/references/epic-child-stop.md |
| command | skills/pr-review-gate/stages/pass.md:152 | skills/pr-review-gate/stages/authenticity-relayed.md, skills/pr-review-gate/stages/hold-resume.md, skills/pr-review-gate/stages/carryover.md, skills/pr-review-gate/stages/authenticity-delegated.md, skills/develop/references/epic-child-stop.md |
| command | skills/pr-review-gate/stages/pass.md:154 | skills/pr-review-gate/declarations.md, skills/pr-review-gate/stages/authenticity-relayed.md, skills/pr-review-gate/stages/comment-parts.md, skills/pr-review-gate/stages/prepare-partitions.md, skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/prepare-light.md, skills/pr-review-gate/stages/triage-escalation.md, skills/pr-review-gate/stages/pass.md, skills/pr-review-gate/stages/triage-epic.md, skills/pr-review-gate/stages/triage-nonblocking.md, skills/pr-review-gate/stages/authenticity-conversation.md, skills/pr-review-gate/stages/hold.md, skills/pr-review-gate/stages/issue-approved.md, skills/pr-review-gate/stages/authenticity.md, skills/pr-review-gate/stages/authenticity-delegated.md, skills/develop/references/parent-pass-criteria.md, skills/develop/references/epic-child-stop.md, skills/develop/references/epic.md, skills/develop/references/handover.md, skills/develop/references/roles/spec-reviewer.md, skills/develop/references/roles/worker/spec.md |
| command | skills/pr-review-gate/stages/pass.md:157 | skills/pr-review-gate/stages/authenticity-delegated.md |
| command | skills/pr-review-gate/stages/pass.md:168 | skills/pr-review-gate/declarations.md, skills/pr-review-gate/stages/authenticity-relayed.md, skills/pr-review-gate/stages/comment-parts.md, skills/pr-review-gate/stages/prepare-partitions.md, skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/prepare-light.md, skills/pr-review-gate/stages/triage-escalation.md, skills/pr-review-gate/stages/pass.md, skills/pr-review-gate/stages/triage-epic.md, skills/pr-review-gate/stages/triage-nonblocking.md, skills/pr-review-gate/stages/authenticity-conversation.md, skills/pr-review-gate/stages/hold.md, skills/pr-review-gate/stages/issue-approved.md, skills/pr-review-gate/stages/authenticity.md, skills/pr-review-gate/stages/authenticity-delegated.md, skills/develop/references/parent-pass-criteria.md, skills/develop/references/epic-child-stop.md, skills/develop/references/epic.md, skills/develop/references/handover.md, skills/develop/references/roles/spec-reviewer.md, skills/develop/references/roles/worker/spec.md |
| command | skills/pr-review-gate/stages/pass.md:184 | skills/pr-review-gate/stages/pass.md |
| command | skills/pr-review-gate/stages/pass.md:222 | skills/pr-review-gate/stages/pass.md |
| command | skills/pr-review-gate/stages/pass.md:229 | skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/pass.md |
| command | skills/pr-review-gate/stages/pass.md:271 | skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/pass.md |
| command | skills/pr-review-gate/stages/pass.md:282 | skills/pr-review-gate/stages/pass.md |
| command | skills/pr-review-gate/stages/prepare.md:19 | skills/pr-review-gate/stages/prepare.md |
| command | skills/pr-review-gate/stages/prepare.md:21 | skills/pr-review-gate/stages/prepare.md |
| command | skills/pr-review-gate/stages/prepare.md:23 | skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/pass.md |
| command | skills/pr-review-gate/stages/prepare.md:26 | skills/pr-review-gate/stages/prepare.md |
| command | skills/pr-review-gate/stages/prepare.md:39 | skills/pr-review-gate/stages/prepare.md |
| command | skills/pr-review-gate/stages/prepare.md:86 | skills/pr-review-gate/stages/prepare-light.md, skills/pr-review-gate/stages/no-point-check.md |
| command | skills/pr-review-gate/stages/prepare.md:119 | skills/pr-review-gate/stages/prepare-partitions.md, skills/pr-review-gate/stages/prepare.md |
| command | skills/pr-review-gate/stages/prepare.md:119 | skills/pr-review-gate/stages/prepare-partitions.md, skills/pr-review-gate/stages/prepare.md |
| command | skills/pr-review-gate/stages/prepare.md:119 | skills/pr-review-gate/declarations.md, skills/pr-review-gate/stages/authenticity-relayed.md, skills/pr-review-gate/stages/comment-parts.md, skills/pr-review-gate/stages/prepare-partitions.md, skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/prepare-light.md, skills/pr-review-gate/stages/triage-escalation.md, skills/pr-review-gate/stages/pass.md, skills/pr-review-gate/stages/triage-epic.md, skills/pr-review-gate/stages/triage-nonblocking.md, skills/pr-review-gate/stages/authenticity-conversation.md, skills/pr-review-gate/stages/hold.md, skills/pr-review-gate/stages/issue-approved.md, skills/pr-review-gate/stages/authenticity.md, skills/pr-review-gate/stages/authenticity-delegated.md, skills/develop/references/parent-pass-criteria.md, skills/develop/references/epic-child-stop.md, skills/develop/references/epic.md, skills/develop/references/handover.md, skills/develop/references/roles/spec-reviewer.md, skills/develop/references/roles/worker/spec.md |
| command | skills/pr-review-gate/stages/prepare.md:127 | skills/pr-review-gate/declarations.md, skills/pr-review-gate/stages/authenticity-relayed.md, skills/pr-review-gate/stages/comment-parts.md, skills/pr-review-gate/stages/prepare-partitions.md, skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/prepare-light.md, skills/pr-review-gate/stages/triage-escalation.md, skills/pr-review-gate/stages/pass.md, skills/pr-review-gate/stages/triage-epic.md, skills/pr-review-gate/stages/triage-nonblocking.md, skills/pr-review-gate/stages/authenticity-conversation.md, skills/pr-review-gate/stages/hold.md, skills/pr-review-gate/stages/issue-approved.md, skills/pr-review-gate/stages/authenticity.md, skills/pr-review-gate/stages/authenticity-delegated.md, skills/develop/references/parent-pass-criteria.md, skills/develop/references/epic-child-stop.md, skills/develop/references/epic.md, skills/develop/references/handover.md, skills/develop/references/roles/spec-reviewer.md, skills/develop/references/roles/worker/spec.md |
| command | skills/pr-review-gate/stages/prepare.md:127 | skills/pr-review-gate/stages/prepare.md |
| command | skills/pr-review-gate/stages/prepare.md:127 | skills/pr-review-gate/stages/prepare.md |
| command | skills/pr-review-gate/stages/prepare.md:165 | skills/pr-review-gate/stages/prepare-reviewer.md |
| command | skills/pr-review-gate/stages/review-run.md:19 | skills/pr-review-gate/stages/review-run.md |
| command | skills/pr-review-gate/stages/review-run.md:22 | skills/pr-review-gate/stages/prepare-reviewer.md, skills/pr-review-gate/stages/review-run.md |
| command | skills/pr-review-gate/stages/review-run.md:52 | skills/pr-review-gate/stages/reviewer-brief.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/roles/worker/implement.md |
| command | skills/pr-review-gate/stages/review-run.md:63 | skills/pr-review-gate/stages/reviewer-brief.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/roles/gate-runner.md |
| command | skills/pr-review-gate/stages/review-run.md:65 | skills/pr-review-gate/stages/reviewer-brief.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/roles/gate-runner.md |
| command | skills/pr-review-gate/stages/review-run.md:71 | skills/pr-review-gate/stages/review-run.md |
| command | skills/pr-review-gate/stages/review-run.md:98 | skills/pr-review-gate/stages/review-run.md |
| command | skills/pr-review-gate/stages/review-run.md:105 | skills/pr-review-gate/stages/reviewer-brief.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/roles/gate-runner.md |
| command | skills/pr-review-gate/stages/review-run.md:113 | skills/pr-review-gate/stages/reviewer-brief.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/roles/gate-runner.md |
| command | skills/pr-review-gate/stages/reviewer-brief.md:38 | skills/pr-review-gate/stages/reviewer-brief.md |
| command | skills/pr-review-gate/stages/reviewer-brief.md:38 | skills/pr-review-gate/stages/reviewer-brief.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/roles/worker/implement.md |
| command | skills/pr-review-gate/stages/reviewer-brief.md:38 | skills/pr-review-gate/stages/reviewer-brief.md |
| command | skills/pr-review-gate/stages/reviewer-brief.md:38 | skills/pr-review-gate/stages/reviewer-brief.md |
| command | skills/pr-review-gate/stages/reviewer-brief.md:61 | skills/pr-review-gate/stages/reviewer-brief.md, skills/pr-review-gate/stages/review-run.md, skills/develop/references/roles/gate-runner.md |
| command | skills/pr-review-gate/stages/triage.md:56 | skills/pr-review-gate/stages/triage-row3.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/triage-convergence.md |
| command | skills/pr-review-gate/stages/triage.md:56 | skills/pr-review-gate/stages/triage-row3.md |
| command | skills/pr-review-gate/stages/triage.md:56 | skills/pr-review-gate/stages/triage-row3.md, skills/pr-review-gate/stages/triage-convergence.md |
| command | skills/pr-review-gate/stages/triage.md:56 | skills/pr-review-gate/stages/triage-row3.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/triage-convergence.md |
| command | skills/pr-review-gate/stages/triage.md:58 | skills/pr-review-gate/stages/triage-row3.md |
| command | skills/pr-review-gate/stages/triage.md:66 | skills/pr-review-gate/stages/triage.md |
| command | skills/pr-review-gate/stages/triage.md:97 | skills/pr-review-gate/stages/triage-nonblocking.md |
| command | skills/pr-review-gate/stages/triage.md:106 | skills/pr-review-gate/stages/triage-nonblocking.md |
| command | skills/pr-review-gate/stages/triage.md:115 | skills/pr-review-gate/stages/triage-epic.md |
| command | skills/pr-review-gate/stages/triage.md:115 | skills/pr-review-gate/stages/triage-epic.md |
| command | skills/pr-review-gate/stages/triage.md:117 | skills/pr-review-gate/stages/triage-epic.md |
| command | skills/pr-review-gate/stages/triage.md:148 | skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/triage-escalation.md |
| command | skills/pr-review-gate/stages/triage.md:187 | skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/triage-escalation.md |
| command | skills/pr-review-gate/stages/triage.md:208 | skills/pr-review-gate/stages/triage-row3.md, skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/triage-convergence.md |
| command | skills/pr-review-gate/stages/triage.md:208 | skills/pr-review-gate/stages/triage-row3.md, skills/pr-review-gate/stages/triage-convergence.md |
| command | skills/pr-review-gate/stages/triage.md:227 | skills/pr-review-gate/stages/comment-parts.md |
| command | skills/pr-review-gate/stages/triage.md:242 | skills/pr-review-gate/stages/comment-parts.md |

Additional negative/exit constraints (しない・禁止・不可・失敗・戻す・進む・return):

| Kind | Fixed source:line | Current files |
|---|---|---|
| prose | skills/develop/references/roles/gate-runner.md:7 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:10 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:27 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:29 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:33 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:40 | skills/pr-review-gate/stages/gate-triage.md |
| prose | skills/develop/references/roles/gate-runner.md:50 | skills/pr-review-gate/stages/gate-triage.md |
| prose | skills/develop/references/roles/gate-runner.md:56 | skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/pass.md, skills/pr-review-gate/stages/hold.md, skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:58 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:73 | skills/develop/references/roles/gate-runner.md |
| prose | skills/develop/references/roles/gate-runner.md:117 | skills/pr-review-gate/stages/triage-nonblocking.md, skills/develop/references/roles/gate-runner.md |
| prose | skills/pr-review-gate/declarations.md:64 | skills/pr-review-gate/declarations.md |
| prose | skills/pr-review-gate/declarations.md:85 | skills/pr-review-gate/stages/issue-approved.md |
| prose | skills/pr-review-gate/declarations.md:98 | skills/pr-review-gate/stages/issue-approved.md |
| prose | skills/pr-review-gate/declarations.md:99 | skills/pr-review-gate/stages/issue-approved.md |
| prose | skills/pr-review-gate/declarations.md:109 | skills/pr-review-gate/stages/issue-approved.md |
| prose | skills/pr-review-gate/declarations.md:117 | skills/pr-review-gate/stages/issue-approved.md |
| prose | skills/pr-review-gate/declarations.md:123 | skills/pr-review-gate/declarations.md |
| prose | skills/pr-review-gate/declarations.md:145 | skills/pr-review-gate/declarations.md |
| prose | skills/pr-review-gate/declarations.md:157 | skills/pr-review-gate/declarations.md |
| prose | skills/pr-review-gate/declarations.md:158 | skills/pr-review-gate/declarations.md |
| prose | skills/pr-review-gate/stages/hold.md:9 | skills/pr-review-gate/stages/hold.md |
| prose | skills/pr-review-gate/stages/hold.md:23 | skills/pr-review-gate/stages/carryover.md |
| prose | skills/pr-review-gate/stages/hold.md:25 | skills/pr-review-gate/stages/carryover.md |
| prose | skills/pr-review-gate/stages/hold.md:54 | skills/pr-review-gate/stages/carryover.md |
| prose | skills/pr-review-gate/stages/hold.md:65 | skills/pr-review-gate/stages/carryover.md |
| prose | skills/pr-review-gate/stages/hold.md:67 | skills/pr-review-gate/stages/carryover.md |
| prose | skills/pr-review-gate/stages/hold.md:74 | skills/pr-review-gate/stages/carryover-judge.md |
| prose | skills/pr-review-gate/stages/hold.md:75 | skills/pr-review-gate/stages/carryover-judge.md |
| prose | skills/pr-review-gate/stages/hold.md:76 | skills/pr-review-gate/stages/carryover-judge.md |
| prose | skills/pr-review-gate/stages/hold.md:77 | skills/pr-review-gate/stages/carryover-judge.md |
| prose | skills/pr-review-gate/stages/hold.md:78 | skills/pr-review-gate/stages/carryover-judge.md |
| prose | skills/pr-review-gate/stages/hold.md:101 | skills/pr-review-gate/stages/no-point-check.md |
| prose | skills/pr-review-gate/stages/hold.md:103 | skills/pr-review-gate/stages/no-point-check.md |
| prose | skills/pr-review-gate/stages/hold.md:104 | skills/pr-review-gate/stages/no-point-check.md |
| prose | skills/pr-review-gate/stages/hold.md:112 | skills/pr-review-gate/stages/no-point-check.md |
| prose | skills/pr-review-gate/stages/hold.md:122 | skills/pr-review-gate/stages/no-point-check.md |
| prose | skills/pr-review-gate/stages/hold.md:123 | skills/pr-review-gate/stages/no-point-check.md |
| prose | skills/pr-review-gate/stages/hold.md:128 | skills/pr-review-gate/stages/hold.md |
| prose | skills/pr-review-gate/stages/hold.md:141 | skills/pr-review-gate/stages/hold-resume.md |
| prose | skills/pr-review-gate/stages/hold.md:144 | skills/pr-review-gate/stages/hold-resume.md |
| prose | skills/pr-review-gate/stages/hold.md:159 | skills/pr-review-gate/stages/hold-categories.md |
| prose | skills/pr-review-gate/stages/hold.md:161 | skills/pr-review-gate/stages/hold-categories.md |
| prose | skills/pr-review-gate/stages/hold.md:167 | skills/pr-review-gate/stages/hold.md |
| prose | skills/pr-review-gate/stages/hold.md:169 | skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/pass.md, skills/pr-review-gate/stages/hold.md |
| prose | skills/pr-review-gate/stages/hold.md:200 | skills/pr-review-gate/stages/hold.md |
| prose | skills/pr-review-gate/stages/pass.md:30 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:42 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:50 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:96 | skills/pr-review-gate/stages/authenticity.md |
| prose | skills/pr-review-gate/stages/pass.md:112 | skills/pr-review-gate/stages/authenticity-conversation.md |
| prose | skills/pr-review-gate/stages/pass.md:114 | skills/pr-review-gate/stages/authenticity-conversation.md |
| prose | skills/pr-review-gate/stages/pass.md:170 | skills/pr-review-gate/stages/issue-approved.md |
| prose | skills/pr-review-gate/stages/pass.md:180 | skills/pr-review-gate/stages/issue-approved.md |
| prose | skills/pr-review-gate/stages/pass.md:182 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:183 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:184 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:193 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:195 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:219 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:220 | skills/pr-review-gate/stages/pass-wording.md |
| prose | skills/pr-review-gate/stages/pass.md:221 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:222 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:229 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:230 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:237 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:254 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:268 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:276 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:277 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:278 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:283 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:291 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:293 | skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/pass.md, skills/pr-review-gate/stages/hold.md |
| prose | skills/pr-review-gate/stages/pass.md:316 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/prepare.md:21 | skills/pr-review-gate/stages/prepare.md |
| prose | skills/pr-review-gate/stages/prepare.md:26 | skills/pr-review-gate/stages/prepare.md |
| prose | skills/pr-review-gate/stages/prepare.md:31 | skills/pr-review-gate/stages/prepare.md |
| prose | skills/pr-review-gate/stages/prepare.md:39 | skills/pr-review-gate/stages/prepare.md |
| prose | skills/pr-review-gate/stages/prepare.md:45 | skills/pr-review-gate/stages/prepare-light.md |
| prose | skills/pr-review-gate/stages/prepare.md:48 | skills/pr-review-gate/stages/prepare-light.md |
| prose | skills/pr-review-gate/stages/prepare.md:63 | skills/pr-review-gate/stages/prepare-light.md |
| prose | skills/pr-review-gate/stages/prepare.md:82 | skills/pr-review-gate/stages/prepare-light.md |
| prose | skills/pr-review-gate/stages/prepare.md:86 | skills/pr-review-gate/stages/prepare-light.md |
| prose | skills/pr-review-gate/stages/prepare.md:88 | skills/pr-review-gate/stages/prepare-light.md |
| prose | skills/pr-review-gate/stages/prepare.md:94 | skills/pr-review-gate/stages/prepare.md |
| prose | skills/pr-review-gate/stages/prepare.md:119 | skills/pr-review-gate/stages/prepare.md（ROOT の解決と入力の作り方）, skills/pr-review-gate/stages/prepare-partitions.md（区画の詰め方） |
| prose | skills/pr-review-gate/stages/prepare.md:146 | skills/pr-review-gate/stages/prepare-reviewer.md |
| prose | skills/pr-review-gate/stages/prepare.md:148 | skills/pr-review-gate/stages/prepare-reviewer.md |
| prose | skills/pr-review-gate/stages/prepare.md:185 | skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:15 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:22 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:26 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:28 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:30 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:36 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:38 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:73 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:74 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:94 | skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/review-run.md:120 | skills/pr-review-gate/stages/prepare.md, skills/pr-review-gate/stages/review-run.md |
| prose | skills/pr-review-gate/stages/reviewer-brief.md:19 | skills/pr-review-gate/stages/reviewer-brief.md |
| prose | skills/pr-review-gate/stages/reviewer-brief.md:23 | skills/pr-review-gate/stages/reviewer-brief.md |
| prose | skills/pr-review-gate/stages/reviewer-brief.md:61 | skills/pr-review-gate/stages/reviewer-brief.md |
| prose | skills/pr-review-gate/stages/reviewer-brief.md:71 | skills/pr-review-gate/stages/reviewer-brief.md |
| prose | skills/pr-review-gate/stages/reviewer-brief.md:76 | skills/pr-review-gate/stages/reviewer-brief.md |
| prose | skills/pr-review-gate/stages/triage.md:36 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:39 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:40 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:41 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:43 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:45 | skills/pr-review-gate/stages/triage-convergence.md |
| prose | skills/pr-review-gate/stages/triage.md:56 | skills/pr-review-gate/stages/triage-row3.md |
| prose | skills/pr-review-gate/stages/triage.md:58 | skills/pr-review-gate/stages/triage-row3.md |
| prose | skills/pr-review-gate/stages/triage.md:64 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:76 | skills/pr-review-gate/stages/triage-nonblocking.md |
| prose | skills/pr-review-gate/stages/triage.md:77 | skills/pr-review-gate/stages/triage-nonblocking.md |
| prose | skills/pr-review-gate/stages/triage.md:87 | skills/pr-review-gate/stages/triage-nonblocking.md |
| prose | skills/pr-review-gate/stages/triage.md:95 | skills/pr-review-gate/stages/triage-nonblocking.md |
| prose | skills/pr-review-gate/stages/triage.md:99 | skills/pr-review-gate/stages/triage-nonblocking.md |
| prose | skills/pr-review-gate/stages/triage.md:102 | skills/pr-review-gate/stages/triage-nonblocking.md |
| prose | skills/pr-review-gate/stages/triage.md:104 | skills/pr-review-gate/stages/triage-nonblocking.md |
| prose | skills/pr-review-gate/stages/triage.md:115 | skills/pr-review-gate/stages/triage-epic.md |
| prose | skills/pr-review-gate/stages/triage.md:117 | skills/pr-review-gate/stages/triage-epic.md |
| prose | skills/pr-review-gate/stages/triage.md:121 | skills/pr-review-gate/stages/triage-nonblocking.md |
| prose | skills/pr-review-gate/stages/triage.md:123 | skills/pr-review-gate/stages/triage-nonblocking.md |
| prose | skills/pr-review-gate/stages/triage.md:144 | skills/pr-review-gate/stages/triage-escalation.md |
| prose | skills/pr-review-gate/stages/triage.md:156 | skills/pr-review-gate/stages/triage-escalation.md |
| prose | skills/pr-review-gate/stages/triage.md:160 | skills/pr-review-gate/stages/triage-escalation.md |
| prose | skills/pr-review-gate/stages/triage.md:162 | skills/pr-review-gate/stages/triage-escalation.md |
| prose | skills/pr-review-gate/stages/triage.md:171 | skills/pr-review-gate/stages/triage-escalation.md |
| prose | skills/pr-review-gate/stages/triage.md:177 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:179 | skills/pr-review-gate/stages/triage.md, skills/pr-review-gate/stages/pass.md, skills/pr-review-gate/stages/hold.md |
| prose | skills/pr-review-gate/stages/triage.md:196 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:206 | skills/pr-review-gate/stages/triage.md |
| prose | skills/pr-review-gate/stages/triage.md:240 | skills/pr-review-gate/stages/comment-parts.md |
| prose | skills/pr-review-gate/stages/triage.md:242 | skills/pr-review-gate/stages/comment-parts.md |
| prose | skills/pr-review-gate/stages/triage.md:246 | skills/pr-review-gate/stages/comment-parts.md |
| prose | skills/pr-review-gate/stages/triage.md:247 | skills/pr-review-gate/stages/comment-parts.md |
| prose | skills/pr-review-gate/stages/triage.md:251 | skills/pr-review-gate/stages/comment-parts.md |
| prose | skills/pr-review-gate/stages/prepare.md:22 | skills/pr-review-gate/stages/prepare.md |
| prose | skills/pr-review-gate/stages/pass.md:226 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/pass.md:232 | skills/pr-review-gate/stages/pass.md |
| prose | skills/pr-review-gate/stages/hold.md:142 | skills/pr-review-gate/stages/hold-resume.md |

Reference-only exceptions: gate-runner:19 adds the conditional prepare-reviewer source; prepare:184 redirects the needs-reviewer return to prepare-reviewer. Those routing conditions and exits remain checked by related bats.

Merged main (#1690, #1697): pass.md:146, :155 and :156 are the texts of origin/main after #1690 moved the delegation conditions to develop `references/epic-delegation.md` (the gate reads them there instead of copying them). Only those three prose expectations differ from the revision above; their destination stays authenticity-delegated.md. #1707 then made the reference path explicit (`skills/develop/references/epic-delegation.md`) in the same three expectations.

## Gate round 1 reference changes (#1687)

The expected prose below was updated only where the referenced file or section moved (compared after the alias normalization above). Rules, stop conditions, commands and templates are unchanged. prepare:119 is split into the part kept in prepare.md and the part kept in prepare-partitions.md (A7).

| Fixed source:line | Reference change (normalized expected → current) |
|---|---|
| skills/pr-review-gate/stages/hold.md:5 | ・ → ）、`stages/triage.md`（ |
| skills/pr-review-gate/stages/hold.md:195 | ∅ → `stages/hold.md` の; このファイル → `stages/hold.md`; 3-c → `stages/hold.md` |
| skills/pr-review-gate/stages/pass.md:5 | ・ → ）、`stages/triage.md`（ |
| skills/pr-review-gate/stages/pass.md:72 | 下 → `stages/pass.md` |
| skills/pr-review-gate/stages/pass.md:73 | 下 → `stages/pass.md` |
| skills/pr-review-gate/stages/pass.md:74 | 下 → `stages/pass.md` |
| skills/pr-review-gate/stages/pass.md:75 | 下 → `stages/pass.md` |
| skills/pr-review-gate/stages/pass.md:78 | 下 → `declarations.md`; ∅ → 「; ∅ → 」 |
| skills/pr-review-gate/stages/prepare.md:5 | ・ → ）、`stages/triage.md`（ |
| skills/pr-review-gate/stages/review-run.md:5 | ・ → ）、`stages/triage.md`（ |
| skills/pr-review-gate/stages/reviewer-brief.md:5 | ・ → ）、`stages/triage.md`（ |
| skills/pr-review-gate/stages/triage.md:15 | 下 → `stages/triage.md` |
| skills/pr-review-gate/stages/triage.md:25 | 下 → `stages/triage.md` |
| skills/pr-review-gate/stages/triage.md:66 | 上 → `stages/triage.md` |
| skills/pr-review-gate/stages/triage.md:68 | 上 → `stages/triage.md` の止める指摘 |
| skills/pr-review-gate/stages/triage.md:106 | この → ∅; ∅ → C |
| skills/pr-review-gate/stages/triage.md:138 | 上 → `stages/triage.md`; 仕分け表 → こ; 直後 → ファイル; ∅ → （仕分け表そのものは `stages/triage.md`） |
| skills/pr-review-gate/stages/triage.md:202 | 下 → `stages/triage.md`; ∅ → （三表と順 3 の一覧） |
| skills/pr-review-gate/stages/triage.md:209 | p → `stages/t; -r → iag; view-gate 手順 2-1 → .md` |
| skills/pr-review-gate/stages/triage.md:210 | 手順 2-1 → `stages/triage.md`; ∅ → `stages/triage.md` の |
| skills/pr-review-gate/stages/hold.md:67 | ∅ → `; ∅ → ` |
| skills/pr-review-gate/stages/hold.md:101 | 下 → `stages/hold.md` の手順 6; 下 → `stages/hold.md` の手順 6 |
| skills/pr-review-gate/stages/hold.md:103 | 下 → `stages/hold.md` |
| skills/pr-review-gate/stages/hold.md:123 | 下 → `stages/hold.md` の手順 6 |
| skills/pr-review-gate/stages/hold.md:200 | ∅ → （`stages/hold.md`） |
| skills/pr-review-gate/stages/triage.md:99 | 段 → このファイルの、エピックに属するかを記録先; C → issue; ∅ → 親から決める |
| skills/pr-review-gate/stages/triage.md:121 | 段 → このファイルの、エピックに属するかを記録先; C → issue; ∅ → 親から決める |

## Gate round 1 block and stop-condition additions (#1687)

Each fenced template is one expectation holding the whole fence (indentation and line breaks included), so editing, deleting or reordering any line inside it fails. Fixed main is the revision above.

| Fixed source:line | Current location | Change |
|---|---|---|
| skills/pr-review-gate/stages/prepare.md:28 | skills/pr-review-gate/stages/prepare.md | indented fence added as one block |
| skills/pr-review-gate/stages/prepare.md:35 | skills/pr-review-gate/stages/prepare.md | indented fence added as one block |
| skills/pr-review-gate/stages/prepare.md:41 | skills/pr-review-gate/stages/prepare.md | indented fence added as one block |
| skills/pr-review-gate/stages/prepare.md:47 | skills/pr-review-gate/stages/prepare-light.md | indented fence added as one block |
| skills/pr-review-gate/stages/pass.md:132 | skills/pr-review-gate/stages/authenticity-relayed.md | indented fence added as one block |
| skills/pr-review-gate/stages/pass.md:159 | skills/pr-review-gate/stages/authenticity-delegated.md | indented fence added as one block |
| skills/pr-review-gate/stages/hold.md:27 | skills/pr-review-gate/stages/carryover.md | per-line entries merged into one whole-fence block |
| skills/pr-review-gate/stages/pass.md:106 | skills/pr-review-gate/stages/authenticity-conversation.md | per-line entries merged into one whole-fence block |
| skills/pr-review-gate/stages/pass.md:186 | skills/pr-review-gate/stages/pass.md | per-line entries merged into one whole-fence block |
| skills/pr-review-gate/stages/pass.md:241 | skills/pr-review-gate/stages/pass.md | per-line entries merged into one whole-fence block |
| skills/pr-review-gate/stages/prepare.md:100 | skills/pr-review-gate/stages/prepare.md | per-line entries merged into one whole-fence block |
| skills/pr-review-gate/stages/prepare.md:121 | skills/pr-review-gate/stages/prepare.md | per-line entries merged into one whole-fence block |
| skills/pr-review-gate/stages/prepare.md:131 | skills/pr-review-gate/stages/prepare.md | per-line entries merged into one whole-fence block |
| skills/pr-review-gate/stages/triage.md:166 | skills/pr-review-gate/stages/triage-escalation.md | per-line entries merged into one whole-fence block |
| skills/pr-review-gate/stages/triage.md:235 | skills/pr-review-gate/stages/comment-parts.md | per-line entries merged into one whole-fence block |
| skills/pr-review-gate/stages/pass.md:197 | skills/pr-review-gate/stages/pass.md (lines 197–210 of the fixed fence), skills/pr-review-gate/stages/pass-wording.md (lines 211–215) | intended split: the record/spec checks stay in pass.md, the wording-sync checks move to pass-wording.md; each contiguous part is one block |
| skills/pr-review-gate/stages/prepare.md:22–27 | skills/pr-review-gate/stages/prepare.md | stop-condition paragraph added as one prose block (lines already listed one by one stay) |
| skills/pr-review-gate/stages/pass.md:226–230 | skills/pr-review-gate/stages/pass.md | stop-condition paragraph added as one prose block (lines already listed one by one stay) |
| skills/pr-review-gate/stages/pass.md:232–239 | skills/pr-review-gate/stages/pass.md | stop-condition paragraph added as one prose block (lines already listed one by one stay) |
| skills/pr-review-gate/stages/hold.md:142–144 | skills/pr-review-gate/stages/hold-resume.md | stop-condition paragraph added as one prose block (lines already listed one by one stay) |
