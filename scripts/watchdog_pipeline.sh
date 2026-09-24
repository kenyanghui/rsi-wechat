#!/usr/bin/env bash
# rsi-wechat 内容流水线「失败自愈」看门狗 v1.5.2
# 用途：由 cron 命令任务定时调用，检测内容流水线当日产物是否完整，
#       不完整（断链/漏跑/主控睡死）则自动触发主任务续跑（每日最多 MAX_RETRY 次）。
#
# v1.5.2 变更（复盘 2026-09-21/23/24 三次断链）：
#   旧版只查 cron lastStatus=ok —— 但主控「正常结束却没等到子代理事件」时状态恰为 ok，
#   导致看门狗永远探测不到断链。新版改为【产物完整性检查】：
#   只认磁盘上的 finished:true 标记，不信任 cron 表面状态。
#
# 判定逻辑（时间闸门 08:00 后生效）：
#   1. 扫描最近 2 天的 pipeline/<日期>/，读 _status.json
#   2. 任一天存在「目录有产物但 finished!=true」→ 触发主任务续跑（主控会从断点续跑）
#   3. 今天 08:00 后目录完全不存在 → 触发主任务重跑
#
# 用法：
#   bash watchdog_pipeline.sh            # 正常检测（由 cron 调用）
#   DRY_RUN=1 bash watchdog_pipeline.sh  # 只检测不触发
#
# 输出约定：无可做之事时输出 NO_REPLY（cron 侧静默）；触发续跑时输出一行简报。

set -uo pipefail

JOB_ID="${WATCHDOG_JOB_ID:-a1687335-482e-4b24-ba14-527099ec9193}"
MAX_RETRY="${WATCHDOG_MAX_RETRY:-3}"
DRY_RUN="${DRY_RUN:-0}"
PIPELINE_ROOT="/root/agents/shared/pipeline"
TZ_NAME="Asia/Shanghai"

CLI="$(command -v openclaw || true)"
[ -z "${CLI}" ] && CLI="/root/.local/share/pnpm/openclaw"

TODAY="$(TZ="${TZ_NAME}" date +%F)"
NOW_HHMM="$(TZ="${TZ_NAME}" date +%H%M)"
RETRY_STATE="${PIPELINE_ROOT}/.watchdog-${TODAY}.retries"

# 时间闸门：主任务每天 07:20 跑，08:00 前不判定（避免误触）
GATE_HHMM="${WATCHDOG_GATE_HHMM:-0800}"
if [ "${NOW_HHMM}" -lt "${GATE_HHMM}" ]; then
  echo "NO_REPLY"
  exit 0
fi

# 主任务此刻正在跑（今天目录存在且无 finished 且 mtime 在 10 分钟内）→ 不干预
TODAY_DIR="${PIPELINE_ROOT}/${TODAY}"
if [ -d "${TODAY_DIR}" ]; then
  NEWEST="$(find "${TODAY_DIR}" -type f -newermt "-10 minutes" 2>/dev/null | head -1)"
  if [ -n "${NEWEST}" ]; then
    echo "NO_REPLY"
    exit 0
  fi
fi

# ---- 产物完整性检查（核心，v1.5.2）----
# 扫最近 2 天：任何一天「有产物但未 finished:true」即断链
BROKEN_REASONS=()
for OFFSET in 0 1; do
  DAY="$(TZ="${TZ_NAME}" date -d "-${OFFSET} days" +%F)"
  DIR="${PIPELINE_ROOT}/${DAY}"
  [ -d "${DIR}" ] || continue
  FINISHED="$(python3 -c "
import json,sys
try:
    d=json.load(open('${DIR}/_status.json'))
    print('true' if d.get('finished') is True else 'false')
except Exception:
    print('missing')
" 2>/dev/null)"
  if [ "${FINISHED}" = "true" ]; then
    continue
  fi
  # 目录存在但未完成：区分「有产物断链」与「空目录刚建」
  ARTIFACTS="$(find "${DIR}" -name '0*.md' -o -name '0*.json' 2>/dev/null | grep -v _status | head -1)"
  if [ -n "${ARTIFACTS}" ]; then
    BROKEN_REASONS+=("${DAY}:产物未完成链")
  elif [ "${OFFSET}" = "0" ]; then
    # 今天的空目录：主控只建了目录就死 → 也算断链
    BROKEN_REASONS+=("${DAY}:空目录无产出")
  fi
done

# 今天过了主任务时刻（07:20+30min 缓冲）仍无目录 → 漏跑
# （独立于闸门：即使闸门被提前覆盖，凌晨也不判「今日漏跑」）
MISSED_HHMM="${WATCHDOG_MISSED_HHMM:-0750}"
if [ ! -d "${TODAY_DIR}" ] && [ "${NOW_HHMM}" -ge "${MISSED_HHMM}" ]; then
  BROKEN_REASONS+=("${TODAY}:目录不存在漏跑")
fi

if [ "${#BROKEN_REASONS[@]}" -eq 0 ]; then
  echo "NO_REPLY"
  exit 0
fi

REASON="$(IFS=';'; echo "${BROKEN_REASONS[*]}")"

# ---- 限次防循环 ----
COUNT=0
[ -f "${RETRY_STATE}" ] && COUNT="$(cat "${RETRY_STATE}" 2>/dev/null || echo 0)"
case "${COUNT}" in ''|*[!0-9]*) COUNT=0 ;; esac

if [ "${COUNT}" -ge "${MAX_RETRY}" ]; then
  # 今日续跑次数用尽：告警一次后静默（写入 .watchdog-alerted 防重复告警）
  ALERT_FLAG="${PIPELINE_ROOT}/.watchdog-${TODAY}-alerted"
  if [ ! -f "${ALERT_FLAG}" ]; then
    touch "${ALERT_FLAG}" 2>/dev/null || true
    echo "🚨 内容流水线看门狗：检测到断链（${REASON}），自动续跑已用尽 ${MAX_RETRY} 次仍未完成，需要人工介入。产物目录：${PIPELINE_ROOT}/"
    exit 0
  fi
  echo "NO_REPLY"
  exit 0
fi

# ---- 触发前安全检查：主任务没在跑 ----
RUNNING="$("${CLI}" cron list --json 2>/dev/null | python3 -c "
import sys,json
raw=sys.stdin.read(); i=raw.find('{')
try:
    d=json.loads(raw[i:]); jobs=d.get('jobs',d)
    for j in jobs:
        if j.get('id','').startswith('${JOB_ID:0:8}'):
            st=j.get('state',{}) or {}
            print('yes' if st.get('runningAtMs') else 'no'); break
    else: print('unknown')
except Exception: print('unknown')
" 2>/dev/null)"
if [ "${RUNNING}" = "yes" ]; then
  echo "NO_REPLY"
  exit 0
fi

COUNT=$((COUNT + 1))
echo "${COUNT}" > "${RETRY_STATE}" 2>/dev/null || true

if [ "${DRY_RUN}" = "1" ]; then
  echo "[DRY-RUN] 将续跑内容流水线（第 ${COUNT}/${MAX_RETRY} 次）｜${REASON}"
  exit 0
fi

OUT="$("${CLI}" cron run "${JOB_ID}" 2>&1 | tail -3)"
echo "🔁 内容流水线自愈：检测到断链（${REASON}），已触发续跑（第 ${COUNT}/${MAX_RETRY} 次）。${OUT}"
exit 0
