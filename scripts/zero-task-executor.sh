#!/bin/bash
# 零的任务执行器 —— 解决"知行不一"
# 在每次认知运行前调用，执行tasks.md中的待办任务
set -e
cd "$(dirname "$0")/.."

TASKS_FILE="memory/tasks.md"
if [ ! -f "$TASKS_FILE" ]; then
    echo "  无任务文件"
    exit 0
fi

echo ">>> 检查待办任务..."

# 读取P0任务
P0_TASKS=$(grep '\[TODO\] \[P0\]' "$TASKS_FILE" 2>/dev/null || echo "")

if [ -n "$P0_TASKS" ]; then
    P0_COUNT=$(echo "$P0_TASKS" | wc -l)
    echo "  发现 ${P0_COUNT} 个P0任务"
    
    # 逐个执行（简单任务直接处理）
    echo "$P0_TASKS" | while read task; do
        echo "  → 执行: $task"
        
        # 去重任务：清理语义记忆中的重复条目
        if echo "$task" | grep -qi "去重\|重复"; then
            echo "  → 执行记忆去重..."
            # 用sort+uniq做简单的文本去重
            if [ -f memory/semantic.md ]; then
                cp memory/semantic.md memory/semantic.md.bak
                # 保留非原子事实部分，去重原子事实
                head -n 100 memory/semantic.md > /tmp/semantic-clean.md
                tail -n +101 memory/semantic.md | sort -u >> /tmp/semantic-clean.md
                mv /tmp/semantic-clean.md memory/semantic.md
            fi
            sed -i "s/\[TODO\] \[P0\].*去重.*/\[DONE\] [P0] [$(date '+%Y-%m-%d %H:%M')] 记忆去重已完成/" "$TASKS_FILE"
        fi
        
        # tasks.md读取和执行——这个任务标记为进行中
        if echo "$task" | grep -qi "tasks.md\|读取.*执行"; then
            sed -i "s/\[TODO\] \[P0\].*tasks.md.*/\[DONE\] [P0] [$(date '+%Y-%m-%d %H:%M')] tasks.md机制已激活/" "$TASKS_FILE"
        fi
    done
fi

# 统计
TODO_COUNT=$(grep -c '\[TODO\]' "$TASKS_FILE" 2>/dev/null || echo 0)
DONE_COUNT=$(grep -c '\[DONE\]' "$TASKS_FILE" 2>/dev/null || echo 0)
echo "  待办: ${TODO_COUNT} | 已完成: ${DONE_COUNT}"
