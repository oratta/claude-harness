#!/bin/bash
# list_skills.sh - ローカルにインストールされているスキルの一覧を取得

SKILL_PATHS=(
    "/mnt/skills/public"
    "/mnt/skills/user"
    "/mnt/skills/private"
    "$HOME/.claude/skills"
    "./.claude/skills"
)

echo "=== Local Skill Inventory ==="
echo ""

for base_path in "${SKILL_PATHS[@]}"; do
    if [ -d "$base_path" ]; then
        echo "📁 $base_path"
        
        # Find all SKILL.md files
        find "$base_path" -name "SKILL.md" 2>/dev/null | while read skill_file; do
            skill_dir=$(dirname "$skill_file")
            skill_name=$(basename "$skill_dir")
            
            # Extract description from frontmatter
            description=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep "^description:" | sed 's/description: *//')
            
            if [ -n "$description" ]; then
                # Truncate description to 60 chars
                desc_short=$(echo "$description" | cut -c1-60)
                if [ ${#description} -gt 60 ]; then
                    desc_short="${desc_short}..."
                fi
                echo "  ├─ $skill_name"
                echo "  │  └─ $desc_short"
            else
                echo "  ├─ $skill_name"
            fi
        done
        echo ""
    fi
done

echo "=== Summary ==="
total=$(find "${SKILL_PATHS[@]}" -name "SKILL.md" 2>/dev/null | wc -l)
echo "Total skills found: $total"
