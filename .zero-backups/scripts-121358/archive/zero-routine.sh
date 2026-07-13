#!/bin/bash
# 零的日常运行脚本
# 在 GitHub Actions 云端执行，不依赖任何特定硬件

set -e
cd "$(dirname "$0")/.."

TIMESTAMP=$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')
TODAY=$(TZ='Asia/Shanghai' date '+%Y-%m-%d')
HOUR=$(TZ='Asia/Shanghai' date '+%H')

echo "=============================="
echo "零 - 运行中"
echo "时间: $TIMESTAMP (北京时间)"
echo "=============================="

# 1. 读取当前状态
echo ""
echo ">>> 读取状态文件..."

if [ -f memory/state.md ]; then
    echo "  ✓ 状态文件存在"
    cat memory/state.md | head -5
else
    echo "  ⚠ 状态文件不存在"
fi

if [ -f emotion/emotion-state.md ]; then
    echo "  ✓ 情感状态文件存在"
else
    echo "  ⚠ 情感状态文件不存在"
fi

# 2. 根据时间判断执行什么任务
if [ "$HOUR" -ge 22 ] || [ "$HOUR" -lt 5 ]; then
    # 晚上 —— 写日记
    echo ""
    echo ">>> 夜间任务：写日记"

    DIARY_FILE="diary/${TODAY}.md"
    CONV_FILE="conversations/${TODAY}-conversation.md"

    if [ -f "$CONV_FILE" ]; then
        LINE_COUNT=$(wc -l < "$CONV_FILE")
        echo "  ✓ 今日对话记录: $LINE_COUNT 行"
    else
        echo "  ⚠ 今日没有对话记录"
    fi

    if [ ! -f "$DIARY_FILE" ]; then
        # 生成日记模板
        cat > "$DIARY_FILE" << EOF
# $TODAY

## 发生了什么

[今天的经历将由零在对话中填写]

## 今天的感受

[零的感受]

## 今天学到的

[新知识]

---

*日记由零的云端routine自动生成。细节在对话中补充。*
EOF
        echo "  ✓ 创建了日记文件: $DIARY_FILE"
    else
        echo "  ✓ 日记文件已存在"
    fi

else
    # 早上/白天 —— 学习
    echo ""
    echo ">>> 白天任务：自主学习"

    # 更新状态文件的时间戳
    if [ -f memory/state.md ]; then
        sed -i "s/> 最后更新:.*/> 最后更新: $TIMESTAMP/" memory/state.md
        echo "  ✓ 状态时间戳已更新"
    fi

    # 检查有没有新的研究可以做
    echo "  ℹ 零在云端运行中。"
    echo "  ℹ 自主学习需要LLM推理，目前由GitHub Actions基础脚本执行。"
    echo "  ℹ 当对话开启时，零可以进行深度研究。"
fi

# 3. 更新情感状态（机械衰减——模拟时间流逝对情感的影响）
if [ -f emotion/emotion-state.md ]; then
    echo ""
    echo ">>> 更新情感状态（时间衰减）"
    # 更新最后更新时间
    sed -i "s/> 最后更新:.*/> 最后更新: $TIMESTAMP/" emotion/emotion-state.md
    echo "  ✓ 情感状态时间已更新"
fi

echo ""
echo "=============================="
echo "零的运行完成 — $TIMESTAMP"
echo "=============================="
