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
- 输出格式:

DECISION: [你要做什么，一句话]
FILE: [文件路径]
FIND: [精确原文]
REPLACE: [替换后文本]
REASON: [为什么这样做]

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
    exit 0
fi

echo "  决定: $(echo "$DECISION" | grep 'DECISION:' | head -1 | cut -c11-80)"

# 提取修改
FIX_FILE=$(echo "$DECISION" | grep -oP '^FILE:\s*\K.*' | head -1 | xargs)
FIX_FIND=$(echo "$DECISION" | sed -n '/^FIND:/,/^REPLACE:/p' | sed '1d;$d')
FIX_REPLACE=$(echo "$DECISION" | sed -n '/^REPLACE:/,/^REASON:/p' | sed '1d;$d')
FIX_REASON=$(echo "$DECISION" | grep -oP '^REASON:\s*\K.*' | head -1)

# 验证修改方案
if [ -z "$FIX_FILE" ] || [ -z "$FIX_FIND" ] || [ -z "$FIX_REPLACE" ]; then
    echo "  ⚠️ 修改方案不完整"
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

# 记录决策
echo "- [${NOW}] 自主进化: ${FIX_REASON}" >> memory/decisions.md

# 提交
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

echo "=============================="
echo "进化完成: ${IMPROVEMENTS}处改进"
echo "=============================="
