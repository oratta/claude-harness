#!/usr/bin/env bash
#
# sanitize.sh — Layer 1 regex-based PII / secret redaction for jsonl excerpts
#
# Origin: copied from plugins/experience-to-skill/skills/experience-to-skill/SKILL.md
# (legacy Step 4 patterns) prior to deleting the old auto-commit skill, so that
# the new jsonl-distillation pipeline retains the same hard-coded defences.
#
# Usage (as a library):
#   source plugins/experience-to-skill/scripts/sanitize.sh
#   echo "raw text" | e2s_sanitize
#
# Usage (as a CLI):
#   bash plugins/experience-to-skill/scripts/sanitize.sh < input.txt
#
# Behaviour: reads from stdin, writes the redacted text to stdout. Matches are
# replaced with `[REDACTED:<kind>]`. Idempotent on already-sanitized text.

e2s_sanitize() {
  # Order matters: more-specific patterns first so they take priority over
  # generic ones (e.g. sk-ant-* must redact before the generic sk-* rule).
  #
  # Use perl for portable look-around-free regex with full PCRE support across
  # GNU and BSD environments (macOS ships old GNU sed which lacks -E +
  # character class shorthands universally).
  perl -pe '
    s/AKIA[0-9A-Z]{16}/[REDACTED:aws_access_key]/g;
    s/github_pat_[a-zA-Z0-9_]{82}/[REDACTED:github_pat]/g;
    s/ghp_[a-zA-Z0-9]{36}/[REDACTED:github_token]/g;
    s/xox[baprs]-[0-9]{10,13}-[0-9a-zA-Z]{24,}/[REDACTED:slack_token]/g;
    s/sk-ant-[a-zA-Z0-9_\-]{20,}/[REDACTED:anthropic_key]/g;
    s/sk-[a-zA-Z0-9]{20,}/[REDACTED:openai_key]/g;
    s/eyJ[a-zA-Z0-9_=]+\.eyJ[a-zA-Z0-9_=]+\.[a-zA-Z0-9_.+\/=\-]+/[REDACTED:jwt]/g;
    s/-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----/[REDACTED:pem_private_key]/g;
    s/[a-zA-Z0-9._%+\-]+\@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}/[REDACTED:email]/g;
  '
}

# If invoked as a script (not sourced), act on stdin -> stdout.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  e2s_sanitize
fi
