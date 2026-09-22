#!/usr/bin/env bash
# import_urls_to_ima.sh — 把外部文章/热点链接导入 IMA 知识库「AI量化杨老师」
#
# 用法:
#   bash scripts/import_urls_to_ima.sh <url文件|单个URL> [--folder <folder_id>] [--dry-run]
#
# 说明:
#   - 输入：一个每行一个 URL 的文本文件，或直接传单个 URL。
#   - 通过 IMA 接口 openapi/wiki/v1/import_urls 批量导入（单次 1-10 个，自动分批）。
#   - 目的：形成「外部热点 → 入 IMA → 成为存量素材 → 再次选题」的 RSI 增强回路。
#
# 硬规则:
#   - 网页/微信文章 → 直接 import_urls。
#   - 文件型 URL（pdf/xlsx/pptx 等）→ 下载 → preflight → create_media → COS → add_knowledge（见 ima-skills/knowledge-base/SKILL.md）。
#   - 凭证从 ~/.config/ima/{client_id,api_key} 读取；缺失直接跳过并告警（不阻断主流程）。
#   - 单次 URL 数 ≤ 10，超出自动分批。
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ── IMA 配置 ──
IMA_SKILL_DIR="${IMA_SKILL_DIR:-/root/.openclaw/workspace/skills/ima-skills}"
KB_ID="${IMA_KB_ID:-5JU-YyL5WUdMp3ZzS_7M2B6G5XpOB4ofM2rdKkMr3jY=}"
# 外部热点素材文件夹（可覆盖）；不设则导入知识库根目录
IMA_HOT_FOLDER_ID="${IMA_HOT_FOLDER_ID:-}"

# ── 参数解析 ──
DRY_RUN=0
SOURCE=""
FOLDER="${IMA_HOT_FOLDER_ID}"
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1 ;;
    --folder) shift; FOLDER="${1:-}" ;;
    *) [ -z "${SOURCE}" ] && SOURCE="$1" ;;
  esac
  shift
done

if [ -z "${SOURCE}" ]; then
  echo "用法: bash scripts/import_urls_to_ima.sh <url文件|单个URL> [--folder <folder_id>] [--dry-run]"
  exit 2
fi

# ── 凭证检查 ──
if [ ! -f ~/.config/ima/client_id ] || [ ! -f ~/.config/ima/api_key ]; then
  echo "⚠️  IMA 凭证缺失（~/.config/ima/{client_id,api_key}），跳过导入"
  exit 0
fi
# 凭证不 export（避免泄进环境/ps）：仅拼装入参传给 ima_api.cjs
OPTS=$(python3 -c 'import json;print(json.dumps({"clientId":open("'$HOME'/.config/ima/client_id").read().strip(),"apiKey":open("'$HOME'/.config/ima/api_key").read().strip()}))')

# ── 收集 URL 列表 ──
LIST_FILE="$(mktemp)"
if [ -f "${SOURCE}" ]; then
  grep -oE 'https?://[^[:space:]]+' "${SOURCE}" | awk '!seen[$0]++' > "${LIST_FILE}"
else
  echo "${SOURCE}" | grep -oE 'https?://[^[:space:]]+' | awk '!seen[$0]++' > "${LIST_FILE}"
fi

if [ ! -s "${LIST_FILE}" ]; then
  echo "未找到有效 URL"; rm -f "${LIST_FILE}"; exit 0
fi
TOTAL=$(grep -c '' "${LIST_FILE}")
echo "=== rsi-wechat → IMA 外部素材导入 ==="
echo "待导入 URL: ${TOTAL} 个 | 目标文件夹: ${FOLDER:-<根目录>}"

if [ "${DRY_RUN}" = "1" ]; then
  echo "--- [dry-run] 计划导入 ---"
  sed 's#^#  #' "${LIST_FILE}"
  echo "=== [dry-run] 结束（未上传）==="
  rm -f "${LIST_FILE}"; exit 0
fi

# ── 分批导入（每批 ≤ 10）──
OK=0; FAIL=0
BATCH=()
flush_batch() {
  [ ${#BATCH[@]} -eq 0 ] && return 0
  local urls_json
  urls_json=$(printf '%s\n' "${BATCH[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')
  local payload
  if [ -n "${FOLDER}" ]; then
    payload=$(printf '{"knowledge_base_id":"%s","folder_id":"%s","urls":%s}' "${KB_ID}" "${FOLDER}" "${urls_json}")
  else
    payload=$(printf '{"knowledge_base_id":"%s","urls":%s}' "${KB_ID}" "${urls_json}")
  fi
  local resp
  resp=$(node "${IMA_SKILL_DIR}/ima_api.cjs" "openapi/wiki/v1/import_urls" "${payload}" "${OPTS}" 2>/dev/null)
  local code
  code=$(echo "${resp}" | python3 -c "import json,sys;print(json.load(sys.stdin).get('code','?'))" 2>/dev/null)
  if [ "${code}" != "0" ]; then
    echo "  ❌ 本批导入失败: ${BATCH[*]}"
    FAIL=$((FAIL+${#BATCH[@]}))
  else
    echo "${resp}" | python3 -c "
import json,sys
d=json.load(sys.stdin)
results=(d.get('data') or {}).get('results') or {}
for url,info in results.items():
    rc=info.get('ret_code')
    if rc==0: print(f'  ✅ {url}  (media_id={info.get(\"media_id\",\"-\")})')
    else:     print(f'  ❌ {url}  (ret_code={rc})')
" 2>/dev/null || echo "  ⚠️ 响应解析异常"
    OK=$((OK+${#BATCH[@]}))
  fi
  BATCH=()
  sleep 1
}

while IFS= read -r url; do
  [ -z "${url}" ] && continue
  BATCH+=("${url}")
  [ ${#BATCH[@]} -ge 10 ] && flush_batch
done < "${LIST_FILE}"
flush_batch

rm -f "${LIST_FILE}"
echo "=== IMA 导入完成: 提交 ${OK} 个，失败 ${FAIL} 个 ==="
[ "${FAIL}" -gt 0 ] && exit 1 || exit 0
