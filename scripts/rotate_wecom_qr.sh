#!/usr/bin/env bash
# rotate_wecom_qr.sh — 更换企业微信获客活码（客户群活码），并同步 meta 与台账
#
# 用法:
#   bash scripts/rotate_wecom_qr.sh <新活码图片路径> [--expires <YYYY-MM-DD|never>] [--dry-run]
#
# 说明:
#   1. 校验新图（存在 + PNG/JPG）。
#   2. 备份旧码到 config/archive/wecom-qr-<旧日期>.png（可回溯）。
#   3. 覆盖 config/wecom-qr.png —— format 环节自动读取该文件，无需改动其它配置。
#   4. 更新 config/wecom-qr.meta.json（类型/到期/替换记录）。
#   5. 更新 _rsi_ledger.md「有效期提醒」表。
#
# 设计目标: 「一次换码，全链路自动复用」——format 只认固定路径 config/wecom-qr.png。
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="${SKILL_DIR}/config"
QR_FILE="${CONFIG_DIR}/wecom-qr.png"
META_FILE="${CONFIG_DIR}/wecom-qr.meta.json"
ARCHIVE_DIR="${CONFIG_DIR}/archive"
LEDGER="${SKILL_DIR}/_rsi_ledger.md"

SRC=""
EXPIRES=""
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --expires) shift; EXPIRES="${1:-}" ;;
    --dry-run|-n) DRY_RUN=1 ;;
    *) [ -z "${SRC}" ] && SRC="$1" ;;
  esac
  shift
done

today="$(date +%Y-%m-%d)"

if [ -z "${SRC}" ]; then
  echo "用法: bash scripts/rotate_wecom_qr.sh <新活码图片路径> [--expires <YYYY-MM-DD|never>] [--dry-run]"
  echo "提示: 客户群活码可在 企业微信后台 →「客户联系 → 加入群聊 → 客户群活码」生成，通常长期有效（--expires never）。"
  exit 2
fi

if [ ! -f "${SRC}" ]; then
  echo "❌ 新活码文件不存在: ${SRC}"; exit 1
fi

ftype="$(file -b --mime-type "${SRC}" 2>/dev/null || echo unknown)"
case "${ftype}" in
  image/png|image/jpeg|image/jpg|image/webp) ;;
  *) echo "❌ 不是支持的图片类型: ${ftype}（需 PNG/JPG/WebP）"; exit 1 ;;
esac

echo "=== 更换企业微信获客活码 ==="
echo "新码: ${SRC} (${ftype})"

if [ "${DRY_RUN}" = "1" ]; then
  echo "[dry-run] 将备份旧码 → ${ARCHIVE_DIR}/wecom-qr-${today}.png"
  echo "[dry-run] 将覆盖 → ${QR_FILE}"
  echo "[dry-run] 将更新 meta 与台账（expires=${EXPIRES:-保持${today}+30?})"
  exit 0
fi

# 1) 备份旧码
mkdir -p "${ARCHIVE_DIR}"
if [ -f "${QR_FILE}" ]; then
  cp -f "${QR_FILE}" "${ARCHIVE_DIR}/wecom-qr-${today}.png"
  echo "✅ 旧码已备份: ${ARCHIVE_DIR}/wecom-qr-${today}.png"
fi

# 2) 覆盖新码（format 自动复用）
cp -f "${SRC}" "${QR_FILE}"
echo "✅ 新码已就位: ${QR_FILE}"

# 3) 更新 meta
python3 - "${META_FILE}" "${EXPIRES}" "${today}" <<'PY'
import json,sys,os
meta_path,expires,today=sys.argv[1],sys.argv[2],sys.argv[3]
try:
    meta=json.load(open(meta_path,encoding="utf-8"))
except Exception:
    meta={}
meta["type"]="group_live_code"
meta["type_label"]="客户群活码（多群轮换·长期有效）"
meta["file"]="config/wecom-qr.png"
meta["replaced_at"]=today
if expires:
    if expires.lower() in ("never","none","0",""):
        meta["expires_at"]=None; meta["never_expires"]=True
    else:
        meta["expires_at"]=expires; meta["never_expires"]=False
json.dump(meta,open(meta_path,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
print(f"✅ meta 已更新: expires_at={meta.get('expires_at')} never_expires={meta.get('never_expires')}")
PY

# 4) 更新台账「有效期提醒」表
if [ -f "${LEDGER}" ]; then
  exp_display="${EXPIRES:-未知}"
  python3 - "${LEDGER}" "${today}" "${exp_display}" <<'PY'
import sys,re
ledger,today,exp=sys.argv[1],sys.argv[2],sys.argv[3]
txt=open(ledger,encoding="utf-8").read()
new_row=f"| 企业微信获客二维码 | `config/wecom-qr.png`（文末 CTA 承接·客户群活码） | {today} | **{exp}** | 客户群活码自动换群，一般长期有效，无需频繁更换 | ✅ 已换新码 |"
# 替换原有二维码行（匹配含「企业微信获客二维码」的表行）
txt2=re.sub(r"\|[^\n]*企业微信获客二维码[^\n]*\|", new_row, txt, count=1)
if txt2==txt:
    txt2=txt.rstrip()+"\n"+new_row+"\n"
open(ledger,"w",encoding="utf-8").write(txt2)
print("✅ 台账「有效期提醒」表已更新")
PY
fi

echo "=== 换码完成，format 环节将自动复用新码 ==="
