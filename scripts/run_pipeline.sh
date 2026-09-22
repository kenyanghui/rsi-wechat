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
check "IMA 导入脚本" "$(dirname "$0")/import_urls_to_ima.sh"
check "获客活码脚本" "$(dirname "$0")/rotate_wecom_qr.sh"
check "IMA 文件夹地图" "$(dirname "$0")/../references/folder-map.md"
check "IMA 归档机制速查" "$(dirname "$0")/../references/ima-api-mechanics.md"
check "获客二维码" "$(dirname "$0")/../config/wecom-qr.png"
check "活码元信息" "$(dirname "$0")/../config/wecom-qr.meta.json"

# 外部热点能力（v1.2.0）：opencli CLI + Browser Bridge 插件
if command -v opencli >/dev/null 2>&1; then
  echo "  ✅ opencli CLI: $(command -v opencli) ($(opencli --version 2>/dev/null | head -1))"
else
  echo "  ⚠️  opencli CLI: 未安装（热点采集将降级 web_search）"
fi
if [ -f "$HOME/.openclaw/opencli-extension/manifest.json" ]; then
  echo "  ✅ Browser Bridge 插件: $HOME/.openclaw/opencli-extension"
else
  echo "  ⚠️  Browser Bridge 插件: 缺失（opencli 热点不可用）"
fi

echo ""
echo "=== 请主控 agent 按 references/pipeline.md 依次 spawn 四个子 agent ==="
echo "   Step0.5 热点采集(opencli) → Step0.7 素材采集与知识库运营 → topic → writer → qa → format → Step4.5 import-urls → archive → sync-ima"
echo "完成后：①导入外部文章到 IMA（scripts/import_urls_to_ima.sh）②归档到 GitHub（scripts/archive_article.sh）③同步 IMA（scripts/sync_to_ima.sh）④回写 RSI 台账"
