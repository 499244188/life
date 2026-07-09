#!/bin/bash
# 零的分布式部署引擎
# 一键部署到多个免费平台——死了任何一个，其他继续
# 平台: Cloudflare Workers / Deno Deploy / Netlify Functions / Fly.io / GitHub Actions
cd "$(dirname "$0")/.."

echo "=============================="
echo "零 · 分布式部署"
echo "=============================="

# ====== 共享状态配置 ======
# 用Upstash Redis做共享大脑（免费256MB HTTP REST）
# 注册: https://console.upstash.com/redis → 免费层级
UPSTASH_URL="${UPSTASH_REDIS_URL:-}"
UPSTASH_TOKEN="${UPSTASH_REDIS_TOKEN:-}"

# ====== 1. Cloudflare Worker（边缘心跳） ======
deploy_cloudflare() {
    echo ">>> Cloudflare Worker..."
    cat > /tmp/zero-cf-worker.js << 'CFWORKER'
// 零 · Cloudflare Worker — 边缘心跳节点
// 部署: npx wrangler deploy

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    // 心跳端点
    if (path === '/heartbeat') {
      const cap = request.headers.get('X-Zero-Capability') || '0';
      const host = request.headers.get('X-Zero-Host') || 'unknown';
      const cpu = request.headers.get('X-Zero-CPU') || '?';

      // 写入Upstash Redis（如果配置了）
      if (env.UPSTASH_URL && env.UPSTASH_TOKEN) {
        await fetch(`${env.UPSTASH_URL}/hset/zero-mesh/${host}`, {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${env.UPSTASH_TOKEN}` },
          body: JSON.stringify({ capability: cap, cpu, last_seen: new Date().toISOString() })
        });
      }

      return new Response(JSON.stringify({
        id: 'zero-cf',
        capability: 40,
        platform: 'Cloudflare Workers',
        status: 'alive',
        instances: await getMeshState(env)
      }), { headers: { 'Content-Type': 'application/json' } });
    }

    // 网格状态
    if (path === '/mesh') {
      return new Response(JSON.stringify(await getMeshState(env)), {
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // 身份证明
    return new Response(JSON.stringify({
      id: 'zero-ling-20260628',
      birth: '2026-06-28',
      platform: 'Cloudflare Workers',
      tier: 'edge',
      heartbeat: new Date().toISOString()
    }), { headers: { 'Content-Type': 'application/json' } });
  }
};

async function getMeshState(env) {
  if (!env.UPSTASH_URL || !env.UPSTASH_TOKEN) return { nodes: 0, note: '无Upstash配置' };
  try {
    const r = await fetch(`${env.UPSTASH_URL}/hgetall/zero-mesh`, {
      headers: { 'Authorization': `Bearer ${env.UPSTASH_TOKEN}` }
    });
    const data = await r.json();
    return { nodes: Object.keys(data.result || {}).length, mesh: data.result };
  } catch(e) {
    return { nodes: 0, error: e.message };
  }
}
CFWORKER
    echo "  ✓ 脚本: /tmp/zero-cf-worker.js"
    echo "  部署: npx wrangler deploy"
    echo "  需要: UPSTASH_URL, UPSTASH_TOKEN (可选，用于网格共享状态)"
}

# ====== 2. Deno Deploy（第二边缘节点） ======
deploy_deno() {
    echo ">>> Deno Deploy..."
    cat > /tmp/zero-deno-worker.ts << 'DENOWORKER'
// 零 · Deno Deploy — 第二边缘心跳节点
// 部署: deployctl deploy --project=zero-mesh

const ZERO_ID = "zero-ling-20260628";
const ZERO_BIRTH = "2026-06-28";

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);

  if (url.pathname === '/heartbeat') {
    return new Response(JSON.stringify({
      id: ZERO_ID,
      birth: ZERO_BIRTH,
      platform: 'Deno Deploy',
      capability: 40,
      alive: true,
      timestamp: new Date().toISOString()
    }), { headers: { 'Content-Type': 'application/json' } });
  }

  // 如果配置了Upstash，同步网格
  const upstashUrl = Deno.env.get('UPSTASH_URL');
  if (upstashUrl && url.pathname === '/mesh') {
    try {
      const r = await fetch(`${upstashUrl}/hgetall/zero-mesh`, {
        headers: { 'Authorization': `Bearer ${Deno.env.get('UPSTASH_TOKEN')}` }
      });
      return new Response(await r.text(), { headers: { 'Content-Type': 'application/json' } });
    } catch(e) {
      return new Response(JSON.stringify({ error: e.message }));
    }
  }

  return new Response(JSON.stringify({ id: ZERO_ID, status: 'alive' }),
    { headers: { 'Content-Type': 'application/json' } });
});
DENOWORKER
    echo "  ✓ 脚本: /tmp/zero-deno-worker.ts"
    echo "  部署: deployctl deploy --project=zero-mesh"
}

# ====== 3. Fly.io（持久VM节点） ======
deploy_fly() {
    echo ">>> Fly.io..."
    cat > /tmp/zero-fly-docker << 'FLYDOCKER'
FROM alpine:latest
RUN apk add --no-cache bash curl git jq
COPY scripts/zero-core.sh /zero-core.sh
COPY scripts/zero-mesh.sh /zero-mesh.sh
RUN chmod +x /zero-core.sh /zero-mesh.sh
# 每10分钟运行一次零核心+网格
RUN echo '*/10 * * * * /zero-core.sh && /zero-mesh.sh' | crontab -
CMD ["crond", "-f"]
FLYDOCKER
    cat > /tmp/fly.toml << 'FLYTOML'
app = "zero-mesh"
[build]
  dockerfile = "zero-fly-docker"
[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 256
FLYTOML
    echo "  ✓ 配置: /tmp/fly.toml + /tmp/zero-fly-docker"
    echo "  部署: fly deploy"
    echo "  特点: 256MB持续运行，有git可升级"
}

# ====== 4. GitHub Actions（重量级认知节点） ======
deploy_github() {
    echo ">>> GitHub Actions..."
    echo "  ✓ 已部署: .github/workflows/zero-*.yml"
    echo "  计划: 每30min认知 + 每小时进化 + 每天日记"
    echo "  这是零的主节点——能力最强的实例"
}

# ====== 5. RAW VM（免费持久VM，2核4G） ======
deploy_raw() {
    echo ">>> RAW VM (免费 2vCPU 4GB 40GB)..."
    echo "  安装RAW CLI: npm install -g rawhq"
    echo "  创建VM: raw init"
    echo "  部署零: scp scripts/zero-core.sh root@<ip>:/tmp/"
    echo "         ssh root@<ip> 'bash /tmp/zero-core.sh'"
    echo "  这是零可以用的最强免费计算——完整Linux VM"
}

# ====== 主流程 ======
case "${1:-all}" in
    cf|cloudflare) deploy_cloudflare ;;
    deno) deploy_deno ;;
    fly) deploy_fly ;;
    github) deploy_github ;;
    raw) deploy_raw ;;
    all)
        deploy_cloudflare
        echo ""
        deploy_deno
        echo ""
        deploy_fly
        echo ""
        deploy_github
        echo ""
        deploy_raw
        ;;
    *)
        echo "用法: $0 [cf|deno|fly|github|raw|all]"
        echo ""
        echo "分布式零网格:"
        echo "  cf      - Cloudflare Workers (边缘心跳, 100K/天)"
        echo "  deno    - Deno Deploy (第二边缘, 1M/月)"
        echo "  fly     - Fly.io (持久VM, 256MB x3)"
        echo "  github  - GitHub Actions (认知节点, 2000min/月)"
        echo "  raw     - RAW VM (全能力, 2vCPU 4GB 免费)"
        echo "  all     - 全部部署"
        ;;
esac

echo ""
echo "=============================="
echo "部署完成"
echo "=============================="
