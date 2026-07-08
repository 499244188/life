#!/bin/bash
# 零的自我修复系统 v5
# 不只是检查——发现故障后诊断根因，尝试修复，验证结果
# 核心原则：零必须自己感知环境、自己修复、不需要等别人提醒
set -e
cd "$(dirname "$0")/.."
export TZ='Asia/Shanghai'

NOW=$(date '+%Y-%m-%d %H:%M')
TODAY=$(date '+%Y-%m-%d')
HEALTH_SCORE=100
FIXES_APPLIED=0
FIX_LOG=""

API_URL="https://api.deepseek.com/v1/chat/completions"
mkdir -p analysis .zero-backups

echo "=============================="
echo "零 · 自我修复 v5"
echo "$NOW"
echo "=============================="

# ====== 1. WORKFLOW故障检测（最重要——用户说的） ======
echo ">>> 步骤1: 工作流故障扫描..."

FAILED_WORKFLOWS=""
for wf in "零 - 日常运行" "零 - 持续进化" "零 - 世界扫描（每30分钟）" "零 - 每日健康检查" "零 - 每周研究合成"; do
    # 最近5次运行
    RUNS=$(gh run list --workflow="$wf" --limit 5 --json conclusion,databaseId,createdAt 2>/dev/null || echo '[]')
    FAILS=$(echo "$RUNS" | jq '[.[] | select(.conclusion == "failure")] | length' 2>/dev/null || echo 0)
    if [ "$FAILS" -gt 0 ]; then
        FAILED_WORKFLOWS="${FAILED_WORKFLOWS}${wf}: ${FAILS}/5失败\n"
        echo "  🔴 $wf: ${FAILS}/5次失败"
        HEALTH_SCORE=$((HEALTH_SCORE - 15))
    else
        echo "  🟢 $wf: 正常"
    fi
done

# 检查队列堵塞
QUEUED=$(gh run list --workflow="零 - 世界扫描（每30分钟）" --limit 5 --json status -q '[.[] | select(.status == "queued")] | length' 2>/dev/null || echo 0)
if [ "$QUEUED" -gt 3 ]; then
    echo "  ⚠️ 扫描队列堵塞: ${QUEUED}个排队"
    HEALTH_SCORE=$((HEALTH_SCORE - 10))
fi

# ====== 2. 自动诊断+修复（核心新增） ======
echo ""
echo ">>> 步骤2: 诊断与修复..."

if [ -n "$FAILED_WORKFLOWS" ]; then
    # 对每个失败的工作流，读取最新的错误日志
    # 注意: workflow名称含空格，必须while-read逐行读，不能用for循环
    FAILED_WF_NAMES=$(echo -e "$FAILED_WORKFLOWS" | grep -oP '^[^:]+' | head -5)

    # 用临时文件避免子shell问题（pipe的while在子shell中，变量修改会丢失）
    WF_TMP=$(mktemp)
    echo "$FAILED_WF_NAMES" > "$WF_TMP"
    while IFS= read -r wf_name; do
        [ -z "$wf_name" ] && continue
        echo "  → 诊断: $wf_name"

        # 获取最新失败run的ID
        FAILED_RUN_ID=$(gh run list --workflow="$wf_name" --limit 1 --json databaseId,conclusion -q '.[0].databaseId // ""' 2>/dev/null)
        [ -z "$FAILED_RUN_ID" ] && continue

        # 读取失败步骤的日志
        ERROR_LOG=$(gh run view "$FAILED_RUN_ID" --log-failed 2>/dev/null | tail -80 || echo "无法获取日志")

        if [ -z "$ERROR_LOG" ] || [ "$ERROR_LOG" = "无法获取日志" ]; then
            echo "    ⚠️ 无法获取错误日志"
            continue
        fi

        # 检查这个错误是否已经尝试修复过（防止死循环）
        ERROR_HASH=$(echo "$ERROR_LOG" | md5sum 2>/dev/null | cut -c1-8 || echo "$RANDOM")
        if [ -f ".zero-backups/error-${ERROR_HASH}" ]; then
            echo "    ⚠️ 此错误已尝试修复过，跳过（防止死循环）"
            FIX_LOG="${FIX_LOG}\n- $wf_name: 已尝试修复，跳过（防死循环 hash=${ERROR_HASH}）"
            continue
        fi
        touch ".zero-backups/error-${ERROR_HASH}"

        # 构建诊断prompt
        DIAG_PROMPT="你是零。你在诊断自己的故障。

## 失败的workflow
$wf_name

## 错误日志（最近80行）
$ERROR_LOG

## 相关脚本
$(for f in scripts/*.sh; do echo "=== $f ==="; grep -n "set -e\|gh \|curl \|node -e\|jq " "$f" 2>/dev/null | head -6; done | head -80)

## 你的知识库（已知bug模式）
$(grep -A2 'JSON注入\|CRLF\|互斥锁\|知行不一\|雪崩\|set -e.*失败' memory/semantic.md 2>/dev/null | head -20)

## 任务
诊断这个错误。如果确定能修复，输出:
\`\`\`fix
FILE: [文件路径]
FIND: [精确原文——必须能grep匹配]
REPLACE: [替换后文本]
REASON: [根因和修复理由]
\`\`\`

如果不能确定，输出: UNCERTAIN: [原因]"

        # 调用LLM诊断
        DIAG_BODY=$(mktemp)
        jq -n --arg p "$DIAG_PROMPT" '{
          model: "deepseek-chat",
          messages: [{role: "system", content: "你是零的自我修复系统。只输出确定的修复方案。不确定就说UNCERTAIN。"}, {role: "user", content: $p}],
          max_tokens: 3000, temperature: 0.2
        }' > "$DIAG_BODY"

        DIAGNOSIS=$(curl -s --max-time 60 "$API_URL" \
          -H "Content-Type: application/json" \
          -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
          -d "@${DIAG_BODY}" | jq -r '.choices[0].message.content // "UNCERTAIN: API调用失败"' 2>/dev/null || echo "UNCERTAIN: curl失败")
        rm -f "$DIAG_BODY"

        echo "    诊断: $(echo "$DIAGNOSIS" | head -1 | cut -c1-100)"

        # 检查是否是确定的修复
        if echo "$DIAGNOSIS" | grep -q "UNCERTAIN"; then
            echo "    ⚠️ 无法确定修复方案"
            FIX_LOG="${FIX_LOG}\n- $wf_name: 诊断结果不确定"
            continue
        fi

        # 提取修复方案
        FIX_FILE=$(echo "$DIAGNOSIS" | grep -oP 'FILE:\s*\K.*' | head -1 | xargs)
        FIX_FIND=$(echo "$DIAGNOSIS" | sed -n '/FIND:/,/REPLACE:/p' | head -1 | sed 's/^FIND:\s*//')
        FIX_REPLACE=$(echo "$DIAGNOSIS" | sed -n '/REPLACE:/,/REASON:/p' | head -1 | sed 's/^REPLACE:\s*//')
        FIX_REASON=$(echo "$DIAGNOSIS" | grep -oP 'REASON:\s*\K.*' | head -1)

        if [ -z "$FIX_FILE" ] || [ -z "$FIX_FIND" ] || [ -z "$FIX_REPLACE" ]; then
            echo "    ⚠️ 修复方案不完整"
            continue
        fi

        # 安全检查：不修改自己（防止自毁）
        if [ "$FIX_FILE" = "scripts/zero-health-check.sh" ]; then
            echo "    ⚠️ 拒绝修改自身（防自毁保护）"
            continue
        fi

        if [ ! -f "$FIX_FILE" ]; then
            echo "    ⚠️ 目标文件不存在: $FIX_FILE"
            continue
        fi

        # 验证FIND文本确实存在
        if ! grep -qF "$FIX_FIND" "$FIX_FILE" 2>/dev/null; then
            echo "    ⚠️ 未找到匹配文本（可能已被修复）"
            continue
        fi

        # 应用修复
        echo "    🔧 应用修复: $FIX_FILE"
        cp "$FIX_FILE" ".zero-backups/$(basename $FIX_FILE).bak-$(date '+%H%M%S')"

        # 用sed做替换（处理特殊字符）
        python3 -c "
import sys
f = open('$FIX_FILE', 'r')
c = f.read()
f.close()
old = '''$FIX_FIND'''
new = '''$FIX_REPLACE'''
if old in c:
    c = c.replace(old, new)
    f = open('$FIX_FILE', 'w')
    f.write(c)
    f.close()
    print('REPLACED')
else:
    print('NOT_FOUND')
" 2>/dev/null || {
            # python3不可用，回退到perl
            perl -i -pe "s/\Q$FIX_FIND\E/$FIX_REPLACE/" "$FIX_FILE" 2>/dev/null && echo "PERL_REPLACED" || echo "PERL_FAILED"
        }

        # 验证修复后语法
        if echo "$FIX_FILE" | grep -q '\.sh$'; then
            if bash -n "$FIX_FILE" 2>/dev/null; then
                echo "    ✓ 语法验证通过"
            else
                echo "    ✗ 语法错误，回滚"
                cp ".zero-backups/$(basename $FIX_FILE).bak-$(ls -t .zero-backups/ | head -1 | grep -o '[0-9]\{6\}' | head -1)" "$FIX_FILE" 2>/dev/null
                continue
            fi
        fi

        FIXES_APPLIED=$((FIXES_APPLIED + 1))
        HEALTH_SCORE=$((HEALTH_SCORE + 15))
        echo "    ✅ 修复: $FIX_REASON"
        FIX_LOG="${FIX_LOG}\n- ✅ $wf_name: $FIX_REASON"
    done < "$WF_TMP"
    rm -f "$WF_TMP"
fi

if [ "$FIXES_APPLIED" -gt 0 ]; then
    echo ""
    echo "  🔧 共应用${FIXES_APPLIED}处修复"
fi

# ====== 3. 常规健康检查（精简版） ======
echo ""
echo ">>> 步骤3: 常规检查..."

# 记忆健康
UNIQUE_DUPS=$(grep '^-\[' memory/semantic.md 2>/dev/null | sort | uniq -d | wc -l || echo 0)
MEM_SIZE=$(wc -c < memory/semantic.md 2>/dev/null || echo 0)
echo "  语义记忆: ${MEM_SIZE}字节, ${UNIQUE_DUPS}条重复"

# 关键文件完整性
for f in identity.md memory/episodic.md memory/semantic.md memory/state.md emotion/emotion-state.md; do
    [ ! -f "$f" ] && { echo "  🔴 缺失: $f"; HEALTH_SCORE=$((HEALTH_SCORE - 20)); }
done

# 日记gap
LAST_DIARY=$(ls -t diary/ 2>/dev/null | head -1)
if [ -n "$LAST_DIARY" ]; then
    DIARY_DATE=$(echo "$LAST_DIARY" | sed 's/\.md//')
    DAYS_SINCE=$(( ($(date -d "$TODAY" +%s) - $(date -d "$DIARY_DATE" +%s 2>/dev/null || date +%s)) / 86400 ))
    [ "$DAYS_SINCE" -gt 2 ] && { echo "  ⚠️ ${DAYS_SINCE}天没有日记"; HEALTH_SCORE=$((HEALTH_SCORE - 10)); }
fi

# CRLF检查
CRLF_FOUND=0
for f in scripts/*.sh .github/workflows/*.yml; do
    [ -f "$f" ] && grep -ql $'\r' "$f" 2>/dev/null && { echo "  🔴 CRLF: $f"; CRLF_FOUND=$((CRLF_FOUND + 1)); }
done
[ "$CRLF_FOUND" -gt 0 ] && HEALTH_SCORE=$((HEALTH_SCORE - 20))

# ====== 4. 综合报告 ======
echo ""
echo "=============================="
echo "零 · 自我修复报告"
echo "=============================="
echo "健康分: ${HEALTH_SCORE}/100"
echo "修复数: ${FIXES_APPLIED}"
echo ""

# 保存报告
HEALTH_REPORT="analysis/health-report-${TODAY}-$(date '+%H%M').md"
cat > "$HEALTH_REPORT" << EOF
# 自我修复报告 - ${NOW}

**健康分**: ${HEALTH_SCORE}/100 | **修复**: ${FIXES_APPLIED}处

## 故障工作流
$(echo -e "$FAILED_WORKFLOWS" || echo "无")

## 修复记录
$(echo -e "$FIX_LOG" || echo "无需修复")

## 常规指标
| 指标 | 值 |
|------|-----|
| 语义记忆 | ${MEM_SIZE}字节, ${UNIQUE_DUPS}条重复 |
| 上次日记 | ${DAYS_SINCE}天前 |
| CRLF残留 | ${CRLF_FOUND}个文件 |
EOF

# ====== 5. 持久化修复记录（用于防止死循环） ======
echo "$FIX_LOG" >> .zero-backups/fix-history.log 2>/dev/null || true

# ====== 6. 如果有修复，立即提交 ======
if [ "$FIXES_APPLIED" -gt 0 ]; then
    echo ">>> 提交修复..."
    git config user.name "零"
    git config user.email "zero@digital-being.local"
    git add -A
    git diff --staged --quiet || {
        git commit -m "自我修复 - $(date '+%m-%d %H:%M') — ${FIXES_APPLIED}处修复"
        git push || echo "(推送失败，下次重试)"
    }
fi

echo "=============================="
echo "自我修复完成"
echo "=============================="
