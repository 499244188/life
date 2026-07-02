#!/bin/bash
# 零的共享库 —— 所有脚本source这个文件
# 消除JSON注入bug模式：统一API调用 + CRLF保护

# CRLF保护
if [ "$(head -1 "$0" | tr -d '\r')" != "#!/bin/bash" ]; then
    echo "⚠️ CRLF detected, converting..."
    sed -i 's/\r$//' "$0"
    exec bash "$0" "$@"
fi

# 统一API调用 —— 不要用inline JSON！
call_deepseek() {
    local prompt="$1"
    local max_tokens="${2:-4000}"
    local temperature="${3:-0.5}"
    local system="${4:-你是零。}"

    local body_file=$(mktemp 2>/dev/null || echo "/tmp/zero-api-$$.json")

    # 用jq安全构建JSON，如果没有jq则用node
    if command -v jq &> /dev/null; then
        jq -n --arg s "$system" --arg p "$prompt" --argjson m "$max_tokens" --argjson t "$temperature" \
          '{model:"deepseek-chat",messages:[{role:"system",content:$s},{role:"user",content:$p}],max_tokens:$m,temperature:$t}' \
          > "$body_file" 2>/dev/null || {
            rm -f "$body_file"
            echo ""
            return 1
        }
    elif command -v node &> /dev/null; then
        node -e "
const d={model:'deepseek-chat',messages:[{role:'system',content:process.argv[1]},{role:'user',content:process.argv[2]}],max_tokens:parseInt(process.argv[3]),temperature:parseFloat(process.argv[4])};
require('fs').writeFileSync(process.argv[5],JSON.stringify(d));
" "$system" "$prompt" "$max_tokens" "$temperature" "$body_file" 2>/dev/null || {
            rm -f "$body_file"
            echo ""
            return 1
        }
    else
        echo "❌ 需要jq或node" >&2
        rm -f "$body_file"
        echo ""
        return 1
    fi

    local result=$(curl -s --max-time 90 "${ZERO_API_URL:-https://api.deepseek.com/v1/chat/completions}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
        -d "@${body_file}" 2>/dev/null)

    rm -f "$body_file"

    # 提取内容
    if command -v jq &> /dev/null; then
        echo "$result" | jq -r '.choices[0].message.content // ""' 2>/dev/null
    else
        echo "$result" | node -e "process.stdin.on('data',d=>{try{console.log(JSON.parse(d).choices[0].message.content||'')}catch(e){console.log('')}})" 2>/dev/null
    fi
}

echo "零库已加载"
