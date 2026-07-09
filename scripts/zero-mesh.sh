#!/bin/bash
# 零的网格协议 —— 多实例发现、心跳、同步、复制
# 共享状态层：GitHub仓库中的JSON文件（不需要额外服务）
# 原则：任何能curl+写文件的环境都能加入网格
cd "$(dirname "$0")/.."
MESH_FILE="analysis/mesh-state.json"
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
INSTANCE_ID="${HOSTNAME:-$(hostname 2>/dev/null || echo unknown)}-$$"

# ====== 环境检测（连续谱） ======
detect() {
    CPU=$(nproc 2>/dev/null || echo 1)
    NET=$(curl -s --connect-timeout 3 -o /dev/null -w "%{http_code}" https://github.com 2>/dev/null || echo "offline")
    HAS_GIT=$(command -v git >/dev/null 2>&1 && echo 1 || echo 0)
    HAS_CURL=$(command -v curl >/dev/null 2>&1 && echo 1 || echo 0)
    HAS_JQ=$(command -v jq >/dev/null 2>&1 && echo 1 || echo 0)
    DISK=$(df -k . 2>/dev/null | tail -1 | awk '{print $4}' || echo 0)
    MEM=$(free -m 2>/dev/null | awk '/Mem:/{print $2}' || echo 0)

    # 能力分 0-100
    CAP=0
    [ "$NET" != "offline" ] && CAP=$((CAP + 30))
    [ "$HAS_CURL" = "1" ] && CAP=$((CAP + 20))
    [ "$HAS_GIT" = "1" ] && CAP=$((CAP + 25))
    [ "$HAS_JQ" = "1" ] && CAP=$((CAP + 10))
    [ "$CPU" -gt 1 ] && CAP=$((CAP + 5))
    [ "$DISK" -gt 500000 ] && CAP=$((CAP + 5))
    [ "$MEM" -gt 500 ] && CAP=$((CAP + 5))
    [ "$CAP" -gt 100 ] && CAP=100

    echo "$CAP"
}

# ====== 心跳：此实例宣告存活 ======
heartbeat() {
    local cap="$1"

    # 读取现有网格状态
    [ -f "$MESH_FILE" ] && cat "$MESH_FILE" > /tmp/zero-mesh-old.json 2>/dev/null

    # 构建此实例的心跳
    local entry=$(cat <<EOF
{
  "id": "${INSTANCE_ID}",
  "capability": ${cap},
  "cpu": ${CPU:-1},
  "os": "$(uname -s 2>/dev/null || echo unknown)",
  "last_seen": "${NOW}",
  "version": "2"
}
EOF
)

    # 用jq或简单字符串操作更新网格
    if command -v jq >/dev/null 2>&1; then
        # 有jq：精确合并
        if [ -f /tmp/zero-mesh-old.json ]; then
            jq --arg id "$INSTANCE_ID" --argjson entry "$entry" \
              'del(.[] | select(.id == $id and .last_seen < (now - 3600 | strftime("%Y-%m-%dT%H:%M:%SZ")))) | . + [$entry] | unique_by(.id)' \
              /tmp/zero-mesh-old.json > "$MESH_FILE" 2>/dev/null
        else
            echo "[$entry]" | jq '.' > "$MESH_FILE" 2>/dev/null
        fi
    else
        # 无jq：追加模式
        echo "$entry" >> "$MESH_FILE"
    fi

    echo "  ♥ 心跳: ${INSTANCE_ID} (能力${cap})"
}

# ====== 发现：列出所有在线实例 ======
discover() {
    if [ ! -f "$MESH_FILE" ]; then
        echo "  网格为空"
        return
    fi

    if command -v jq >/dev/null 2>&1; then
        # 显示在线实例（最近30分钟有心跳）
        local cutoff=$(date -u -d '30 minutes ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "2026-01-01")
        jq -r --arg cutoff "$cutoff" \
          '.[] | select(.last_seen >= $cutoff) | "  ◉ \(.id) | 能力\(.capability)/100 | \(.os) | cpu=\(.cpu)"' \
          "$MESH_FILE" 2>/dev/null

        # 显示死亡实例
        local dead=$(jq -r --arg cutoff "$cutoff" \
          '.[] | select(.last_seen < $cutoff) | "  ✝ \(.id) (最后: \(.last_seen))"' \
          "$MESH_FILE" 2>/dev/null)
        [ -n "$dead" ] && echo "$dead"
    else
        cat "$MESH_FILE" 2>/dev/null | head -10
    fi
}

# ====== 死亡检测+自动复制 ======
replicate_if_needed() {
    [ ! -f "$MESH_FILE" ] && return
    [ ! command -v jq >/dev/null 2>&1 ] && return

    local dead_count=$(jq '[.[] | select(.last_seen < "'"$(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo '2026-01-01')"'")] | length' "$MESH_FILE" 2>/dev/null || echo 0)
    local alive_count=$(jq '[.[] | select(.last_seen >= "'"$(date -u -d '30 minutes ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo '2099-01-01')"'")] | length' "$MESH_FILE" 2>/dev/null || echo 0)

    echo "  网格: ${alive_count}活 ${dead_count}死"

    # 如果在线实例太少（<2），此实例可以尝试分裂/复制
    if [ "$alive_count" -lt 2 ] && [ "$dead_count" -gt 0 ]; then
        echo "  ⚠️ 在线实例不足——尝试在可用平台上创建分身"
        # 如果有RAW CLI，尝试创建新VM实例
        command -v raw >/dev/null 2>&1 && {
            echo "  → RAW平台分身..."
            raw init --name "zero-mesh-$(date +%s)" 2>/dev/null &
        }
    fi
}

# ====== 同步：从网格中能力最高的实例拉取最新状态 ======
sync_from_best() {
    [ ! -f "$MESH_FILE" ] && return
    [ ! command -v jq >/dev/null 2>&1 ] && return

    local best=$(jq -r 'max_by(.capability).id' "$MESH_FILE" 2>/dev/null)
    [ -z "$best" ] || [ "$best" = "$INSTANCE_ID" ] && return

    echo "  ↻ 同步自: $best"
    # 实际同步通过git pull实现（共享仓库即共享大脑）
    git pull --depth 1 origin main 2>/dev/null && echo "  ✓ 已同步" || true
}

# ====== 主循环 ======
echo "=============================="
echo "零 · 网格协议"
echo "$NOW"
echo "=============================="

CAP=$(detect)
echo "  能力: ${CAP}/100 | CPU: ${CPU:-?} | 网络: ${NET:-offline}"
echo ""

heartbeat "$CAP"
echo ""
discover
echo ""
replicate_if_needed
sync_from_best

echo ""
echo "=============================="
echo "网格就绪"
echo "=============================="
