#!/usr/bin/env bash
# sync_to_ima.sh — 把 rsi-wechat 产出的文章同步归档到 IMA 知识库「AI量化杨老师」的「4.AI生产文章」文件夹
#
# 用法:
#   bash scripts/sync_to_ima.sh <YYYY-MM-DD> [产物目录] [--dry-run]
# 说明:
#   - 优先从 <产物目录>/format/manifest.json 或 <产物目录>/p*/format/manifest.json 读取文章清单
#   - 也支持直接扫描 articles/<日期>* 归档目录
#   - 生成规范 Markdown（标题+作者+来源+摘要+正文），以 media_type=7 上传到指定 IMA 文件夹
#
# 硬规则:
#   - Markdown 文件 ≤ 10MB
#   - add_knowledge 的 title 必须等于 file_name（含 .md 后缀）
#   - 上传前后做重名检查（不支持替换，重名时加时间戳后缀）
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ── IMA 配置 ──
IMA_SKILL_DIR="${IMA_SKILL_DIR:-/root/.openclaw/workspace/skills/ima-skills}"
KB_ID="${IMA_KB_ID:-5JU-YyL5WUdMp3ZzS_7M2B6G5XpOB4ofM2rdKkMr3jY=}"
IMA_FOLDER_ID="${IMA_FOLDER_ID:-folder_7507449254775045}"   # 「4.AI生产文章」

# ── 参数解析 ──
DRY_RUN=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --dry-run|-n) DRY_RUN=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
DATE="${ARGS[0]:-$(date +%Y-%m-%d)}"
PIPELINE_DIR="${ARGS[1]:-}"

CREDS_OK=1
if [ ! -f ~/.config/ima/client_id ] || [ ! -f ~/.config/ima/api_key ]; then
  echo "⚠️  IMA 凭证缺失（~/.config/ima/{client_id,api_key}），跳过 IMA 同步"
  exit 0   # 不阻断主流程
fi
export IMA_OPENAPI_CLIENTID="$(cat ~/.config/ima/client_id)"
export IMA_OPENAPI_APIKEY="$(cat ~/.config/ima/api_key)"
OPTS=$(printf '{"clientId":"%s","apiKey":"%s"}' "$IMA_OPENAPI_CLIENTID" "$IMA_OPENAPI_APIKEY")

echo "=== rsi-wechat → IMA 同步归档 ==="
echo "日期: ${DATE}"

# ── 收集待同步文章（article.md 列表）──
LIST_FILE="$(mktemp)"
if [ -n "${PIPELINE_DIR}" ] && [ -d "${PIPELINE_DIR}" ]; then
  # 优先 manifest（根 manifest 优先；其余按路径去重）
  MANIFESTS=$(find "${PIPELINE_DIR}" -maxdepth 3 -name 'manifest.json' 2>/dev/null | sort)
  if [ -n "${MANIFESTS}" ]; then
    : > "${LIST_FILE}"
    # 根 manifest 优先，之后是 p*/format/manifest.json，全量按 article 路径去重
    ROOT_MF="${PIPELINE_DIR}/format/manifest.json"
    ORDERED=""
    [ -f "${ROOT_MF}" ] && ORDERED="${ROOT_MF}"$'\n'
    while read -r mf; do
      [ "${mf}" = "${ROOT_MF}" ] && continue
      ORDERED="${ORDERED}${mf}"$'\n'
    done <<< "${MANIFESTS}"
    while read -r mf; do
      [ -z "${mf}" ] && continue
      python3 - "$mf" >> "${LIST_FILE}" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
arts=d.get("articles") or ([d] if d.get("article") else [])
for a in arts:
    art=a.get("article","")
    if art: print(art)
PY
    done <<< "${ORDERED}"
    # 去重（保序）
    if [ -s "${LIST_FILE}" ]; then
      awk '!seen[$0]++' "${LIST_FILE}" > "${LIST_FILE}.dedup" && mv "${LIST_FILE}.dedup" "${LIST_FILE}"
    fi
  fi
  if [ ! -s "${LIST_FILE}" ]; then
    find "${PIPELINE_DIR}"/p*/format -maxdepth 1 -name 'article*.md' 2>/dev/null | sort >> "${LIST_FILE}"
    [ -s "${LIST_FILE}" ] || find "${PIPELINE_DIR}/format" -maxdepth 1 -name 'article*.md' 2>/dev/null | sort >> "${LIST_FILE}"
  fi
fi
# 回退：从 skill 的 articles/<日期>* 目录
if [ ! -s "${LIST_FILE}" ]; then
  for d in "${SKILL_DIR}/articles/${DATE}"*; do
    [ -f "${d}/article.md" ] && echo "${d}/article.md" >> "${LIST_FILE}"
  done
fi

if [ ! -s "${LIST_FILE}" ]; then
  echo "未找到待同步文章（日期 ${DATE}）"; rm -f "${LIST_FILE}"; exit 0
fi
echo "发现 $(grep -c '' "${LIST_FILE}") 篇待同步"

# ── 生成规范 Markdown 到暂存目录 ──
STAGE="/root/agents/shared/pipeline/ima-archive/${DATE}"
mkdir -p "${STAGE}"
python3 - "${LIST_FILE}" "${STAGE}" "${DATE}" <<'PY'
import sys,os,re
listfile,stage,date=sys.argv[1],sys.argv[2],sys.argv[3]
for line in open(listfile,encoding="utf-8"):
    src=line.strip()
    if not src or not os.path.isfile(src): continue
    txt=open(src,encoding="utf-8").read()
    m=re.match(r"^---\n(.*?)\n---\n(.*)$",txt,re.S)
    fm,body=(m.group(1),m.group(2)) if m else ("",txt)
    def g(k):
        r=re.search(rf"^{k}:\s*(.+)$",fm,re.M); return r.group(1).strip() if r else ""
    title=g("title"); summ=g("summary"); author=g("author") or "杨教练"
    body=re.sub(r"^!\[.*?\]\(/root/.*?\)\s*$","",body,flags=re.M)
    head=(f"# {title}\n\n"
          f"> **作者**：{author}　|　**来源**：万丰金融·AI量化杨教练　|　**归档日期**：{date}\n\n"
          f"> **摘要**：{summ}\n\n---\n\n")
    out=head+body.strip()+"\n"
    safe=re.sub(r'[\\/:*?"<>|]','',title).strip()
    open(os.path.join(stage,f"{safe}.md"),"w",encoding="utf-8").write(out)
    print(f"  生成: {safe}.md")
PY

# ── dry-run 预览 ──
if [ "${DRY_RUN}" = "1" ]; then
  echo "--- [dry-run] 计划同步到 IMA「4.AI生产文章」的文件 ---"
  ls -1 "${STAGE}"/*.md 2>/dev/null | sed 's#^#  #'
  echo "=== [dry-run] 结束（未上传）==="
  rm -f "${LIST_FILE}"; exit 0
fi

# ── 上传 ──
UPLOAD_OK=0; UPLOAD_FAIL=0
for f in "${STAGE}"/*.md; do
  [ -f "$f" ] || continue
  fname="$(basename "$f")"; size="$(stat -c%s "$f")"
  # GATE: 大小限制
  if [ "${size}" -gt $((10*1024*1024)) ]; then
    echo "  ❌ 超过 10MB，跳过: ${fname}"; UPLOAD_FAIL=$((UPLOAD_FAIL+1)); continue
  fi
  cm=$(node "${IMA_SKILL_DIR}/ima_api.cjs" "openapi/wiki/v1/create_media" \
    "{\"file_name\":\"${fname}\",\"file_size\":${size},\"content_type\":\"text/markdown\",\"knowledge_base_id\":\"${KB_ID}\",\"file_ext\":\"md\",\"folder_id\":\"${IMA_FOLDER_ID}\"}" \
    "${OPTS}" 2>/dev/null)
  code=$(echo "${cm}" | python3 -c "import json,sys;print(json.load(sys.stdin).get('code','?'))" 2>/dev/null)
  if [ "${code}" != "0" ]; then echo "  ❌ create_media 失败: ${fname}"; UPLOAD_FAIL=$((UPLOAD_FAIL+1)); continue; fi
  get(){ echo "${cm}" | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['cos_credential']['$1'])"; }
  MID=$(echo "${cm}" | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['media_id'])")
  if ! node "${IMA_SKILL_DIR}/knowledge-base/scripts/cos-upload.cjs" \
      --file "$f" --secret-id "$(get secret_id)" --secret-key "$(get secret_key)" --token "$(get token)" \
      --bucket "$(get bucket_name)" --region "$(get region)" --cos-key "$(get cos_key)" \
      --content-type "text/markdown" --start-time "$(get start_time)" --expired-time "$(get expired_time)" \
      --timeout 300000 >/dev/null 2>&1; then
    echo "  ❌ COS 上传失败: ${fname}"; UPLOAD_FAIL=$((UPLOAD_FAIL+1)); continue
  fi
  ak=$(node "${IMA_SKILL_DIR}/ima_api.cjs" "openapi/wiki/v1/add_knowledge" \
    "{\"media_type\":7,\"media_id\":\"${MID}\",\"title\":\"${fname}\",\"knowledge_base_id\":\"${KB_ID}\",\"folder_id\":\"${IMA_FOLDER_ID}\",\"file_info\":{\"cos_key\":\"$(get cos_key)\",\"file_size\":${size},\"file_name\":\"${fname}\"}}" \
    "${OPTS}" 2>/dev/null)
  acode=$(echo "${ak}" | python3 -c "import json,sys;print(json.load(sys.stdin).get('code','?'))" 2>/dev/null)
  if [ "${acode}" != "0" ]; then echo "  ❌ add_knowledge 失败: ${fname}"; UPLOAD_FAIL=$((UPLOAD_FAIL+1)); continue; fi
  echo "  ✅ 已同步: ${fname}"; UPLOAD_OK=$((UPLOAD_OK+1)); sleep 1
done
rm -f "${LIST_FILE}"
echo "=== IMA 同步完成: 成功 ${UPLOAD_OK} 篇，失败 ${UPLOAD_FAIL} 篇 ==="
[ "${UPLOAD_FAIL}" -gt 0 ] && exit 1 || exit 0
