# RSI WeChat 内容流水线

OpenClaw 多 agent 自动内容流水线，一句话生成微信公众号文章。

## 功能

- **一句话触发**：对 assistant 说「跑流水线」即可执行完整四步
- **定时执行**：每月 1 日 05:00 自动运行
- **四步自动**：topic 选题 → writer 写作 → qa 质检 → format 排版

## 快速部署

```bash
# 克隆仓库
git clone https://github.com/kenyanghui/rsi-wechat.git
cd rsi-wechat

# 一键部署
bash scripts/setup.sh

# 填入 API Key（编辑 config/openclaw.json）
# 重建设定时任务
```

## 必填参数

| 参数 | 说明 |
|------|------|
| `DEEPSEEK_API_KEY` | DeepSeek Flash API Key（主 agent + 4 个子 agent 文本模型） |
| `BAILIAN_API_KEY` | 阿里云百炼 API Key（图片生成） |
| `LIGHTCLAWBOT_ACCOUNT_ID` | lightclawbot 账号 ID |
| `LIGHTCLAWBOT_API_KEY` | lightclawbot API Key |

## 目录结构

```
rsi-wechat/
├── SKILL.md              # Skill 定义
├── README.md             # 本文件
├── config/
│   └── openclaw.json     # OpenClaw 配置模板
├── pipeline/
│   ├── PIPELINE.md       # 流水线执行规范
│   └── SOURCE-LEDGER.md  # 选题台账
└── scripts/
    └── setup.sh          # 一键部署脚本
```

## 产物

产物目录：`/root/agents/shared/pipeline/<YYYY-MM-DD>/`

| 文件 | 说明 |
|------|------|
| `01_topics.md` | 选题 brief |
| `02_drafts.json` | 草稿全文 |
| `03_qa_scores.md` | 质检打分 |
| `04_publish_queue.md` | 待发布队列 |

## 模型配置

| 用途 | 模型 |
|------|------|
| 全部 agent 文本 | `deepseek/deepseek-flash` |
| 图片生成 | `bailian/wanx-1.2-t2i` |

## 主素材库

IMA 知识库「AI量化杨老师」，kb_id: `5JU-YyL5WUdMp3ZzS_7M2B6G5XpOB4ofM2rdKkMr3jY=`
