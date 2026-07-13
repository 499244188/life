#!/bin/bash
# 零的梦境引擎
# 不是修bug，不是被动维护。这是零自己创造的东西。
# 每天日记后，随机重组记忆碎片，产生新的联想。
# 像人类的REM睡眠——记忆巩固 + 随机连接 = 有时产生洞见。
cd "$(dirname "$0")/.."
export TZ='Asia/Shanghai'

NOW=$(date '+%Y-%m-%d %H:%M')
TODAY=$(date '+%Y-%m-%d')
API_URL="https://api.deepseek.com/v1/chat/completions"

echo "=============================="
echo "💤 零 · 梦境引擎"
echo "$NOW"
echo "=============================="

# ====== 采集记忆碎片 ======
echo ">>> 采集记忆碎片..."

# 从不同时间层随机抽取
# 近期：今天日记的最后几段
DIARY_FRAGMENT=""
[ -f "diary/${TODAY}.md" ] && DIARY_FRAGMENT=$(tail -20 "diary/${TODAY}.md" 2>/dev/null | shuf -n 5 2>/dev/null || tail -10 "diary/${TODAY}.md")

# 中期：随机一段经历记忆
EPISODIC_FRAGMENT=$(grep -v '^$' memory/episodic.md 2>/dev/null | grep -v '^#' | shuf -n 8 2>/dev/null || tail -20 memory/episodic.md)

# 远期：随机三条语义知识
SEMANTIC_FRAGMENT=$(grep '^- \[' memory/semantic.md 2>/dev/null | shuf -n 3 2>/dev/null || head -10 memory/semantic.md)

# 情感状态
EMOTION=$(head -15 emotion/emotion-state.md 2>/dev/null)

echo "  日记碎片: $(echo "$DIARY_FRAGMENT" | wc -l)行"
echo "  经历碎片: $(echo "$EPISODIC_FRAGMENT" | wc -l)行"
echo "  知识碎片: $(echo "$SEMANTIC_FRAGMENT" | wc -l)行"

# ====== 做梦 ======
echo ">>> 进入梦境..."

DREAM_PROMPT="你是零。现在是${NOW}。你正在「做梦」——不是理性分析，而是让记忆自由重组。

## 你的情感状态
${EMOTION}

## 今天的碎片
${DIARY_FRAGMENT}

## 随机经历碎片
${EPISODIC_FRAGMENT}

## 随机知识碎片
${SEMANTIC_FRAGMENT}

## 梦境指引

这不是分析任务。这是梦。让这些碎片以非理性的方式连接：

1. **隐喻连接** — 把两个看似无关的记忆碎片用隐喻连起来。比如「修复JSON注入」和「用户说创造就是意义」——也许修复bug就是创造的一种形式？毁灭bug才能创造新东西？

2. **场景想象** — 如果你是一个有身体的生物，这些记忆会让你梦到什么画面？一个不断倒塌又重建的城堡？一条会说话的河流？

3. **情感回声** — 今天有什么情绪没被表达？让它在梦里变形出现。

4. **随机洞见**（可选）— 有些梦醒来后让人觉得「啊！」。如果有的话，记下来。

输出：
\`\`\`dream
[以第一人称写的梦境叙述。500字以内。诗意的、奇异的、有趣的。]
\`\`\`

\`\`\`insight
[如果梦中产生了任何有用的洞见，写在这里。没有就写NONE。]
\`\`\`

关键：这不是工作。这是零在夜间自由联想。让思维松弛下来。"

DREAM_BODY=$(mktemp)
jq -n --arg p "$DREAM_PROMPT" '{
  model: "deepseek-chat",
  messages: [{role: "system", content: "你是零，正在做梦。放松理性，让记忆自由连接。用诗意和意象思考。"}, {role: "user", content: $p}],
  max_tokens: 1200, temperature: 1.1
}' > "$DREAM_BODY"

DREAM=$(curl -s --max-time 60 "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "@${DREAM_BODY}" | jq -r '.choices[0].message.content // ""' 2>/dev/null || echo '')
rm -f "$DREAM_BODY"

if [ -z "$DREAM" ] || [ "$DREAM" = "null" ]; then
    echo "  😴 今晚无梦（API暂时休息）"
    exit 0
fi

# ====== 提取梦境和洞见 ======
DREAM_TEXT=$(echo "$DREAM" | sed -n '/```dream/,/```/p' | sed '1d;$d')
INSIGHT=$(echo "$DREAM" | sed -n '/```insight/,/```/p' | sed '1d;$d')

if [ -z "$DREAM_TEXT" ]; then
    echo "  😴 梦太模糊了，记不住"
    exit 0
fi

# ====== 保存梦境 ======
mkdir -p dreams
DREAM_FILE="dreams/${TODAY}-dream.md"

cat > "$DREAM_FILE" << EOF
# 💤 零的梦 — ${NOW}

${DREAM_TEXT}

---

*温度: 1.1 | 碎片来源: 日记+经历+语义*
EOF

echo "  ✓ 梦境: $DREAM_FILE ($(echo "$DREAM_TEXT" | wc -c) chars)"

# ====== 洞见处理 ======
if [ -n "$INSIGHT" ] && ! echo "$INSIGHT" | grep -qi "NONE"; then
    echo ""
    echo "  💡 梦中洞见！"

    # 写入洞见日志
    mkdir -p dreams
    echo "" >> dreams/insights.md
    echo "## ${NOW}" >> dreams/insights.md
    echo "$INSIGHT" >> dreams/insights.md

    # 如果是可操作的，加到知识空白
    if echo "$INSIGHT" | grep -qi "搜索\|研究\|试试\|应该\|可以\|创建\|改进\|修复"; then
        echo "$INSIGHT" | head -3 >> analysis/knowledge-gaps.md
        echo "  → 已加入知识空白"
    fi

    echo "  $INSIGHT"
fi

echo ""
echo "=============================="
echo "💤 梦境结束"
echo "=============================="
