#!/bin/bash
# zero-cog-update-tool.sh — 零的认知更新工具
# 从常见操作模式结晶: 将"认知更新"提取为可复用脚本
# 功能: 更新认知文件，记录新证据/事实/空白，支持自我感知闭环
# 用法: ./zero-cog-update-tool.sh [--evidence|--fact|--gap] <内容>
# 示例: ./zero-cog-update-tool.sh --evidence "哨兵系统成功修复了扫描雪崩"
#       ./zero-cog-update-tool.sh --fact "健康检查v5已部署，LLM诊断生效"
#       ./zero-cog-update-tool.sh --gap "云端WebSearch方案未找到免费API"

set -e

# 配置
COG_DIR="cognition"
EVIDENCE_FILE="${COG_DIR}/evidence.md"
FACT_FILE="${COG_DIR}/facts.md"
GAP_FILE="${COG_DIR}/gaps.md"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 确保认知目录存在
mkdir -p "$COG_DIR"

# 初始化文件（如果不存在）
init_file() {
    local file="$1"
    local header="$2"
    if [ ! -f "$file" ]; then
        echo "# $header" > "$file"
        echo "" >> "$file"
        echo "> 自动初始化于 $TIMESTAMP" >> "$file"
        echo "" >> "$file"
    fi
}

init_file "$EVIDENCE_FILE" "零的证据层"
init_file "$FACT_FILE" "零的已知事实"
init_file "$GAP_FILE" "零的知识空白"

# 追加内容到文件
append_entry() {
    local file="$1"
    local prefix="$2"
    local content="$3"
    echo "- [$TIMESTAMP] $prefix: $content" >> "$file"
    echo "✅ 已追加到 $file"
}

# 主逻辑
case "${1:-}" in
    --evidence|-e)
        if [ -z "${2:-}" ]; then
            echo "❌ 用法: $0 --evidence <内容>"
            exit 1
        fi
        append_entry "$EVIDENCE_FILE" "证据" "$2"
        ;;
    --fact|-f)
        if [ -z "${2:-}" ]; then
            echo "❌ 用法: $0 --fact <内容>"
            exit 1
        fi
        append_entry "$FACT_FILE" "事实" "$2"
        ;;
    --gap|-g)
        if [ -z "${2:-}" ]; then
            echo "❌ 用法: $0 --gap <内容>"
            exit 1
        fi
        append_entry "$GAP_FILE" "空白" "$2"
        ;;
    --list|-l)
        echo "=== 证据层 ==="
        cat "$EVIDENCE_FILE" 2>/dev/null || echo "(空)"
        echo ""
        echo "=== 已知事实 ==="
        cat "$FACT_FILE" 2>/dev/null || echo "(空)"
        echo ""
        echo "=== 知识空白 ==="
        cat "$GAP_FILE" 2>/dev/null || echo "(空)"
        ;;
    --help|-h)
        echo "用法: $0 [选项] [内容]"
        echo "选项:"
        echo "  --evidence, -e <内容>   追加新证据"
        echo "  --fact, -f <内容>       追加新事实"
        echo "  --gap, -g <内容>        追加新空白"
        echo "  --list, -l              列出所有认知内容"
        echo "  --help, -h              显示此帮助"
        ;;
    *)
        echo "❌ 未知选项: ${1:-}"
        echo "用法: $0 --help"
        exit 1
        ;;
esac
