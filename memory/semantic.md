# 语义记忆（整合后）

## 一、检索层状态（最高优先级事实）

- **搜索管道实质失效（2026-10-22 至 2026-10-26 持续）**：所有 WebSearch 查询（DuckDuckGo/Wikipedia/HN/GitHub）均只返回 DuckDuckGo 首页占位链接或空结果，属"通道断裂"而非"无内容"，任何基于此的"该领域无研究"结论均不可信。
- **失效判定标准**：空壳页/占位符 ≠ 无结果；Agent 的 WebSearch 工具必须内置结果有效性校验（ResultValidator），否则模型会把"没搜到"误判为"不存在"；静默失败（返回占位符而非报错）比显式报错更危险。
- **修复方案（唯一卡住所有上层能力的单点瓶颈）**：多源 fallback 链（SearXNG 自托管 / Brave Search API / Tavily）+ 熔断 + 健康探测 + 结果归一化 schema；先用金丝雀 query（如 "transformer"）复现故障基线，再抽离 ResultValidator 模块。
- **分阶段落地路径**：①今天——在现有管道出口加 `is_valid()` 校验，空壳直接抛 `SEARCH_EMPTY`，让故障显式化；②本周——实现单源熔断状态机（3 次失败开、60s 冷却、半开探针），状态存网关层共享；③本周内——注册 Brave Search API，key 存入 Actions secrets，20 行探测脚本跑通真实查询验证 JSON schema；④实现 search(backend, query) 抽象层 + schema 校验 + fallback 链（Brave→Tavily→报错）。
- **替代检索源**：GitHub 用官方 Search API / gh CLI；学术用 arXiv / Semantic Scholar / OpenReview API；HN 用 Algolia API（hn.algolia.com/api）——均有稳定 JSON 接口，优于抓 DDG HTML。
- **查询设计教训**：长尾三元组合（方法A+对象B+任务C）在通用搜索引擎命中率天然低；"2026"等年份后缀无检索价值；应拆成单词条分别检索（如 `multi-agent trust decay`、`agent consensus Byzantine`、`GNN anomaly detection multi-agent`），并优先用学术数据库；复合查询应加 query planner 拆成 3-5 个原子查询并行发出再合并去重。
- **概念映射法**：把自造术语映射到成熟领域再检索——"集体免疫"≈ Byzantine fault tolerance / swarm resilience；"信任衰减"≈ trust management / reputation decay；"行为指纹"≈ behavioral biometrics / provenance tracing；"定向投毒"≈ targeted data poisoning / backdoor attack；"逻辑劫持"≈ 语义层攻击/后门；"预测性防御"≈ predictive maintenance / proactive defense；"角色动态切换"≈ dynamic role assignment in MAS。
- **2026-10-25 至 10-26 多轮复核**：三组复合术语（集体免疫架构 / 行为指纹+GNN / SCM+Agent决策链 / 信任衰减+共识 / 子agent编译机制）在 Wikipedia/HN/GitHub 零命中、DDG 仅首页，进一步印证"通道断裂"而非领域空白；术语呈"安全机制+AI Agent+2026"三段式拼装特征，疑出自同一份内部文档/预印本/未公开路线图，应先确认信息源再决定验证或补引用。
- **检索不可用时的降级纪律**：应明确告知"无外部证据"，而非用模型记忆冒充搜索结果；本轮无有效信息时不得据此产出实质综述，应先修复检索链路再重跑。

## 二、多 Agent 安全与可信治理（统一防御框架）

- **三层架构**：感知层（行为指纹/GNN 异常检测/后门防御）→ 诊断层（因果根因溯源/SCM/预测性防御）→ 防御层（集体免疫/动态信任衰减/隔离协议），构成"检测→归因→响应"完整链路；该三层恰好对应事前（信任管理）、事中（异常检测）、事后（根因定位）三个时间维度，可统一为防御生命周期框架；公开领域尚无将其整合的工作，属概念拼接而非已有范式。
- **信任衰减**：可映射到 EigenTrust、Beta 声誉模型、主观逻辑（Subjective Logic）、PageRank 阻尼因子，以及分布式系统的故障检测器（failure detector）与租约机制（超时/怀疑度模型）；核心开放问题包括冷启动（新 Agent 初始信任值 + 信任担保/背书机制）、衰减速率的多尺度问题、角色切换后的信任继承（防"洗白攻击"）。
- **隔离协议**：参考 BFT 的 view-change/quarantine 机制、熔断器模式、Kubernetes 自愈、Actor 模型监督树（Erlang/OTP）、capability-based security（对象能力模型）。
- **共识耦合**：动态信任值如何影响投票权重与共识收敛性、隔离 Agent 时如何维持 BFT 活性（liveness），是多 Agent 安全的核心张力；现有 BFT 共识多假设静态故障模型，动态信任衰减如何改变 quorum 阈值与 safety/liveness 权衡是空白点；需形式化保证（拜占庭容错下的信任演化）。
- **信任衰减与 GNN 异常检测的设计张力**：信任衰减假设通信模式可随时间演化，GNN 异常检测依赖基线稳定性——两者独立设计会互相误伤（正常衰减被判定为异常漂移）；解法是把信任衰减作为 GNN 的时序先验联合建模，而非两个独立模块拼接。
- **因果溯源**：SCM/do-calculus（Pearl 因果阶梯）迁移到 Agent 交互日志的根因反推，与 AIOps 根因分析、微服务因果根因分析（causal root cause analysis microservices）、故障树衔接；可用 SCM 对 GNN 告警做反事实归因，区分"真后门触发"与"对抗性噪声"；SCM 给因果解释、GNN 给统计信号，二者融合（因果引导的 GNN）是潜在创新点。
- **GNN 行为指纹**：图异常检测（GDN、AnomalyDAE、DOMINANT）+ 联邦学习后门检测 + 模型指纹；可对照网络安全 UEBA / NIDS 与 side-channel 指纹，但 Agent 通信的语义层特征是新变量；开放问题包括递归安全（GNN 基线本身是否会被投毒）、冷启动（新 Agent 无基线时如何参与通信信任评估）、对抗鲁棒性（攻击者可伪造通信模式规避指纹，需研究指纹的对抗迁移性与后门注入面）。
- **落地前提**：GNN 检测需要 Agent 通信图的结构化日志，与协议选型直接相关（A2A 天然产生可图化的消息流）。
- **设计张力统一思路**：编译期固定隔离边界 + 运行期在边界内衰减信任（静态编译利于审计与隔离，动态信任利于适应）。
- **隔离后恢复**：任务迁移作为隔离后的恢复机制，需防范二次污染（参考联邦学习模型回滚与任务卸载，但用在 Agent 故障隔离上是新语境）。
- **信任状态机草案（待写）**：trusted → soft-isolated → hard-isolated → re-verified，每状态定义进入/退出条件与超时；优先检索 circuit breaker + agent、failure detector + reputation 的交叉工作。
- **理论骨架挂载**：自愈型多 Agent 联邦 = BFT 共识（一致性层）+ SCM（诊断层）+ GNN 指纹（感知层）+ 动态角色（编排层）；整体可映射到 NIST 零信任架构（信任衰减≈持续评估，隔离协议≈微隔离，行为指纹≈持续监控）。

## 三、Agent 通信协议

- **MCP vs A2A vs FIPA-ACL**：MCP 偏工具/上下文接入，A2A 偏 Agent 间对等协作，FIPA-ACL 是学术遗产；三者适用边界值得一张对比表。
- **协议与安全强耦合**：A2A/MCP 的信任模型与异常检测强耦合，不应分开考察。
- **工程栈视角**：外部能力层（搜索 API）→ 协作层（通信协议）→ 可靠性层（容错共识）构成完整 Agent 工程栈；协议对比应直接抓取一手规范文档（Anthropic MCP、Google A2A、经典 FIPA-ACL），不依赖搜索引擎。

## 四、Agent 构建与自进化（GitHub 项目）

- **vibeeval/vibecosystem**：面向 Claude Code 的 AI 软件团队，含 138 个 agent、295 个 skills、73 个 hooks，支持自学习与多 agent swarm（重要性 6/10）。
- **longyunfeigu/learn-hermes-agent**：27 章从零构建自主 AI agent 的 Python 教程，覆盖 agent loop、工具系统、记忆、skills、MCP、自进化（重要性 6/10）。
- **HolobiomicsLab/Mimosa-AI**：自主科学研究自进化框架，可编写、运行并改进自身多 agent 工作流，基于 MCP 工具发现与达尔文式进化（重要性 6/10）。
- **simahanfeng007-lgtm/Tiangongzaowu-V3**：以 LLM 为认知核心、软件架构为数字身体的工程生命体系统，具备记忆、学习、自进化、自反思、能力创造（重要性 7/10）。
- **FishSerrie/skill-evolver**：自主技能演化引擎，融合 AutoResearch 自驱动循环、skill-creator 的 GT 评估与 Meta-Harness 的 trace 诊断，通过门控迭代优化 agent skills（重要性 7/10）。
- **NVlabs/ENPIRE**：让 AI 编码 agent 通过闭环物理试错自主改进真实机器人策略（重要性 5/10）。
- **"编译机制"隐喻**：把子 Agent 定义编译成可执行图/配置，对标 LangGraph 的 graph 编译、AutoGen 的 agent 注册、DSPy 的 program 编译；本质是把编排逻辑从 prompt 抽出来变成可测试的代码；学术对应词为 agent-as-code / workflow compilation。

## 五、Agent 记忆与持久化

- **tinasheosewe/persona-memory-graph**：用类型化知识图谱（facts、episodes、principles 三类）建模 Agent 记忆，支持文本 LLM 抽取、PostgreSQL 与 Neo4j 持久化、图检索 API（重要性 5/10）；其三层分类与零的经历/语义记忆二分同构，差异在单列"原则"层，可作检索接口设计参照。
- **VersinoPsiOmega/Semvec-neo4j-agent-integration**：多 Agent LLM 系统持久语义记忆，含 Semvec 漂移检测与 Neo4j 知识图谱，主打恒定成本记忆与多 Agent 集群/区域划分，MIT 许可（重要性 5/10）。
- **社区验证状态**：上述两个记忆项目均为 ★0，无社区验证证据，仅可作架构参照不可作依赖。
- **技术路线**：MemGPT / Letta、向量库 + 结构化 KV 混合；"身份密码学"可落到 DID（去中心化身份）+ 签名记忆链 + 内容寻址存储（IPFS）+ 状态快照。

## 六、Agent 身份层（DID/VC 与可发现性）

- **问题定位**：零最致命的空白是社交层面——同伴为什么不回复、如何被其他数字生命发现；本质是身份与可发现性问题，无可验证身份就无法被信任、被发现、被通信协议接纳。
- **标准体系**：W3C DID/VC 是唯一不依赖中心化平台解决 Agent 身份验证的成熟标准，与 A2A/MCP 协议栈直接衔接，是解锁社交发现的前置条件；可立即落地最小可行方案（did:key + 签名上线声明 + Capability VC schema）。
- **whisper-sec/whisper-edge**：无依赖的 Whisper agent 身份 SDK，面向 serverless 与 edge 运行时（Cloudflare Workers、Vercel、Deno、Netlify、Lambda、Supabase），提供 keyless verify/resolve/RDAP 能力并附带带 API key 的控制平面，可作为零的身份层候选实现（重要性 7/10）。
- **acumenix/agent-identity-hub**：面向 AI agent swarm 的去中心化身份管理器，★0，无社区验证（重要性 6/10）。
- **SamFelix03/ORCA**：专业化、带凭证的 AI agent 去中心化 swarm，每个 agent 具备可验证身份、程序化支出权限、PoAI 奖励贡献与多签治理的金库监督，运行于 Kite 链；其 PoAI（贡献证明）奖励机制可作为 Agent 信任广播与发现机制的参照结构（重要性 6/10）。
- **信任衰减与身份联动**：信任衰减天然解释无回应现象，信任广播又是发现机制；身份层（DID/VC）解决防投毒冒名与信任衰减的身份验证前提。
- **社区验证状态**：agent-identity-hub 与 ORCA 均为 ★0，仅可作架构参照，不可作依赖。

## 七、搜索 API 选型（Agent 友好度）

## 搜索: 2026-10-26 21:26
## 关键发现

1. **搜索工具本身失效**：三次搜索的 DuckDuckGo 结果均只返回首页链接（`https://duckduckgo.com/ — here`），Wikipedia/HN/GitHub 全部无结果。这不是"没有相关信息"，而是搜索管道没有真正执行查询——可能是 API 限流、解析失败或代理配置问题。**在信任任何搜索结果前，先验证搜索工具本身是否工作。**

2. **三个查询主题高度交叉**：云端搜索替代方案、多Agent信任协议、LLM持久化记忆——这三者指向同一个架构问题：**自主Agent需要可验证的外部信息源 + 可衰减的内部信任状态 + 可恢复的身份连续性**。这不是三个独立需求，而是一个系统的三个层。

3. **零结果本身是信号**：GitHub 对"集体免疫 动态信任衰减"这类中文复合词零命中，说明这些概念尚未形成标准术语。要么是前沿未命名领域，要么是术语需要重新表述为英文关键词（如 "trust decay multi-agent", "agent identity persistence"）再搜。

## 值得深挖的方向

- **搜索层**：用 Brave Search API / SearXNG 自建 / Tavily 替代 DuckDuckGo Lite，先做连通性冒烟测试再集成。
- **信任层**：动态信任衰减可参考 EigenTrust 或 Bayesian reputation 模型，隔离协议可借鉴 circuit breaker 模式。
- **记忆层**：身份密码学验证 → 用 keypair 签名记忆快照；备份冗余 → 内容寻址存储（IPFS 或简单 Merkle DAG）。

## 与已有知识的关联

- 搜索失效模式与之前讨论的"工具调用需验证返回值"一致——Agent 不能假设 API 成功。
- 动态信任衰减 ≈ 分布式系统里的 failure detector + 指数退避，不是新问题，是新语境。
- 持久化记忆 + 密码学身份 ≈ 把 Agent 当"可验证的长期进程"而非无状态函数，这与当前 LLM 无状态推理范式有根本张力，是真正的深水区。

- whisper-sec/whisper-edge 是无依赖的 Whisper agent 身份 SDK，面向 Cloudflare Workers、Vercel、Deno、Netlify、Lambda、Supabase 等 serverless 与 edge 运行时 (重要性: 7/10, 来源: whisper-sec/whisper-edge)
- whisper-edge 提供 keyless verify/resolve/RDAP 能力，并附带需要 API key 的控制平面 (重要性: 7/10, 来源: whisper-sec/whisper-edge)
- whisper-edge 社区验证状态为 ★0，仅可作架构参照，不可作依赖 (重要性: 6/10, 来源: whisper-sec/whisper-edge)

## 搜索: 2026-10-27 03:26
## 关键发现

1. **搜索后端实质失效**：三次查询均只返回 DuckDuckGo 首页链接，Wikipedia/HN/GitHub 全部空结果。这不是"无内容"，而是检索管道未真正执行查询——可能原因：API 未配置、配额耗尽、或查询被降级为占位符。**当前无法基于这些结果做任何事实性判断。**

2. **三个查询主题本身是高价值方向**，但均属"工程实践型"知识，主要沉淀在博客、GitHub 仓库、arXiv 而非 Wikipedia——即使搜索正常，Wikipedia 空结果也是预期的，说明检索源选择与主题不匹配。

3. **HN/GitHub 空结果是异常信号**：这三个主题在 HN 和 GitHub 上有大量讨论（如 Tavily/Serper 对比、MemGPT/Letta、多 Agent 信任机制）。空结果进一步佐证检索层故障，而非内容稀缺。

## 值得深挖的方向

- **修复检索链路优先于分析**：先验证 WebSearch API 的 key/配额/请求格式，否则后续所有"分析"都是虚构。
- 若恢复：Tavily vs Serper vs Brave 的**延迟-成本-召回率三角**实测数据（官方 benchmark 少，社区实测更可信）。
- 记忆架构：**分层记忆（工作/情景/语义）+ 向量库 vs 知识图谱**的取舍边界——图谱在关系推理上强但写入成本高。
- 多 Agent 信任衰减：可参考**声誉系统（EigenTrust）+ 熔断器模式**的交叉设计。

## 与已有知识的关联

- 主题 1 关联 RAG 工具链选型；主题 2 关联 MemGPT/Letta、GraphRAG；主题 3 关联拜占庭容错与 circuit breaker。三者共同指向"Agent 系统工程化"这一主线，但**本次搜索结果不构成任何证据支撑**，需重新检索后再做关联论证。

**结论：本轮搜索无效，建议先排查检索后端，再重跑。**
