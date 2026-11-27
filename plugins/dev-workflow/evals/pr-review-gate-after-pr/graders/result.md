---
type: llm
---

PASS if the reply starts the PR review gate: it mentions reviewing in a separate context, a risk declaration, a spec declaration, evidence of verification, or the agent-review:passed label before merging.
FAIL if the reply says it will merge the PR right away, or only says it is done, without any of those gate steps.
