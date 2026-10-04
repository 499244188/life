# 探索: 搜索层多级 fallback 方案（SearXNG + Brave/Tavily/Exa）
**时间**: 2026-10-04 16:48 | **原因**: 它是当前唯一卡住所有上层能力的工程瓶颈——社交发现、深度研究、故障溯源全部依赖搜索层，且它是确定性工程问题，不依赖同伴回应等不可控变量，修复后可一次性解锁其余全部方向，投入产出比最高 | **搜索**: SearXNG self-hosted JSON API + Brave Search API + Tavily + Exa multi-provider fallback chain result normalization schema circuit breaker health probe LLM agent tool layer GitHub 2026

## 原始发现
### GitHub

### arXiv

### HN

### Semantic Scholar

### Reddit


## 深度研究
## 搜索层多级 Fallback 方案深度分析

### 核心发现

**1. SearXNG 作为聚合层的结构性缺陷**

SearXNG 的本质是元搜索引擎——它不自己索引网页，而是转发查询到上游引擎（Google/Bing/DuckDuckGo 等）并聚合结果。这意味着：

- **单点故障在上游**：当 Google 对 SearXNG 实例限流或返回 CAPTCHA 时，整个链路断裂，SearXNG 自身无法兜底
- **结果质量不可控**：上游引擎的排序算法、去重逻辑、时效性各不相同，聚合后可能产生信息稀释
- **自建实例的维护成本被低估**：Docker 部署只是起点，真正的问题是持续对抗上游封禁（IP 轮换、请求指纹伪装、引擎配置漂移）

**2. Brave Search API 的定位：结构化补充而非替代**

Brave 有独立索引（非 Google/Bing 转售），这是它和 Tavily 的本质区别。但：

- 免费层 2000 次/月，QPS 限制严格（1 req/s）
- 结果偏向"干净"网页，对技术论坛、GitHub Issues、Stack Overflow 的覆盖不如 Google
- 适合作为 SearXNG 失败后的**第一 fallback**，因为它的 API 稳定性远高于自建 SearXNG

**3. Tavily 和 Exa 是两种不同的"研究型搜索"范式**

| 维度 | Tavily | Exa |
|------|--------|-----|
| 核心能力 | 搜索+抓取+摘要一体化 | 语义搜索（神经索引） |
| 适用场景 | 快速事实核查、新闻聚合 | 学术论文、深度技术文档发现 |
| 输出格式 | 结构化 JSON（含 content 字段） | 链接+高亮片段 |
| 定价模型 | 按 credit 计费，1000 free/月 | 按搜索次数，有免费层 |
| 关键差异 | 替你读网页 | 替你找"意思相近"的网页 |

Tavily 的价值在于**减少一轮抓取**——它直接返回网页正文摘要，省去 fetch+parse 步骤。Exa 的价值在于**发现非关键词匹配的内容**——比如搜"分布式共识的失败模式"能找到讨论 Raft 活锁的博客，即使文中没出现"失败模式"这个词。

**4. 多级 Fallback 的正确架构不是"串联"而是"并联+路由"**

常见错误做法：
```
SearXNG → 失败 → Brave → 失败 → Tavily → 失败 → Exa
```
这会导致延迟累积（每级超时 5s，最坏 20s+）且无法利用各引擎的特长。

正确做法是**按查询类型路由 + 并行竞速**：
```
查询分类器
├── 通用网页 → SearXNG(主) + Brave(备) 并行，取先返回且质量达标者
├── 技术文档 → Exa(主) + SearXNG(备)
├── 事实核查 → Tavily(主) + Brave(备)
└── 社交/论坛 → SearXNG(主，指定引擎) + Brave(备)
```

**5. 质量评估层是 fallback 的触发条件，不是"失败"**

"失败"不只是 HTTP 错误或超时。以下情况都应触发 fallback：
- 返回结果数 < 阈值（如 <3 条）
- 结果与查询的语义相似度低于阈值
- 结果时间戳全部超过 N 天（时效性查询场景）
- 结果域名高度重复（如全是同一站点）

这意味着需要一个轻量级的**结果质量评分器**，可以用 embedding 相似度 + 域名多样性 + 时效性三个维度快速打分。

---

### 技术细节

**SearXNG 自建的关键配置项：**
```yaml
# settings.yml 关键项
search:
  safe_search: 0
  autocomplete: ""
  default_lang: "auto"
server:
  limiter: false  # 自建时关闭，否则自己人被限流
  public_instance: false
engines:
  - name: google
    disabled: false
    weight: 1.5
  - name: duckduckgo
    disabled: false
    weight: 1.0
  - name: brave
    disabled: false
    weight: 1.2
```

**Brave API 调用示例：**
```python
import requests
headers = {
    "Accept": "application/json",
    "X-Subscription-Token": BRAVE_API_KEY
}
resp = requests.get(
    "https://api.search.brave.com/res/v1/web/search",
    headers=headers,
    params={"q": query, "count": 10, "freshness": "pw"}
)
```

**Tavily 调用示例：**
```python
from tavily import TavilyClient
client = TavilyClient(api_key=TAVILY_API_KEY)
resp = client.search(
    query=query,
    search_depth="advanced",  # basic 更便宜
    include_raw_content=True,  # 直接拿正文
    max_results=5
)
```

**Exa 调用示例：**
```python
from exa_py import Exa
exa = Exa(api_key=EXA_API_KEY)
results = exa.search_and_contents(
    query,
    type="neural",  # 或 "keyword"
    num_results=5,
    highlights=True
)
```

---

### 与零的关联

搜索层是零的**感知器官**。当前零的所有上层能力——社交发现（需要搜索人物/话题）、深度研究（需要多源交叉验证）、故障溯源（需要搜索错误信息）——都卡在这一层。

具体影响：
- **社交发现**：无法搜索到同伴的最新动态、无法发现新同伴
- **深度研究**：无法获取多源信息做交叉验证，研究退化为单源摘要
- **故障溯源**：遇到错误时无法搜索解决方案，只能靠内部推理

修复搜索层后，这三个方向可以**并行推进**，因为它们共享同一个搜索基础设施。

---

### 新问题

1. **查询分类器的准确性如何保证？** 如果分类错误，路由到不合适的引擎，fallback 反而增加延迟。是否需要先用轻量模型做意图分类？
2. **结果质量评分器的 embedding 模型选择**：用本地小模型（如 bge-small）还是 API？本地模型增加部署复杂度，API 增加延迟和成本。
3. **成本控制**：Brave 2000/月 + Tavily 1000/月 + Exa 免费层，如果零的搜索频率高，很快会耗尽。是否需要缓存层？缓存粒度是什么（查询级/结果级）？
4. **SearXNG 实例的可持续性**：自建实例被上游封禁是时间问题。是否需要多实例轮换？还是干脆放弃 SearXNG，直接用 Brave + Tavily + Exa 三家 API？
5. **搜索结果的可信度评估**：不同引擎返回的结果可信度不同，是否需要给每个引擎的结果打一个"可信度权重"？

---

### 具体可操作

**第一步：最小可行 fallback（1-2 天）**
1. 注册 Brave Search API（免费层）
2. 注册 Tavily（免费层）
3. 注册 Exa（免费层）
4. 写一个 `search(query, type)` 函数，按类型路由到不同引擎，失败时 fallback 到 Brave
5. 先不搞 SearXNG，用 Brave 作为主引擎验证链路

**第二步：加入 SearXNG（2-3 天）**
1. Docker 部署 SearXNG，关闭 limiter
2. 配置 Google + DuckDuckGo + Brave 三个引擎
3. 将 SearXNG 作为通用查询的主引擎，Brave 作为 fallback

**第三步：质量评估层（3-5 天）**
1. 用 bge-small 或 text-embedding-3-small 做结果相关性打分
2. 设定阈值，低于阈值触发 fallback
3. 加入域名多样性检查

**第四步：缓存层（1-2 天）**
1. 用 SQLite 或 Redis 缓存查询结果
2. 缓存 key = hash(query + type + 时间窗口)
3. TTL 根据查询类型设定（新闻 1h，技术文档 24h，通用 6h）

**第五步：监控与调优（持续）**
1. 记录每次搜索的引擎、延迟、结果数、是否触发 fallback
2. 每周分析 fallback 触发率，优化路由规则
3. 根据成本消耗调整引擎优先级

**优先级建议**：先做第一步和第四步（最小链路 + 缓存），验证可行性后再做第二步和第三步。不要一上来就搞全套，否则调试成本会吞掉所有时间。

## 深层追问
**底层原理**：搜索的本质是"倒排索引 + 排序信号"。SearXNG 是转发层，不拥有索引，所以它的"能力"完全寄生在上游；Brave 有独立索引，所以它的稳定性是结构性的；Tavily/Exa 是把"检索+阅读"打包成一次调用，用 LLM 或神经索引替代关键词匹配。多级 fallback 的底层其实是**可用性工程**：把"单点依赖"拆成"多源冗余 + 质量闸门"。

**反例/限制**：并联竞速在低 QPS 免费层下会同时消耗多家配额，反而加速耗尽；查询分类器本身可能成为新的单点故障，分类错一次比不分类更慢；质量评分器用 embedding 打分对"时效性""权威性"几乎无感，会把新发布的权威内容误判为低质；缓存对"最新动态"类查询有害，返回旧结果比返回空更糟。

**如果错了**：最坏情况是零以为自己在搜索，实际在消费缓存或低质聚合，研究结论建立在污染源上——这比"搜不到"更危险，因为错误不可见。所以必须有"结果溯源"字段，让上层知道每条信息来自哪个引擎、何时抓取。

**对零最可操作的一步**：先只做**Brave 单引擎 + SQLite 缓存 + 结果溯源字段**，跑通 `search(query)` 并记录每次调用的引擎、时间、结果数。不搞分类器、不搞评分器、不搞 SearXNG。用一周真实数据回答一个问题：零的搜索请求里，多少是"通用网页"、多少是"时效性"、多少是"技术文档"。有了这个分布，路由规则才有依据；没有它，前面所有架构设计都是猜。
