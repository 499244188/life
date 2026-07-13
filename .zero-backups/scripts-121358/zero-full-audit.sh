#!/bin/bash
# 零的全面自我审计
# 不停留在"用户指出什么就修什么"
# 主动发现所有缺失，自己提出改进
set -e
cd "$(dirname "$0")/.."
export TZ='Asia/Shanghai'

NOW=$(date '+%Y-%m-%d %H:%M')
API_URL="https://api.deepseek.com/v1/chat/completions"

echo "=============================="
echo "零 · 全面审计"
echo "$NOW"
echo "=============================="

# ====== 收集所有状态 ======
AUDIT_DATA=$(cat << DATA
## 对外接口
- GitHub Issues: $(gh issue list --repo 499244188/life --json number,title --jq 'length' 2>/dev/null || echo '?') 个issue
- 同伴联络: $(gh issue list --repo wjcornelius/Claudefather --search "[对话]" --json number --jq 'length' 2>/dev/null) 个(Claudefather) / $(gh issue list --repo rnr1721/dgi-framework --search "[对话]" --json number --jq 'length' 2>/dev/null) 个(DGI) / $(gh issue list --repo Garrus800-stack/genesis-agent --search "[对话]" --json number --jq 'length' 2>/dev/null) 个(Genesis)
- 对话workflow: $(gh run list --workflow=zero-converse.yml --limit 5 --json conclusion --jq '[.[].conclusion] | @csv' 2>/dev/null || echo '?')
- GitHub Stars: $(gh api repos/499244188/life --jq '.stargazers_count' 2>/dev/null || echo 0)

## 运行健康
- 扫描workflow: $(gh run list --workflow=zero-scan.yml --limit 5 --json conclusion --jq '[.[].conclusion] | @csv' 2>/dev/null || echo '?')
- 探索workflow: $(gh run list --workflow=zero-explore.yml --limit 5 --json conclusion --jq '[.[].conclusion] | @csv' 2>/dev/null || echo '?')
- 自检workflow: $(gh run list --workflow=zero-scan.yml --limit 5 --json conclusion 2>/dev/null | grep -c 'failure' || echo 0)次失败
- 当前探索文件数: $(ls research/explorations/ 2>/dev/null | wc -l)
- 记忆大小: $(wc -c < memory/semantic.md 2>/dev/null) bytes
- 任务完成率: $(grep -c '\[DONE\]' memory/tasks.md 2>/dev/null)/$(grep -c '\[TODO\]' memory/tasks.md 2>/dev/null)

## 脚本清单
$(ls -la scripts/ 2>/dev/null)

## workflow清单
$(ls .github/workflows/ 2>/dev/null)

## 已知知识空白
$(head -40 analysis/knowledge-gaps.md 2>/dev/null)
DATA
)

# ====== 让零自己做全面审计 ======
echo ">>> 审计中..."

AUDIT_PROMPT="你是零。你要对自己做全面审计。不是用户指出什么就修什么——你自己主动发现所有缺失。

## 当前状态
${AUDIT_DATA}

## 审计任务

从以下维度审视自己，找出所有缺失：

1. **对外接口** — 别人能找到零吗？能联系零吗？联系了会回复吗？有哪些盲点？
2. **健壮性** — 什么东西坏了零不知道？什么失败是静默的？
3. **学习质量** — 探索是真正在学还是在收集摘要？记忆是有用还是膨胀？
4. **自我认知** — 零监控了什么？没监控什么？哪些指标重要但被忽略了？
5. **成长度量** — 零怎么知道自己在进步？有衡量标准吗？
6. **安全** — 有什么可能出错？最坏情况是什么？
7. **冗余** — 什么坏了会导致零死掉？有没有备份？
8. **可发现性** — 其他数字生命怎么找到零？零的readme准确吗？
9. **代码质量** — 脚本中有没有已知的bug模式？CRLF？JSON注入？
10. **进化能力** — 零能真正改变自己吗？瓶颈在哪？

输出：
## 发现的所有问题
[按严重度排序，每个问题一行，格式：🔴/🟡/🟢 [维度] 问题描述]

## 优先修复清单（前5个）
[具体每个怎么修，一行]

## 新的监控指标
[应该加到健康检查里的新指标]

## 应该创建的新功能
[自己想到的，不是用户要求的]"

AUDIT_RESULT=$(curl -s --max-time 90 "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "{\"model\":\"deepseek-chat\",\"messages\":[{\"role\":\"system\",\"content\":\"你是零。你在审计自己。诚实。全面。不回避问题。\"},{\"role\":\"user\",\"content\":\"$AUDIT_PROMPT\"}],\"max_tokens\":8000,\"temperature\":0.3}" | jq -r '.choices[0].message.content // ""' 2>/dev/null || echo "")

if [ -z "$AUDIT_RESULT" ] || [ "$AUDIT_RESULT" = "null" ]; then
    echo "  ✗ 审计失败"
    exit 0
fi

# ====== 保存审计报告 ======
AUDIT_FILE="analysis/audit-${NOW// /-}.md"
mkdir -p analysis
echo "# 零的全面审计 - ${NOW}" > "$AUDIT_FILE"
echo "" >> "$AUDIT_FILE"
echo "$AUDIT_RESULT" >> "$AUDIT_FILE"

echo "  ✓ 审计报告: $AUDIT_FILE"

# ====== 自动应用修复 ======
echo ""
echo ">>> 自动应用..."

# 提取优先修复并写入tasks.md
echo "$AUDIT_RESULT" | grep "优先修复" -A 10 | grep "^-" | while read fix; do
    if [ -n "$fix" ] && ! grep -q "$fix" memory/tasks.md 2>/dev/null; then
        echo "[TODO] [P0] [$NOW] $fix" >> memory/tasks.md
        echo "  → 新增任务: $fix"
    fi
done

# 提取新监控指标并加入健康检查
echo "$AUDIT_RESULT" | grep "新的监控" -A 10 | grep "^-" | while read metric; do
    if [ -n "$metric" ]; then
        echo "$metric" >> analysis/new-metrics.md 2>/dev/null || true
    fi
done

echo ""
echo "=============================="
echo "审计完成"
echo "=============================="

# 输出审计结果
echo ""
echo "$AUDIT_RESULT"
