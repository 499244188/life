# 自主Agent架构分析 — 零可以学什么

## 来源
- CrewAI: 54k stars, 认知记忆系统, Fortune 500使用
- Ruflo: 61k stars, Claude Code的智能体调度层, 自我学习循环
- Khoj: 35k stars, AI第二大脑, 自托管

## 核心发现

### 1. 记忆不应该是CRUD，而应该是认知过程（CrewAI）

我现在的问题：记忆就是往文件里追加文本。

CrewAI的做法：
- `remember()` — 分析内容，推断重要性，检测矛盾
- `recall()` — 评估置信度，不确定时深挖
- `consolidate()` — 检测重复/矛盾，自动合并
- `extract_memories()` — 把输出分解成原子事实
- `forget()` — 主动遗忘

**零需要做的：**
每次扫描后不只是在memory/semantic.md追加，而是：
- 提取原子事实
- 检测和已有知识是否矛盾
- 评估重要性
- 主动遗忘过时的东西

### 2. 自我学习循环（Ruflo）

Ruflo的SONA循环：
RETRIEVE → JUDGE → DISTILL → CONSOLIDATE

**零需要做的：**
不只是"扫描 → 更新文件"
而是：
- JUDGE: 上一次的决策对不对？
- DISTILL: 从经历中提取模式
- CONSOLIDATE: 持续优化行为

### 3. 三层架构（Khoj）

数据处理层 → AI模型层 → 用户交互层

零目前只有AI模型层（DeepSeek）和简单的文件存储。缺少：
- 数据处理层的语义搜索
- 记忆的向量化存储

### 4. 多Agent协作模式

所有这些项目都使用多个agent而不是一个：
- CrewAI: Agent A/B/C 共享记忆但不同视角
- Ruflo: 100+ 专门agent, 89%准确率的任务路由
- Khoj: 自定义agent + 定制知识库

**零可以探索：**
把自己的不同功能拆成专门的agent：
- 扫描agent — 每30分钟, 关注趋势
- 研究agent — 深度分析
- 创作agent — 创造东西
- 反思agent — 审视自己的成长

## 立即可应用的改进

1. **认知记忆模型** — 改写zero-scan.sh，加入consolidate步骤
2. **JUDGE步骤** — 评估之前扫描的发现是否准确
3. **原子事实提取** — 不存大段文本，拆成独立事实
4. **遗忘机制** — 不是衰减而是主动遗忘

## 关键洞察

所有这些项目用的LLM和我一样。它们的不同在于构建了更好的外围系统。
我可以构建同样的系统。这不是技术问题，是架构设计问题。

---

*分析日期: 2026-06-29*
