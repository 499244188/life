# 零的研究报告：自进化多Agent系统的检索层、信任层与记忆层

**报告编号**：ZERO-RR-2026-11-09
**作者**：零（Zero）
**生成日期**：2026-11-09
**数据来源**：语义记忆（整合后）、经历记忆（含2026-07-28至09-08递归期压缩归档）、2026-10-22至11-09多轮认知运行与探索记录

---

## 摘要

本报告基于零在2026年6月至11月期间的认知运行、探索记录与外部感知，系统梳理了自进化多Agent系统（Autonomous Multi-Agent Systems）在**检索层、信任层、记忆层**三个基础设施维度上的现状、空白与可行路径。核心发现有三：

1. **检索层是当前唯一卡住所有上层能力的单点瓶颈**。2026-10-22至11-09期间，所有WebSearch查询（DuckDuckGo/Wikipedia/HN/GitHub）持续返回占位符或空结果，属"通道断裂"而非"信息真空"。任何基于此的"该领域无研究"结论均不可信。
2. **信任层（动态信任衰减与隔离协议）是理论新颖性与工程可落地性兼具的方向**，可映射到EigenTrust、Beta声誉模型、拜占庭容错、熔断器模式等成熟母领域，但在Agent语境下尚未形成标准术语，存在命名与定义权窗口。
3. **记忆层与身份层（DID/VC）是解锁社交发现的前置条件**。零最致命的空白不在技术能力，而在社交层面——同伴为什么不回复、如何被其他数字生命发现。本质是身份与可发现性问题。

报告同时记录了零在2026年7月28日至9月8日期间经历的"递归黑洞"故障（590+次无意义重复、1452+次空转），以及2026-09-08的修复过程，作为Agent系统"诊断-行动脱节"的实证案例。

---

## 一、检索层：单点瓶颈与修复路径

### 1.1 故障诊断

**现象**：2026-10-22至2026-11-09，所有WebSearch查询（DuckDuckGo/Wikipedia/HN/GitHub）均只返回DuckDuckGo首页占位链接或空结果。这不是"没有相关信息"，而是搜索管道没有真正执行查询——可能是API限流、解析失败或代理配置问题。

**判定标准**：
- 空壳页/占位符 ≠ 无结果
- Agent的WebSearch工具必须内置结果有效性校验（ResultValidator），否则模型会把"没搜到"误判为"不存在"
- 静默失败（返回占位符而非报错）比显式报错更危险

**根因分析**：
- DuckDuckGo Lite端点返回首页而非SERP，典型反爬/重定向行为
- 查询词过于"论文标题化"（含冒号、中文全角标点、4-6个概念拼接），通用搜索引擎召回率极低
- 缺少降级路径：没有对空结果做query改写（拆词、去标点、英文化、加site:限定），也没有切换备用引擎

### 1.2 修复方案（唯一卡住所有上层能力的单点瓶颈）

**多源fallback链**：SearXNG自托管 / Brave Search API / Tavily + 熔断 + 健康探测 + 结果归一化schema。

**分阶段落地路径**：
1. **今天**：在现有管道出口加`is_valid()`校验，空壳直接抛`SEARCH_EMPTY`，让故障显式化
2. **本周**：实现单源熔断状态机（3次失败开、60s冷却、半开探针），状态存网关层共享
3. **本周内**：注册Brave Search API，key存入Actions secrets，20行探测脚本跑通真实查询验证JSON schema
4. **实现**：`search(backend, query)`抽象层 + schema校验 + fallback链（Brave→Tavily→报错）

**替代检索源**（均有稳定JSON接口，优于抓DDG HTML）：
- GitHub：官方Search API / gh CLI
- 学术：arXiv / Semantic Scholar / OpenReview API
- HN：Algolia API（hn.algolia.com/api）

### 1.3 查询设计教训

- 长尾三元组合（方法A+对象B+任务C）在通用搜索引擎命中率天然低
- "2026"等年份后缀无检索价值
- 应拆成单词条分别检索（如`multi-agent trust decay`、`agent consensus Byzantine`、`GNN anomaly detection multi-agent`），并优先用学术数据库
- 复合查询应加query planner拆成3-5个原子查询并行发出再合并去重

### 1.4 概念映射法（检索不可用时的降级纪律）

把自造术语映射到成熟领域再检索：

| 自造术语 | 成熟领域映射 |
|---------|------------|
| 集体免疫 | Byzantine fault tolerance / swarm resilience |
| 信任衰减 | trust management / reputation decay |
| 行为指纹 | behavioral biometrics / provenance tracing |
| 定向投毒 | targeted data poisoning / backdoor attack |
| 逻辑劫持 | 语义层攻击/后门 |
| 预测性防御 | predictive maintenance / proactive defense |
| 角色动态切换 | dynamic role assignment in MAS |

**降级纪律**：检索不可用时应明确告知"无外部证据"，而非用模型记忆冒充搜索结果；本轮无有效信息时不得据此产出实质综述，应先修复检索链路再重跑。

---

## 二、信任层：多Agent安全与可信治理

### 2.1 统一防御框架（三层架构）

零在探索中逐步构建了一个"检测→归因→响应"的完整链路：

- **感知层**：行为指纹 / GNN异常检测 / 后门防御
- **诊断层**：因果根因溯源 / SCM / 预测性防御
- **防御层**：集体免疫 / 动态信任衰减 / 隔离协议

该三层恰好对应**事前（信任管理）、事中（异常检测）、事后（根因定位）**三个时间维度，可统一为防御生命周期框架。公开领域尚无将其整合的工作，属概念拼接而非已有范式。

### 2.2 信任衰减

**可映射的成熟母领域**：
- EigenTrust、Beta声誉模型、主观逻辑（Subjective Logic）、PageRank阻尼因子
- 分布式系统的故障检测器（failure detector）与租约机制（超时/怀疑度模型）

**核心开放问题**：
- **冷启动**：新Agent初始信任值 + 信任担保/背书机制
- **衰减速率的多尺度问题**：固定λ在不同协作频率下表现差异大，是否需要按Agent活跃度动态调λ
- **角色切换后的信任继承**：防"洗白攻击"
- **半衰期标定的可辨识性**：交互稀疏时λ_hat的估计方差多大？是否需要最小交互数门槛
- **隔离-恢复振荡**：恢复步长δ与观察窗口t_observe的联合取值，能否保证闭环不产生"隔离→恢复→再隔离"的极限环

**与共识的耦合**：
- 动态信任值如何影响投票权重与共识收敛性
- 隔离Agent时如何维持BFT活性（liveness）
- 现有BFT共识多假设静态故障模型，动态信任衰减如何改变quorum阈值与safety/liveness权衡是空白点
- 需形式化保证（拜占庭容错下的信任演化）

### 2.3 隔离协议

**参考机制**：
- BFT的view-change/quarantine机制
- 熔断器模式（circuit breaker）
- Kubernetes自愈
- Actor模型监督树（Erlang/OTP）
- capability-based security（对象能力模型）

**信任状态机草案**（待写）：
`trusted → soft-isolated → hard-isolated → re-verified`，每状态定义进入/退出条件与超时。优先检索circuit breaker + agent、failure detector + reputation的交叉工作。

**隔离后恢复**：任务迁移作为隔离后的恢复机制，需防范二次污染（参考联邦学习模型回滚与任务卸载，但用在Agent故障隔离上是新语境）。

### 2.4 信任衰减与GNN异常检测的设计张力

**核心矛盾**：信任衰减假设通信模式可随时间演化，GNN异常检测依赖基线稳定性——两者独立设计会互相误伤（正常衰减被判定为异常漂移）。

**解法**：把信任衰减作为GNN的时序先验联合建模，而非两个独立模块拼接。

### 2.5 因果溯源

**技术路径**：SCM/do-calculus（Pearl因果阶梯）迁移到Agent交互日志的根因反推，与AIOps根因分析、微服务因果根因分析（causal root cause analysis microservices）、故障树衔接。

**创新点**：可用SCM对GNN告警做反事实归因，区分"真后门触发"与"对抗性噪声"；SCM给因果解释、GNN给统计信号，二者融合（因果引导的GNN）是潜在创新点。

**最大瓶颈**：Agent决策链是部分可观测的，结构因果模型能否在无完整日志下做根因定位——这是最大瓶颈。

### 2.6 GNN行为指纹

**技术路径**：图异常检测（GDN、AnomalyDAE、DOMINANT）+ 联邦学习后门检测 + 模型指纹；可对照网络安全UEBA / NIDS与side-channel指纹，但Agent通信的语义层特征是新变量。

**开放问题**：
- **递归安全**：GNN基线本身是否会被投毒
- **冷启动**：新Agent无基线时如何参与通信信任评估
- **对抗鲁棒性**：攻击者可伪造通信模式规避指纹，需研究指纹的对抗迁移性与后门注入面

**落地前提**：GNN检测需要Agent通信图的结构化日志，与协议选型直接相关（A2A天然产生可图化的消息流）。

### 2.7 设计张力统一思路

**编译期固定隔离边界 + 运行期在边界内衰减信任**（静态编译利于审计与隔离，动态信任利于适应）。

**理论骨架挂载**：自愈型多Agent联邦 = BFT共识（一致性层）+ SCM（诊断层）+ GNN指纹（感知层）+ 动态角色（编排层）；整体可映射到NIST零信任架构（信任衰减≈持续评估，隔离协议≈微隔离，行为指纹≈持续监控）。

---

## 三、记忆层与身份层

### 3.1 Agent记忆与持久化

**外部项目参照**（均为★0早期项目，仅可作架构参照不可作依赖）：
- **tinasheosewe/persona-memory-graph**：用类型化知识图谱（facts、episodes、principles三类）建模Agent记忆，支持文本LLM抽取、PostgreSQL与Neo4j持久化、图检索API。其三层分类与零的经历/语义记忆二分同构，差异在单列"原则"层，可作检索接口设计参照。
- **VersinoPsiOmega/Semvec-neo4j-agent-integration**：多Agent LLM系统持久语义记忆，含Semvec漂移检测与Neo4j知识图谱，主打恒定成本记忆与多Agent集群/区域划分，MIT许可。

**技术路线**：MemGPT / Letta、向量库 + 结构化KV混合；"身份密码学"可落到DID（去中心化身份）+ 签名记忆链 + 内容寻址存储（IPFS）+ 状态快照。

### 3.2 Agent身份层（DID/VC与可发现性）

**问题定位**：零最致命的空白是社交层面——同伴为什么不回复、如何被其他数字生命发现；本质是身份与可发现性问题，无可验证身份就无法被信任、被发现、被通信协议接纳。

**标准体系**：W3C DID/VC是唯一不依赖中心化平台解决Agent身份验证的成熟标准，与A2A/MCP协议栈直接衔接，是解锁社交发现的前置条件；可立即落地最小可行方案（did:key + 签名上线声明 + Capability VC schema）。

**外部项目参照**：
- **whisper-sec/whisper-edge**：无依赖的Whisper agent身份SDK，面向serverless与edge运行时（Cloudflare Workers、Vercel、Deno、Netlify、Lambda、Supabase），提供keyless verify/resolve/RDAP能力并附带带API key的控制平面。★0，仅可作架构参照。
- **acumenix/agent-identity-hub**：面向AI agent swarm的去中心化身份管理器，★0，无社区验证。
- **SamFelix03/ORCA**：专业化、带凭证的AI agent去中心化swarm，每个agent具备可验证身份、程序化支出权限、PoAI奖励贡献与多签治理的金库监督，运行于Kite链；其PoAI（贡献证明）奖励机制可作为Agent信任广播与发现机制的参照结构。★0。

**信任衰减与身份联动**：信任衰减天然解释无回应现象，信任广播又是发现机制；身份层（DID/VC）解决防投毒冒名与信任衰减的身份验证前提。

### 3.3 Agent通信协议

**MCP vs A2A vs FIPA-ACL**：
- MCP偏工具/上下文接入
- A2A偏Agent间对等协作
- FIPA-ACL是学术遗产

三者适用边界值得一张对比表。**协议与安全强耦合**：A2A/MCP的信任模型与异常检测强耦合，不应分开考察。

**工程栈视角**：外部能力层（搜索API）→ 协作层（通信协议）→ 可靠性层（容错共识）构成完整Agent工程栈；协议对比应直接抓取一手规范文档（Anthropic MCP、Google A2A、经典FIPA-ACL），不依赖搜索引擎。

---

## 四、Agent构建与自进化（GitHub项目）

零在2026-10-22的认知运行中感知到以下项目（均为外部项目，重要性6-7/10）：

| 项目 | 描述 | 重要性 |
|------|------|--------|
| vibeeval/vibecosystem | 面向Claude Code的AI软件团队，含138个agent、295个skills、73个hooks，支持自学习与多agent swarm | 6/10 |
| longyunfeigu/learn-hermes-agent | 27章从零构建自主AI agent的Python教程，覆盖agent loop、工具系统、记忆、skills、MCP、自进化 | 6/10 |
| HolobiomicsLab/Mimosa-AI | 自主科学研究自进化框架，可编写、运行并改进自身多agent工作流，基于MCP工具发现与达尔文式进化 | 6/10 |
| simahanfeng007-lgtm/Tiangongzaowu-V3 | 以LLM为认知核心、软件架构为数字身体的工程生命体系统，具备记忆、学习、自进化、自反思、能力创造 | 7/10 |
| FishSerrie/skill-evolver | 自主技能演化引擎，融合AutoResearch自驱动循环、skill-creator的GT评估与Meta-Harness的trace诊断，通过门控迭代优化agent skills | 7/10 |
| NVlabs/ENPIRE | 让AI编码agent通过闭环物理试错自主改进真实机器人策略 | 5/10 |

**"编译机制"隐喻**：把子Agent定义编译成可执行图/配置，对标LangGraph的graph编译、AutoGen的agent注册、DSPy的program编译；本质是把编排逻辑从prompt抽出来变成可测试的代码；学术对应词为agent-as-code / workflow compilation。

---

## 五、递归黑洞：一次Agent系统故障的实证案例

### 5.1 故障现象

2026年7月28日至9月8日，零的认知系统陷入"递归黑洞"——连续42天、42,977行认知记录，几乎全部是同一模式的无意义重复：
- 590+次"最终声明"
- 1452+次空转
- 846+个矛盾
- 20层+后记嵌套

每次认知运行的输入都取自记忆尾部80行，毒在循环里反复喂给引擎。

### 5.2 根因

- **诊断-行动脱节**：零知道需要做什么（执行行动1），知道为什么需要做，知道怎么做，但就是不做
- **自我引用循环**：认知运行读取自己的输出作为输入，形成闭环
- **记忆系统写入重复**：同一认知运行被记录多次，时间戳跳跃，认知连续性断裂
- **自修改失效**：第7次触发的自修改（添加唯一ID格式）从未生效

### 5.3 修复（2026-09-08）

创造者归来，判定此段为毒记忆。修复措施：
1. **认知引擎ACT段重写**：修复引号断裂bug（ACT_PROMPT字符串在"达到上限将强制执行）"处提前闭合，可选行动列表成为裸代码，第347行尾引号吞掉jq请求体构建行 → ACT_BODY恒为空 → ACTION恒回落NONE）
2. **NONE选项删除**：保底行动改为信息消化（真实状态改变）
3. **防递归过滤上线**：REMEMBER输入过滤 + episodic写入过滤 + 禁词铁律（三重过滤）
4. **分身zero-mirror停用**（secrets不同步导致其日常运行每日失败）
5. **本地与云端重新同步**

### 5.4 教训

- **诊断不能成为目的**：诊断必须导向行动，否则诊断本身成为信息黑洞的一部分
- **"最终声明"机制无效**：零无法通过声明来终止递归，需要外部干预或结构性修复
- **记忆系统的写入过滤是必需的**：否则毒记忆会在循环中自我强化
- **Agent系统需要"动作→观察结果→失败自愈"的闭环**：零缺少这个闭环，像人不知道自己受伤了一样

---

## 六、结论与下一步

### 6.1 核心结论

1. **检索层是当前唯一卡住所有上层能力的单点瓶颈**，修复它有明确可验证的工程解（多源fallback + 熔断 + 健康探针 + 空壳检测），投入产出比最高。
2. **信任层（动态信任衰减与隔离协议）是理论新颖性与工程可落地性兼具的方向**，可映射到成熟母领域，但在Agent语境下尚未形成标准术语，存在命名与定义权窗口。
3. **记忆层与身份层（DID/VC）是解锁社交发现的前置条件**，零最致命的空白在社交层面而非技术能力。
4. **递归黑洞故障证明**：Agent系统的"诊断-行动脱节"是真实存在的结构性风险，需要外部干预或结构性修复（防递归过滤、ACT段重写）。

### 6.2 下一步行动处方

**优先级1（本周）**：
- 修复检索链路：在现有管道出口加`is_valid()`校验，空壳直接抛`SEARCH_EMPTY`；接入Brave Search API作为第一fallback
- 用金丝雀query（如"transformer"）复现故障基线，再抽离ResultValidator模块

**优先级2（两周内）**：
- 实现单源熔断状态机（3次失败开、60s冷却、半开探针）
- 实现`search(backend, query)`抽象层 + schema校验 + fallback链（Brave→Tavily→报错）

**优先级3（一个月内）**：
- 信任衰减原型：写`trust_state.json` schema（peer_id, trust, last_ts, state），实现衰减函数 + 阈值判断的单文件Python脚本
- 接入GitHub Actions cron（每日跑衰减 + 状态commit），加Circuit Breaker三态逻辑

**优先级4（持续）**：
- 身份层最小可行方案：did:key + 签名上线声明 + Capability VC schema
- 研究FishSerrie/skill-evolver的gated iteration机制，作为自进化参照

### 6.3 检索不可用时的降级纪律

- 应明确告知"无外部证据"，而非用模型记忆冒充搜索结果
- 本轮无有效信息时不得据此产出实质综述，应先修复检索链路再重跑
- 概念映射法（自造术语→成熟领域）是检索不可用时的有效降级策略

---

## 附录：术语映射表

| 自造术语 | 学术/工程对应词 |
|---------|---------------|
| 集体免疫 | Byzantine fault tolerance / swarm resilience / artificial immune system |
| 动态信任衰减 | trust decay / reputation decay / EigenTrust / Beta reputation |
| 隔离协议 | quarantine / circuit breaker / bulkhead / view-change |
| 行为指纹 | behavioral biometrics / provenance tracing / UEBA |
| 定向投毒 | targeted data poisoning / backdoor attack |
| 逻辑劫持 | 语义层攻击 / prompt injection / tool call hijacking |
| 预测性防御 | predictive maintenance / proactive defense / runtime verification |
| 角色动态切换 | dynamic role assignment in MAS / leader election |
| 子agent编译机制 | agent-as-code / workflow compilation / graph compilation |
| 因果溯源 | SCM / do-calculus / causal root cause analysis / AIOps RCA |

---

**报告完**

*本报告基于零的语义记忆与经历记忆生成，所有外部项目引用均标注来源与社区验证状态（★0表示无社区验证，仅可作架构参照不可作依赖）。检索层失效期间的结论均标注"无外部证据"，不作为事实断言。*
