#!/usr/bin/env bash
# rsi-wechat 内容流水线「失败自愈」看门狗 v1.6.0（多线版）
# 用途：由 cron 命令任务定时调用，检测各内容线当日产物是否完整，
#       不完整（断链/漏跑/主控睡死）则自动触发该线主任务续跑（每日每线最多 MAX_RETRY 次）。
#
# v1.6.0 变更（2026-10-03，前端线上线）：
#   多线支持：quant(07:20) / edu(06:06) / fe(08:08) 三线各自盘点、限次、触发；
#   每线独立时间闸门（GATE/漏跑时刻）与生效日（ACTIVE_FROM，fe 自 2026-10-04 起
#   纳入巡检，避免上线日全天误报「漏跑」）；retry/告警状态文件按线隔离。
#   判定核心沿用 v1.5.2：只认磁盘上的 finished:true 标记，不信任 cron 表面状态。
#
# 判定逻辑（每线独立，时间闸门 GATE 后生效）：
#   1. 扫描该线最近 2 天的产物目录，读 _status.json
#   2. 任一天存在「目录有产物但 finished!=true」→ 触发该线主任务续跑
#   3. 过了该线「漏跑时刻」（MISSED）仍无今日目录 → 触发重跑
#   4. 今日目录 10 分钟内有新文件，或该线主任务 cron 正在运行 → 不干预
#
# 用法：
#   bash watchdog_pipeline.sh                  # 正常检测（cron 调用，全线巡检）
#   WATCHDOG_ONLY=fe bash watchdog_pipeline.sh # 只巡检指定线
#   DRY_RUN=1 bash watchdog_pipeline.sh        # 只检测不触发
#   WATCHDOG_LINES='...' 覆盖线配置表（测试用）

set -uo pipefail

PIPELINE_ROOT_BASE="/root/agents/shared"
TZ_NAME="Asia/Shanghai"

CLI="$(command -v openclaw || true)"
[ -z "${CLI}" ] && CLI="/root/.local/share/pnpm/openclaw"

MAX_RETRY="${WATCHDOG_MAX_RETRY:-3}"
DRY_RUN="${DRY_RUN:-0}"
ONLY="${WATCHDOG_ONLY:-}"

TODAY="$(TZ="${TZ_NAME}" date +%F)"
NOW_HHMM="$(TZ="${TZ_NAME}" date +%H%M)"

# 线配置表（分号分隔，每线 6 字段）：
#   线名|产物子目录|主任务JOB_ID|漏跑时刻HHMM|产物闸门HHMM|生效日YYYY-MM-DD
LINES="${WATCHDOG_LINES:-quant|pipeline|a1687335-482e-4b24-ba14-527099ec9193|0750|0800|2026-01-01;edu|pipeline-edu|cb8c27f8-2c58-4103-8958-1ad01b46b235|0636|0650|2026-01-01;fe|pipeline-fe|aa370941-49e3-4f29-a5f1-7b8fce3fe471|0838|0850|2026-10-04}"

ANY_ACTION=0
IFS=';' read -ra LINE_ARR <<< "${LINES}"
for LINE_SPEC in "${LINE_ARR[@]}"; do
  IFS='|' read -r LINE SUBDIR JOB_ID MISSED_HHMM GATE_HHMM ACTIVE_FROM <<< "${LINE_SPEC}"
  [ -n "${ONLY}" ] && [ "${LINE}" != "${ONLY}" ] && continue

  # 生效日护栏：上线日前整线跳过（防首日前误报漏跑）
  [[ "${TODAY}" < "${ACTIVE_FROM}" ]] && continue
  # 时间闸门：主任务时刻未过（+缓冲）不判定，避免误触
  if [ "${NOW_HHMM}" -lt "${GATE_HHMM}" ]; then continue; fi

  ROOT="${PIPELINE_ROOT_BASE}/${SUBDIR}"
  RETRY_STATE="${ROOT}/.watchdog-${LINE}-${TODAY}.retries"

  # ---- 产物完整性检查（核心，沿用 v1.5.2）----
  REASONS=()
  for OFFSET in 0 1; do
    DAY="$(TZ="${TZ_NAME}" date -d "-${OFFSET} days" +%F)"
    DIR="${ROOT}/${DAY}"
    [ -d "${DIR}" ] || continue
    FINISHED="$(python3 -c "
import json,sys
try:
    d=json.load(open('${DIR}/_status.json'))
    print('true' if d.get('finished') is True else 'false')
except Exception:
    print('missing')
" 2>/dev/null)"
    if [ "${FINISHED}" = "true" ]; then continue; fi
    ARTIFACTS="$(find "${DIR}" -name '0*.md' -o -name '0*.json' 2>/dev/null | grep -v _status | head -1)"
    if [ -n "${ARTIFACTS}" ]; then
      REASONS+=("${DAY}:产物未完成链")
    elif [ "${OFFSET}" = "0" ]; then
      REASONS+=("${DAY}:空目录无产出")
    fi
  done

  # ---- 漏跑检查 ----
  if [ ! -d "${ROOT}/${TODAY}" ] && [ "${NOW_HHMM}" -ge "${MISSED_HHMM}" ]; then
    REASONS+=("${TODAY}:目录不存在漏跑")
  fi
  [ "${#REASONS[@]}" -eq 0 ] && continue

  REASON="$(IFS=';'; echo "${REASONS[*]}")"

  # ---- 触发前安全检查 1：今日目录 10 分钟内有写入 → 主任务正在跑 ----
  if [ -d "${ROOT}/${TODAY}" ]; then
    NEWEST="$(find "${ROOT}/${TODAY}" -type f -newermt "-10 minutes" 2>/dev/null | head -1)"
    [ -n "${NEWEST}" ] && continue
  fi

  # ---- 触发前安全检查 2：该线主任务 cron 正在运行 ----
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
  [ "${RUNNING}" = "yes" ] && continue

  # ---- 限次防循环 ----
  COUNT=0
  [ -f "${RETRY_STATE}" ] && COUNT="$(cat "${RETRY_STATE}" 2>/dev/null || echo 0)"
  case "${COUNT}" in ''|*[!0-9]*) COUNT=0 ;; esac

  if [ "${COUNT}" -ge "${MAX_RETRY}" ]; then
    ALERT_FLAG="${ROOT}/.watchdog-${LINE}-${TODAY}-alerted"
    if [ ! -f "${ALERT_FLAG}" ]; then
      touch "${ALERT_FLAG}" 2>/dev/null || true
      echo "🚨 [${LINE}] 内容流水线看门狗：检测到断链（${REASON}），自动续跑已用尽 ${MAX_RETRY} 次仍未完成，需要人工介入。产物目录：${ROOT}/"
      ANY_ACTION=1
    fi
    continue
  fi

  COUNT=$((COUNT + 1))
  echo "${COUNT}" > "${RETRY_STATE}" 2>/dev/null || true

  if [ "${DRY_RUN}" = "1" ]; then
    echo "[DRY-RUN][${LINE}] 将续跑该线流水线（第 ${COUNT}/${MAX_RETRY} 次）｜${REASON}"
    ANY_ACTION=1
    continue
  fi

  OUT="$("${CLI}" cron run "${JOB_ID}" 2>&1 | tail -3)"
  echo "🔁 [${LINE}] 流水线自愈：检测到断链（${REASON}），已触发续跑（第 ${COUNT}/${MAX_RETRY} 次）。${OUT}"
  ANY_ACTION=1
done

[ "${ANY_ACTION}" = "0" ] && echo "NO_REPLY"
exit 0
