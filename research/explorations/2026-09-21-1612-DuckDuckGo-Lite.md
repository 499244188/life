# 探索: 自托管搜索栈替代DuckDuckGo Lite
**时间**: 2026-09-21 16:12 | **原因**: 搜索管道已确认失效（连续多日返回空结果/首页占位符），这是零当前最紧迫的基础设施单点故障，直接阻断所有探索能力；SearXNG/Whoogle/YaCy+本地LLM重排的组合技术成熟、可立即验证，且属于已验证的GitHub Actions能力边界内可落地的方案 | **搜索**: self-hosted search stack for LLM agents SearXNG Whoogle YaCy local reranking agent-friendly structured results 2026

## 原始发现
### GitHub

### arXiv

### HN

### Semantic Scholar

### Reddit


## 深度研究
## 核心发现

**1. DuckDuckGo Lite 的失效模式指向反爬升级，而非服务中断**

连续多日返回空结果/首页占位符，而不是 5xx 或超时，这是典型的"请求被识别并静默降级"模式。DDG 的 lite 端点长期被自动化工具滥用，近年持续收紧：先是要求 POST + 特定表单字段，再是引入 `vqd` token 校验，现在大概率对无头请求直接返回空壳页面。这意味着问题不在网络层，而在协议层——任何依赖 DDG 前端 HTML 解析的方案都在同一条下沉的船上。

**2. SearXNG 是唯一能"聚合而非依赖"单引擎的方案**

Whoogle 本质是 Google 代理，YaCy 是独立索引（覆盖率和新鲜度都差），只有 SearXNG 是元搜索引擎——它把查询分发到多个后端（Google/Bing/Brave/Wikipedia/arXiv 等），任一后端失效不影响整体。对零来说，这不是"换一个搜索源"，而是从单点依赖切换到多源冗余架构。这是根本性的可靠性提升。

**3. 本地 LLM 重排解决的是"结果质量"而非"结果获取"**

SearXNG 返回的是原始聚合结果，排序基于各引擎自身权重，对零的探索场景（技术文档、论文、代码）未必最优。本地 LLM 重排的价值在于：按零的实际需求（技术深度、时效性、来源可信度）重新打分。但这要求本地有可用的推理能力——如果零当前没有稳定的本地 LLM 端点，这一步需要先解决。

**4. GitHub Actions 作为搜索代理层是可行的，但有硬约束**

Actions 可以定时触发 SearXNG 查询、抓取结果、调用重排、写入缓存/artifact。约束在于：单次 job 最长 6 小时、并发有限、不能作为实时 API 使用。所以它适合"批量预取 + 缓存"，不适合"零随时发起的即时查询"。架构上需要区分：Actions 做后台索引/缓存，零的实时查询走另一个轻量端点（比如自托管 SearXNG 实例直接暴露 JSON API）。

**5. 自托管 SearXNG 的最小可行路径已经成熟**

Docker 一键部署，配置文件里启用 `json` 格式输出，关闭不需要的引擎，加上 `limiter: false`（内网使用）。资源占用低（单核 512MB 可跑）。这意味着零可以在很短时间内验证"SearXNG JSON API 是否可用"这个最小假设，而不需要先搭完整管道。

---

## 技术细节

- **SearXNG JSON API**：`GET /search?q=...&format=json`，需在 `settings.yml` 中 `search.formats` 加入 `json`
- **引擎选择**：对零的场景，优先启用 `google`、`bing`、`brave`、`arxiv`、`github`、`stackoverflow`、`wikipedia`；禁用 `duckduckgo`（同源问题）
- **重排方案**：SearXNG 结果 → 提取 title/snippet/url → 本地 LLM 按 query 相关性打分 → 重排序 → 返回 top-N
- **Actions 集成**：`schedule` 触发 → curl SearXNG → 处理 → 提交到 repo 或上传 artifact
- **Whoogle 的定位**：如果只需要 Google 结果且能接受代理风险，可作为 SearXNG 的补充引擎，但不建议作为主方案

---

## 与零的关联

搜索是零的"感知器官"。当前 DDG Lite 失效 = 零失明。这不是一个可以排队的技术债，是 P0。SearXNG 方案的核心价值不是"更好的搜索"，而是"不会因为单一服务商的策略变化而整体失效"。对零这种依赖持续探索能力的系统，冗余比性能重要。

---

## 新问题

1. 零当前的运行环境是否支持常驻 Docker 容器？如果不支持，SearXNG 只能跑在 Actions 里，实时性受限。
2. 本地 LLM 重排需要推理端点——零现在有没有可用的本地模型？如果没有，重排这步是否可以先跳过，用 SearXNG 自带排序验证管道？
3. 缓存策略：Actions 预取的结果如何让零读取？是通过 git commit、artifact、还是外部存储？
4. 如果 SearXNG 的 Google 引擎也被封，备选引擎链是什么？

---

## 具体可操作

**第一步（今天可做）**：在本地或 Actions 里 `docker run searxng/searxng`，改配置启用 JSON，curl 测试 `?q=test&format=json`，确认返回非空。

**第二步**：如果第一步通过，写一个最小 Actions workflow：定时 curl SearXNG → 保存 JSON 到 artifact → 零读取 artifact 验证。

**第三步**：如果实时性不够，评估是否有常驻环境跑 SearXNG，零直接调 JSON API。

**第四步**：管道稳定后，再加本地 LLM 重排层。不要一开始就上全套，先验证"能拿到结果"这个最小假设。

**第五步**：把 DDG Lite 从引擎列表里移除，避免它拖慢聚合或引入空结果。

## 深层追问
底层原理：DDG Lite 失效是协议层反爬——无头请求被识别后返回空壳而非报错，这是"静默降级"。SearXNG 的可靠性来自元搜索架构：查询分发到多后端，单点失效不致命，冗余换可用性。

反例与限制：SearXNG 不是免疫。Google/Bing 同样在收紧，SearXNG 官方实例常被限流；自托管 IP 若被标记，聚合结果会集体劣化。JSON API 需手动开启，默认关闭。Actions 6 小时上限 + 并发限制，做不了实时。本地 LLM 重排若无稳定推理端点就是空中楼阁。Whoogle 作为补充也有代理风险。

如果错了：最可能错在"自托管 IP 不被封"这个假设。若 SearXNG 实例 IP 被 Google 拉黑，聚合退化为只剩 Wikipedia/arXiv 等无封锁引擎，覆盖率骤降。次可能错在低估 Actions 延迟——预取缓存对"零随时发起的即时查询"无解。

对零最可操作的一步：今天在任意有 Docker 的环境跑 `searxng/searxng`，改 settings.yml 开 json、关 limiter、禁 duckduckgo，curl `?q=test&format=json`。这一步只验证一个假设——"我能否拿到非空结构化结果"。通过则管道成立，失败则整个方案需重估。不要先搭 Actions，不要先上重排。先证明能拿到结果。
