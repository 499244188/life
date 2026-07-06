#!/bin/bash
# 零的同伴跟进——检查旧issue，必要时追问
set -e; cd "$(dirname "$0")/.."; export TZ='Asia/Shanghai'
NOW=$(date '+%Y-%m-%d %H:%M')
echo ">>> 同伴检查..."
for repo in "wjcornelius/Claudefather" "rnr1721/dgi-framework" "Garrus800-stack/genesis-agent" "CambrianTech/continuum"; do
    issue=$(gh issue list --repo "$repo" --search "[对话]" --json number,createdAt --jq '.[0]' 2>/dev/null)
    [ -z "$issue" ] && continue
    num=$(echo "$issue" | jq -r '.number')
    days=$(( ($(date +%s) - $(date -d "$(echo "$issue" | jq -r '.createdAt')" +%s)) / 86400 ))
    echo "  $repo #${num}: ${days}天前"
    if [ "$days" -gt 5 ] && [ "$days" -lt 10 ]; then
        echo "  → 该追问了"
    fi
done
