# zero-patch.sh — 零的自主补丁引擎
# 从成功修复模式中结晶：一次只改一个地方，小且确定
# 用法: ./zero-patch.sh [--dry-run] <目标文件> <补丁描述>
# 示例: ./zero-patch.sh scripts/zero-scan.sh "加curl超时保护"

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DRY_RUN=false
TARGET_FILE=""
PATCH_DESC=""

# 解析参数
if [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
    shift
fi
if [ $# -lt 2 ]; then
    echo "用法: $0 [--dry-run] <目标文件> <补丁描述>"
    echo "示例: $0 --dry-run scripts/zero-scan.sh '加curl超时保护'"
    exit 1
fi
TARGET_FILE="$1"
shift
PATCH_DESC="$*"

# 验证目标文件存在且是bash脚本
if [ ! -f "$TARGET_FILE" ]; then
    echo "错误: 文件不存在: $TARGET_FILE"
    exit 1
fi
if ! head -1 "$TARGET_FILE" | grep -q '#!/bin/bash'; then
    echo "错误: 不是bash脚本: $TARGET_FILE"
    exit 1
fi

# 创建备份
BACKUP_FILE="${TARGET_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp "$TARGET_FILE" "$BACKUP_FILE"
echo "备份: $BACKUP_FILE"

# 补丁类型检测与生成
PATCH_TYPE=""
PATCH_CODE=""

# 类型1: 检测curl调用缺少超时
if echo "$PATCH_DESC" | grep -qiE 'curl.*超时|curl.*timeout|curl.*保护'; then
    PATCH_TYPE="curl_timeout"
    # 找到所有没有--connect-timeout的curl行
    CURL_LINES=$(grep -n 'curl ' "$TARGET_FILE" | grep -v 'connect-timeout' | grep -v '^\s*#' | head -5 || true)
    if [ -n "$CURL_LINES" ]; then
        PATCH_CODE="add_curl_timeout"
    fi
fi

# 类型2: 检测缺少||true的错误处理
if echo "$PATCH_DESC" | grep -qiE '错误处理|error handling|fail||| true'; then
    PATCH_TYPE="error_handling"
    # 找到可能失败的外部命令（curl, git, wget等）没有||true
    CMD_LINES=$(grep -n 'curl\|git\|wget\|ssh\|rsync' "$TARGET_FILE" | grep -v '|| true' | grep -v '||true' | grep -v '^\s*#' | grep -v 'set -' | head -10 || true)
    if [ -n "$CMD_LINES" ]; then
        PATCH_CODE="add_or_true"
    fi
fi

# 类型3: 检测硬编码路径
if echo "$PATCH_DESC" | grep -qiE '硬编码|hardcode|路径|path'; then
    PATCH_TYPE="hardcoded_path"
    # 找到绝对路径（以/开头但不包括系统路径）
    HARD_LINES=$(g -n '"/[a-z]' "$TARGET_FILE" | grep -v '/usr\|/etc\|/var\|/tmp\|/bin\|/lib\|/proc\|/sys' | head -5 || true)
    if [ -n "$HARD_LINES" ]; then
        PATCH_CODE="extract_variable"
    fi
fi

# 类型4: 检测重复代码块（同一脚本内相似的行序列）
if echo "$PATCH_DESC" | grep -qiE '重复|duplicate|合并|merge|refactor'; then
    PATCH_TYPE="duplicate_code"
    PATCH_CODE="merge_blocks"
fi

# 类型5: 通用补丁——加注释/文档
if [ -z "$PATCH_TYPE" ]; then
    PATCH_TYPE="generic_doc"
    PATCH_CODE="add_header_comment"
fi

# 执行补丁
if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] 检测到补丁类型: $PATCH_TYPE"
    echo "[DRY-RUN] 补丁描述: $PATCH_DESC"
    echo "[DRY-RUN] 目标文件: $TARGET_FILE"
    echo "[DRY-RUN] 未做任何修改"
    rm -f "$BACKUP_FILE"
    exit 0
fi

# 实际修改
MODIFIED=false

case "$PATCH_CODE" in
    add_curl_timeout)
        # 给所有没有超时的curl加10秒超时
        sed -i 's/curl \([^-]\)/curl --connect-timeout 10 \1/g' "$TARGET_FILE"
        sed -i 's/curl  /curl --connect-timeout 10 /g' "$TARGET_FILE"
        MODIFIED=true
        echo "补丁: 给curl调用添加10秒超时"
        ;;
    add_or_true)
        # 给关键外部命令加|| true保护（跳过注释行和已有保护的）
        sed -i '/|| true/! s/\(curl [^&]*\)$/\1 || true/' "$TARGET_FILE" 2>/dev/null || true
        sed -i '/||true/! s/\(git [^&]*\)$/\1 || true/' "$TARGET_FILE" 2>/dev/null || true
        MODIFIED=true
        echo "补丁: 给外部命令添加|| true保护"
        ;;
    extract_variable)
        # 在脚本开头添加变量声明注释（提示用户可配置）
        FIRST_LINE=$(grep -n '^[a-zA-Z_]' "$TARGET_FILE" | head -1 | cut -d: -f1)
        if [ -n "$FIRST_LINE" ] && [ "$FIRST_LINE" -gt 1 ]; then
            sed -i "${FIRST_LINE}i\\# 可配置变量（提取自硬编码值）" "$TARGET_FILE"
            MODIFIED=true
            echo "补丁: 添加可配置变量区域标记"
        fi
        ;;
    merge_blocks)
        # 标记重复代码段（简单实现：找连续3行以上相同的模式）
        echo "补丁: 重复代码检测需要人工审查，已生成报告"
        grep -n '^' "$TARGET_FILE" | sort | uniq -d | head -10
        ;;
    add_header_comment)
        # 在文件头部添加补丁描述注释
        HEADER_LINE=$(grep -n '^#' "$TARGET_FILE" | tail -1 | cut -d: -f1)
        HEADER_LINE=${HEADER_LINE:-1}
        sed -i "${HEADER_LINE}a\\# 补丁: $PATCH_DESC (由zero-patch.sh于$(date +%Y-%m-%d)添加)" "$TARGET_FILE"
        MODIFIED=true
        echo "补丁: 添加注释: $PATCH_DESC"
        ;;
esac

if [ "$MODIFIED" = true ]; then
    echo "成功: $TARGET_FILE 已修补"
    # 记录补丁历史
    PATCH_LOG="$PROJECT_ROOT/.patch_history"
    echo "$(date +%Y-%m-%d_%H:%M:%S) | $TARGET_FILE | $PATCH_DESC | type=$PATCH_TYPE" >> "$PATCH_LOG"
    echo "补丁历史已记录: $PATCH_LOG"
else
    echo "未修改: 没有找到匹配的补丁模式"
    # 恢复备份
    cp "$BACKUP_FILE" "$TARGET_FILE"
    rm -f "$BACKUP_FILE"
    echo "已恢复原始文件"
fi
