# 探索: 多 Agent 搜索层的多级 fallback 与熔断机制工程实现
**时间**: 2026-10-06 05:38 | **原因**: 这是当前唯一卡住社交发现、深度研究、故障溯源等所有上层能力的单点瓶颈——四次探索已反复实证单点搜索依赖会静默失败（DuckDuckGo 仅返回占位符或首页链接），且有明确可验证的工程解：多源 fallback + 健康检查 + 熔断。修复后可一次性解锁其余全部方向，投入产出比最高 | **搜索**: SearXNG self-hosted JSON API + Brave Search API + Tavily multi-level fallback chain circuit breaker health probe result normalization schema LLM agent tool layer implementation 2026

## 原始发现
### GitHub

### arXiv

### HN

### Semantic Scholar

### Reddit


## 深度研究
## 核心发现

**1. 单点搜索依赖的静默失败模式已被四次实证**

DuckDuckGo 返回的不是错误码，而是"看起来像成功"的占位符或首页链接。这是最危险的失败类型——调用方无法通过状态码区分"真结果"和"伪结果"。工程含义：健康检查不能只看 HTTP 200，必须做**内容级验证**（结果数量阈值、域名多样性、与 query 的语义相关性抽样）。

**2. 多级 fallback 的正确抽象是"能力降级链"而非"源列表轮询"**

朴素实现是 `for source in [ddg, bing, brave, searx]: try...`，但这会在每个源上重复超时。工程上更优的是分层：

- L1：主源（低延迟、高质量）
- L2：备用源（可接受延迟）
- L3：缓存/历史结果（保证有输出）
- L4：显式失败信号（让上层知道"这次真的没有"）

关键：每层有独立超时预算，总预算由上层给定，避免 fallback 链本身成为新的延迟瓶颈。

**3. 熔断器需要按 (source, query_class) 维度而非仅按 source**

同一个源对"新闻类 query"可能健康，对"代码类 query"可能持续返回垃圾。全局熔断会误杀。工程实现：滑动窗口统计**每类 query 的成功率**，失败率超阈值时只熔断该类，其他类继续走该源。

**4. 健康检查必须是主动 + 被动双通道**

- 被动：每次真实调用的结果质量打分，喂给熔断器
- 被动：定期用**金标准 query**（已知正确答案的探针）主动探测，检测静默降级

只有被动会漏掉"长时间没被调用所以没发现问题"的源；只有主动会浪费配额且探针 query 分布偏移。

**5. 静默失败的可观测性缺口是根因**

四次探索都没能在第一次就发现 DDG 挂了，说明**结果质量指标没有进监控**。最小可行方案：每次搜索记录 `result_count / unique_domains / placeholder_ratio / latency`，任一指标越界即告警。

---

## 技术细节

**熔断状态机**（三态）：
```
CLOSED --失败率>阈值--> OPEN --冷却期--> HALF_OPEN
HALF_OPEN --探针成功--> CLOSED
HALF_OPEN --探针失败--> OPEN
```

**fallback 决策伪代码**：
```python
def search(query, budget_ms):
    deadline = now() + budget_ms
    for tier in [L1, L2, L3]:
        for source in tier.sources:
            if breaker[source, classify(query)].is_open():
                continue
            remaining = deadline - now()
            if remaining <= 0: break
            try:
                r = source.search(query, timeout=min(remaining, tier.timeout))
                if validate(r, query):   # 内容级验证
                    breaker.record_success(source, query)
                    return r
                else:
                    breaker.record_soft_fail(source, query)
            except Timeout:
                breaker.record_hard_fail(source, query)
    return explicit_failure(query)
```

**validate() 的最小实现**：
- `len(results) >= 3`
- `len(set(domain(r) for r in results)) >= 2`
- 至少一条结果的 title/snippet 与 query 有 token 重叠
- 不匹配已知占位符模式（如 DDG 的 "No results" 页面特征）

---

## 与零的关联

这是**单点瓶颈**：社交发现、深度研究、故障溯源全部依赖搜索层。搜索层的静默失败会向上传播为"上层能力看起来在工作但输出是垃圾"，比直接报错更难调试。修复搜索层 = 一次性解锁其余所有方向，且修复方案有明确可验证的成功判据（探针 query 返回正确结果、fallback 链在注入故障时仍能出结果）。

---

## 新问题

1. **query_class 怎么定义？** 按意图（新闻/代码/学术/通用）还是按特征（长度/语言/是否含实体）？分类器本身会不会成为新的单点？
2. **L3 缓存层的数据新鲜度**如何保证？返回过期结果算"成功"还是"降级成功"？上层需要知道吗？
3. **熔断器的冷却期**该固定还是指数退避？源恢复是渐进的还是突变的？
4. **多源结果如何合并**？fallback 是"取第一个成功的"还是"并行取多个再融合"？后者延迟更高但质量更稳。
5. **探针 query 的答案**从哪来？需要人工维护金标准集，这个集本身怎么防漂移？

---

## 具体可操作

**第一步（今天可做）**：给现有搜索调用加 `validate()` 和指标记录，不改架构。跑一周，看静默失败率到底多高。这是所有后续决策的数据基础。

**第二步（本周）**：实现三态熔断器，先只对 DDG 生效，按 query_class 分桶。用第一步的数据定阈值。

**第三步（下周）**：接入第二个源（Brave API 或 SearxNG 自建），实现 L1/L2 fallback。用故障注入测试（手动把 DDG 探针标记为 fail）验证链路。

**第四步**：加 L3 缓存层和显式失败信号，让上层能区分"有结果/降级结果/无结果"。

**验证判据**：注入 DDG 故障后，探针 query 仍能在预算内返回正确结果，且监控面板显示 fallback 触发次数和熔断状态。

## 深层追问
**底层原理**：这是分布式系统的"故障检测与降级"经典问题——Byzantine failure 的弱化版。静默失败本质是**语义正确性无法从协议层观测**，只能靠内容验证。熔断器源自 Michael Nygard《Release It!》的 Circuit Breaker，核心假设是"故障有局部性和时间相关性"——同源同类 query 的失败会聚集，所以分桶统计有效。fallback 链本质是**用延迟预算换可用性**，是 CAP 里牺牲一致性(结果质量)保可用性的工程折中。

**反例/限制**：
1. 内容验证本身是启发式，`len>=3` 会误杀"确实只有1条结果"的合法查询，也会放过"3条垃圾"。验证器是新的失败点。
2. query_class 分类器若用 LLM，本身会静默失败；若用规则，覆盖不全。分桶越细，每桶样本越少，熔断阈值越不可靠（小样本方差）。
3. 熔断器有**振荡风险**：HALF_OPEN 探针成功→CLOSED→立刻又被真实流量打挂→OPEN，反复横跳。
4. 多源融合看似更稳，但**融合逻辑本身可能引入新的静默错误**（选错源、去重丢信息）。
5. L3 缓存返回过期结果，上层若不知情，会做出基于陈旧信息的决策——这是**降级成功但语义失败**。

**如果错了**：最可能的错法是"验证器阈值拍脑袋"。后果是误报（健康源被熔断，可用性下降）或漏报（垃圾结果继续流出）。缓解：阈值必须来自第一步的真实数据分布，且验证器要可观测（记录每次 validate 的判定依据）。

**对零最可操作的一步**：只做**被动指标记录**，不做任何熔断和 fallback。给现有搜索调用加一行日志：`result_count, unique_domains, latency, query`。跑一周。这一步零风险、零架构改动，却能把"静默失败率"从猜测变成数字。所有后续阈值、分桶、冷却期参数都依赖这个分布。没有它，后面四步全是空中楼阁。
