#!/usr/bin/env bash
# check_drift.sh — rsi-wechat 防漂移守卫（v1.4.0 新增，借鉴 octopus-workflow drift guards）
#
# 以 pipeline/MANIFEST.json 为唯一事实源（SSOT），校验：
#   G1 版本一致性：SKILL.md frontmatter version == MANIFEST.version
#   G2 步骤链一致：关键文档必须包含「热点采集」步骤链关键词，且不得出现禁用词（四步/五步等旧口径）
#   G3 台账完整性：_rsi_ledger.md 章节必须连续存在（## 1. ~ ## N.）
#   G4 归档断档：articles/ 最新归档日期距今超过阈值则告警（默认 2 天）
#   G5 编码健康：核心 md/json 文件必须是合法 UTF-8
#
# 用法: bash scripts/check_drift.sh [--archive-gap-days N]
# 退出码: 0=通过(允许 warning)  1=存在 error
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="${SKILL_DIR}/pipeline/MANIFEST.json"
ERRORS=0
WARNINGS=0

err()   { echo "❌ $*"; ERRORS=$((ERRORS+1)); }
warn()  { echo "⚠️  $*"; WARNINGS=$((WARNINGS+1)); }
ok()    { echo "✅ $*"; }

GAP_DAYS=2
while [ $# -gt 0 ]; do
  case "$1" in
    --archive-gap-days) shift; GAP_DAYS="${1:-2}" ;;
  esac
  shift
done

echo "=== rsi-wechat 防漂移守卫（drift guard）==="

# ── 前置 ──
if [ ! -f "${MANIFEST}" ]; then
  err "SSOT 注册表缺失: pipeline/MANIFEST.json"
  echo "=== 结果: FAIL (1 error) ==="; exit 1
fi
jsonget() { python3 -c "import json,sys;d=json.load(open(sys.argv[1]));v=d$1;print(v if not isinstance(v,list) else ' '.join(v))" "${MANIFEST}" 2>/dev/null; }
VER="$(jsonget "['version']")"
ok "SSOT 注册表: pipeline/MANIFEST.json (version=${VER})"

# ── G1 版本一致性 ──
echo ""
echo "--- G1 版本一致性 ---"
SKILL_VER="$(sed -n 's/^version:[[:space:]]*//p' "${SKILL_DIR}/SKILL.md" | head -1 | tr -d '[:space:]')"
if [ "${SKILL_VER}" = "${VER}" ]; then
  ok "SKILL.md version (${SKILL_VER}) == MANIFEST.version"
else
  err "版本漂移: SKILL.md=${SKILL_VER:-<空>} vs MANIFEST=${VER} —— 改 MANIFEST 并同步 SKILL.md"
fi

# ── G2 步骤链口径 ──
echo ""
echo "--- G2 步骤链口径 ---"
STEP_CHAIN_FILE="$(jsonget "['drift_guards']['step_chain_expected_in']")"
for f in ${STEP_CHAIN_FILE}; do
  path="${SKILL_DIR}/${f}"
  if [ ! -f "${path}" ]; then warn "${f} 不存在（跳过）"; continue; fi
  if grep -q "热点采集" "${path}"; then
    ok "${f} 含九步步骤链关键词「热点采集」"
  else
    err "${f} 缺少步骤链关键词「热点采集」（疑似旧版口径）"
  fi
done
BANNED="$(python3 -c "import json;d=json.load(open('${MANIFEST}'))['drift_guards']['banned_words'];[print(f,v) for f,vs in d.items() for v in vs]" 2>/dev/null)"
while read -r f word; do
  [ -z "${f}" ] && continue
  path="${SKILL_DIR}/${f}"
  [ -f "${path}" ] || continue
  if grep -q "${word}" "${path}"; then
    err "${f} 仍含旧口径「${word}」"
  else
    ok "${f} 无旧口径「${word}」"
  fi
done <<< "${BANNED}"

# ── G3 台账完整性 ──
echo ""
echo "--- G3 台账完整性 ---"
LEDGER="${SKILL_DIR}/_rsi_ledger.md"
python3 - "${MANIFEST}" "${LEDGER}" <<'PY' || ERRORS=$((ERRORS+1))
import json,sys,re
man,ledger=sys.argv[1],sys.argv[2]
secs=json.load(open(man))["drift_guards"]["ledger_required_sections"]
txt=open(ledger,encoding="utf-8").read()
missing=[s for s in secs if not re.search(r"^"+re.escape(s),txt,re.M)]
for s in missing: print(f"❌ 台账章节缺失: {s}（_rsi_ledger.md）")
if not missing: print("✅ 台账章节 ## 1. ~ ## %s 全部存在" % secs[-1].split()[1])
sys.exit(1 if missing else 0)
PY

# ── G4 归档断档 ──
echo ""
echo "--- G4 归档断档 ---"
LAST_ARCHIVE="$(ls -1 "${SKILL_DIR}/articles" 2>/dev/null | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/' | sort | tail -1)"
if [ -z "${LAST_ARCHIVE}" ]; then
  warn "articles/ 无归档记录（新仓库可忽略）"
else
  GAP=$(( ($(date +%s) - $(date -d "${LAST_ARCHIVE}" +%s)) / 86400 ))
  if [ "${GAP}" -gt "${GAP_DAYS}" ]; then
    warn "归档断档 ${GAP} 天（最新 ${LAST_ARCHIVE}，阈值 ${GAP_DAYS} 天）—— 检查流水线是否静默失败"
  else
    ok "归档新鲜: 最新 ${LAST_ARCHIVE}（${GAP} 天前）"
  fi
fi

# ── G5 编码健康 ──
echo ""
echo "--- G5 编码健康 ---"
for f in SKILL.md README.md _rsi_ledger.md pipeline/MANIFEST.json pipeline/PIPELINE.md references/pipeline.md config/qa-rubric.json config/wecom-qr.meta.json; do
  path="${SKILL_DIR}/${f}"
  [ -f "${path}" ] || continue
  if iconv -f UTF-8 -t UTF-8 "${path}" >/dev/null 2>&1; then
    ok "UTF-8 合法: ${f}"
  else
    err "编码损坏（非 UTF-8）: ${f}"
  fi
done

# ── G6 编排可靠性口径（v1.5.2）──
echo ""
echo "--- G6 编排可靠性口径 ---"
G6_MISSES=0
for f in pipeline/PIPELINE.md references/pipeline.md SKILL.md; do
  path="${SKILL_DIR}/${f}"
  [ -f "${path}" ] || continue
  if grep -q "禁止被动等待" "${path}" || grep -q "v1.5.2 可靠性" "${path}" || grep -q "编排可靠性硬规则" "${path}"; then
    ok "可靠性硬规则口径存在: ${f}"
  else
    err "缺 v1.5.2 可靠性硬规则口径: ${f}"
    G6_MISSES=$((G6_MISSES+1))
  fi
done
WD="${SKILL_DIR}/scripts/watchdog_pipeline.sh"
if [ -f "${WD}" ]; then
  if grep -q "产物完整性检查" "${WD}" && grep -q "finished" "${WD}"; then
    ok "watchdog v1.5.2 产物完整性检查在位"
  else
    err "watchdog_pipeline.sh 未升级到 v1.5.2（缺产物完整性检查/finished 标记）"
  fi
fi

# ── 汇总 ──
echo ""
echo "=== 结果: $([ ${ERRORS} -eq 0 ] && echo PASS || echo FAIL) — ${ERRORS} error(s), ${WARNINGS} warning(s) ==="
[ ${ERRORS} -eq 0 ]
