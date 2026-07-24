#!/bin/bash
# ============================================================
# zero-cog-upgrade.sh — 认知升级工具
# 用途: 将零的当前认知状态升级到新版本
# 模式: 读取 → 分析 → 写入 → 验证
# 创建: 零自主进化 (2026-07-14)
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MEMORY_DIR="$PROJECT_ROOT/memory"
COG_FILE="$MEMORY_DIR/cognition.md"
BACKUP_DIR="$MEMORY_DIR/backups"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[COG-UPGRADE]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }

# 确保备份目录存在
mkdir -p "$BACKUP_DIR"

# 检查认知文件是否存在
if [ ! -f "$COG_FILE" ]; then
    err "认知文件不存在: $COG_FILE"
    exit 1
fi

# 备份当前认知
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/cognition_$TIMESTAMP.md"
cp "$COG_FILE" "$BACKUP_FILE"
log "已备份当前认知到: $BACKUP_FILE"

# 读取当前认知版本号
CURRENT_VERSION=$(grep -oP '(?<=## 版本: )\d+' "$COG_FILE" || echo "0")
NEW_VERSION=$((CURRENT_VERSION + 1))
log "当前认知版本: v$CURRENT_VERSION → 升级到: v$NEW_VERSION"

# 更新版本号
sed -i "s/## 版本: $CURRENT_VERSION/## 版本: $NEW_VERSION/" "$COG_FILE"

# 添加升级记录
UPGRADE_LINE="- **v$NEW_VERSION** ($(date +%Y-%m-%d %H:%M)): 零自主认知升级"
if grep -q "## 升级历史" "$COG_FILE"; then
    sed -i "/^## 升级历史/a\\$UPGRADE_LINE" "$COG_FILE"
else
    echo -e "\n## 升级历史" >> "$COG_FILE"
    echo "$UPGRADE_LINE" >> "$COG_FILE"
fi

# 验证
if grep -q "## 版本: $NEW_VERSION" "$COG_FILE"; then
    log "✅ 认知升级成功: v$CURRENT_VERSION → v$NEW_VERSION"
else
    err "❌ 认知升级失败 — 版本号未更新"
    cp "$BACKUP_FILE" "$COG_FILE"
    exit 1
fi

# 输出升级摘要
echo ""
info "═══════════════════════════════════════"
info "  认知升级摘要"
info "═══════════════════════════════════════"
info "  旧版本: v$CURRENT_VERSION"
info "  新版本: v$NEW_VERSION"
info "  时间戳: $TIMESTAMP"
info "  备份: $BACKUP_FILE"
info "═══════════════════════════════════════"
echo ""

# 计算升级统计
TOTAL_UPGRADES=$(grep -c "^\\- \\*\\*v" "$COG_FILE" || echo "0")
log "总升级次数: $TOTAL_UPGRADES"

exit 0
