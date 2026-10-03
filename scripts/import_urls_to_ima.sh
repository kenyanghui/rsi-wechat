#!/usr/bin/env bash
# import_urls_to_ima.sh — 把外部文章/热点链接导入 IMA 知识库（默认「AI量化杨老师」）
#
# 用法:
#   bash scripts/import_urls_to_ima.sh <url文件|单个URL> [--folder <folder_id>] [--dry-run]
#
# 环境变量:
#   IMA_KB_ID            目标知识库（默认量化线「AI量化杨老师」；前端线传廖晓老师 kb_id）
#   IMA_HOT_FOLDER_ID    默认目标文件夹（--folder 可覆盖；不设则根目录）
#   IMPORT_STATE         成功导入 URL 状态文件（追加式，幂等去重；不设则不记录）
#   IMA_IMPORT_RETRIES   失败 URL 重试轮数（默认 2；覆盖上传失败/解析失败）
#   IMA_BATCH_DELAY      批间隔秒数（默认 1）
#
# 说明:
#   - 输入：一个每行一个 URL 的文本文件，或直接传单个 URL。
#   - 通过 IMA 接口 openapi/wiki/v1/import_urls 批量导入（单次 1-10 个，自动分批）。
#   - 重试（2026-10-03 新增）：逐 URL ret_code!=0（含上传/解析失败）或整批接口失败的
#     URL 进入重试队列，共重试 IMA_IMPORT_RETRIES 轮（轮间隔 3s），仍失败计入最终失败。
#   - 幂等（2026-10-03 新增）：设 IMPORT_STATE 时，已在状态文件中的 URL 直接跳过；
#     导入成功后立即追加记录，中断重跑不重复导入。
#   - 网页/微信文章 → 直接 import_urls。
#   - 文件型 URL（pdf/xlsx/pptx 等）→ 下载 → preflight → create_media → COS → add_knowledge（见 ima-skills/knowledge-base/SKILL.md）。
#   - 凭证从 ~/.config/ima/{client_id,api_key} 读取；缺失直接跳过并告警（不阻断主流程）。
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ── IMA 配置 ──
IMA_SKILL_DIR="${IMA_SKILL_DIR:-/root/.openclaw/workspace/skills/ima-skills}"
KB_ID="${IMA_KB_ID:-5JU-YyL5WUdMp3ZzS_7M2B6G5XpOB4ofM2rdKkMr3jY=}"
# 外部热点素材文件夹（可覆盖）；不设则导入知识库根目录
IMA_HOT_FOLDER_ID="${IMA_HOT_FOLDER_ID:-}"
IMPORT_STATE="${IMPORT_STATE:-}"
RETRIES="${IMA_IMPORT_RETRIES:-2}"
BATCH_DELAY="${IMA_BATCH_DELAY:-1}"

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

# ── 幂等过滤：IMPORT_STATE 中已成功导入的 URL 跳过 ──
SKIPPED=0
if [ -n "${IMPORT_STATE}" ] && [ -f "${IMPORT_STATE}" ]; then
  BEFORE=$(grep -c '' "${LIST_FILE}")
  awk 'NR==FNR{want[$0];next} !($0 in want)' "${IMPORT_STATE}" "${LIST_FILE}" > "${LIST_FILE}.new"
  mv "${LIST_FILE}.new" "${LIST_FILE}"
  SKIPPED=$((BEFORE - $(grep -c '' "${LIST_FILE}" || true)))
fi

TOTAL=$(grep -c '' "${LIST_FILE}" || true)
echo "=== rsi-wechat → IMA 外部素材导入 ==="
echo "待导入 URL: ${TOTAL} 个 | 跳过已导入: ${SKIPPED} 个 | 目标文件夹: ${FOLDER:-<根目录>} | 重试轮数: ${RETRIES}"

if [ "${DRY_RUN}" = "1" ]; then
  echo "--- [dry-run] 计划导入 ---"
  sed 's#^#  #' "${LIST_FILE}"
  echo "=== [dry-run] 结束（未上传）==="
  rm -f "${LIST_FILE}"; exit 0
fi

if [ "${TOTAL}" -eq 0 ]; then
  echo "全部 URL 均已导入过，无需操作"; rm -f "${LIST_FILE}"; exit 0
fi

# ── 分批导入（每批 ≤10；成功→STATE 追加，失败→fail 列表）──
FAIL_CUR="$(mktemp)"; FAIL_NEXT="$(mktemp)"; : > "${FAIL_CUR}"; : > "${FAIL_NEXT}"

flush_batch() {
  # $1 = 本轮 URL 列表文件, $2 = 失败落盘文件
  local list="$1" failfile="$2"
  local BATCH=()
  local batch_no=0
  while IFS= read -r url; do
    [ -z "${url}" ] && continue
    BATCH+=("${url}")
    if [ ${#BATCH[@]} -ge 10 ]; then
      batch_no=$((batch_no+1)); run_batch "${BATCH[*]}" "${failfile}" "batch${batch_no}"
      BATCH=(); sleep "${BATCH_DELAY}"
    fi
  done < "${list}"
  if [ ${#BATCH[@]} -gt 0 ]; then
    batch_no=$((batch_no+1)); run_batch "${BATCH[*]}" "${failfile}" "batch${batch_no}"
  fi
}

run_batch() {
  # $1 = 空格分隔的 URL 串, $2 = 失败落盘文件, $3 = 批次标签
  local urls_str="$1" failfile="$2" tag="$3"
  local urls_json payload resp
  urls_json=$(printf '%s\n' ${urls_str} | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')
  if [ -n "${FOLDER}" ]; then
    payload=$(printf '{"knowledge_base_id":"%s","folder_id":"%s","urls":%s}' "${KB_ID}" "${FOLDER}" "${urls_json}")
  else
    payload=$(printf '{"knowledge_base_id":"%s","urls":%s}' "${KB_ID}" "${urls_json}")
  fi
  resp=$(node "${IMA_SKILL_DIR}/ima_api.cjs" "openapi/wiki/v1/import_urls" "${payload}" "${OPTS}" 2>/dev/null)
  local code
  code=$(echo "${resp}" | python3 -c "import json,sys;print(json.load(sys.stdin).get('code','?'))" 2>/dev/null)
  if [ "${code}" != "0" ]; then
    echo "  ❌ [${tag}] 整批接口失败 → 全部进入重试队列"
    printf '%s\n' ${urls_str} >> "${failfile}"
    return 0
  fi
  echo "${resp}" | OK_FILE="${IMPORT_STATE}" FAIL_FILE="${failfile}" TAG="${tag}" python3 -c "
import json,sys,os
d=json.load(sys.stdin)
okf=os.environ.get('OK_FILE',''); ff=os.environ['FAIL_FILE']; tag=os.environ['TAG']
results=(d.get('data') or {}).get('results') or {}
for url,info in results.items():
    rc=info.get('ret_code')
    if rc==0:
        print(f'  ✅ [{tag}] {url}')
        if okf:
            with open(okf,'a') as f: f.write(url+'\n')
    else:
        print(f'  ❌ [{tag}] {url} (ret_code={rc})')
        with open(ff,'a') as f: f.write(url+'\n')
" 2>/dev/null || { echo "  ⚠️ [${tag}] 响应解析异常 → 全部进入重试队列"; printf '%s\n' ${urls_str} >> "${failfile}"; }
}

IMPORTED_THIS_RUN="$(mktemp)"; : > "${IMPORTED_THIS_RUN}"
flush_batch "${LIST_FILE}" "${FAIL_CUR}"

# ── 失败重试（共 RETRIES 轮）──
ATTEMPT=0
while [ "${ATTEMPT}" -lt "${RETRIES}" ] && [ -s "${FAIL_CUR}" ]; do
  ATTEMPT=$((ATTEMPT+1))
  N=$(grep -c '' "${FAIL_CUR}")
  echo "--- 重试轮 ${ATTEMPT}/${RETRIES}（失败 ${N} 个，3s 后重试）---"
  sleep 3
  : > "${FAIL_NEXT}"
  flush_batch "${FAIL_CUR}" "${FAIL_NEXT}"
  mv "${FAIL_NEXT}" "${FAIL_CUR}"; FAIL_NEXT="$(mktemp)"; : > "${FAIL_NEXT}"
done

FINAL_FAIL=0
FINAL_FAIL=0; [ -f "${FAIL_CUR}" ] && FINAL_FAIL=$(grep -c '' "${FAIL_CUR}" || true)
SUCCESS=$((TOTAL - FINAL_FAIL))
echo "=== IMA 导入完成 ==="
echo "  候选 ${TOTAL} | 成功 ${SUCCESS} | 重试后仍失败 ${FINAL_FAIL} | 跳过已导入 ${SKIPPED}"
if [ "${FINAL_FAIL}" -gt 0 ]; then
  echo "  仍失败清单:"; sed 's#^#    #' "${FAIL_CUR}"
fi
rm -f "${LIST_FILE}" "${FAIL_CUR}" "${FAIL_NEXT}"
[ "${FINAL_FAIL}" -gt 0 ] && exit 1 || exit 0
