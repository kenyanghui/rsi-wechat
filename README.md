# RSI WeChat 内容流水线

> **RSI = Recursive Self-Improvement（递归自改进）**：AI 参与改进自身内容研发，形成「能力越强 → 内容越好 → 能力更强」的反馈回路。

OpenClaw 多 agent 自动内容流水线，从 IMA 知识库挖素材，全自动产出微信公众号爆款长文。

## 功能

- **一句话触发**：对 assistant 说「跑流水线」即可执行完整四步（+归档）
- **定时执行**：每天 07:20 自动运行，产出 1 篇爆款
- **四步自动**：topic 选题 → writer 写作 → qa 质检 → format 排版（含配图、发文到草稿箱）
- **文章归档**：每次发布后把文章同步到 GitHub（`articles/<日期>/`），便于后续处理
- **RSI 自进化**：每轮回收进化台账，内容质量逐轮递增

## 四步流水线

```
topic（选题） → writer（写作） → qa（质检） → format（排版发文） → archive（归档 GitHub）
```

## 文章归档（GitHub）

已推送到公众号草稿箱的文章，会自动同步到本仓库，便于后续处理（数据分析、二次分发、人工复盘、构建历史文章库）。

```
articles/<YYYY-MM-DD>/
├── article.md      # 正文终稿
├── meta.json       # 元数据（标题/摘要/作者/质检分/media_id/源）
├── cover.png       # 封面图
└── images/         # 正文配图
```

归档脚本：`scripts/archive_article.sh <日期> <产物目录>`

## 整合的 9 个 baoyu skill

| baoyu skill | 能力 | 嵌入点 |
|-------------|------|--------|
| `baoyu-cover-image` | 封面图生成 | format |
| `baoyu-article-illustrator` | 文章插图生成 | format |
| `baoyu-image-gen` | 通用图像生成 | format（兜底） |
| `baoyu-markdown-to-html` | Markdown 转 HTML | format |
| `baoyu-compress-image` | 图片压缩 | format |
| `baoyu-post-to-wechat` | 公众号发文 | format |
| `baoyu-url-to-markdown` | URL 转 Markdown | topic |
| `baoyu-xhs-images` | 小红书图片处理 | 可选复用 |
| `baoyu-slide-deck` | PPT/幻灯片生成 | 可选二次传播 |

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
├── SKILL.md                      # Skill 定义（主入口）
├── README.md                     # 本文件
├── _rsi_ledger.md                # RSI 进化台账（自进化核心）
├── articles/                     # 📦 已发布文章归档（同步到 GitHub）
│   └── <YYYY-MM-DD>/             # article.md + meta.json + cover.png
├── config/
│   └── openclaw.json             # OpenClaw 配置模板
├── pipeline/
│   ├── PIPELINE.md               # 流水线执行规范
│   └── SOURCE-LEDGER.md          # 选题台账
├── references/
│   └── pipeline.md               # 四步流水线详细编排（含 baoyu 嵌入点）
├── templates/                    # 4 个产物模板
│   ├── 01_topics.md
│   ├── 02_drafts.json
│   ├── 03_qa_scores.md
│   └── 04_publish_queue.md
└── scripts/
    ├── setup.sh                  # 一键部署脚本
    ├── run_pipeline.sh           # 手动编排入口
    └── archive_article.sh        # 文章归档到 GitHub
```

## 产物

产物目录：`/root/agents/shared/pipeline/<YYYY-MM-DD>/`

| 文件 | 说明 |
|------|------|
| `01_topics.md` | 选题 brief（含源清单） |
| `02_drafts.json` | 草稿全文 |
| `03_qa_scores.md` | 质检打分 |
| `04_publish_queue.md` | 待发布队列（含归档状态） |

## RSI 自进化机制

每轮流水线结束后，主控回写 `_rsi_ledger.md`（素材避重 / 风格偏好 / 金句库 / 人工修正记录 / RSI 回路快照），下一轮启动时作为硬约束喂给 topic/writer，实现「越跑越准、越用越聪明」。

## 模型配置

| 用途 | 模型 |
|------|------|
| 全部 agent 文本 | `deepseek/deepseek-flash` |
| 图片生成 | `bailian/wanx-1.2-t2i` |

## 主素材库

IMA 知识库「AI量化杨老师」，kb_id: `5JU-YyL5WUdMp3ZzS_7M2B6G5XpOB4ofM2rdKkMr3jY=`

---

_为正行明熙创造价值，RSI 自进化，越用越聪明！_ 🦐
