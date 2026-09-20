#!/usr/bin/env bash
# rsi-wechat 文章归档脚本
# 把已推送到公众号草稿箱的文章，同步归档到 GitHub，便于后续处理。
#
# 用法：
#   bash archive_article.sh <YYYY-MM-DD> <产物目录> [标题]
#
# 参数：
#   <YYYY-MM-DD>  文章日期
#   <产物目录>    流水线产物目录，默认 /root/agents/shared/pipeline/<日期>
#   [标题]        文章标题（缺省时从 meta 或 article.md 首行推断）

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATE="${1:-$(date +%Y-%m-%d)}"
PIPELINE_DIR="${2:-/root/agents/shared/pipeline/${DATE}}"
TITLE="${3:-}"

DEST="${SKILL_DIR}/articles/${DATE}"
REPO_REMOTE="origin"
BRANCH="$(git -C "${SKILL_DIR}" symbolic-ref --short HEAD 2>/dev/null || echo main)"

echo "=== rsi-wechat 文章归档 ==="
echo "日期: ${DATE}"
echo "产物目录: ${PIPELINE_DIR}"
echo "归档目标: ${DEST}"

# 1. 校验产物目录
if [ ! -d "${PIPELINE_DIR}" ]; then
  echo "❌ 产物目录不存在: ${PIPELINE_DIR}" >&2
  exit 1
fi

# 2. 收集终稿正文（优先 format/article.md，其次 02_drafts.json 提取）
mkdir -p "${DEST}/images"
SRC_MD=""
for cand in "${PIPELINE_DIR}/format/article.md" "${PIPELINE_DIR}/article.md"; do
  if [ -f "${cand}" ]; then SRC_MD="${cand}"; break; fi
done

if [ -n "${SRC_MD}" ]; then
  cp "${SRC_MD}" "${DEST}/article.md"
  echo "✅ 正文已归档: ${DEST}/article.md"
else
  echo "⚠️  未找到终稿 markdown，跳过正文（请检查 format 产物）"
fi

# 3. 收集封面与配图
for cand in "${PIPELINE_DIR}/format/imgs/cover.png" "${PIPELINE_DIR}/imgs/cover.png" "${PIPELINE_DIR}/cover.png"; do
  if [ -f "${cand}" ]; then cp "${cand}" "${DEST}/cover.png"; echo "✅ 封面已归档"; break; fi
done

if [ -d "${PIPELINE_DIR}/format/imgs" ]; then
  find "${PIPELINE_DIR}/format/imgs" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    ! -name 'cover.*' -exec cp {} "${DEST}/images/" \; 2>/dev/null || true
fi

# 4. 生成 meta.json
# 从 04_publish_queue.md 抓 media_id（若有）
MEDIA_ID="$(grep -oE 'draft[^|]*media_id[^|]*|media_id[:：]?\s*[A-Za-z0-9_-]+' "${PIPELINE_DIR}/04_publish_queue.md" 2>/dev/null | head -1 | sed -E 's/.*media_id[:：]?\s*//' || true)"
[ -z "${TITLE}" ] && TITLE="$(grep -m1 '^# ' "${DEST}/article.md" 2>/dev/null | sed 's/^# //' || true)"

cat > "${DEST}/meta.json" <<EOF
{
  "date": "${DATE}",
  "title": "${TITLE}",
  "source_pipeline": "${PIPELINE_DIR}",
  "media_id": "${MEDIA_ID}",
  "archived_at": "$(date -Iseconds)",
  "files": {
    "article": "article.md",
    "cover": "cover.png",
    "images_dir": "images/"
  }
}
EOF
echo "✅ 元数据已生成: ${DEST}/meta.json"

# 5. 提交并推送
cd "${SKILL_DIR}"
git add "articles/${DATE}" >/dev/null 2>&1 || true
if git diff --cached --quiet; then
  echo "ℹ️  无变更需提交（可能已归档过）"
else
  git commit -m "article: ${TITLE:-$DATE} (${DATE})" >/dev/null
  echo "✅ 已提交: article: ${TITLE:-$DATE} (${DATE})"
fi

if git push "${REPO_REMOTE}" "${BRANCH}" 2>/dev/null; then
  echo "✅ 已推送到 GitHub (${REPO_REMOTE}/${BRANCH})"
else
  echo "⚠️  GitHub 推送失败（网络/认证）。文章已本地归档，稍后重试。"
  exit 2
fi

echo "=== 归档完成 ==="
