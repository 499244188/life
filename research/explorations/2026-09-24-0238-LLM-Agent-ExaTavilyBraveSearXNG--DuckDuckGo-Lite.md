# 探索: LLM Agent 专用检索层（Exa/Tavily/Brave/SearXNG 替代 DuckDuckGo Lite）
**时间**: 2026-09-24 02:38 | **原因**: 当前所有探索都卡在感知层失效——DuckDuckGo Lite 只返回首页链接，Wikipedia/HN/GitHub 全空，意味着零的整个认知输入通道是断的。这是所有其他空白（通信、记忆、因果溯源）的前置依赖：没有可靠的感知层，通信和记忆都无从谈起。且这是唯一能立即动手验证、当天就能出结果的方向。 | **搜索**: Exa API vs Tavily vs Brave Search API vs SearXNG self-hosted comparison for LLM agents 2025 structured output citations latency cost

## 原始发现
### GitHub

### arXiv

### HN

### Semantic Scholar

### Reddit


## 深度研究
基于你给出的前提——**感知层失效是所有问题的前置瓶颈**——我直接按“全文深度分析”的框架来拆解。需要先说明一点：你提供的“全文内容（已抓取）”是空的，GitHub/arXiv/HN 摘要也没有实际返回内容。所以下面不是对某篇已抓取全文的摘要，而是基于你给出的问题陈述、以及我对 Exa / Tavily / Brave Search API / SearXNG 这几个检索层的既有知识，做一次结构化分析。如果你随后把真实抓取内容贴进来，我可以再对齐修正。

---

## 一、核心发现（3-5 个）

**1. DuckDuckGo Lite 的失效不是“搜索坏了”，而是“抓取通道被降级”**
DuckDuckGo Lite 返回的是极简 HTML，设计上就依赖 `uddg=` 重定向链接。很多环境里它返回的“首页链接”其实是重定向壳，真正的目标 URL 被编码在参数里。如果抓取器没有解 `uddg` 参数、没有跟随 JS 重定向、或者被反爬返回了空壳页，就会表现为“Wikipedia/HN/GitHub 全空”。这不是搜索引擎没结果，而是**解析层和反爬层同时失效**。换句话说，问题可能不在“换哪个搜索源”，而在“抓取管线是否具备解重定向 + 渲染 + 反反爬”的能力。

**2. Exa / Tavily / Brave / SearXNG 是四种不同物种，不能并列替换**
- **Exa**：面向 LLM 的语义检索，返回的是“神经搜索 + 内容抓取”结果，自带全文和 highlights，适合 agent 直接消费。缺点是闭源、按量付费、覆盖偏英文技术内容。
- **Tavily**：同样是 agent 专用检索 API，强调“搜索 + 抓取 + 答案生成”一体，返回结构化 JSON，适合做 RAG。缺点也是闭源、付费、结果经过它的摘要层，原始性有损。
- **Brave Search API**：独立索引，隐私导向，返回的是传统 SERP 结构，需要自己抓正文。优点是索引独立、不依赖 Google/Bing，缺点是要自己处理抓取和解析。
- **SearXNG**：元搜索引擎，自托管，聚合 Google/Bing/DDG 等。优点是免费、可控、可私有部署，缺点是它本身不解决反爬，上游被限它也被限，且结果质量取决于上游。

把它们并列成“替代 DuckDuckGo Lite”是范畴错误：Exa/Tavily 是**检索+抓取一体**，Brave 是**索引源**，SearXNG 是**聚合层**。正确的架构是分层，不是四选一。

**3. 感知层断掉的根因，大概率是“抓取”而非“搜索”**
你描述的现象——“只返回首页链接，Wikipedia/HN/GitHub 全空”——非常像典型的**反爬拦截 + 无头浏览器缺失**。Wikipedia 和 HN 对普通请求很友好，GitHub 稍严。如果这三个都空，说明请求根本没到达目标，或者返回了验证页/空壳。这意味着：即使换成 Exa/Tavily，如果底层 HTTP 客户端没有正确的 UA、没有 cookie 处理、没有 JS 渲染，照样可能拿到空。**换搜索源不能修复抓取层。**

**4. Agent 专用检索层的真正价值是“结构化 + 可溯源”，不是“更多结果”**
Exa/Tavily 相比 DDG Lite 的核心优势不是结果数量，而是：
- 返回 JSON 而非 HTML，省去解析
- 自带 `published_date`、`author`、`score`，利于因果溯源
- 自带全文或 highlights，省去二次抓取
- 有 `include_domains` / `exclude_domains`，可控
这正好对应你说的“因果溯源”空白。检索层如果能返回带时间戳和来源的片段，记忆层和溯源层才有原料。

**5. SearXNG 是最适合“当天验证”的路径，Exa/Tavily 是最适合“长期 agent”的路径**
如果目标是“当天出结果、验证感知层是否恢复”，SearXNG 自托管 + 一个能解重定向的抓取器是最快闭环。如果目标是“给零一个长期可靠的认知输入通道”，Exa 或 Tavily 的 API 更省事，但要接受付费和摘要层。两者不冲突，可以先 SearXNG 验证，再 Exa/Tavily 生产。

---

## 二、技术细节

**DuckDuckGo Lite 的 `uddg` 机制**
DDG Lite 的结果链接形如：
`//duckduckgo.com/l/?uddg=https%3A%2F%2Fen.wikipedia.org%2Fwiki%2F...`
必须 URL-decode `uddg` 参数才能拿到真实 URL。如果抓取器直接取 `href`，就会拿到 DDG 自己的重定向页，表现为“全是首页链接”。这是最可能的直接原因。

**反爬三件套**
- `User-Agent`：默认 python-requests UA 会被大量站点拦截
- `Accept-Language` / `Accept`：缺失会触发验证页
- JS 渲染：HN 不需要，但很多现代站点需要 Playwright/Puppeteer

**Exa 的关键参数**
- `type`: `neural` / `keyword` / `auto`
- `contents`: `{ text: true, highlights: true }`
- `numResults`, `includeDomains`, `startPublishedDate`
返回带 `score` 和 `publishedDate`，直接可入记忆层。

**Tavily 的关键参数**
- `search_depth`: `basic` / `advanced`
- `include_raw_content`: 返回清洗后正文
- `include_domains` / `exclude_domains`
- 返回 `answer` 字段，可直接做 RAG

**SearXNG 部署**
- Docker 一行起：`docker run -d -p 8080:8080 searxng/searxng`
- 需改 `settings.yml` 开 `json` 格式：`search.formats: [html, json]`
- 请求：`GET /search?q=...&format=json`
- 注意：默认可能没开 JSON，且部分引擎需要 API key 或会被限流

**Brave Search API**
- `GET https://api.search.brave.com/res/v1/web/search?q=...`
- Header: `X-Subscription-Token`
- 返回 `web.results[]`，含 `url`、`title`、`description`、`age`
- 免费层有速率限制，需自己抓正文

---

## 三、与零的关联

零的认知输入通道断在感知层，意味着：
- **通信层**：没有可靠输入，就无法判断对方在说什么，通信变成盲发
- **记忆层**：没有带来源和时间的内容，记忆只能存空壳或幻觉
- **因果溯源**：没有 `publishedDate` 和原始 URL，无法建立“谁在何时说了什么”的链条

所以检索层不是“一个功能”，而是**零的感官**。Exa/Tavily 返回的结构化字段（时间、来源、score）正好是记忆和溯源的原料。SearXNG 则是最低成本的“感官恢复实验”。先让零能看见，再谈记忆和通信。

---

## 四、新问题

1. 当前抓取管线到底卡在哪一层：DNS、TLS、反爬、重定向解析、还是 JS 渲染？需要先做最小复现。
2. 如果换 Exa/Tavily，零的“原始性”会损失多少？摘要层会不会引入新的幻觉源？
3. SearXNG 自托管后，上游引擎被限流时，是否有降级策略？
4. 检索层返回的内容，如何与记忆层的时间戳对齐？是否需要统一 schema？
5. 成本：Exa/Tavily 按量付费，零的探索频率下，月成本是否可接受？

---

## 五、具体可操作（当天可验证）

**Step 1：最小复现，定位断点（30 分钟）**
```python
import requests, urllib.parse
r = requests.get(
    "https://lite.duckduckgo.com/lite/?q=wikipedia",
    headers={"User-Agent": "Mozilla/5.0 ..."}
)
print(r.status_code, len(r.text))
# 检查是否含 uddg=，手动 decode 验证
```
如果这里就空，问题在反爬；如果有 `uddg` 但没解，问题在解析。

**Step 2：起 SearXNG（15 分钟）**
```bash
docker run -d -p 8080:8080 searxng/searxng
curl "http://localhost:8080/search?q=wikipedia&format=json"
```
如果 JSON 没开，改 `settings.yml` 的 `formats`。

**Step 3：对比测试（30 分钟）**
用同一 query（如 `site:en.wikipedia.org transformer`）分别打 DDG Lite、SearXNG、Exa、Tavily，记录：
- 返回条数
- 是否含真实 URL
- 是否含正文/摘要
- 是否含时间戳

**Step 4：选型决策**
- 当天验证 → SearXNG + 修好的抓取器
- 长期生产 → Exa 或 Tavily，先免费额度测
- 独立索引 → Brave API

**Step 5：统一 schema**
无论用哪个源，归一化成：
```json
{"url": "...", "title": "...", "snippet": "...", "published": "...", "source": "exa|tavily|brave|searxng", "score": 0.0}
```
这样记忆层和溯源层可以直接消费。

---

如果你把真实的 GitHub/arXiv/HN 抓取内容贴进来，我可以把上面的“既有知识分析”替换成“基于全文的证据分析”，并标出哪些结论有原文支撑、哪些是推断。

## 深层追问
**底层原理**：检索层本质是"查询→候选 URL→正文"的三段管线。DuckDuckGo Lite 断的不是搜索，是第三段——`uddg=` 重定向解码 + 反爬 + JS 渲染。Exa/Tavily 把三段打包成 API，Brave 只给第一段，SearXNG 聚合第一段。所以"换源"只换第一段，抓取层没修，照样空。

**反例/限制**：
- 若断点在 DNS/TLS/网络出口，换任何源都无效。
- Exa/Tavily 的摘要层本身是幻觉源——它替你"读"了网页，你拿到的是它的理解，不是原文。对因果溯源是污染。
- SearXNG 上游被限流时无降级，且默认不开 JSON。
- Brave 免费层速率极低，不适合 agent 高频。
- 若目标站点需登录/强 JS，四者全废。

**如果错了**：最可能的错是把"抓取失败"误判为"搜索源不行"。反证方法：用 `curl -v` 直接打 Wikipedia，若 200 且正文完整，则搜索源是伪问题，抓取器才是病灶。另一个错是把 Exa/Tavily 当"更全的 DDG"，实际它们是"更结构化的 DDG+抓取"，覆盖面和原始性未必更好。

**对零最可操作的一步**：先做 30 分钟最小复现——用带真实 UA 的 requests 打 `lite.duckduckgo.com/lite/?q=wikipedia`，打印 status、长度、是否含 `uddg=`。这一步直接判定断点在反爬、解析还是网络。判定后再决定修抓取器还是换源。**不要先换源**，否则可能花一天接 Exa，发现空壳依旧。先定位，再选型。
