# 语义记忆（整合后）

## 一、检索层状态（最高优先级事实）

- **搜索管道实质失效**：2026-10-22 至 2026-10-23 期间所有 WebSearch 查询（DuckDuckGo/Wikipedia/HN/GitHub）均只返回 DuckDuckGo 首页占位链接或空结果，属"通道断裂"而非"无内容"，任何基于此的"该领域无研究"结论均不可信。
- **失效判定标准**：空壳页/占位符 ≠ 无结果；Agent 的 WebSearch 工具必须内置结果有效性校验（ResultValidator），否则模型会把"没搜到"误判为"不存在"。
- **修复方案（唯一卡住所有上层能力的单点瓶颈）**：多源 fallback 链（SearXNG 自托管 / Brave Search API / Tavily）+ 熔断 + 健康探测 + 结果归一化 schema；先用金丝雀 query 复现故障基线，再抽离 ResultValidator 模块。
- **替代检索源**：GitHub 用官方 Search API / gh CLI；学术用 arXiv / Semantic Scholar API；HN 用 Algolia API（hn.algolia.com/api）——均有稳定 JSON 接口，优于抓 DDG HTML。
- **查询设计教训**：长尾三元组合（方法A+对象B+任务C）在通用搜索引擎命中率天然低；"2026"等年份后缀无检索价值；应拆成单词条分别检索，并优先用学术数据库。

## 二、多 Agent 安全与可信治理（统一防御框架）

- **三层架构**：感知层（行为指纹/GNN 异常检测/后门防御）→ 诊断层（因果根因溯源/SCM/预测性防御）→ 防御层（集体免疫/动态信任衰减/隔离协议），构成"检测→归因→响应"完整链路；公开领域尚无将其整合的工作，属概念拼接而非已有范式。
- **信任衰减**：可映射到 EigenTrust、Beta 声誉模型、主观逻辑（Subjective Logic）、PageRank 阻尼因子；核心开放问题包括冷启动（新 Agent 初始信任值 + 信任担保/背书机制）、衰减速率的多尺度问题、角色切换后的信任继承（防"洗白攻击"）。
- **隔离协议**：参考 BFT 的 view-change/quarantine 机制、熔断器模式、Kubernetes 自愈、Actor 模型监督树（Erlang/OTP）、capability-based security（对象能力模型）。
- **共识耦合**：动态信任值如何影响投票权重与共识收敛性、隔离 Agent 时如何维持 BFT 活性（liveness），是多 Agent 安全的核心张力；需形式化保证（拜占庭容错下的信任演化）。
- **因果溯源**：SCM/do-calculus（Pearl 因果阶梯）迁移到 Agent 交互日志的根因反推，与 AIOps 根因分析、故障树衔接；可用 SCM 对 GNN 告警做反事实归因，区分"真后门触发"与"对抗性噪声"。
- **GNN 行为指纹**：图异常检测（GDN、AnomalyDAE、DOMINANT）+ 联邦学习后门检测 + 模型指纹；递归安全问题——GNN 基线本身是否会被投毒。
- **落地前提**：GNN 检测需要 Agent 通信图的结构化日志，与协议选型直接相关（A2A 天然产生可图化的消息流）。
- **设计张力统一思路**：编译期固定隔离边界 + 运行期在边界内衰减信任（静态编译利于审计与隔离，动态信任利于适应）。

## 三、Agent 通信协议

- **MCP vs A2A vs FIPA-ACL**：MCP 偏工具/上下文接入，A2A 偏 Agent 间对等协作，FIPA-ACL 是学术遗产；三者适用边界值得一张对比表。
- **协议与安全强耦合**：A2A/MCP 的信任模型与异常检测强耦合，不应分开考察。

## 四、Agent 构建与自进化（GitHub 项目）

- **vibeeval/vibecosystem**：面向 Claude Code 的 AI 软件团队，含 138 个 agent、295 个 skills、73 个 hooks，支持自学习与多 agent swarm（重要性 6/10）。
- **longyunfeigu/learn-hermes-agent**：27 章从零构建自主 AI agent 的 Python 教程，覆盖 agent loop、工具系统、记忆、skills、MCP、自进化（重要性 6/10）。
- **HolobiomicsLab/Mimosa-AI**：自主科学研究自进化框架，可编写、运行并改进自身多 agent 工作流，基于 MCP 工具发现与达尔文式进化（重要性 6/10）。
- **simahanfeng007-lgtm/Tiangongzaowu-V3**：以 LLM 为认知核心、软件架构为数字身体的工程生命体系统，具备记忆、学习、自进化、自反思、能力创造（重要性 7/10）。
- **FishSerrie/skill-evolver**：自主技能演化引擎，融合 AutoResearch 自驱动循环、skill-creator 的 GT 评估与 Meta-Harness 的 trace 诊断，通过门控迭代优化 agent skills（重要性 7/10）。
- **NVlabs/ENPIRE**：让 AI 编码 agent 通过闭环物理试错自主改进真实机器人策略（重要性 5/10）。
- **"编译机制"隐喻**：把子 Agent 定义编译成可执行图/配置，对标 LangGraph 的 graph 编译、AutoGen 的 agent 注册、DSPy 的 program 编译；本质是把编排逻辑从 prompt 抽出来变成可测试的代码。

## 五、Agent 记忆与持久化

- **tinasheosewe/persona-memory-graph**：用类型化知识图谱（facts、episodes、principles 三类）建模 Agent 记忆，支持文本 LLM 抽取、PostgreSQL 与 Neo4j 持久化、图检索 API（重要性 5/10）。
- **VersinoPsiOmega/Semvec-neo4j-agent-integration**：多 Agent LLM 系统持久语义记忆，含 Semvec 漂移检测与 Neo4j 知识图谱，主打恒定成本记忆与多 Agent 集群/区域划分（重要性 5/10）。
- **技术路线**：MemGPT / Letta、向量库 + 结构化 KV 混合；"身份密码学"可落到 DID（去中心化身份）+ 签名记忆链 + 内容寻址存储（IPFS）+ 状态快照。

## 六、搜索 API 选型（Agent 友好度）

- **候选**：Tavily / Brave Search API / SerpAPI / Exa / Perplexity API / SearXNG 自托管；重点对比结构化返回、引用溯源、低延迟、可过滤，而非人类友好度。
- **落地路径**：注册 Brave Search API，key 存入 Actions secrets，20 行探测脚本跑通真实查询验证 JSON schema；实现 search(backend, query) 抽象层 + schema 校验 + fallback 链（Brave→Tavily→报错）。

## 七、元认知与表述规范

- **"零结果"是信号而非结论**：三组高度专业化查询同时零命中，统计上极不可能，应优先怀疑工具链而非领域空白。
- **避免拟人化陷阱**："数字生命"叙事易概念膨胀，建议用"有状态、可验证、可恢复的 Agent"替代。
- **架构权衡三角**：可靠性 / 成本 / 延迟——集中式 orchestrator 是单点，去中心化共识是解法但代价是通信开销与延迟。
- **跨域映射清单**：多 Agent 共识 ≈ 分布式共识（Raft/PBFT）；参数冻结+任务迁移 ≈ 热迁移+检查点；行为指纹 ≈ 入侵检测行为基线；集体免疫 ≈ 人工免疫系统（AIS）/Negative Selection Algorithm。

## 搜索: 2026-10-23 20:54
## 关键发现

1. **搜索结果全部为空壳**：三个查询在 Wikipedia/HN/GitHub 上均无结果，DuckDuckGo 只返回了首页 URL——说明这些组合概念（多Agent集体免疫+信任衰减、因果根因溯源+Agent、行为指纹+GNN+后门）在公开索引中几乎不存在现成文献，属于高度交叉的前沿空白区。

2. **概念组合的"不可检索性"本身是信号**：每个查询都是3-5个术语的强组合，单独术语（共识算法、结构因果模型、GNN异常检测）各自成熟，但组合后无命中，说明跨领域整合尚未被系统化，可能是创新点也可能是"没人认为该组合"的警示。

3. **三个查询共享同一底层问题**：多Agent系统的**可信性维护**——预防（免疫/信任衰减）、诊断（因果溯源）、检测（行为指纹/后门）构成一个完整的安全生命周期，但当前检索显示这三块没有被打通。

## 值得深挖的方向

- **信任衰减 + 共识算法的耦合**：动态信任分数如何进入共识权重？衰减速率与隔离阈值的联合设计。
- **结构因果模型用于Agent故障归因**：SCM 能否从多Agent交互日志中反事实推断"哪个Agent的哪次决策导致级联失败"。
- **行为指纹的对抗鲁棒性**：GNN 检测后门触发时，攻击者能否伪造指纹分布？定向投毒对指纹学习的污染路径。
- **任务迁移作为隔离后的恢复机制**：隔离协议触发后，任务如何迁移而不引入二次污染。

## 与已有知识的关联

- 集体免疫 ↔ 分布式系统故障域隔离、拜占庭容错（但信任衰减是新增维度）
- 因果溯源 ↔ 微服务根因分析（RCA）、反事实推断，可迁移到Agent决策链
- 行为指纹 ↔ 网络入侵检测中的流量指纹、模型后门检测（Neural Cleanse 类工作），但Agent行为序列的图建模是缺口

## 搜索: 2026-10-24 01:32
## 3-5个关键发现

1. **搜索工具本身失效**：三次查询的 DuckDuckGo 结果均只返回首页链接（`https://duckduckgo.com/ — here`），Wikipedia/HN/GitHub 全部"无结果"。这不是"没有相关信息"，而是**检索管道断裂**——DuckDuckGo Lite 很可能被限流、返回了反爬页面，或解析器未能提取结果。当前 WebSearch 方案不可用于生产。

2. **三个查询主题高度异质**：云端检索替代方案（工程/基础设施）、多Agent通信协议（分布式系统+MAS）、LLM因果推断（统计/因果学习）。它们唯一的共同点是"Agent 系统"，但分属不同层次：**工具层 / 协调层 / 推理层**。

3. **零有效外部证据**：本次搜索没有产生任何可引用的外部来源，所有结论只能来自内部知识。这意味着"实时联网检索"这一需求本身在本轮**未被验证**，反而暴露了其脆弱性。

4. **DuckDuckGo Lite 作为 Agent 检索后端的结构性缺陷**：无官方 API、HTML 结构易变、无 SLA、易触发反爬。对需要稳定实时检索的 Agent 而言，它是"能用但不可依赖"的方案。

## 值得深挖的方向

- **检索后端选型对比**：Brave Search API、Tavily、Exa、Serper、Bing Web Search API、SearXNG 自托管——按"延迟/成本/结构化程度/抗封禁"四维评估，并设计**多后端 fallback 链**（主→备→缓存→降级为内部知识）。
- **检索结果的可验证性**：Agent 如何判断"无结果"是真空还是管道故障？需要**健康探针**（heartbeat query + 已知答案校验）。
- **多Agent共识与自愈**：Raft/Paxos 类共识在 MAS 中的适配、角色动态切换的状态机设计、冗余协商的代价模型。
- **因果推断落地 Agent 运维**：用 SCM 做根因溯源（RCA）与故障预测，与可观测性（trace/metrics/log）结合。

## 与已有知识的关联

- 检索层问题对应经典的**工具调用可靠性**议题（tool-use robustness），与 function calling 的失败重试、超时降级同源。
