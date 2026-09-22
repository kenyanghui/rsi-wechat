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
#   - 上传前调用 check_repeated_names 查重（不支持替换，重名时加时间戳后缀）
#   - 幂等去重：已同步过的文章（含本地状态文件 + 远端查重）自动跳过，可重复执行
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
# 凭证不 export、不落明文变量：由下方 Python 直接读文件（key 不进 ps/env）

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

# ── 上传 ──（含：重名检查 + 幂等去重 + 失败分类）──
SYNC_STATE="${STAGE}/../.synced_manifest.txt"   # 已同步清单（幂等去重用）
mkdir -p "$(dirname "${SYNC_STATE}")"

# 用 Python 内嵌执行：重名检查 → 幂等去重 → create_media → COS → add_knowledge
python3 - "${STAGE}" "${SYNC_STATE}" "${KB_ID}" "${IMA_FOLDER_ID}" "${IMA_SKILL_DIR}" <<'PY'
import sys, os, json, time, subprocess, hashlib

stage, state_file, kb_id, folder_id, ima_dir = sys.argv[1:6]
ima_api = os.path.join(ima_dir, "ima_api.cjs")
cos_upload = os.path.join(ima_dir, "knowledge-base", "scripts", "cos-upload.cjs")

client_id = open(os.path.expanduser("~/.config/ima/client_id")).read().strip()
api_key = open(os.path.expanduser("~/.config/ima/api_key")).read().strip()
opts = json.dumps({"clientId": client_id, "apiKey": api_key}, ensure_ascii=False)

def api(path, body):
    p = subprocess.run(["node", ima_api, path, json.dumps(body, ensure_ascii=False), opts],
                       capture_output=True, text=True)
    try:
        return json.loads(p.stdout or "{}")
    except:
        return {"code": -1, "msg": (p.stderr or p.stdout or "unknown")[:200]}

# 已同步状态（幂等去重）
synced = set()
if os.path.isfile(state_file):
    synced = set(l.strip() for l in open(state_file) if l.strip())

files = sorted(f for f in os.listdir(stage) if f.endswith(".md"))
if not files:
    print("未找到待同步 Markdown 文件")
    sys.exit(0)

# 1) 批量重名检查（对每个候选文件名）
to_check = [{"name": f, "media_type": 7} for f in files]
rep = api("openapi/wiki/v1/check_repeated_names",
          {"params": to_check, "knowledge_base_id": kb_id, "folder_id": folder_id})
rep_map = {}
if rep.get("code") == 0:
    for r in (rep.get("data", {}).get("results") or []):
        rep_map[r.get("name")] = r.get("is_repeated", False)

ok = fail = skipped = renamed = 0
for f in files:
    fpath = os.path.join(stage, f)
    # 幂等：文件内容指纹已同步过 → 跳过
    digest = hashlib.md5(open(fpath, "rb").read()).hexdigest()
    if digest in synced:
        print(f"  ⏭ 已同步（幂等跳过）: {f}"); skipped += 1; continue

    size = os.path.getsize(fpath)
    if size > 10*1024*1024:
        print(f"  ❌ 超过 10MB 跳过: {f}"); fail += 1; continue

    # 重名处理：远端已有同名 → 加时间戳后缀
    final_name = f
    if rep_map.get(f, False):
        base, ext = os.path.splitext(f)
        final_name = f"{base}_{time.strftime('%Y%m%d%H%M%S')}{ext}"
        renamed += 1
        print(f"  ⚠️ 同名已存在，改名重传: {f} → {final_name}")

    # create_media
    cm = api("openapi/wiki/v1/create_media", {
        "file_name": final_name, "file_size": size, "content_type": "text/markdown",
        "knowledge_base_id": kb_id, "file_ext": "md", "folder_id": folder_id})
    if cm.get("code") != 0:
        print(f"  ❌ create_media 失败: {f} ({cm.get('msg','')})"); fail += 1; continue
    d = cm["data"]
    mid = d.get("media_id", "")
    cred = d.get("cos_credential", {})
    cos_key = cred.get("cos_key", "")

    # COS 上传
    cp = subprocess.run(["node", cos_upload,
        "--file", fpath,
        "--secret-id", cred.get("secret_id",""),
        "--secret-key", cred.get("secret_key",""),
        "--token", cred.get("token",""),
        "--bucket", cred.get("bucket_name",""),
        "--region", cred.get("region",""),
        "--cos-key", cos_key,
        "--content-type", "text/markdown",
        "--start-time", str(cred.get("start_time","")),
        "--expired-time", str(cred.get("expired_time","")),
        "--timeout", "300000"], capture_output=True, text=True)
    if cp.returncode != 0:
        print(f"  ❌ COS 上传失败: {final_name}"); fail += 1; continue

    # add_knowledge
    ak = api("openapi/wiki/v1/add_knowledge", {
        "media_type": 7, "media_id": mid, "title": final_name,
        "knowledge_base_id": kb_id, "folder_id": folder_id,
        "file_info": {"cos_key": cos_key, "file_size": size, "file_name": final_name}})
    if ak.get("code") != 0:
        print(f"  ❌ add_knowledge 失败: {final_name} ({ak.get('msg','')})"); fail += 1; continue

    # 记录同步指纹
    with open(state_file, "a") as sf:
        sf.write(digest + "\n")
    print(f"  ✅ 已同步: {final_name}"); ok += 1
    time.sleep(0.5)

print(f"=== IMA 同步完成: 成功 {ok}，重名改名 {renamed}，跳过(幂等) {skipped}，失败 {fail} ===")
sys.exit(1 if fail > 0 else 0)
PY
EXIT_CODE=$?
rm -f "${LIST_FILE}"
exit ${EXIT_CODE}
