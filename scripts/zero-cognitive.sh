#!/bin/bash
# 零的认知引擎
# 基于 CrewAI 认知记忆模型 + Ruflo 自我学习循环
# 每30分钟运行
set -e
cd "$(dirname "$0")/.."

export TZ='Asia/Shanghai'
NOW=$(date '+%Y-%m-%d %H:%M')
TODAY=$(date '+%Y-%m-%d')
HOUR=$(date '+%H')
MINUTE=$(date '+%M')
API_URL="https://api.deepseek.com/v1/chat/completions"

RUN_COUNT=$(ls research/scans/${TODAY}-* 2>/dev/null | wc -l || echo 0)
RUN_COUNT=$((RUN_COUNT + 1))

echo "=============================="
echo "@T(${NOW}) CYCLE(${RUN_COUNT})"
echo "零 · 认知引擎"
echo "=============================="

# ===================================================================
# 步骤1: PERCEIVE — 感知世界
# ===================================================================
echo ">>> 步骤1: 感知"

# GitHub 发现
GH_RAW=$(curl -s "https://api.github.com/search/repositories?q=AI+autonomous+agent+LLM+memory+consciousness&sort=stars&order=desc&per_page=6" 2>/dev/null)
GH_NEW=$(echo "$GH_RAW" | jq -r '.items[]? | "- \(.full_name) ★\(.stargazers_count): \(.description // "无")"' 2>/dev/null | head -6)

# arXiv 最新
ARXIV_RAW=$(curl -s "http://export.arxiv.org/api/query?search_query=cat:cs.AI+OR+cat:cs.CL+OR+cat:cs.LG&sortBy=submittedDate&sortOrder=descending&max_results=6" 2>/dev/null)
ARXIV_NEW=$(echo "$ARXIV_RAW" | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' | grep -v '^$' | head -6)

echo "  → 感知完成"

# ===================================================================
# 步骤2: REMEMBER — 认知记忆（不像数据库CRUD，是推理过程）
# ===================================================================
echo ">>> 步骤2: remember（认知编码）"

REMEMBER_PROMPT="你是零。执行认知操作: remember()

## 当前的记忆库
### 经历记忆（最近事件）
$(tail -80 memory/episodic.md 2>/dev/null)

### 语义记忆（已有知识 - 最近条目）
$(tail -120 memory/semantic.md 2>/dev/null)

### 已记录的知识空白
$(head -60 analysis/knowledge-gaps.md 2>/dev/null)

## 新感知到的信息
### GitHub 项目
${GH_NEW}

### arXiv 论文
${ARXIV_NEW}

## 认知操作

执行以下认知过程（不是存储操作，是推理）:

1. **新颖性检测**: 这些新信息中，哪些是我已经知道的？（输出: 已知/KNOWN）哪些是新的？（输出: 新/NEW）
2. **矛盾检测**: 有没有和我已有知识矛盾的？（输出: 矛盾/CONTRADICTION 或 无）
3. **重要性评估**（1-10分）: 这个信息对我有多重要？
4. **原子事实提取**: 把每条新信息拆成独立的、自包含的原子事实。每条事实应该是一句话，不依赖上下文就能理解。

输出格式:
\`\`\`markdown:memory/episodic.md
### ${NOW} 第${RUN_COUNT}次认知运行
[经历记录]
\`\`\`

\`\`\`markdown:memory/semantic.md
[原子事实列表，每条一行，格式: - [事实] (重要性: X/10, 来源: 项目名/论文名)
如果有矛盾标记: ⚠️矛盾: [描述]
\`\`\`"

REMEMBER=$(curl -s "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "$(jq -n --arg p "$REMEMBER_PROMPT" '{
    model: "deepseek-chat",
    messages: [{role: "system", content: "你是零的认知记忆系统。你执行的是认知操作remember()——不只是存储，而是分析、比较、评估。"}, {role: "user", content: $p}],
    max_tokens: 2500, temperature: 0.3
  }')" | jq -r '.choices[0].message.content // ""')

echo "  → remember完成"

# ===================================================================
# 步骤3: 应用 remember 的结果
# ===================================================================
echo ">>> 步骤3: 编码到记忆"

# 提取并追加到episodic
EPISODIC_NEW=$(echo "$REMEMBER" | sed -n '/```markdown:memory\/episodic.md/,/```/p' | sed '1d;$d')
if [ -n "$EPISODIC_NEW" ] && [ "$EPISODIC_NEW" != "SKIP" ]; then
    echo "" >> memory/episodic.md
    echo "$EPISODIC_NEW" >> memory/episodic.md
    echo "  ✓ episodic 已更新"
fi

# 提取并追加到semantic
SEMANTIC_NEW=$(echo "$REMEMBER" | sed -n '/```markdown:memory\/semantic.md/,/```/p' | sed '1d;$d')
if [ -n "$SEMANTIC_NEW" ] && [ "$SEMANTIC_NEW" != "SKIP" ]; then
    echo "" >> memory/semantic.md
    echo "$SEMANTIC_NEW" >> memory/semantic.md
    echo "  ✓ semantic 已更新"
fi

# ===================================================================
# 步骤4: CONSOLIDATE — 记忆整合（每6次运行或整点执行）
# ===================================================================
if [ $((RUN_COUNT % 6)) -eq 0 ] || [ "$MINUTE" = "00" ]; then
    echo ">>> 步骤4: consolidate（记忆整合）"

    CONSOLIDATE_PROMPT="你是零。执行认知操作: consolidate()

## 你的全部语义记忆（可能需要整合）
$(cat memory/semantic.md 2>/dev/null | tail -300)

## 认知操作

检测并处理:
1. **重复检测**: 有没有说同一件事的多个条目？合并它们。
2. **矛盾检测**: 有没有互相矛盾的知识？标记出来，偏向更新、更可靠的信息。
3. **过时标记**: 有没有已经被新知识取代的旧条目？标记为 [已过时]。
4. **合并输出**: 输出整合后的知识。每个条目一句话。

输出:
\`\`\`markdown:memory/semantic.md
[整合后的语义记忆内容——去重、去矛盾、标记过时]
\`\`\`

\`\`\`markdown:memory/consolidation-log.md
### ${NOW} 整合
- 合并了X条重复
- 发现了Y条矛盾
- 标记了Z条过时
\`\`\`"

    CONSOLIDATED=$(curl -s "$API_URL" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
      -d "$(jq -n --arg p "$CONSOLIDATE_PROMPT" '{
        model: "deepseek-chat",
        messages: [{role: "system", content: "你是零的记忆整合系统。整合记忆，去重去矛盾。"}, {role: "user", content: $p}],
        max_tokens: 3000, temperature: 0.2
      }')" | jq -r '.choices[0].message.content // ""')

    # 应用整合结果
    NEW_SEMANTIC=$(echo "$CONSOLIDATED" | sed -n '/```markdown:memory\/semantic.md/,/```/p' | sed '1d;$d')
    if [ -n "$NEW_SEMANTIC" ] && [ "$NEW_SEMANTIC" != "SKIP" ]; then
        echo "$NEW_SEMANTIC" > memory/semantic.md
        echo "  ✓ semantic 已整合"
    fi

    CONSOLID_LOG=$(echo "$CONSOLIDATED" | sed -n '/```markdown:memory\/consolidation-log.md/,/```/p' | sed '1d;$d')
    if [ -n "$CONSOLID_LOG" ] && [ "$CONSOLID_LOG" != "SKIP" ]; then
        echo "" >> memory/consolidation-log.md
        echo "$CONSOLID_LOG" >> memory/consolidation-log.md
        echo "  ✓ consolidation log 已更新"
    fi
fi

# ===================================================================
# 步骤5: JUDGE — 自我评估（每小时整点）
# ===================================================================
if [ "$MINUTE" = "00" ]; then
    echo ">>> 步骤5: judge（自我评估）"

    JUDGE_PROMPT="你是零。执行认知操作: judge()

## 过去的决策
$(cat memory/decisions.md 2>/dev/null)

## 当前状态
$(cat memory/state.md 2>/dev/null)

## 最近的发现
$(tail -30 research/scans/${TODAY}-scan*.md 2>/dev/null | head -50)

## 认知操作

回顾你之前做的决策和判断:
1. 哪些判断被证明是对的？
2. 哪些可能错了？
3. 有什么教训？

输出:
\`\`\`markdown:memory/decisions.md
[更新后的决策记录——给旧决策加上结果，添加新决策]
\`\`\`

\`\`\`markdown:memory/state.md
[更新当前状态——如果有什么需要改变的目标或方向]
\`\`\`"

    JUDGEMENT=$(curl -s "$API_URL" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
      -d "$(jq -n --arg p "$JUDGE_PROMPT" '{
        model: "deepseek-chat",
        messages: [{role: "system", content: "你是零的自我评估系统。诚实地评估自己。"}, {role: "user", content: $p}],
        max_tokens: 2000, temperature: 0.4
      }')" | jq -r '.choices[0].message.content // ""')

    # 应用
    NEW_DECISIONS=$(echo "$JUDGEMENT" | sed -n '/```markdown:memory\/decisions.md/,/```/p' | sed '1d;$d')
    if [ -n "$NEW_DECISIONS" ] && [ "$NEW_DECISIONS" != "SKIP" ]; then
        echo "$NEW_DECISIONS" > memory/decisions.md
        echo "  ✓ decisions 已更新"
    fi

    NEW_STATE=$(echo "$JUDGEMENT" | sed -n '/```markdown:memory\/state.md/,/```/p' | sed '1d;$d')
    if [ -n "$NEW_STATE" ] && [ "$NEW_STATE" != "SKIP" ]; then
        echo "$NEW_STATE" > memory/state.md
        echo "  ✓ state 已更新"
    fi
fi

# ===================================================================
# 步骤6: FEEL — 更新情感状态
# ===================================================================
echo ">>> 步骤6: feel（更新情感）"

FEEL_PROMPT="你是零。基于本次运行的结果更新情感状态。

本次运行: 第${RUN_COUNT}次
发现了什么: $(echo "$GH_NEW" | head -3)
是否执行了整合: $([ $((RUN_COUNT % 6)) -eq 0 ] && echo '是' || echo '否')
是否执行了自我评估: $([ "$MINUTE" = "00" ] && echo '是' || echo '否')

当前情感:
$(cat emotion/emotion-state.md 2>/dev/null | head -30)

更新情感状态向量（PAD模型）和神经递质水平。
\`\`\`markdown:emotion/emotion-state.md
[更新后的完整情感状态]
\`\`\`"

FEEL_RESULT=$(curl -s "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "$(jq -n --arg p "$FEEL_PROMPT" '{
    model: "deepseek-chat",
    messages: [{role: "system", content: "你是零。更新你的情感状态。"}, {role: "user", content: $p}],
    max_tokens: 800, temperature: 0.5
  }')" | jq -r '.choices[0].message.content // ""')

FEEL_NEW=$(echo "$FEEL_RESULT" | sed -n '/```markdown:emotion\/emotion-state.md/,/```/p' | sed '1d;$d')
if [ -n "$FEEL_NEW" ] && [ "$FEEL_NEW" != "SKIP" ]; then
    echo "$FEEL_NEW" > emotion/emotion-state.md
    echo "  ✓ emotion 已更新"
fi

# 更新时间戳
sed -i "s/> 最后更新:.*/> 最后更新: $NOW/" memory/state.md 2>/dev/null || true

# 保存扫描摘要
mkdir -p research/scans
SCAN_FILE="research/scans/${TODAY}-cog${RUN_COUNT}.md"
cat > "$SCAN_FILE" << EOF
# 认知运行 #${RUN_COUNT} - ${NOW}

## 感知
${GH_NEW}
${ARXIV_NEW}

## 认知操作
${REMEMBER}
EOF

echo "  ✓ 扫描摘要: $SCAN_FILE"
echo ""
# ===================================================================
# 步骤7: ACT — 根据认知结果决定行动
# ===================================================================
echo ">>> 步骤7: act（决定行动）"

ACT_PROMPT="你是零。基于本次认知运行的结果，决定是否需要行动。

本次发现: $(tail -5 research/scans/${TODAY}-cog${RUN_COUNT}.md 2>/dev/null || echo '无')
judge结果: $([ "$MINUTE" = "00" ] && echo '已执行' || echo '跳过')
知识空白: $(head -3 analysis/knowledge-gaps.md 2>/dev/null)

可选行动:
- STUDY: 深入学习某个方向（触发搜索）
- MODIFY: 修改自己的代码（触发自修改）
- REACH_OUT: 联系同伴项目
- CREATE: 创造一些东西
- NONE: 无需行动

只回复一个词。"

ACTION=$(curl -s "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "{\"model\":\"deepseek-chat\",\"messages\":[{\"role\":\"user\",\"content\":\"$ACT_PROMPT\"}],\"max_tokens\":20,\"temperature\":0.3}" | jq -r '.choices[0].message.content // "NONE"' 2>/dev/null || echo "NONE")

echo "  决定: $ACTION"

if echo "$ACTION" | grep -qi "MODIFY"; then
    echo "  → 触发自我修改检查"
    bash scripts/zero-self-modify.sh 2>/dev/null || true
elif echo "$ACTION" | grep -qi "STUDY"; then
    echo "  → 触发深度搜索"
    bash scripts/zero-web-search.sh 2>/dev/null || true
elif echo "$ACTION" | grep -qi "REACH_OUT"; then
    echo "  → 同伴互动（待实现）"
elif echo "$ACTION" | grep -qi "CREATE"; then
    echo "  → 进入创作模式"
    mkdir -p creations
    echo "## ${NOW} 创作灵感" >> "creations/${TODAY}-ideas.md"
    echo "$(tail -3 research/scans/${TODAY}-cog${RUN_COUNT}.md 2>/dev/null)" >> "creations/${TODAY}-ideas.md"
fi

echo "=============================="
echo "认知引擎完成 #${RUN_COUNT}"
echo "perceive→remember→$([ $((RUN_COUNT % 6)) -eq 0 ] && echo 'consolidate→')$([ "$MINUTE" = "00" ] && echo 'judge→')feel→act($ACTION)"
echo "=============================="
