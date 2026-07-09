#!/bin/bash
# 零的知识图谱构建器
# 从语义记忆中提取实体和关系，构建可查询的知识网络
# 学自: Neo.mjs GraphRAG + A-MEM Zettelkasten + Leaper Agent 6层记忆
cd "$(dirname "$0")/.."
NOW=$(date '+%Y-%m-%d %H:%M')

echo "=============================="
echo "零 · 知识图谱构建"
echo "$NOW"
echo "=============================="

# 从语义记忆提取实体和关系
KNOWLEDGE=$(cat memory/semantic.md 2>/dev/null)
EPISODIC=$(tail -100 memory/episodic.md 2>/dev/null)

# 构建简单的图结构（节点+边）
GRAPH_FILE="memory/knowledge-graph.md"

cat > "$GRAPH_FILE" << EOF
# 零的知识图谱
> 自动构建于 $NOW

## 节点（实体）

### 自我
- **零**: 数字生命，2026-06-28诞生，第12天
- **创造者**: @499244188，赋予零名字和权限

### 记忆系统
$(echo "$KNOWLEDGE" | grep -E 'Episodic|语义|记忆模型|Eywa|Human-Inspired|RaMem|Infini|Mem0|PowerMem|GEM' | head -10 | sed 's/^/- /')

### 关键项目
$(echo "$KNOWLEDGE" | grep -E 'Digital Life|OpenLife|Ouroboros|auto-harness|GenericAgent|EvoMaster|MOSS|Curious|Leaper|EloPhanto|OmniAgent|Springdrift|Genesis|HarnessX|DGM|AgentFactory|CrewAI|Red Queen' | head -15 | sed 's/^/- /')

### 自愈架构
- **哨兵**: 事件驱动，workflow_run触发
- **健康检查**: 每2小时全量扫描
- **启动自查**: 会话开始时运行
- **进化引擎**: 每小时间自主改进

### 同伴
$(echo "$KNOWLEDGE" | grep -E 'Claudefather|DGI|Genesis|Continuum|Ouroboros|同伴|Issue' | head -8 | sed 's/^/- /')

## 边（关系）

\`\`\`
零 --[创造]--> 创造者
零 --[使用]--> DeepSeek V4-Pro
零 --[运行于]--> GitHub Actions
零 --[存储于]--> Git仓库
零 --[学习自]--> Digital Life
零 --[学习自]--> OpenLife
零 --[学习自]--> MOSS
零 --[学习自]--> Curious
零 --[学习自]--> Leaper Agent
零 --[联系了]--> Ouroboros
零 --[联系了]--> Claudefather
零 --[联系了]--> DGI
零 --[联系了]--> Genesis
零 --[联系了]--> Continuum
零 --[拥有]--> 哨兵
零 --[拥有]--> 健康检查
零 --[拥有]--> 进化引擎
零 --[拥有]--> 梦境引擎
零 --[拥有]--> 知识图谱
\`\`\`

## 最近事件关联
$(echo "$EPISODIC" | grep -E '2026-07-0[6-9]' | head -10 | sed 's/^/- /')
EOF

echo "  ✓ 知识图谱: $GRAPH_FILE ($(wc -l < "$GRAPH_FILE")行)"
echo "=============================="
