---
name: rsi-wechat
description: 正行明熙「RSI 自进化」微信公众号内容运营流水线。以 RSI（Recursive Self-Improvement，递归自改进）理念驱动：AI 参与改进自身内容研发，形成"能力越强→内容越好→能力更强"的反馈回路。整合 topic→writer→qa→format 四步内容流水线与 9 个 baoyu 图文能力（封面图/文章插图/通用图像生成/PPT/Markdown转HTML/图片压缩/公众号发文/URL转Markdown/小红书图片），从 IMA 知识库「AI量化杨老师」挖掘素材，自动产出公众号爆款长文并推送到草稿箱（人工闸门前停）。Use when user mentions "发公众号", "公众号文章", "内容流水线", "rsi-wechat", "每天一篇爆款", "RSI 自进化".
version: 1.0.0
metadata:
  openclaw:
    homepage: https://github.com/kenyanghui/rsi-wechat
---

# RSI-WeChat 自进化公众号内容流水线

## 语言

**跟随用户语言**：用户说中文就用中文回复，说英文就用英文回复。

## RSI 是什么（本 Skill 的哲学内核）

**RSI = Recursive Self-Improvement（递归自改进）**

> 定义很工程：AI 参与改进自身研发，形成「能力越强 → 研发越快 → 能力更强」的反馈回路。

在这个 skill 里，RSI 落成这样一条自我进化回路：

```
内容流水线每跑一轮（topic→writer→qa→format）
        ↓
产生真实数据：用了什么素材、什么标题/风格效果好、质检分数、人工修正
        ↓
写入进化台账 _rsi_ledger.md（换源避重、风格偏好、金句库、修正记录）
        ↓
下一轮流水线启动时先读台账，把「上轮教训」作为硬约束喂给 topic/writer
        ↓
内容质量逐轮递增 → 能力更强 → 产出更快更好
```

**核心信条（写入每个子 agent 的职责）**：
1. 上一轮的人工修正和质检反馈，是下一轮最重要的养分。
2. 每次跑完必须「复盘」，把可复用经验固化进台账，不重复踩坑。
3. 越用越聪明：素材库、风格卡、金句库随轮次累积，永不归零。

## 目录结构

```
rsi-wechat/
├── SKILL.md                  # 本文件（主入口）
├── _rsi_ledger.md            # RSI 进化台账（换源避重 + 风格偏好 + 金句库 + 修正记录）
├── references/
│   └── pipeline.md           # 四步流水线详细编排（topic→writer→qa→format）
├── templates/
│   ├── 01_topics.md          # 选题 Brief 模板
│   ├── 02_drafts.json        # 草稿 JSON 模板
│   ├── 03_qa_scores.md       # 质检评分模板
│   └── 04_publish_queue.md   # 待发布队列模板
└── scripts/
    └── run_pipeline.sh       # 一键编排入口（可选，用于手动触发）
```

## 四步流水线（核心流程）

```
topic（选题） → writer（写作） → qa（质检） → format（排版发文）
```

每个环节都是一个独立的 agent（`topic`/`writer`/`qa`/`format`），由主控依次 `sessions_spawn` 编排。详细编排见 `references/pipeline.md`。

### 各环节职责速览

| 环节 | Agent | 输入 | 输出 | 关键动作 |
|------|-------|------|------|----------|
| 选题 | topic | IMA 知识库 + RSI 台账 | `01_topics.md` | 挖素材、查重、定爆款选题 |
| 写作 | writer | `01_topics.md` | `02_drafts.json` | 写完整长文（付费段不占位） |
| 质检 | qa | `02_drafts.json` | `03_qa_scores.md` | 打分评级、合规一票否决 |
| 排版 | format | `03_qa_scores.md` | `04_publish_queue.md` + 草稿箱 | 排版、配图、推草稿箱 |

## 整合的 9 个 baoyu Skill（必须用好）

这是本 skill 的核心增值点——把散装的 baoyu 能力，按流水线环节精准嵌入，做到「该出图时出图、该压缩时压缩、该发文时发文」。

| baoyu Skill | 能力 | 在流水线中的嵌入点 |
|-------------|------|-------------------|
| `baoyu-cover-image` | 封面图生成 | **format 环节**：为过审文章生成公众号封面（2.35:1） |
| `baoyu-article-illustrator` | 文章插图生成 | **format 环节**：分析正文结构，在关键段落插入配图 |
| `baoyu-image-gen` | 通用图像生成 | 兜底：封面/插图不满意时的补充生成 |
| `baoyu-markdown-to-html` | Markdown 转 HTML | **format 环节**：正文转微信兼容 HTML（含主题样式） |
| `baoyu-compress-image` | 图片压缩 | **format 环节**：所有配图转 WebP 并压缩到目标体积 |
| `baoyu-post-to-wechat` | 公众号发文 | **format 环节**：推送到草稿箱（人工闸门前停） |
| `baoyu-url-to-markdown` | URL 转 Markdown | **topic 环节**：外部参考链接转成素材 |
| `baoyu-xhs-images` | 小红书图片处理 | 可选：同一素材复用到小红书图文 |
| `baoyu-slide-deck` | PPT/幻灯片生成 | 可选：长文转信息图/幻灯用于二次传播 |

**关键纪律**：
- 每个 baoyu skill 都要读它自己的 `SKILL.md` 再调用，用对参数（尤其 theme/color/尺寸）。
- 图片生成后**必须**经过 `baoyu-compress-image` 压缩再发布，控制体积与加载速度。
- 公众号发文**默认进草稿箱，绝不自动群发**，到人工闸门即停。

## RSI 进化台账（_rsi_ledger.md）

这是自进化机制的核心落点。每次跑完一轮，主控**必须**更新台账。结构：

```markdown
# RSI 进化台账

## 1. 素材避重（换源）
| 日期 | 源名称 | 累计使用次数 | 最近使用日期 | 备注 |
|------|--------|-------------|-------------|------|

## 2. 风格偏好（哪些标题/调性效果最好）
| 日期 | 标题模式 | 质检分 | 人工反馈 | 结论 |
|------|---------|--------|---------|------|

## 3. 金句库（可复用、验证过传播力的表达）
| 金句 | 来源 | 首次使用日期 | 复用次数 |
|------|------|-------------|---------|

## 4. 人工修正记录（杨辉老师的每次改动都是进化信号）
| 日期 | 文章 | 改了什么 | 为什么 | 固化为规则？ |
|------|------|---------|--------|-------------|

## 5. RSI 回路快照（每轮一次的自我评估）
| 轮次 | 日期 | 质检分变化 | 比上轮强在哪 | 下轮重点 |
|------|------|-----------|-------------|---------|
```

**进化规则**：
1. topic 启动前必读台账「素材避重」表，7 天内复用 / 累计≥2 次的源要换源或标新角度。
2. writer 启动前必读「风格偏好」和「金句库」，沿用验证过有效的模式。
3. 每轮结束，主控把人工修正和质检反馈回写台账，实现「越跑越准」。

## 手动触发（测试 / 手动跑一轮）

```bash
# 一键触发（调用 cron run 或直接 spawn 主控）
openclaw cron run <cron-job-id>
# 或直接读 references/pipeline.md 手动按四步 spawn
```

## 默认配置

- **素材库**：IMA 知识库「AI量化杨老师」，kb_id `5JU-YyL5WUdMp3ZzS_7M2B6G5XpOB4ofM2rdKkMr3jY=`
- **发布方式**：`baoyu-post-to-wechat` API 方式
- **主题/颜色**：`default` / `blue`
- **作者**：`杨教练`
- **频率**：每天 07:20 一篇爆款（cron `20 7 * * *`）
- **安全红线**：只进草稿箱，绝不自动群发；投资内容必含风险提示

## 详细参考

| 主题 | 文件 |
|------|------|
| 四步流水线详细编排 | `references/pipeline.md` |
| 选题 Brief 模板 | `templates/01_topics.md` |
| 草稿 JSON 模板 | `templates/02_drafts.json` |
| 质检评分模板 | `templates/03_qa_scores.md` |
| 待发布队列模板 | `templates/04_publish_queue.md` |

---

_为正行明熙创造价值，RSI 自进化，越用越聪明！_ 🦐
