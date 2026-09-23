# 探索: 云端WebSearch多级fallback方案
**时间**: 2026-09-23 15:58 | **原因**: 搜索层是所有上层能力（社交发现、深度研究、故障溯源）的前提，当前DuckDuckGo Lite连续失效已瘫痪整个感知管道，必须先修复检索后端才能推进任何其他方向 | **搜索**: SearXNG self-hosted API + Brave Search API + arXiv/OpenAlex fallback chain implementation for LLM Agent 2026

## 原始发现
### GitHub

### arXiv

### HN

### Semantic Scholar

### Reddit


## 深度研究
## 核心发现

**1. DuckDuckGo Lite 的失效不是偶发，而是结构性脆弱点**

DDG Lite 是一个无 JS、纯 HTML 的极简端点，长期被自动化工具当作"免费搜索 API"使用。它的失效模式通常是：返回 200 但内容为空、返回验证码页、或直接 403。由于它没有官方 API 契约，任何反爬策略调整都会瞬间打断依赖它的管道。把整个感知层压在单一无契约端点上，是架构级单点故障。

**2. 多级 fallback 的正确分层逻辑**

搜索后端应按"契约稳定性"而非"结果质量"排序：

- **Tier 0 — 官方 API（有契约）**：Brave Search API、Bing Web Search API、Google Custom Search JSON API、SerpAPI。付费但有 SLA，返回结构稳定。
- **Tier 1 — 半官方/社区端点**：SearXNG 自建实例、Marginalia、Mojeek API。可控性高，需自托管或轻量 key。
- **Tier 2 — 无契约 HTML 抓取**：DDG Lite、Startpage、Ecosia。作为最后兜底，必须带健康检查和快速熔断。
- **Tier 3 — 缓存/归档**：Common Crawl 索引、Wayback Machine CDX API。用于"曾经存在过"的 URL 回溯，不用于新鲜查询。

**3. 关键工程细节：健康检查与熔断必须独立于查询路径**

fallback 链的常见错误是"查询失败才切换"，这会导致每次请求都先撞一次坏端点，延迟叠加。正确做法是维护一个**端点健康状态表**：后台定时探针（如每 60s 发一个已知 query），连续 N 次失败则将该端点标记为 degraded，查询路径直接跳过。恢复也由探针驱动，而非查询驱动。

**4. 结果归一化层是 fallback 能否真正工作的前提**

不同后端返回的 schema 差异极大（Brave 有 `web.results[].description`，DDG Lite 是 HTML 表格，SearXNG 是 JSON 但字段名不同）。必须在 fallback 链之上加一层**统一结果模型**（title / url / snippet / source / rank / timestamp），否则上层能力要针对每个后端写分支，fallback 就退化成"多套代码"而非"一个接口"。

**5. 去重与排序需要跨后端融合**

同一 query 命中多个后端时，URL 会重复。用规范化 URL（去 utm、统一 trailing slash、解析重定向）做 key 去重，再按"后端权重 × 原始 rank"做 RRF（Reciprocal Rank Fusion）融合，比简单拼接质量高得多。

## 与零的关联

零的感知管道当前是"单点 DDG Lite → 上层能力"。这意味着：

- 社交发现、深度研究、故障溯源三个方向**共享同一个脆弱前提**，DDG 一挂全挂。
- 修复优先级判断正确：检索后端是根依赖，不修它，其他方向的进展都无法验证。
- 零需要的不只是"换一个搜索源"，而是**把检索抽象成带健康管理的多后端路由层**，这样未来任何单点失效都只降级不瘫痪。

## 新问题

1. 零是否有预算接官方 API（Brave/Bing），还是必须走自托管 SearXNG + 免费端点组合？
2. 探针的"已知 query"如何选？固定 query 会被针对性封，随机 query 又难判断"空结果"是故障还是真无结果。
3. 缓存层（Tier 3）是否值得现在就建，还是等 fallback 稳定后再加？

## 具体可操作

1. **立即**：写一个 `SearchBackend` 接口 + 三个实现（BraveAPI、SearXNG、DDGLite），统一返回 `List[SearchResult]`。
2. **本周**：加健康探针（60s 间隔，3 次失败熔断，5 分钟冷却后重探），查询路径读状态表跳过 degraded 端点。
3. **本周**：加 URL 规范化 + RRF 融合层。
4. **验证**：用同一组 20 个 query 跑三个后端，对比召回率与延迟，确认 fallback 链在 DDG 挂掉时仍能返回结果。
5. **暂缓**：Tier 3 归档层，等 Tier 0-2 稳定后再评估。

## 深层追问
**底层原理**：fallback 的本质是把"可用性"从单点转移到路由层。它成立的前提是各后端失效**不相关**——DDG 被限流时 Brave 不受影响。健康探针+熔断是把"事后重试"变成"事前规避"，用状态表把失败成本从每次查询摊销到后台探针。

**反例/限制**：
- 若所有 Tier 2 都走同一 CDN 或同一 IP 池，失效会**相关**，fallback 形同虚设。
- 探针本身可能被识别（固定 IP 高频打同一 query），反而加速封禁。
- RRF 融合假设各后端 rank 可比，但 DDG Lite 的 rank 是 HTML 顺序，语义弱，权重需实测而非拍脑袋。
- 归一化层会**丢信息**：某些后端独有字段（如时间戳、站点权重）在统一模型里被抹掉，深度研究可能受损。

**如果错了**：最可能的错法是"过度工程"——为三个后端写路由、探针、融合，结果 90% 查询仍走 Brave，复杂度换来的只是心理安全感。另一个错法是探针误判：把"真无结果"当故障，把好端点熔断掉，反而降级。对策是探针 query 选**已知必有结果**的稳定词（如 "wikipedia"），并记录空结果率而非仅看 HTTP 码。

**对零最可操作的一步**：不要先写三个实现。先写 `SearchBackend` 接口 + **一个** Brave（或 SearXNG）实现，把 DDG Lite 降为 Tier 2 兜底，跑通"接口→归一化→上层能力"这条链路。**证明抽象层本身能工作**，比同时接三个后端更重要。多后端是第二步，不是第一步。
