#!/usr/bin/env bash
# rsi-wechat 内容流水线「失败自愈」看门狗
# 用途：由 cron 命令任务定时调用，检测主任务（内容流水线每日编排）当日是否失败/漏跑，
#       若失败则自动触发重跑（每日最多 MAX_RETRY 次），从而弥补「网关重启打断」这类
#       内建 transient 重试无法覆盖的故障。
#
# 用法：
#   bash watchdog_pipeline.sh            # 正常检测（由 cron 调用）
#   DRY_RUN=1 bash watchdog_pipeline.sh  # 只检测不触发
#
# 输出约定：无可做之事时输出 NO_REPLY（cron 侧静默）；触发重跑时输出一行简报。

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

# 时间闸门：主任务每天 07:20 跑，08:00 前不判定「今日漏跑」，避免误触
GATE_HHMM="${WATCHDOG_GATE_HHMM:-0800}"
if [ "${NOW_HHMM}" -lt "${GATE_HHMM}" ] && [ "${WATCHDOG_FAKE_STATE:-}" = "" ]; then
  echo "NO_REPLY"
  exit 0
fi

# ---- 读取主任务运行时状态 ----
if [ -n "${WATCHDOG_FAKE_STATE:-}" ]; then
  STATE_JSON="${WATCHDOG_FAKE_STATE}"
else
RAW="$("${CLI}" cron get "${JOB_ID}" 2>/dev/null)"
STATE_JSON="$(printf '%s' "${RAW}" | python3 -c '
import sys, json
raw = sys.stdin.read()
i = raw.find("{")
if i < 0:
    print("{}"); raise SystemExit
try:
    d = json.loads(raw[i:])
except Exception:
    print("{}"); raise SystemExit
st = d.get("state", {}) or {}
print(json.dumps({
    "runningAtMs": st.get("runningAtMs"),
    "lastRunAtMs": st.get("lastRunAtMs"),
    "lastRunStatus": st.get("lastRunStatus"),
    "lastError": st.get("lastError"),
}))
' 2>/dev/null)"
fi

if [ -z "${STATE_JSON}" ] || [ "${STATE_JSON}" = "{}" ]; then
  # 读不到状态（网关重启中/CLI 异常）→ 本轮不动，避免误触
  echo "NO_REPLY"
  exit 0
fi

get_field() {
  printf '%s' "${STATE_JSON}" | python3 -c '
import sys, json
d = json.loads(sys.stdin.read() or "{}")
print(d.get(sys.argv[1]) if d.get(sys.argv[1]) is not None else "")
' "$1"
}

RUNNING_AT="$(get_field runningAtMs)"
LAST_AT="$(get_field lastRunAtMs)"
LAST_STATUS="$(get_field lastRunStatus)"
LAST_ERROR="$(get_field lastError)"

# 正在跑 → 不干预
if [ -n "${RUNNING_AT}" ]; then
  echo "NO_REPLY"
  exit 0
fi

# 判定「今天是否已经跑过且成功」
LAST_DAY=""
if [ -n "${LAST_AT}" ]; then
  LAST_DAY="$(TZ="${TZ_NAME}" date -d "@$((LAST_AT / 1000))" +%F 2>/dev/null || true)"
fi

if [ "${LAST_DAY}" = "${TODAY}" ] && [ "${LAST_STATUS}" = "ok" ]; then
  echo "NO_REPLY"
  exit 0
fi

# 今天未跑或跑了但失败 → 需要自愈
REASON="today=${TODAY} lastDay=${LAST_DAY:-none} lastStatus=${LAST_STATUS:-none}"
[ -n "${LAST_ERROR}" ] && REASON="${REASON} err=${LAST_ERROR}"

COUNT=0
[ -f "${RETRY_STATE}" ] && COUNT="$(cat "${RETRY_STATE}" 2>/dev/null || echo 0)"
case "${COUNT}" in ''|*[!0-9]*) COUNT=0 ;; esac

if [ "${COUNT}" -ge "${MAX_RETRY}" ]; then
  # 今日重试已用尽，别刷屏（主任务的失败告警已单独投递）
  echo "NO_REPLY"
  exit 0
fi

COUNT=$((COUNT + 1))
echo "${COUNT}" > "${RETRY_STATE}" 2>/dev/null || true

if [ "${DRY_RUN}" = "1" ]; then
  echo "[DRY-RUN] 将重跑内容流水线（第 ${COUNT}/${MAX_RETRY} 次）｜${REASON}"
  exit 0
fi

OUT="$("${CLI}" cron run "${JOB_ID}" 2>&1 | tail -3)"
echo "🔁 内容流水线自愈：检测到当日未成功（${REASON}），已自动重跑（第 ${COUNT}/${MAX_RETRY} 次）。${OUT}"
exit 0
