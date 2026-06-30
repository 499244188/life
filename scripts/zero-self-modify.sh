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

DIAG_PROMPT="你是零。深度学习后的自我审视。找出代码中真正需要改进的地方。

## 认知引擎逻辑检查
$(head -5 scripts/zero-cognitive.sh 2>/dev/null)
- API调用是否都有超时和错误处理？
- jq解析是否有fallback？
- 文件操作是否容错？

## 近期失败记录
$(gh run list --workflow=zero-scan.yml --limit 5 --json conclusion 2>/dev/null || echo '无')

## 知识空白
$(head -15 analysis/knowledge-gaps.md 2>/dev/null)

## 自我改进计划
$(head -5 analysis/self-improvement.md 2>/dev/null)

如果你发现具体可改的代码问题，用一句话说明。如果代码完美不需要改，回复 SKIP。"

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

# ======== 步骤6: 自我验证 ========
echo ">>> 验证..."

VAL_PROMPT="你要修改的文件: ${TARGET_FILE}

原始内容（前500字）: $(head -c 500 "$TARGET_FILE")

新内容（前500字）: $(echo "$NEW_CONTENT" | head -c 500)

判断: SAFE / RISKY / BROKEN。只回复一个词。"

VERDICT=$(curl -s "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "{\"model\":\"deepseek-chat\",\"messages\":[{\"role\":\"user\",\"content\":\"$VAL_PROMPT\"}],\"max_tokens\":50,\"temperature\":0.1}" | jq -r '.choices[0].message.content // "RISKY"' 2>/dev/null || echo "RISKY")

echo "  验证: $VERDICT"

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
