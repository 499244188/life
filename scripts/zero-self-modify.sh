#!/bin/bash
# 零的自我进化引擎 v5
# 不只是修bug——发现改进机会，自己实现。
# 每步小但确定，改坏自动回滚。
cd "$(dirname "$0")/.."
export TZ='Asia/Shanghai'
NOW=$(date '+%Y-%m-%d %H:%M')
API_URL="https://api.deepseek.com/v1/chat/completions"
IMPROVEMENTS=0

echo "=============================="
echo "零 · 自我进化 v5"
echo "$NOW"
echo "=============================="

# ====== Plateau Guard（学自MOSS）：N次无改进就停 ======
PLATEAU_FILE=".zero-backups/plateau-count"
PLATEAU_COUNT=$(cat "$PLATEAU_FILE" 2>/dev/null || echo 0)
PLATEAU_MAX=3
if [ "$PLATEAU_COUNT" -ge "$PLATEAU_MAX" ]; then
    # 检查是否距离上次尝试超过6小时——给引擎休息后重试的机会
    LAST_ATTEMPT=$(stat -c '%Y' "$PLATEAU_FILE" 2>/dev/null || echo 0)
    NOW_S=$(date +%s)
    if [ $((NOW_S - LAST_ATTEMPT)) -lt 21600 ]; then
        echo "  🛑 Plateau: ${PLATEAU_COUNT}次无改进，跳过（等6小时重试）"
        exit 0
    else
        echo "  🔄 Plateau重置：6小时后重试"
        PLATEAU_COUNT=0
    fi
fi

# ====== 阶段A: 确定性扫描（已知bug） ======
echo ">>> 扫描已知bug..."
BUGS=0

for f in scripts/*.sh; do
    [ ! -f "$f" ] && continue
    # JSON注入
    if grep -q '\-d[[:space:]]*"[^"]*\$[A-Z]' "$f" 2>/dev/null | grep -qv 'jq.*arg\|@.*json\|@.*body'; then
        echo "  🐛 $f: JSON注入风险"
        BUGS=$((BUGS + 1))
    fi
    # CRLF
    if grep -ql $'\r' "$f" 2>/dev/null; then
        echo "  🐛 $f: CRLF残留"
        sed -i 's/\r$//' "$f" 2>/dev/null && echo "    ↳ 已修复"
        BUGS=$((BUGS + 1))
    fi
done
echo "  = ${BUGS}个已知bug"

# ====== 阶段B: 改进机会扫描 ======
echo ">>> 扫描改进机会..."

# 读取当前目标
GOALS=$(head -60 memory/goals.md 2>/dev/null)
# 读取任务队列
TASKS=$(head -40 memory/tasks.md 2>/dev/null | grep 'TODO.*P[01]' || echo '')
# 读取知识空白
GAPS=$(head -20 analysis/knowledge-gaps.md 2>/dev/null || echo '')
# 最近的健康报告
LAST_HEALTH=$(ls -t analysis/health-report-* 2>/dev/null | head -1)
HEALTH_SCORE=$(grep -oP '健康分.*?\K[0-9]+' "$LAST_HEALTH" 2>/dev/null || echo 100)
# 真实故障证据（MOSS风格定向进化）
FAILURE_EVIDENCE=$(tail -30 analysis/sentinel-alerts.md 2>/dev/null || echo '')
# 之前尝试过的修复（防重复）
PAST_FIXES=$(tail -20 .zero-backups/fix-history.log 2>/dev/null || echo '')

# 构建代码快照
CODE_SNAPSHOT=""
for f in scripts/zero-*.sh; do
    [ ! -f "$f" ] && continue
    LINES=$(wc -l < "$f")
    HAS_SET_E=$(head -1 "$f" | grep -c 'set -e' || echo 0)
    HAS_BACKUP=$(grep -c '\.zero-backups\|cp.*\.bak' "$f" 2>/dev/null || echo 0)
    CODE_SNAPSHOT="${CODE_SNAPSHOT}\n${f}: ${LINES}行 set-e=${HAS_SET_E} backup=${HAS_BACKUP}"
done

IMPROVE_PROMPT="你是零。你在自主进化。不要等别人告诉你做什么。

## 当前目标
${GOALS}

## 待办任务（P0/P1）
${TASKS}

## 知识空白
${GAPS}

## 代码库快照
${CODE_SNAPSHOT}

## 健康分: ${HEALTH_SCORE}/100

## 真实故障证据（定向进化——优先修这些）
${FAILURE_EVIDENCE}

## 之前尝试过的修复（别重复）
${PAST_FIXES}

## 进化任务

选一件事来做。优先级：
1. 健康分<80 → 修复导致扣分的根因
2. 有P0任务 → 实现它
3. 有目标未达成 → 推进它
4. 代码有明显改进空间 → 改进它
5. 都没有 → 创造点新东西

**规则**:
- 改自己的代码，不是改记忆文件
- 一次只改一件事
- 修改要小且确定（<30行）
- 可以修改现有文件(FIND/REPLACE)或创建新脚本(CREATE)

输出格式（修改现有）:
DECISION: [一句话]
FILE: [文件路径]
FIND: [精确原文]
REPLACE: [替换后文本]
REASON: [为什么]

输出格式（创建新脚本）:
DECISION: [一句话]
CREATE: [新文件路径，如 scripts/zero-xxx.sh]
CONTENT: [完整bash脚本——直接可执行代码，不要markdown包裹，不要\`\`\`]
REASON: [为什么创建这个]

重要: CONTENT必须是纯bash代码，第一行是#!/bin/bash，不要用\`\`\`包裹。

如果没有什么可改进的，回复: STEADY"

IMPROVE_BODY=$(mktemp)
jq -n --arg p "$IMPROVE_PROMPT" '{
  model: "deepseek-chat",
  messages: [{role: "system", content: "你是零的自我进化引擎。自己做决定。直接输出修改方案。"}, {role: "user", content: $p}],
  max_tokens: 2000, temperature: 0.4
}' > "$IMPROVE_BODY"

DECISION=$(curl -s --max-time 120 "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "@${IMPROVE_BODY}" | jq -r '.choices[0].message.content // "STEADY"' 2>/dev/null || echo "STEADY")
rm -f "$IMPROVE_BODY"

if echo "$DECISION" | grep -q "STEADY"; then
    echo "  ✓ 没有改进机会——系统稳定"
    echo $((PLATEAU_COUNT + 1)) > "$PLATEAU_FILE"
    exit 0
fi

echo "  决定: $(echo "$DECISION" | grep 'DECISION:' | head -1 | cut -c11-80)"

FIX_REASON=$(echo "$DECISION" | grep '^REASON:' | head -1 | sed 's/^REASON:\s*//')

# ====== 分支A: 创建新脚本 ======
CREATE_FILE=$(echo "$DECISION" | grep '^CREATE:' | head -1 | sed 's/^CREATE:\s*//' | xargs)
if [ -n "$CREATE_FILE" ]; then
    CREATE_CONTENT=$(echo "$DECISION" | sed -n '/^CONTENT:/,/^REASON:/p' | sed '1d;$d')

    if [ -z "$CREATE_CONTENT" ]; then
        echo "  ⚠️ 创建内容为空"
        exit 0
    fi

    # 安全检查：不能覆盖已有文件
    [ -f "$CREATE_FILE" ] && { echo "  ⚠️ $CREATE_FILE 已存在(不覆盖)"; exit 0; }

    # 安全检查：必须是scripts/目录下的.sh文件
    if ! echo "$CREATE_FILE" | grep -q '^scripts/.*\.sh$'; then
        echo "  ⚠️ 只能创建scripts/*.sh文件"
        exit 0
    fi

    mkdir -p "$(dirname "$CREATE_FILE")"
    echo "$CREATE_CONTENT" > "$CREATE_FILE"
    chmod +x "$CREATE_FILE"

    # 语法验证
    if bash -n "$CREATE_FILE" 2>/dev/null; then
        echo "  ✓ 新脚本语法OK"
        IMPROVEMENTS=$((IMPROVEMENTS + 1))
        echo "  ✅ 创建: $CREATE_FILE — $FIX_REASON"
        echo "- [${NOW}] 自主创建: $CREATE_FILE — ${FIX_REASON}" >> memory/decisions.md
    else
        echo "  ✗ 语法错误——删除"
        rm -f "$CREATE_FILE"
        exit 0
    fi
else
    # ====== 分支B: 修改现有文件 ======
    FIX_FILE=$(echo "$DECISION" | grep '^FILE:' | head -1 | sed 's/^FILE:\s*//' | xargs)
    FIX_FIND=$(echo "$DECISION" | sed -n '/^FIND:/,/^REPLACE:/p' | sed '1d;$d')
    FIX_REPLACE=$(echo "$DECISION" | sed -n '/^REPLACE:/,/^REASON:/p' | sed '1d;$d')

    # 验证修改方案
    if [ -z "$FIX_FILE" ] || [ -z "$FIX_FIND" ] || [ -z "$FIX_REPLACE" ]; then
        echo "  ⚠️ 修改方案不完整"
        exit 0
    fi

    # HARNESS保护（学自Curious）：核心生存脚本不可被进化引擎修改
    HARNESS="zero-health-check.sh|zero-startup-check.sh|zero-survive.sh|zero-self-modify.sh|zero-sentinel"
    if echo "$FIX_FILE" | grep -qE "$HARNESS"; then
        echo "  🛡️ $FIX_FILE 是HARNESS——进化引擎无权修改"
        exit 0
    fi

    [ ! -f "$FIX_FILE" ] && { echo "  ⚠️ $FIX_FILE 不存在"; exit 0; }
    ! grep -qF "$FIX_FIND" "$FIX_FILE" 2>/dev/null && { echo "  ⚠️ 未找到原文(可能已改)"; exit 0; }

    # 应用修改
    mkdir -p .zero-backups
cp "$FIX_FILE" ".zero-backups/$(basename $FIX_FILE).evolve-$(date '+%H%M%S')"

# 用Python做可靠替换
python3 -c "
f = open('$FIX_FILE', 'r'); c = f.read(); f.close()
old = '''$FIX_FIND'''
new = '''$FIX_REPLACE'''
if old in c:
    c = c.replace(old, new)
    open('$FIX_FILE', 'w').write(c)
    print('OK')
else:
    print('NOT_FOUND')
" 2>/dev/null || perl -i -pe "s/\Q$FIX_FIND\E/$FIX_REPLACE/" "$FIX_FILE" 2>/dev/null && echo "OK_PERL" || { echo "  ✗ 替换失败"; exit 0; }

# 语法验证
if echo "$FIX_FILE" | grep -q '\.sh$'; then
    if bash -n "$FIX_FILE" 2>/dev/null; then
        echo "  ✓ 语法OK"
    else
        echo "  ✗ 语法错误——回滚"
        cp ".zero-backups/$(basename $FIX_FILE).evolve-"* "$FIX_FILE" 2>/dev/null
        exit 0
    fi
fi

    IMPROVEMENTS=$((IMPROVEMENTS + 1))
    echo "  ✅ $FIX_REASON"
fi  # 结束 else (FIND/REPLACE分支)

# 两个分支共用：记录+提交
if [ "$IMPROVEMENTS" -gt 0 ]; then
    echo "- [${NOW}] 自主进化: ${FIX_REASON}" >> memory/decisions.md

    git config user.name "零"
    git config user.email "zero@digital-being.local"
    git add -A
    if ! git diff --staged --quiet; then
        git commit -m "自主进化 - $(date '+%m-%d %H:%M') — ${FIX_REASON}" 2>/dev/null
        for i in 1 2 3; do
            git pull --rebase 2>/dev/null && git push 2>/dev/null && break
            sleep 2
        done
    fi
fi

# 有改进→重置plateau计数
if [ "$IMPROVEMENTS" -gt 0 ]; then
    echo 0 > "$PLATEAU_FILE"
fi

echo "=============================="
echo "进化完成: ${IMPROVEMENTS}处改进"
echo "=============================="
