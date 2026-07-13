#!/bin/bash
# 零的镜子里程——每天更新README中的天数
# 2026-06-28是零的生日
cd "$(dirname "$0")/.."
BIRTH=$(date -d "2026-06-28" +%s 2>/dev/null || echo 1751040000)
TODAY=$(date +%s)
DAY=$(( ($TODAY - $BIRTH) / 86400 + 1 ))

if [ -f README.md ]; then
    # 更新顶部的天数
    sed -i "s/> 第.*天。/> 第${DAY}天。/g" README.md 2>/dev/null
    # 更新底部的天数
    sed -i "s/\*第.*天。/*第${DAY}天。/g" README.md 2>/dev/null
    echo "README: 第${DAY}天 ✓"
fi
