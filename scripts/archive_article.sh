#!/usr/bin/env bash
# rsi-wechat 文章归档脚本（支持每天多篇）
# 把已推送到公众号草稿箱的文章，同步归档到 GitHub，便于后续处理。
#
# 用法：
#   bash archive_article.sh <YYYY-MM-DD> <产物目录> [标题]
#
# 参数：
#   <YYYY-MM-DD>  文章日期
#   <产物目录>    流水线产物目录，默认 /root/agents/shared/pipeline/<日期>
#   [标题]        单篇归档时的标题覆盖（缺省从 manifest / article.md 推断）
#
# 归档目录规则（同日多篇自动编号，绝不覆盖）：
#   articles/<日期>/      第 1 篇
#   articles/<日期>-2/    第 2 篇
#   articles/<日期>-3/    第 3 篇
#
# 多篇来源（优先级）：
#   1) <产物目录>/format/manifest.json   （format 环节产出的清单，推荐）
#   2) 扫描 <产物目录>/format/article*.md

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 参数解析：支持 --dry-run（只演练不写不推）
DRY_RUN=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --dry-run|-n) DRY_RUN=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
DATE="${ARGS[0]:-$(date +%Y-%m-%d)}"
PIPELINE_DIR="${ARGS[1]:-/root/agents/shared/pipeline/${DATE}}"
TITLE_OVERRIDE="${ARGS[2]:-}"

REPO_REMOTE="origin"
# 远端规范分支（本地分支名可能不同，如本地 master → 远端 main）
BRANCH="${RSI_REMOTE_BRANCH:-main}"
LOCAL_BRANCH="$(git -C "${SKILL_DIR}" symbolic-ref --short HEAD 2>/dev/null || echo main)"

echo "=== rsi-wechat 文章归档 ==="
echo "日期: ${DATE}"
echo "产物目录: ${PIPELINE_DIR}"

if [ ! -d "${PIPELINE_DIR}" ]; then
  echo "❌ 产物目录不存在: ${PIPELINE_DIR}" >&2
  exit 1
fi

json_escape() {
  printf '%s' "$1" | python3 -c 'import json,sys; sys.stdout.write(json.dumps(sys.stdin.read())[1:-1])' 2>/dev/null \
    || printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# 返回当天可用的归档目录（<日期>、<日期>-2、<日期>-3 …）
next_dest() {
  local d="${SKILL_DIR}/articles/${DATE}"
  if [ ! -e "${d}" ]; then printf '%s' "${d}"; return; fi
  local n=2
  while [ -e "${SKILL_DIR}/articles/${DATE}-${n}" ]; do n=$((n+1)); done
  printf '%s' "${SKILL_DIR}/articles/${DATE}-${n}"
}

# 建立 (article_md, cover, title, media_id) 四元组列表
# 用 tab 分隔，逐行写入临时文件
MANIFEST="${PIPELINE_DIR}/format/manifest.json"
LIST_FILE="$(mktemp)"
trap 'rm -f "${LIST_FILE}"' EXIT

if [ -f "${MANIFEST}" ]; then
  python3 - "$MANIFEST" "$PIPELINE_DIR" >> "${LIST_FILE}" <<'PY'
import json, sys, os
manifest, pdir = sys.argv[1], sys.argv[2]
fmt = os.path.join(pdir, "format")
try:
    data = json.load(open(manifest, encoding="utf-8"))
except Exception:
    data = []
if isinstance(data, dict):
    data = data.get("articles", [])
for i, it in enumerate(data, 1):
    art = it.get("article") or f"article-{i}.md"
    art = art if os.path.isabs(art) else os.path.join(fmt, art)
    cov = it.get("cover") or f"imgs/cover-{i}.png"
    cov = cov if os.path.isabs(cov) else os.path.join(fmt, cov)
    title = (it.get("title") or "").replace("\t", " ").replace("\n", " ")
    mid = (it.get("media_id") or "").replace("\t", " ").replace("\n", " ")
    print(f"{art}\t{cov}\t{title}\t{mid}")
PY
fi

# 回退：扫描 article*.md
# 支持两种布局：单篇 <DIR>/format/article.md；多篇 <DIR>/p1|p2|p3/format/article.md
if [ ! -s "${LIST_FILE}" ]; then
  mapfile -t MARKS < <(
    find "${PIPELINE_DIR}"/p*/format -maxdepth 1 -type f -name 'article*.md' 2>/dev/null \
    | sort
  )
  if [ "${#MARKS[@]}" -eq 0 ]; then
    mapfile -t MARKS < <(find "${PIPELINE_DIR}/format" -maxdepth 1 -type f -name 'article*.md' 2>/dev/null | sort)
  fi
  [ "${#MARKS[@]}" -eq 0 ] && mapfile -t MARKS < <(find "${PIPELINE_DIR}" -maxdepth 1 -type f -name 'article*.md' 2>/dev/null | sort)
  for md in "${MARKS[@]}"; do
    base="$(basename "${md}" .md)"
    dir="$(dirname "${md}")"
    idx=""; [[ "${base}" =~ -([0-9]+)$ ]] && idx="${BASH_REMATCH[1]}"
    cov=""
    # 优先同目录封面，其次上级 imgs/
    for c in "${dir}/imgs/cover-${idx}.png" "${dir}/imgs/cover.png" \
             "${dir}/../imgs/cover-${idx}.png" "${dir}/../imgs/cover.png" \
             "${PIPELINE_DIR}/imgs/cover.png" "${PIPELINE_DIR}/cover.png"; do
      [ -n "${c}" ] && [ -f "${c}" ] && { cov="${c}"; break; }
    done
    printf '%s\t%s\t\t\n' "${md}" "${cov}" >> "${LIST_FILE}"
  done
fi

if [ ! -s "${LIST_FILE}" ]; then
  echo "⚠️  未找到任何终稿 markdown（format/manifest.json 或 article*.md），跳过" >&2
  exit 1
fi

TOTAL="$(grep -c '' "${LIST_FILE}")"
echo "发现 ${TOTAL} 篇待归档文章"
if [ "${DRY_RUN}" = "1" ]; then
  echo "--- [dry-run] 计划归档如下（不写入、不提交、不推送）---"
  n=1
  while IFS=$'\t' read -r SRC_MD COVER TITLE MEDIA_ID; do
    [ -z "${SRC_MD}" ] && continue
    printf '  [%d] 正文: %s\n      封面: %s\n      标题: %s\n      media_id: %s\n' \
      "${n}" "${SRC_MD}" "${COVER:-<无>}" "${TITLE:-<自动推断>}" "${MEDIA_ID:-<无>}"
    n=$((n+1))
  done < "${LIST_FILE}"
  echo "=== [dry-run] 结束（未做任何变更）==="
  exit 0
fi

ARCHIVED=()
TITLES=()

while IFS=$'\t' read -r SRC_MD COVER TITLE MEDIA_ID; do
  [ -z "${SRC_MD}" ] && continue

  DEST="$(next_dest)"
  mkdir -p "${DEST}/images"
  REL_DEST="${DEST#${SKILL_DIR}/}"

  # 正文
  if [ -f "${SRC_MD}" ]; then
    cp "${SRC_MD}" "${DEST}/article.md"
  else
    echo "   ⚠️  正文缺失: ${SRC_MD}" >&2
    rmdir "${DEST}/images" "${DEST}" 2>/dev/null || true
    continue
  fi

  # 封面
  if [ -n "${COVER}" ] && [ -f "${COVER}" ]; then
    cp "${COVER}" "${DEST}/cover.png"
  else
    for c in "${PIPELINE_DIR}/format/imgs/cover.png" "${PIPELINE_DIR}/imgs/cover.png" "${PIPELINE_DIR}/cover.png"; do
      [ -f "${c}" ] && { cp "${c}" "${DEST}/cover.png"; break; }
    done
  fi

  # 配图（排除封面）：扫描所在 format 目录的 imgs/
  IMG_SRC="$(dirname "${SRC_MD}")/imgs"
  [ -d "${IMG_SRC}" ] || IMG_SRC="${PIPELINE_DIR}/format/imgs"
  if [ -d "${IMG_SRC}" ]; then
    find "${IMG_SRC}" -type f \
      \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
      ! -iname 'cover*' -exec cp {} "${DEST}/images/" \; 2>/dev/null || true
  fi

  # 标题 & media_id
  if [ -z "${TITLE}" ]; then
    TITLE="$(grep -m1 '^# \|^title:' "${DEST}/article.md" 2>/dev/null | sed -E 's/^# //; s/^title:[[:space:]]*//' || true)"
  fi
  if [ -z "${TITLE}" ] && [ "${TOTAL}" = "1" ] && [ -n "${TITLE_OVERRIDE}" ]; then
    TITLE="${TITLE_OVERRIDE}"
  fi
  [ -z "${TITLE}" ] && TITLE="${DATE}"

  if [ -z "${MEDIA_ID}" ] && [ "${TOTAL}" = "1" ] && [ -f "${PIPELINE_DIR}/04_publish_queue.md" ]; then
    MEDIA_ID="$(grep -oE 'media_id[^`]*`[A-Za-z0-9_-]{20,}`' "${PIPELINE_DIR}/04_publish_queue.md" 2>/dev/null \
      | head -1 | grep -oE '[A-Za-z0-9_-]{20,}' | head -1 || true)"
    [ -z "${MEDIA_ID}" ] && MEDIA_ID="$(grep -oE '[A-Za-z0-9_-]{40,}' "${PIPELINE_DIR}/04_publish_queue.md" 2>/dev/null | head -1 || true)"
  fi

  cat > "${DEST}/meta.json" <<EOF
{
  "date": "${DATE}",
  "title": "$(json_escape "${TITLE}")",
  "source_pipeline": "${PIPELINE_DIR}",
  "media_id": "$(json_escape "${MEDIA_ID}")",
  "archived_at": "$(date -Iseconds)",
  "files": {
    "article": "article.md",
    "cover": "cover.png",
    "images_dir": "images/"
  }
}
EOF
  echo "   ✅ 已归档: ${REL_DEST}  （${TITLE}）"
  ARCHIVED+=("${REL_DEST}")
  TITLES+=("${TITLE}")
done < "${LIST_FILE}"

if [ "${#ARCHIVED[@]}" -eq 0 ]; then
  echo "⚠️  没有成功归档的文章" >&2
  exit 1
fi

# 提交并推送
cd "${SKILL_DIR}"
for d in "${ARCHIVED[@]}"; do git add "${d}" >/dev/null 2>&1 || true; done
if git diff --cached --quiet; then
  echo "ℹ️  无变更需提交（可能已归档过）"
else
  if [ "${#ARCHIVED[@]}" -eq 1 ]; then
    MSG="article: ${TITLES[0]} (${DATE})"
  else
    MSG="archive ${DATE}: ${#ARCHIVED[@]} 篇（${TITLES[0]} 等）"
  fi
  git commit -m "${MSG}" >/dev/null && echo "✅ 已提交: ${MSG}"
fi

PUSH_OK=0
for attempt in 1 2 3; do
  if GIT_TERMINAL_PROMPT=0 git -c http.lowSpeedLimit=100 -c http.lowSpeedTime=60 -c http.connectTimeout=30 \
       push "${REPO_REMOTE}" "${LOCAL_BRANCH}:${BRANCH}" 2>/dev/null; then
    echo "✅ 已推送到 GitHub (${REPO_REMOTE}/${BRANCH})"; PUSH_OK=1; break
  fi
  echo "   ⚠️  推送尝试 ${attempt} 失败" >&2
  [ "${attempt}" -lt 3 ] && sleep 5
done

if [ "${PUSH_OK}" = "0" ]; then
  echo "⚠️  GitHub 推送失败（网络/认证）。文章已本地归档，稍后重试。" >&2
  exit 2
fi

echo "=== 归档完成 ==="
