#!/usr/bin/env bash
# rsi-wechat 一键编排入口（手动触发用）
# 用法：bash run_pipeline.sh [YYYY-MM-DD]
# 实际编排由主控 agent 通过 sessions_spawn 依次执行 topic→writer→qa→format。
# 本脚本仅做前置准备：建产物目录 + 检查前置依赖，后续交给主控。

set -euo pipefail

DATE="${1:-$(date +%Y-%m-%d)}"
PIPELINE_DIR="/root/agents/shared/pipeline/${DATE}"

echo "=== rsi-wechat 流水线编排准备 ==="
echo "日期: ${DATE}"

# 1. 建产物目录
mkdir -p "${PIPELINE_DIR}"
echo "✅ 产物目录已就绪: ${PIPELINE_DIR}"

# 2. 检查关键依赖文件
echo ""
echo "=== 依赖检查 ==="
check() {
  local desc="$1"; local path="$2"
  if [ -e "${path}" ]; then
    echo "  ✅ ${desc}: ${path}"
  else
    echo "  ⚠️  ${desc}: 缺失 (${path})"
  fi
}

check "IMA 知识库 skill" "/root/.openclaw/workspace/skills/ima-skills/knowledge-base/SKILL.md"
check "baoyu-post-to-wechat" "/root/.openclaw/workspace/skills/baoyu-post-to-wechat/SKILL.md"
check "baoyu-cover-image" "/root/.openclaw/workspace/skills/baoyu-cover-image/SKILL.md"
check "baoyu-article-illustrator" "/root/.openclaw/workspace/skills/baoyu-article-illustrator/SKILL.md"
check "baoyu-markdown-to-html" "/root/.openclaw/workspace/skills/baoyu-markdown-to-html/SKILL.md"
check "baoyu-compress-image" "/root/.openclaw/workspace/skills/baoyu-compress-image/SKILL.md"
check "RSI 进化台账" "$(dirname "$0")/../_rsi_ledger.md"
check "选题查重台账" "/root/agents/shared/SOURCE-LEDGER.md"
check "文章归档目录" "$(dirname "$0")/../articles"
check "归档脚本" "$(dirname "$0")/archive_article.sh"

echo ""
echo "=== 请主控 agent 按 references/pipeline.md 依次 spawn 四个子 agent ==="
echo "   topic → writer → qa → format"
echo "完成后：①归档文章到 GitHub（scripts/archive_article.sh） ②回写 RSI 台账 _rsi_ledger.md"
