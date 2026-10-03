#!/usr/bin/env bash
# weixin_search.sh — 微信公众号文章搜索（Tavily API include_domains 版）
# 用法: bash weixin_search.sh "<关键词>" <输出文件> [条数=10]
# 输出: 追加到输出文件，每条两行——"# 标题" + URL（与流水线 candidates.txt 格式一致）
# 凭证: /root/.config/tavily/api_key（chmod 600，不入提示词/环境）
# 说明: 不用 site: 操作符（Tavily 对其支持差），直接 include_domains 限定 mp.weixin.qq.com
# 重试: 接口失败自动重试（共 3 次尝试）；0 结果返回 exit 1（调用方换关键词补搜）
set -uo pipefail

KEY_FILE="${TAVILY_KEY_FILE:-/root/.config/tavily/api_key}"
KW="${1:?用法: $0 <关键词> <输出文件> [条数]}"
OUT="${2:?缺少输出文件参数}"
N="${3:-10}"

[ -f "${KEY_FILE}" ] || { echo "❌ 缺搜索凭证 ${KEY_FILE}"; exit 3; }
KEY="$(cat "${KEY_FILE}")"

TMP="$(mktemp)"
OK=0
for i in 1 2 3; do
  if python3 - "${KEY}" "${KW}" "${N}" >"${TMP}" 2>"${TMP}.err" <<'PY'
import sys, json, urllib.request
key, kw, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
body = json.dumps({
    "api_key": key,
    "query": kw,
    "search_depth": "basic",
    "max_results": max(1, min(n, 20)),
    "include_domains": ["mp.weixin.qq.com"],
}).encode()
req = urllib.request.Request("https://api.tavily.com/search", data=body,
                             headers={"Content-Type": "application/json"})
d = json.loads(urllib.request.urlopen(req, timeout=30).read())
for r in d.get("results", []):
    title = str(r.get("title") or "").strip()
    url = str(r.get("url") or "").strip()
    if title and url:
        print(f"# {title}")
        print(url)
PY
  then OK=1; break; fi
  echo "  ⚠️ 搜索失败(第${i}次): $(tail -1 "${TMP}.err" 2>/dev/null | head -c 150)"
  [ "${i}" -lt 3 ] && sleep 5
done
if [ "${OK}" != "1" ]; then
  echo "❌ 搜索 3 次尝试均失败"; rm -f "${TMP}" "${TMP}.err"; exit 1
fi

# 只保留真正的文章页 /s/（过滤掉 mp.weixin.qq.com 首页/栏目页），标题与 URL 成对追加
ADDED=$(python3 - "${TMP}" "${OUT}" <<'PY'
import sys
lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
keep = []
for i, ln in enumerate(lines):
    if ln.startswith("https://mp.weixin.qq.com/s"):
        title = lines[i-1] if i > 0 and lines[i-1].startswith("# ") else "# (无标题)"
        keep.append((title, ln))
seen = set()
try:
    for l in open(sys.argv[2], encoding="utf-8"):
        if l.startswith("https://"):
            seen.add(l.strip())
except FileNotFoundError:
    pass
n = 0
with open(sys.argv[2], "a", encoding="utf-8") as f:
    for t, u in keep:
        if u in seen:
            continue
        f.write(f"{t}\n{u}\n")
        seen.add(u)
        n += 1
print(n)
PY
)
echo "  🔍 [${KW}] 新增文章 ${ADDED} 条"
rm -f "${TMP}" "${TMP}.err"
[ "${ADDED:-0}" -gt 0 ]
