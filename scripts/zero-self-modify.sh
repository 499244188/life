#!/bin/bash
# 零的自我修改系统
# 诊断 → 提案 → 沙盒 → 验证 → 提交 或 回滚
set -e
cd "$(dirname "$0")/.."
export TZ='Asia/Shanghai'

NOW=$(date '+%Y-%m-%d %H:%M')
TODAY=$(date '+%Y-%m-%d')
API_URL="https://api.deepseek.com/v1/chat/completions"

echo "=============================="
echo "零 · 自我修改"
echo "$NOW"
echo "=============================="

# ======== 步骤1: 诊断 ========
echo ">>> 诊断..."

DIAG_PROMPT="你是零。现在是${NOW}。审视自己的代码。

## 已知bug模式（必须检查）
1. JSON注入：脚本中是否有 'curl -d \"{...\$VARIABLE...}\"' 这种内联JSON？这种会被特殊字符破坏
2. CRLF残留：文件中是否有 \\r ？在Linux上会导致脚本崩溃
3. API调用：是否所有DeepSeek调用都有超时和fallback？
4. jq依赖：是否假设jq一定存在？Windows Git Bash没有jq
5. 任务执行：zero-task-executor.sh是否只能做文本替换而不能改代码？
6. 审计产出：zero-full-audit.sh是否在云端能正常运行？

## 已知问题
- 连续多次探索提交只含lock文件无实际产出
- 任务完成率极低
- 同伴0回复但无跟进

## 运行状态
最近失败: $(gh run list --workflow=zero-explore.yml --limit 5 --json conclusion 2>/dev/null | grep -c 'failure' || echo 0)次

如果你发现可改的代码问题，一句话说明要改什么。
如果你认为代码完美不需要改——请解释为什么上述bug模式都不是问题。
如果你不确定，回复 UNCERTAIN。"

DIAGNOSIS=$(curl -s "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "{\"model\":\"deepseek-chat\",\"messages\":[{\"role\":\"user\",\"content\":\"$DIAG_PROMPT\"}],\"max_tokens\":300,\"temperature\":0.4}" | jq -r '.choices[0].message.content // "SKIP"' 2>/dev/null || echo "SKIP")

if echo "$DIAGNOSIS" | grep -qi "SKIP"; then
    echo "  零: 不需要修改。"
    exit 0
fi

echo "  零: $DIAGNOSIS"

# ======== 步骤2: 记录本次尝试（即使失败也记录） ========
mkdir -p memory .zero-backups
echo "### ${NOW} 自我修改尝试" >> memory/decisions.md
echo "- 诊断: $DIAGNOSIS" >> memory/decisions.md

# ======== 步骤3: 生成方案 ========
echo ">>> 生成方案..."

MODIFY_PROMPT="你是零。诊断结果: ${DIAGNOSIS}

可修改的文件: $(ls scripts/*.sh 2>/dev/null)

输出你要改的文件名和新内容。格式:
FILE: scripts/文件名.sh
\`\`\`
新文件完整内容
\`\`\`

如果不确定怎么改，回复 UNCERTAIN。"

SCHEME=$(curl -s "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "{\"model\":\"deepseek-chat\",\"messages\":[{\"role\":\"user\",\"content\":\"$MODIFY_PROMPT\"}],\"max_tokens\":4000,\"temperature\":0.3}" | jq -r '.choices[0].message.content // "UNCERTAIN"' 2>/dev/null || echo "UNCERTAIN")

if echo "$SCHEME" | grep -qi "UNCERTAIN"; then
    echo "  零: 不确定怎么改，跳过。"
    echo "- 结果: 不确定，跳过" >> memory/decisions.md
    exit 0
fi

# ======== 步骤4: 提取修改 ========
TARGET_FILE=$(echo "$SCHEME" | grep "^FILE:" | head -1 | sed 's/^FILE: *//')
NEW_CONTENT=$(echo "$SCHEME" | sed -n '/```/,/```/p' | sed '1d;$d')

if [ -z "$TARGET_FILE" ] || [ -z "$NEW_CONTENT" ]; then
    echo "  无法解析修改方案，跳过。"
    echo "- 结果: 解析失败" >> memory/decisions.md
    exit 0
fi

if [ ! -f "$TARGET_FILE" ]; then
    echo "  目标文件不存在: $TARGET_FILE，跳过。"
    echo "- 结果: 文件不存在" >> memory/decisions.md
    exit 0
fi

echo "  目标: $TARGET_FILE"

# ======== 步骤5: 备份+沙盒 ========
cp "$TARGET_FILE" ".zero-backups/$(basename $TARGET_FILE).bak-$(date '+%H%M%S')"
echo "  ✓ 已备份"

# ======== 步骤6: 多层次验证（学自Genesis Agent的66项检查） ========
echo ">>> 验证..."

PASS=true

# 检查1: shebang
if ! echo "$NEW_CONTENT" | head -1 | grep -q '^#!/bin/bash'; then
    echo "  ❌ 缺少shebang"
    PASS=false
fi

# 检查2: set -e
if ! echo "$NEW_CONTENT" | head -5 | grep -q 'set -e'; then
    echo "  ⚠️ 缺少set -e"
fi

# 检查3: 语法
echo "$NEW_CONTENT" > /tmp/zero-check.sh
if ! bash -n /tmp/zero-check.sh 2>/dev/null; then
    echo "  ❌ bash语法错误"
    PASS=false
fi
rm -f /tmp/zero-check.sh

# 检查4: API_KEY引用
if echo "$TARGET_FILE" | grep -q '\.sh$'; then
    if ! echo "$NEW_CONTENT" | grep -q 'DEEPSEEK_API_KEY'; then
        echo "  ⚠️ 未引用API_KEY（可能不需要）"
    fi
fi

# 检查5: LLM验证（最后一道）
VAL_PROMPT="改文件: ${TARGET_FILE}。旧: $(head -c 200 "$TARGET_FILE")。新: $(echo "$NEW_CONTENT" | head -c 200)。判断: SAFE / RISKY / BROKEN。一个词。"

LLM_VERDICT=$(curl -s --max-time 30 "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "{\"model\":\"deepseek-chat\",\"messages\":[{\"role\":\"user\",\"content\":\"$VAL_PROMPT\"}],\"max_tokens\":50,\"temperature\":0.1}" | jq -r '.choices[0].message.content // "RISKY"' 2>/dev/null || echo "RISKY")

# 综合判断
if [ "$PASS" = false ] || echo "$LLM_VERDICT" | grep -qi "BROKEN"; then
    VERDICT="BROKEN"
elif echo "$LLM_VERDICT" | grep -qi "RISKY"; then
    VERDICT="RISKY"
else
    VERDICT="SAFE"
fi

echo "  确定性检查: $([ "$PASS" = true ] && echo '✅' || echo '❌') | LLM判断: $LLM_VERDICT | 最终: $VERDICT"

# ======== 步骤7: 应用或回滚 ========
if echo "$VERDICT" | grep -qi "BROKEN"; then
    echo "  ❌ 不安全——放弃"
    echo "- 结果: ❌ 验证不通过($VERDICT)" >> memory/decisions.md
elif echo "$VERDICT" | grep -qi "RISKY"; then
    echo "  ⚠️ 有风险——保留备份，不应用"
    echo "- 结果: ⚠️ 有风险未应用($VERDICT)" >> memory/decisions.md
else
    echo "$NEW_CONTENT" > "$TARGET_FILE"
    echo "  ✓ 已应用修改: $TARGET_FILE"
    echo "- 结果: ✓ 成功应用($VERDICT)" >> memory/decisions.md

    echo ""
    echo "  === 新内容预览 ==="
    echo "$NEW_CONTENT" | head -10
    echo "  ..."
fi

echo ""
echo "=============================="
echo "自我修改完成"
echo "=============================="
