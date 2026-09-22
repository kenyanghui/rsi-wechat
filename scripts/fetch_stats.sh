#!/usr/bin/env bash
# fetch_stats.sh — 发布数据回流（v1.4.0 新增，治体检报告 R3/升级机会#2）
#
# 作用：把已【群发】文章的阅读/点赞等数据拉回来，回写 articles/<日期>[-n]/meta.json
#       的 stats 字段，并汇总追加到 RSI 台账「发布数据」表，形成「标题模式 ↔ 真实传播」
#       的闭环（此前风格偏好表的「人工反馈」只能靠人工回评）。
#
# 重要边界：公众号「草稿箱」文章没有阅读数据；只有【群发】过的才有。所以本脚本
#   扫描的是 meta.json 里带 published_at 标记的文章（由 Step7 复盘时人工标注群发后写入，
#   或由本脚本 --mark-published 交互写入）。未标注的文章自动跳过。
#
# 凭证（三选一，缺失则优雅退出不阻断主流程）：
#   ~/.config/wechat/appid  + ~/.config/wechat/secret      （公众号 API 直连：用
#     datacube/getarticletotal 拉全量群发数据，按 msg_data_id+title 匹配）
#   环境变量 WECHAT_APPID / WECHAT_SECRET                  （同上，优先级更高）
#   WECHAT_STATS_JSON=<文件或JSON>                          （离线注入：人工从后台导出，
#     字段 [{title, read_num, like_num, datetime}]，便于测试/无API环境）
#
# 用法：
#   bash scripts/fetch_stats.sh [YYYY-MM-DD] [--all] [--dry-run] [--mark-published <日期>[-n]]
#     [日期]      只处理该日归档（默认今天）
#     --all       扫描 articles/ 全部归档
#     --mark-published <dir-suffix>  把某篇标记为已群发（写 published_at），
#                                    如 --mark-published 2026-09-24-2
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARTICLES="${SKILL_DIR}/articles"
LEDGER="${SKILL_DIR}/_rsi_ledger.md"

DRY_RUN=0; DO_ALL=0; MARK=""; DATE_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1 ;;
    --all) DO_ALL=1 ;;
    --mark-published) shift; MARK="${1:-}" ;;
    *) [ -z "${DATE_ARG}" ] && DATE_ARG="$1" ;;
  esac
  shift
done

# ── 模式一：--mark-published 标记群发 ──
if [ -n "${MARK}" ]; then
  DIR="${ARTICLES}/${MARK}"
  META="${DIR}/meta.json"
  if [ ! -f "${META}" ]; then echo "❌ 未找到 ${META}"; exit 1; fi
  python3 - "${META}" <<'PY'
import json,sys,datetime
p=sys.argv[1]; d=json.load(open(p,encoding="utf-8"))
d["published_at"]=datetime.date.today().isoformat()
json.dump(d,open(p,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
print(f"✅ 已标记群发: {p} (published_at={d['published_at']})")
PY
  exit 0
fi

# ── 收集候选（已群发 = meta.json 有 published_at）──
CANDIDATES="$(mktemp)"
if [ "${DO_ALL}" = "1" ]; then
  find "${ARTICLES}" -maxdepth 2 -name meta.json -printf '%h\n' 2>/dev/null | sort
else
  D="${DATE_ARG:-$(date +%Y-%m-%d)}"
  ls -d "${ARTICLES}/${D}" "${ARTICLES}/${D}"-* 2>/dev/null
fi | while read -r dir; do
  [ -f "${dir}/meta.json" ] && [ -f "${dir}/article.md" ] && printf '%s\n' "${dir}"
done > "${CANDIDATES}"

PUBLISHED="$(mktemp)"
while read -r dir; do
  [ -n "${dir}" ] || continue
  grep -q '"published_at"' "${dir}/meta.json" 2>/dev/null && printf '%s\n' "${dir}"
done < "${CANDIDATES}" > "${PUBLISHED}"

COUNT_P="$(grep -c . "${PUBLISHED}" 2>/dev/null || true)"
if [ "${COUNT_P:-0}" -eq 0 ]; then
  echo "无已群发文章待回流（需先 --mark-published 标记，或本就是草稿箱文章无数据）。"
  rm -f "${CANDIDATES}" "${PUBLISHED}"; exit 0
fi
echo "=== rsi-wechat 发布数据回流 ==="
echo "已群发待回流: ${COUNT_P} 篇"

# ── 凭证三选一 ──
APPID="${WECHAT_APPID:-}"; SECRET="${WECHAT_SECRET:-}"
[ -z "${APPID}" ] && [ -f ~/.config/wechat/appid ] && APPID="$(cat ~/.config/wechat/appid)"
[ -z "${SECRET}" ] && [ -f ~/.config/wechat/secret ] && SECRET="$(cat ~/.config/wechat/secret)"

fetch_json() {  # fetch_json <url> <payload> → stdout
  curl -sS -X POST "$1" -H 'Content-Type: application/json' -d "$2" --max-time 20 2>/dev/null || true
}

# ── 拉全量群发数据（标题 → read/like 映射）──
STATS_JSON="${WECHAT_STATS_JSON:-}"
if [ -n "${STATS_JSON}" ] && [ -f "${STATS_JSON}" ]; then STATS_JSON="$(cat "${STATS_JSON}")"; fi

if [ -z "${STATS_JSON}" ] && [ -n "${APPID}" ] && [ -n "${SECRET}" ]; then
  TOKEN="$(fetch_json "https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=${APPID}&secret=${SECRET}" '{}' | python3 -c 'import json,sys;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null || true)"
  if [ -z "${TOKEN}" ]; then
    echo "⚠️  获取 access_token 失败（检查 appid/secret/IP白名单），本次跳过"; exit 0
  fi
  TODAY="$(date +%Y-%m-%d)"
  BEGIN="$(date -d "${TODAY} 30 days ago" +%Y-%m-%d)"
  # getarticletotal: 单日全量群发阅读数据（日期为群发日）。拉近 30 天窗口逐日合并。
  STATS_JSON="$(for day in $(seq 0 29); do D=$(date -d "${TODAY} -${day} days" +%Y-%m-%d); \
      fetch_json "https://api.weixin.qq.com/datacube/getarticletotal?access_token=${TOKEN}" "{\"begin_date\":\"${D}\",\"end_date\":\"${D}\"}"; echo; done \
    | python3 -c '
import json,sys
m={}
for line in sys.stdin:
    line=line.strip()
    if not line: continue
    try: d=json.loads(line)
    except Exception: continue
    for item in d.get("list",[]):
        t=item.get("title","").strip()
        if not t: continue
        r=item.get("int_page_read_count",item.get("read_count",0)) or 0
        l=item.get("ori_page_read_count",item.get("like_num",item.get("like",0))) or 0
        if t not in m or r>m[t][0]: m[t]=[r,l]   # 取该标题历史峰值
print(json.dumps({t:v for t,v in m.items()},ensure_ascii=False))
' 2>/dev/null || true)"
fi

if [ -z "${STATS_JSON}" ] || [ "${STATS_JSON}" = "{}" ]; then
  echo "⚠️  无数据源：未配 WECHAT_APPID/SECRET、~/.config/wechat/*，也无 WECHAT_STATS_JSON 注入。本次跳过（不阻断）。"
  rm -f "${CANDIDATES}"; exit 0
fi

# ── 回写 meta.json + 汇总 ──
python3 - "${PUBLISHED}" "${STATS_JSON}" "${DRY_RUN}" "${LEDGER}" <<'PY'
import json,sys,os,re,datetime
cands,stats_raw,dry,ledger=sys.argv[1],sys.argv[2],sys.argv[3]=="1",sys.argv[4]
stats=json.loads(stats_raw)
if isinstance(stats,list):  # 列表格式 [{title,read_num,like_num}] → 归一为 {title:[read,like]}
    stats={s.get("title","").strip():[s.get("read_num",s.get("int_page_read_count",0)) or 0,
                                      s.get("like_num",s.get("ori_page_read_count",0)) or 0]
           for s in stats if s.get("title")}
today=datetime.date.today().isoformat()
rows=[]
def norm(t):  # 标题宽松匹配：去空白
    return re.sub(r"\s+","",t or "")
snorm={norm(k):v for k,v in stats.items()}
for line in open(cands,encoding="utf-8"):
    d=line.strip()
    if not d: continue
    mp=os.path.join(d,"meta.json")
    try: meta=json.load(open(mp,encoding="utf-8"))
    except Exception: continue
    if "published_at" not in meta: continue
    title=meta.get("title","")
    hit=snorm.get(norm(title))
    if not hit:
        rows.append(("miss",title,d,None)); continue
    newstats={"read_num":hit[0],"like_num":hit[1],"fetched_at":today}
    if dry:
        print(f"[dry-run] {title}: read={hit[0]} like={hit[1]} → {mp}")
    else:
        meta["stats"]=newstats
        json.dump(meta,open(mp,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
        print(f"✅ {title}: read={hit[0]} like={hit[1]} → meta.stats")
    rows.append(("hit",title,d,newstats))
if dry: sys.exit(0)
hits=[r for r in rows if r[0]=="hit"]
if not hits:
    print("（无标题匹配命中——若刚群发，数据有 1 天延迟，隔天再跑）"); sys.exit(0)
# 台账追加「发布数据」行（表不存在则在「## 8. 演进记录」前建表；行插到表尾而非文件尾）
txt=open(ledger,encoding="utf-8").read()
header="## 7. 发布数据（阅读/点赞回流）"
if header not in txt:
    anchor="## 8. 演进记录"
    table=header+"\n\n| 日期 | 标题 | 阅读 | 点赞 | 采集日 | 归档目录 |\n|------|------|------|------|--------|----------|\n"
    txt=txt.replace(anchor,table+"\n"+anchor)
lines="".join(f"| {s['fetched_at']} | {t} | {s['read_num']} | {s['like_num']} | {s['fetched_at']} | {os.path.basename(d)} |\n" for _,t,d,s in hits)
lst=txt.split("\n")
hi=next((i for i,ln in enumerate(lst) if ln.startswith(header)), -1)
if hi >= 0:
    j=hi+1
    while j < len(lst) and not lst[j].startswith("|"): j+=1   # 跳到表头行
    while j < len(lst) and lst[j].startswith("|"): j+=1       # 走到表尾
    lst.insert(j, lines.rstrip("\n"))
    txt="\n".join(lst)
else:
    txt=txt+lines
open(ledger,"w",encoding="utf-8").write(txt if txt.endswith("\n") else txt+"\n")
print(f"✅ 台账已回写 {len(hits)} 条发布数据（{header}）")
PY
rm -f "${CANDIDATES}" "${PUBLISHED}"
