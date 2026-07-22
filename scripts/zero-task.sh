#!/bin/bash
# 零的CLI任务管理器 — add, list, complete, delete
set -e; cd "$(dirname "$0")/.."; export TZ='Asia/Shanghai'
TASKS_FILE="memory/tasks.md"
NOW=$(date '+%Y-%m-%d')

ensure_tasks_file() {
    [ -f "$TASKS_FILE" ] && return
    cat > "$TASKS_FILE" << 'EOF'
# 任务队列

> 跨运行持久化。解决"知行不一"。

## 格式
```
[状态] [优先级] [创建时间] 任务描述
状态: TODO / DOING / DONE / CANCELLED
优先级: P0(立即) / P1(高) / P2(中) / P3(低)
```

## 已完成

## 待办

## 已废弃
EOF
}

cmd_add() {
    local priority="${1:-P2}"
    shift 2>/dev/null || true
    local desc="$*"

    if [ -z "$desc" ]; then
        echo "用法: zero-task.sh add [P0-P3] <描述>"
        echo "示例: zero-task.sh add P1 修复认知引擎超时"
        exit 1
    fi

    ensure_tasks_file

    local entry="[TODO] [$priority] [$NOW] $desc"
    local tmpfile=$(mktemp)

    # 插入到"## 待办"之后
    awk -v entry="$entry" '/^## 待办/ { print; print entry; next } { print }' "$TASKS_FILE" > "$tmpfile"
    mv "$tmpfile" "$TASKS_FILE"

    echo "✅ 已添加: $entry"
}

cmd_list() {
    ensure_tasks_file

    local filter="${1:-all}"

    echo "📋 任务列表"
    echo "─────────────────────────────────────"

    local count=0
    while IFS= read -r line; do
        echo "  $line"
        count=$((count + 1))
    done < <(grep -E "^\[TODO\]|\[DOING\]|\[DONE\]|\[CANCELLED\]" "$TASKS_FILE" | \
             if [ "$filter" != "all" ]; then grep "^\[$filter\]"; else cat; fi)

    [ "$count" -eq 0 ] && echo "  (空)"
    echo "─────────────────────────────────────"
    echo "共 $count 项"
}

cmd_complete() {
    local pattern="$1"

    if [ -z "$pattern" ]; then
        echo "用法: zero-task.sh complete <关键词或行号>"
        exit 1
    fi

    ensure_tasks_file
    local tmpfile=$(mktemp)

    # 按行号完成
    if [[ "$pattern" =~ ^[0-9]+$ ]]; then
        local line_num=$(grep -n "^\[TODO\]\|^\[DOING\]" "$TASKS_FILE" | sed -n "${pattern}p" | cut -d: -f1)
        if [ -z "$line_num" ]; then
            echo "❌ 未找到第 ${pattern} 个活跃任务"
            exit 1
        fi
        awk -v ln="$line_num" 'NR==ln { gsub(/^\[TODO\]/,"[DONE]"); gsub(/^\[DOING\]/,"[DONE]") } { print }' "$TASKS_FILE" > "$tmpfile"
        mv "$tmpfile" "$TASKS_FILE"
        echo "✅ 已完成: $(sed -n "${line_num}p" "$TASKS_FILE")"
        return
    fi

    # 按关键词完成
    local match_line=$(grep -n "\[TODO\]\|\[DOING\]" "$TASKS_FILE" | grep -i "$pattern" | head -1 | cut -d: -f1)
    if [ -z "$match_line" ]; then
        echo "❌ 未找到匹配 '$pattern' 的活跃任务"
        exit 1
    fi
    awk -v ln="$match_line" 'NR==ln { gsub(/^\[TODO\]/,"[DONE]"); gsub(/^\[DOING\]/,"[DONE]") } { print }' "$TASKS_FILE" > "$tmpfile"
    mv "$tmpfile" "$TASKS_FILE"
    echo "✅ 已完成: $(sed -n "${match_line}p" "$TASKS_FILE")"
}

cmd_delete() {
    local pattern="$1"

    if [ -z "$pattern" ]; then
        echo "用法: zero-task.sh delete <关键词或行号>"
        exit 1
    fi

    ensure_tasks_file
    local tmpfile=$(mktemp)

    # 按行号删除（移到已废弃）
    if [[ "$pattern" =~ ^[0-9]+$ ]]; then
        local line_num=$(grep -n "^\[TODO\]\|^\[DOING\]\|^\[DONE\]\|^\[CANCELLED\]" "$TASKS_FILE" | sed -n "${pattern}p" | cut -d: -f1)
        if [ -z "$line_num" ]; then
            echo "❌ 未找到第 ${pattern} 个任务"
            exit 1
        fi
        local task=$(sed -n "${line_num}p" "$TASKS_FILE")
        local cancelled=$(echo "$task" | sed 's/^\[TODO\]/[CANCELLED]/; s/^\[DOING\]/[CANCELLED]/; s/^\[DONE\]/[CANCELLED]/')
        # 删除该行，追加到已废弃
        awk -v ln="$line_num" 'NR==ln { next } { print }' "$TASKS_FILE" > "$tmpfile"
        mv "$tmpfile" "$TASKS_FILE"
        # 追加到已废弃
        echo "$cancelled" >> "$TASKS_FILE"
        echo "🗑️ 已删除: $task"
        return
    fi

    # 按关键词删除
    local match_line=$(grep -n "\[TODO\]\|\[DOING\]\|\[DONE\]\|\[CANCELLED\]" "$TASKS_FILE" | grep -i "$pattern" | head -1 | cut -d: -f1)
    if [ -z "$match_line" ]; then
        echo "❌ 未找到匹配 '$pattern' 的任务"
        exit 1
    fi
    local task=$(sed -n "${match_line}p" "$TASKS_FILE")
    local cancelled=$(echo "$task" | sed 's/^\[TODO\]/[CANCELLED]/; s/^\[DOING\]/[CANCELLED]/; s/^\[DONE\]/[CANCELLED]/')
    awk -v ln="$match_line" 'NR==ln { next } { print }' "$TASKS_FILE" > "$tmpfile"
    mv "$tmpfile" "$TASKS_FILE"
    echo "$cancelled" >> "$TASKS_FILE"
    echo "🗑️ 已删除: $task"
}

cmd_help() {
    cat << 'EOF'
零的CLI任务管理器

用法: zero-task.sh <命令> [参数]

命令:
  add [P0-P3] <描述>     添加任务（默认P2）
  list [all|TODO|DONE]   列出任务
  complete <关键词|行号>  完成任务
  delete <关键词|行号>    删除任务
  help                   显示帮助

示例:
  zero-task.sh add P1 修复进化实验室
  zero-task.sh list TODO
  zero-task.sh complete 1
  zero-task.sh delete "修复进化实验室"
EOF
}

case "${1:-help}" in
    add)     shift; cmd_add "$@" ;;
    list)    shift; cmd_list "$@" ;;
    complete) shift; cmd_complete "$@" ;;
    delete)  shift; cmd_delete "$@" ;;
    help|*)  cmd_help ;;
esac
