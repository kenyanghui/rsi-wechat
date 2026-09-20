#!/bin/bash
# RSI WeChat Pipeline — 一键部署脚本
set -e

echo "=== RSI WeChat Pipeline 部署 ==="

# 1. 安装 Node 22 LTS
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. 安装 OpenClaw
sudo npm install -g openclaw@2026.7.1-2

# 3. 注册 4 个子 agent
for agent in writer topic qa format; do
  openclaw agents add $agent \
    --workspace /root/agents/$agent \
    --agent-dir /root/.openclaw/agents/$agent/agent \
    --model deepseek/deepseek-flash \
    --non-interactive
done

# 4. 创建共享目录
mkdir -p /root/agents/shared

# 5. 复制流水线文件
cp pipeline/PIPELINE.md /root/agents/shared/
cp pipeline/SOURCE-LEDGER.md /root/agents/shared/

# 6. 启用 gateway
openclaw gateway install

echo "=== 部署完成 ==="
echo "下一步：编辑 config/openclaw.json 填入真实 API Key，然后重建定时任务"
