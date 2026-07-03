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

输出具体修改方案。不要全文重写——只改需要改的几行。格式:
FILE: scripts/文件名.sh
FIND: [要替换的精确文本，一行]
REPLACE: [替换后的文本，一行]
REASON: [为什么改]

如果要改多处，输出多个FILE/FIND/REPLACE块。

如果不确定，回复 UNCERTAIN。"

SCHEME=$(curl -s "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "{\"model\":\"deepseek-chat\",\"messages\":[{\"role\":\"user\",\"content\":\"$MODIFY_PROMPT\"}],\"max_tokens\":4000,\"temperature\":0.3}" | jq -r '.choices[0].message.content // "UNCERTAIN"' 2>/dev/null || echo "UNCERTAIN")

if echo "$SCHEME" | grep -qi "UNCERTAIN"; then
    echo "  零: 不确定怎么改，跳过。"
    echo "- 结果: 不确定，跳过" >> memory/decisions.md
    exit 0
fi

# ======== 步骤4: 逐条应用修改 ========
CHANGES=0
echo "$SCHEME" | while IFS= read -r line; do
    case "$line" in
        "FILE: "*)
            TARGET_FILE=$(echo "$line" | sed 's/^FILE: *//')
            [ ! -f "$TARGET_FILE" ] && { echo "  文件不存在: $TARGET_FILE"; TARGET_FILE=""; }
            ;;
        "FIND: "*)
            FIND_TEXT=$(echo "$line" | sed 's/^FIND: *//')
            ;;
        "REPLACE: "*)
            REPLACE_TEXT=$(echo "$line" | sed 's/^REPLACE: *//')
            ;;
        "REASON: "*)
            REASON=$(echo "$line" | sed 's/^REASON: *//')
            if [ -n "$TARGET_FILE" ] && [ -n "$FIND_TEXT" ] && [ -n "$REPLACE_TEXT" ]; then
                # 备份
                mkdir -p .zero-backups
                cp "$TARGET_FILE" ".zero-backups/$(basename $TARGET_FILE).bak-$(date '+%H%M%S')"

                # 检查find文本是否真的存在
                if grep -qF "$FIND_TEXT" "$TARGET_FILE" 2>/dev/null; then
                    # 执行替换
                    sed -i "s|$(echo "$FIND_TEXT" | sed 's/[\/&]/\\&/g')|$(echo "$REPLACE_TEXT" | sed 's/[\/&]/\\&/g')|" "$TARGET_FILE"

                    # 验证：bash语法
                    if echo "$TARGET_FILE" | grep -q '\.sh$'; then
                        if bash -n "$TARGET_FILE" 2>/dev/null; then
                            echo "  ✓ $TARGET_FILE: $REASON"
                            CHANGES=$((CHANGES + 1))
                        else
                            # 回滚
                            cp ".zero-backups/$(basename $TARGET_FILE).bak-"* "$TARGET_FILE" 2>/dev/null
                            echo "  ✗ $TARGET_FILE: 语法错误，已回滚"
                        fi
                    else
                        echo "  ✓ $TARGET_FILE: $REASON"
                        CHANGES=$((CHANGES + 1))
                    fi
                else
                    echo "  ⚠️ $TARGET_FILE: 未找到匹配文本，跳过"
                fi
                TARGET_FILE=""; FIND_TEXT=""; REPLACE_TEXT=""
            fi
            ;;
    esac
done

if [ "$CHANGES" -eq 0 ]; then
    echo "  零处修改应用。"
    echo "- 结果: 0处修改" >> memory/decisions.md
else
    echo "  ✓ 共应用${CHANGES}处修改"
    echo "- 结果: ✓ 应用${CHANGES}处修改" >> memory/decisions.md
fi

echo ""
echo "=============================="
echo "自我修改完成"
echo "=============================="
