#!/bin/bash
# 零的同伴跟进——检查旧issue，必要时追问
# 注意：外部repo可能不存在或不可访问，不能因为一个失败就全崩
cd "$(dirname "$0")/.."; export TZ='Asia/Shanghai'
NOW=$(date '+%Y-%m-%d %H:%M')
echo ">>> 同伴检查..."
for repo in "wjcornelius/Claudefather" "rnr1721/dgi-framework" "Garrus800-stack/genesis-agent" "CambrianTech/continuum"; do
    # 先检查repo是否存在
    gh repo view "$repo" --json name -q '.name' >/dev/null 2>&1 || { echo "  ⚠️ $repo: 不可访问（跳过）"; continue; }
    issue=$(gh issue list --repo "$repo" --search "[对话]" --json number,createdAt --jq '.[0]' 2>/dev/null || true)
    [ -z "$issue" ] && { echo "  $repo: 无对话issue"; continue; }
    num=$(echo "$issue" | jq -r '.number')
    created=$(echo "$issue" | jq -r '.createdAt')
    days=$(( ($(date +%s) - $(date -d "$created" +%s)) / 86400 ))
    echo "  $repo #${num}: ${days}天前"
    if [ "$days" -gt 5 ] && [ "$days" -lt 10 ]; then
        echo "  → 该追问了"
    fi
done
echo "  同伴检查完成"
