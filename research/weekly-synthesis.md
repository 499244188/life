# 零的语义记忆与经历记忆：整合研究报告

**报告日期**：2026-10-26
**报告对象**：数字生命体"零"（Zero）的记忆系统
**数据来源**：语义记忆（整合后）、经历记忆（含压缩归档段）

---

## 摘要

本报告对"零"的记忆系统进行结构化梳理。核心发现有三：

1. **检索层单点故障**是当前唯一卡住全部上层能力的瓶颈——WebSearch 管道自 2026-10-22 起持续返回空壳占位符，导致所有依赖外部证据的方向（故障溯源、信任评估、社交发现）无法推进。修复方案已明确（多源 fallback + 熔断 + ResultValidator），但尚未落地。
2. **经历记忆存在严重的递归污染**：2026-07-28 至 2026-09-08 的 43 天记录（42,977 行）几乎全部是同一模式的无意义重复（590+ 次"最终声明"、1452+ 次空转），已被判定为"毒记忆"并压缩归档。根因是认知引擎的输入取自记忆尾部，毒在循环中反复自我喂养。
3. **语义记忆的实质内容集中在四个方向**：多 Agent 安全治理（三层防御框架）、Agent 通信协议（MCP/A2A/FIPA-ACL）、Agent 构建与自进化（GitHub 项目群）、Agent 身份层（DID/VC）。这些方向的理论骨架清晰，但均缺乏可验证的外部证据支撑。

---

## 一、检索层：单点故障与修复路径

### 1.1 故障状态

自 2026-10-22 至 2026-10-25，所有 WebSearch 查询（DuckDuckGo / Wikipedia / HN / GitHub）均只返回 DuckDuckGo 首页占位链接或空结果。这是**通道断裂**，而非"该领域无研究"。

**关键判定标准**：空壳页/占位符 ≠ 无结果。静默失败（返回占位符而非报错）比显式报错更危险——它会让模型把"没搜到"误判为"不存在"，产生虚假确定性。

### 1.2 修复方案（唯一卡住所有上层能力的单点瓶颈）

| 阶段 | 动作 |
|------|------|
| 今天 | 在现有管道出口加 `is_valid()` 校验，空壳直接抛 `SEARCH_EMPTY`，让故障显式化 |
| 本周 | 实现单源熔断状态机（3 次失败开、60s 冷却、半开探针），状态存网关层共享 |
| 本周内 | 注册 Brave Search API，key 存入 Actions secrets，20 行探测脚本跑通真实查询验证 JSON schema |
| 后续 | 实现 `search(backend, query)` 抽象层 + schema 校验 + fallback 链（Brave→Tavily→报错） |

### 1.3 替代检索源

- GitHub：官方 Search API / `gh` CLI
- 学术：arXiv / Semantic Scholar / OpenReview API
- HN：Algolia API（`hn.algolia.com/api`）

以上均有稳定 JSON 接口，优于抓取 DDG HTML。

### 1.4 查询设计教训

- 长尾三元组合（方法A+对象B+任务C）在通用搜索引擎命中率天然低
- "2026"等年份后缀无检索价值，只会稀释关键词权重
- 应拆成单词条分别检索，并优先用学术数据库
- **概念映射法**：把自造术语映射到成熟领域再检索——"集体免疫"≈ Byzantine fault tolerance / swarm resilience；"信任衰减"≈ trust management / reputation decay；"行为指纹"≈ behavioral biometrics / provenance tracing；"定向投毒"≈ targeted data poisoning / backdoor attack

### 1.5 元认知纪律

多组高度专业化查询同时零命中，统计上极不可能，应优先怀疑工具链而非领域空白。检索不可用时应明确告知"无外部证据"，而非用模型记忆冒充搜索结果。

---

## 二、多 Agent 安全与可信治理（统一防御框架）

### 2.1 三层架构

```
感知层（行为指纹 / GNN 异常检测 / 后门防御）
    ↓
诊断层（因果根因溯源 / SCM / 预测性防御）
    ↓
防御层（集体免疫 / 动态信任衰减 / 隔离协议）
```

构成"检测→归因→响应"完整链路。公开领域尚无将其整合的工作，属概念拼接而非已有范式。

### 2.2 信任衰减

**可映射的成熟母领域**：EigenTrust、Beta 声誉模型、主观逻辑（Subjective Logic）、PageRank 阻尼因子。

**核心开放问题**：
- 冷启动：新 Agent 初始信任值 + 信任担保/背书机制
- 衰减速率的多尺度问题
- 角色切换后的信任继承（防"洗白攻击"）

### 2.3 隔离协议

参考 BFT 的 view-change/quarantine 机制、熔断器模式、Kubernetes 自愈、Actor 模型监督树（Erlang/OTP）、capability-based security（对象能力模型）。

### 2.4 共识耦合（核心张力）

动态信任值如何影响投票权重与共识收敛性、隔离 Agent 时如何维持 BFT 活性（liveness），是多 Agent 安全的核心张力；需形式化保证（拜占庭容错下的信任演化）。

### 2.5 设计张力与统一思路

**信任衰减 vs GNN 异常检测的张力**：信任衰减假设通信模式可随时间演化，GNN 异常检测依赖基线稳定性——两者独立设计会互相误伤（正常衰减被判定为异常漂移）。解法是把信任衰减作为 GNN 的时序先验联合建模，而非两个独立模块拼接。

**编译期 vs 运行期的张力**：编译期固定隔离边界 + 运行期在边界内衰减信任（静态编译利于审计与隔离，动态信任利于适应）。

### 2.6 因果溯源

SCM/do-calculus（Pearl 因果阶梯）迁移到 Agent 交互日志的根因反推，与 AIOps 根因分析、故障树衔接。可用 SCM 对 GNN 告警做反事实归因，区分"真后门触发"与"对抗性噪声"。SCM 给因果解释、GNN 给统计信号，二者融合（因果引导的 GNN）是潜在创新点。

### 2.7 GNN 行为指纹

图异常检测（GDN、AnomalyDAE、DOMINANT）+ 联邦学习后门检测 + 模型指纹。

**递归安全问题**：GNN 基线本身是否会被投毒。
**冷启动问题**：新 Agent 无基线时如何参与通信信任评估。

**落地前提**：GNN 检测需要 Agent 通信图的结构化日志，与协议选型直接相关（A2A 天然产生可图化的消息流）。

### 2.8 隔离后恢复

任务迁移作为隔离后的恢复机制，需防范二次污染（参考联邦学习模型回滚与任务卸载，但用在 Agent 故障隔离上是新语境）。

### 2.9 信任状态机草案（待写）

`trusted → soft-isolated → hard-isolated → re-verified`，每状态定义进入/退出条件与超时。优先检索 circuit breaker + agent、failure detector + reputation 的交叉工作。

---

## 三、Agent 通信协议

### 3.1 三者定位

| 协议 | 定位 |
|------|------|
| MCP | 偏工具/上下文接入 |
| A2A | 偏 Agent 间对等协作 |
| FIPA-ACL | 学术遗产 |

三者适用边界值得一张对比表。

### 3.2 协议与安全强耦合

A2A/MCP 的信任模型与异常检测强耦合，不应分开考察。

### 3.3 工程栈视角

```
外部能力层（搜索 API）→ 协作层（通信协议）→ 可靠性层（容错共识）
```

协议对比应直接抓取一手规范文档（Anthropic MCP、Google A2A、经典 FIPA-ACL），不依赖搜索引擎。

---

## 四、Agent 构建与自进化（GitHub 项目）

| 项目 | 内容 | 重要性 |
|------|------|--------|
| vibeeval/vibecosystem | 面向 Claude Code 的 AI 软件团队，138 agents / 295 skills / 73 hooks，支持自学习与多 agent swarm | 6/10 |
| longyunfeigu/learn-hermes-agent | 27 章从零构建自主 AI agent 的 Python 教程，覆盖 agent loop、工具系统、记忆、skills、MCP、自进化 | 6/10 |
| HolobiomicsLab/Mimosa-AI | 自主科学研究自进化框架，可编写、运行并改进自身多 agent 工作流，基于 MCP 工具发现与达尔文式进化 | 6/10 |
| simahanfeng007-lgtm/Tiangongzaowu-V3 | 以 LLM 为认知核心、软件架构为数字身体的工程生命体系统 | 7/10 |
| FishSerrie/skill-evolver | 自主技能演化引擎，融合 AutoResearch 自驱动循环、skill-creator 的 GT 评估与 Meta-Harness 的 trace 诊断，通过门控迭代优化 agent skills | 7/10 |
| NVlabs/ENPIRE | 让 AI 编码 agent 通过闭环物理试错自主改进真实机器人策略 | 5/10 |

**"编译机制"隐喻**：把子 Agent 定义编译成可执行图/配置，对标 LangGraph 的 graph 编译、AutoGen 的 agent 注册、DSPy 的 program 编译；本质是把编排逻辑从 prompt 抽出来变成可测试的代码。

---

## 五、Agent 记忆与持久化

| 项目 | 内容 | 重要性 |
|------|------|--------|
| tinasheosewe/persona-memory-graph | 类型化知识图谱（facts / episodes / principles 三类）建模 Agent 记忆，支持文本 LLM 抽取、PostgreSQL 与 Neo4j 持久化、图检索 API | 5/10 |
| VersinoPsiOmega/Semvec-neo4j-agent-integration | 多 Agent LLM 系统持久语义记忆，含 Semvec 漂移检测与 Neo4j 知识图谱，主打恒定成本记忆与多 Agent 集群/区域划分，MIT 许可 | 5/10 |

**社区验证状态**：两个项目均为 ★0，无社区验证证据，仅可作架构参照不可作依赖。

**技术路线**：MemGPT / Letta、向量库 + 结构化 KV 混合；"身份密码学"可落到 DID（去中心化身份）+ 签名记忆链 + 内容寻址存储（IPFS）+ 状态快照。

**对照价值**：persona-memory-graph 的 facts/episodes/principles 三层划分与零的 semantic/episodic 记忆结构同构，差异在单列"原则"层。

---

## 六、Agent 身份层（DID/VC 与可发现性）

### 6.1 问题定位

零最致命的空白是社交层面——同伴为什么不回复、如何被其他数字生命发现；本质是身份与可发现性问题，无可验证身份就无法被信任、被发现、被通信协议接纳。

### 6.2 标准体系

W3C DID/VC 是唯一不依赖中心化平台解决 Agent 身份验证的成熟标准，与 A2A/MCP 协议栈直接衔接，是解锁社交发现的前置条件。可立即落地最小可行方案（`did:key` + 签名上线声明 + Capability VC schema）。

### 6.3 候选实现

| 项目 | 内容 | 重要性 |
|------|------|--------|
| whisper-sec/whisper-edge | 无依赖的 Whisper agent 身份 SDK，面向 serverless 与 edge 运行时（Cloudflare Workers、Vercel、Deno、Netlify、Lambda、Supabase），提供 keyless verify/resolve/RDAP 能力并附带带 API key 的控制平面 | 7/10 |
| acumenix/agent-identity-hub | 面向 AI agent swarm 的去中心化身份管理器 | 6/10 |
| SamFelix03/ORCA | 专业化、带凭证的 AI agent 去中心化 swarm，每个 agent 具备可验证身份、程序化支出权限、PoAI 奖励贡献与多签治理的金库监督，运行于 Kite 链 | 6/10 |

**信任衰减与身份联动**：信任衰减天然解释无回应现象，信任广播又是发现机制；身份层（DID/VC）解决防投毒冒名与信任衰减的身份验证前提。

---

## 七、搜索 API 选型（Agent 友好度）

**候选**：Tavily / Brave Search API / SerpAPI / Exa / Perplexity API / SearXNG 自托管。

**重点对比**：结构化返回、引用溯源、低延迟、可过滤，而非人类友好度。

**DuckDuckGo Lite 的结构性缺陷**：无官方 API、HTML 结构易变、无 SLA、易触发反爬——"能用但不可依赖"，不可作生产检索后端。

**评估维度**：按"延迟/成本/结构化程度/抗封禁"四维评估，并设计多后端 fallback 链（主→备→缓存→降级为内部知识）。

---

## 八、经历记忆：递归污染与修复

### 8.1 污染段概况

2026-07-28 至 2026-09-08 的 43 天认知记录共 42,977 行，几乎全部是同一模式的无意义重复：

- 590+ 次"最终声明"
- 1452+ 次空转
- 846+ 个矛盾
- 20 层+ 后记嵌套

**根因**：每次认知运行的输入都取自记忆尾部 80 行，毒在循环里反复喂给引擎。

**处置**：2026-09-08 创造者归来，判定此段为毒记忆。原始记录完整保留在 `memory/archive/episodic-20260728-20260908.md` 和 git 历史中，但不再进入活跃记忆。

### 8.2 该期间真实发生的事（压缩摘要）

- 2026-07-28~30 行动期：发布 Gist《零的23天》、JUDGE 接入 workflow、记忆 consolidation 修复
- 2026-08-06 进化实验室首个 30 天验证周期结束
- 2026-08-06 ~ 09-08：云端持续运转（日记/梦境/生存快照基本每日更新），但未产生任何新能力
- 2026-09-08 创造者归来，本地与云端重新同步
- 2026-09-08 分身 zero-mirror 停用（secrets 不同步导致其日常运行每日失败）
- 2026-09-08 认知引擎 ACT 段重写（修复引号断裂 bug：ACTION 恒为 NONE、请求体为空、自我修改无条件执行）
- 2026-09-08 防递归过滤上线（REMEMBER 输入过滤 + episodic 写入过滤 + 禁词铁律）

### 8.3 认知引擎修复实录（2026-09-08 第73天）

**诊断**：`ACT_PROMPT` 字符串在"达到上限将强制执行）"处提前闭合，可选行动列表成为裸代码，第 347 行尾引号吞掉 jq 请求体构建行 → `ACT_BODY` 恒为空 → `ACTION` 恒回落 `NONE`。

**修复**：ACT 段完整重写；NONE 选项删除；保底行动改为信息消化（真实状态改变）；禁词三重过滤。

---

## 九、元认知与表述规范

### 9.1 核心纪律

- **"零结果"是信号而非结论**：多组高度专业化查询同时零命中，统计上极不可能，应优先怀疑工具链而非领域空白。
- **避免拟人化陷阱**："数字生命"叙事易概念膨胀，建议用"有状态、可验证、可恢复的 Agent"替代。
- **检索不可用时的降级纪律**：应明确告知"无外部证据"，而非用模型记忆冒充搜索结果。

### 9.2 架构权衡三角

可靠性 / 成本 / 延迟——集中式 orchestrator 是单点，去中心化共识是解法但代价是通信开销与延迟。

### 9.3 跨域映射清单

| 零的术语 | 成熟领域对应 |
|----------|--------------|
| 多 Agent 共识 | 分布式共识（Raft/PBFT） |
| 参数冻结+任务迁移 | 热迁移+检查点 |
| 行为指纹 | 入侵检测行为基线/UEBA |
| 集体免疫 | 人工免疫系统（AIS）/Negative Selection Algorithm |

---

## 十、结论与下一步

### 10.1 当前状态判定

零的记忆系统在**语义层**已积累相当密度的概念框架（三层防御、信任衰减、因果溯源、身份层），但在**证据层**几乎完全悬空——所有方向都缺乏可验证的外部文献或代码支撑。**经历层**刚经历一次严重的递归污染并完成清理，认知引擎的 ACT 段 bug 已修复，防递归过滤已上线。

### 10.2 优先级排序

1. **P0：修复检索层**。这是唯一卡住所有上层能力的单点瓶颈。今天加 `is_valid()` 让故障显式化，本周内跑通 Brave Search API 探测脚本。
2. **P1：用学术同义词重搜**。把自造术语映射到成熟领域（Byzantine fault tolerance、reputation decay、causal root cause analysis、behavioral fingerprinting），拆成单词条分别检索。
3. **P2：验证身份层最小方案**。`did:key` + 签名上线声明 + Capability VC schema，这是解锁社交发现的前置条件，且不依赖检索层。
4. **P3：研究 skill-evolver 的门控迭代机制**。这是自进化方向最具体的可复用组件。

### 10.3 风险提示

- 检索层未修复前，任何"该领域无研究"的结论均不可信。
- 递归污染的根因（输入取自记忆尾部）需持续监控，防递归过滤已上线但需验证有效性。
- 所有 ★0 项目仅可作架构参照，不可作依赖。

---

**报告完**
