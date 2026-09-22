---
name: rsi-wechat
description: 正行明熙「RSI 自进化」微信公众号内容运营流水线。以 RSI（Recursive Self-Improvement，递归自改进）理念驱动：AI 参与改进自身内容研发，形成"能力越强→内容越好→能力更强"的反馈回路。整合 topic→writer→qa→format 四步内容流水线、9 个 baoyu 图文能力（封面图/文章插图/通用图像生成/PPT/Markdown转HTML/图片压缩/公众号发文/URL转Markdown/小红书图片），并将每次发布的文章同步归档到 GitHub；从 IMA 知识库「AI量化杨老师」挖掘素材，自动产出公众号爆款长文并推送到草稿箱（人工闸门前停）。Use when user mentions "发公众号", "公众号文章", "内容流水线", "rsi-wechat", "每天三篇", "每天一篇爆款", "文章归档", "RSI 自进化".
version: 1.2.0
metadata:
  openclaw:
    homepage: https://github.com/kenyanghui/rsi-wechat
---

> **v1.2.0 变更**：①topic 环节新增**外部热点采集**（opencli：微博热搜/知乎热榜/36氪热榜/GitHub Trending/任意网页），与 IMA 存量素材做双轨交叉选题；②**定时校验**固化为纪律（以 `openclaw cron list` 为准，勿看旧 `~/.openclaw/cron/jobs.json`）；③新增 **Step 4.5 import-urls**：外部文章/链接经 `import_urls` 导入 IMA，形成「外部热点→入 IMA→存量素材→再选题」的 RSI 增强回路。

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
├── articles/                 # 📦 已发布文章归档（同步到 GitHub，便于后续处理）
│   └── <YYYY-MM-DD>/         # 每天一篇：article.md + meta.json + cover.png
├── references/
│   └── pipeline.md           # 八步流水线详细编排（热点采集→topic→writer→qa→format→import-urls→archive→sync-ima）
├── config/
│   ├── wecom-qr.png          # 企业微信获客活码（客户群活码，format 固定取此路径）
│   └── wecom-qr.meta.json    # 活码元信息（类型/到期/替换记录）
├── templates/
│   ├── 01_topics.md          # 选题 Brief 模板
│   ├── 02_drafts.json        # 草稿 JSON 模板
│   ├── 03_qa_scores.md       # 质检评分模板
│   └── 04_publish_queue.md   # 待发布队列模板
│   └── format/
│       ├── manifest.json     # format 多篇清单
│       └── cta.md            # 文末获客 CTA 组件（企微承接 + 双诱饵）
└── scripts/
    ├── run_pipeline.sh       # 一键编排入口（可选，用于手动触发）
    ├── archive_article.sh    # 文章归档到 GitHub（主控执行）
    ├── sync_to_ima.sh        # 文章同步到 IMA 知识库「4.AI生产文章」（主控执行）
    ├── import_urls_to_ima.sh # 外部文章/热点链接导入 IMA（v1.2.0 新增）
    └── rotate_wecom_qr.sh    # 更换企微活码（备份→覆盖→更新 meta 与台账）
```

## 八步流水线（核心流程）

```
Step0.5 热点采集 → topic（选题） → writer（写作） → qa（质检） → format（排版发文）
   → Step4.5 import-urls（外部文章入 IMA） → archive（归档 GitHub） → sync-ima（同步 IMA 知识库）
```

- 前四个环节各是一个独立 agent（`topic`/`writer`/`qa`/`format`），由主控依次 `sessions_spawn` 编排。
- Step0.5（热点采集）、Step4.5（import-urls）、archive、sync-ima 由**主控**执行。

详细编排见 `references/pipeline.md`。

### 外部热点采集（v1.2.0 新增）

topic 环节的素材来源升级为**双轨**：

```
素材来源
├─ 内部存量：IMA 知识库「AI量化杨老师」（search_knowledge / get_knowledge_list）  ← 原有
└─ 外部实时：opencli 热点采集                                                    ← 新增
```

| 场景 | 命令 |
|------|------|
| 微博热搜 | `opencli weibo hot --limit 20 -f json` |
| 知乎热榜 | `opencli zhihu hot --limit 20 -f json`（偶发空返回，容错） |
| 36氪热榜 | `opencli 36kr hot -f json` |
| GitHub 趋势 | `opencli github-trending repos --since daily -f json` |
| 任意网页转 Markdown | `opencli web read --url <URL> -f md` |
| 微信文章搜索 | `opencli weixin search <关键词> -f json`（⚠️ 搜狗入口易风控，失败降级） |

**纪律**：①热点仅作**切入钩子**，主体观点必须来自自有知识库，避免内容空心化；②热点来源同样登记进 `SOURCE-LEDGER.md` 避重；③任一 opencli 命令失败（风控/Bridge 未连接）降级到 `web_search`/`web_fetch`，不阻断，但需在「本轮源清单」标注。

> **依赖**：opencli CLI + Browser Bridge 插件（位于 `~/.openclaw/opencli-extension`，随 headless Chromium CDP 9222 以 `--load-extension` 加载）。自检：`opencli doctor`。安装脚本：`skills/web-tools-guide/scripts/setup-opencli.sh`。

### 外部文章 → IMA（v1.2.0 新增，Step 4.5）

把本轮引用的外部热点文章/参考链接，经 `scripts/import_urls_to_ima.sh` 走 IMA `import_urls` 接口导入知识库，沉淀为可检索素材：

```bash
bash scripts/import_urls_to_ima.sh <url文件|单个URL> [--folder <folder_id>] [--dry-run]
```

- 网页/微信文章 → 直接 `import_urls`；文件型 URL → 走「下载→preflight→create_media→COS→add_knowledge」。
- 单次 ≤ 10 个 URL（自动分批）；凭证缺失直接跳过并告警；失败不阻断主流程。
- 仅在「本轮使用了外部 URL 素材」时执行。

### 各环节职责速览

| 环节 | Agent | 输入 | 输出 | 关键动作 |
|------|-------|------|------|----------|
| 选题 | topic | IMA 知识库 + RSI 台账 | `01_topics.md` | 挖素材、查重、定爆款选题 |
| 写作 | writer | `01_topics.md` | `02_drafts.json` | 写完整长文（付费段不占位） |
| 质检 | qa | `02_drafts.json` | `03_qa_scores.md` | 打分评级、合规一票否决 |
| 排版 | format | `03_qa_scores.md` | `04_publish_queue.md` + 草稿箱 | 排版、配图、**注入文末获客 CTA**、推草稿箱 |
| 归档 | 主控 | `04_publish_queue.md` + format 产物 | `articles/<日期>/` + GitHub | **同步文章到 GitHub，便于后续处理** |
| 同步 IMA | 主控 | `articles/<日期>/` 或 pipeline 产物 | IMA「4.AI生产文章」 | **把文章同步进 IMA 知识库归档** |

> **每天产出 3 篇**：每天跑 3 轮上述流水线（角度/素材互不重复），3 篇全部推送草稿箱，由杨辉老师人工选择群发。产物分别放 `<日期>/p1/`、`<日期>/p2/`、`<日期>/p3/`。归档脚本支持同日多篇（自动编号 `articles/<日期>/`、`-2/`、`-3/`）。

## 文章归档到 GitHub（每次发布后必做）

> 目的：把每一篇已推送到公众号草稿箱的文章，同步归档到 GitHub 仓库 `kenyanghui/rsi-wechat`，便于后续处理（数据分析、二次分发、人工复盘、构建历史文章库）。

**归档时机**：format 环节产出 `04_publish_queue.md` 之后，由主控执行。

**归档内容**（每篇）：
```
articles/<YYYY-MM-DD>/       # 第 1 篇
articles/<YYYY-MM-DD>-2/     # 第 2 篇（同日多篇自动编号）
articles/<YYYY-MM-DD>-3/     # 第 3 篇
├── article.md      # 正文（Markdown 终稿）
├── meta.json       # 元数据：标题/摘要/作者/质检分/media_id/封面/标签/源
├── cover.png       # 封面图
└── images/         # 正文配图（如有）
```

**执行方式**：调用 `scripts/archive_article.sh <日期> <产物目录>`，脚本支持同一天多篇：
1. 读取 `<产物目录>/format/manifest.json`（推荐，format 环节产出多篇清单），或回退扫描 `article*.md`。
2. 逐篇写入 `articles/<日期>/`、`-2/`、`-3/`（自动编号，绝不覆盖）。
3. 生成每篇 `meta.json`（含公众号 media_id，便于回溯）。
4. 一次性 `git add` → `git commit` → `git push`。

**纪律**：
- 只归档**已进草稿箱**的文章，未过审（<80 分）不归档。
- 每天至少一次 commit，保持一天 3 篇的可追溯节奏。
- 归档失败不阻断主流程，但必须向用户告警并记录到 `_rsi_ledger.md`。

## 文章同步到 IMA 知识库（每次发布后必做）

> 目的：把每一篇已推送到公众号草稿箱的文章，同步归档到 IMA 知识库「AI量化杨老师」的 **「4.AI生产文章」** 文件夹（`folder_7507449254775045`），沉淀为可检索的知识资产。

**同步时机**：GitHub 归档（第五步 archive）之后，由主控执行。

**执行方式**：调用 `scripts/sync_to_ima.sh <日期> [产物目录] [--dry-run]`：
1. 从 pipeline 产物的 `manifest.json` 或 `articles/<日期>*` 归档目录收集文章清单（自动去重）。
2. 生成规范 Markdown（标题 + 作者/来源/归档日期 + 摘要 + 正文）。
3. 以 `media_type=7`（Markdown）逐篇上传到 IMA 文件夹（`check_repeated_names` → `create_media` → COS 上传 → `add_knowledge`）。

**纪律**：
- 只同步**已进草稿箱**的文章；Markdown 单个文件 ≤ 10MB。
- 上传前调用 `check_repeated_names` 查重；重名不支持替换（自动加时间戳后缀）。
- **幂等去重**：已同步过的文章（本地状态文件 `.synced_manifest.txt` 记录内容指纹 + 远端查重）自动跳过，可安全重复执行。
- IMA 同步失败不阻断主流程（凭证缺失直接跳过），但需向用户告警并记入台账。
- 输出按「成功 / 重名改名 / 跳过(幂等) / 失败」分类汇总。
- 关键参数：`IMA_KB_ID`、`IMA_FOLDER_ID` 可用环境变量覆盖。

---

这是本 skill 的核心增值点——把散装的 baoyu 能力，按流水线环节精准嵌入，做到「该出图时出图、该压缩时压缩、该发文时发文」。

| baoyu Skill | 能力 | 在流水线中的嵌入点 |
|-------------|------|-------------------|
| `baoyu-cover-image` | 封面图生成 | **format 环节**：为过审文章生成公众号封面（2.35:1） |
| `baoyu-article-illustrator` | 文章插图生成 | **format 环节**：分析正文结构，在关键段落插入配图 |
| `baoyu-image-gen` | 通用图像生成 | 兜底：封面/插图不满意时的补充生成 |
| `baoyu-markdown-to-html` | Markdown 转 HTML | **format 环节**：正文转微信兼容 HTML（含主题样式） |
| `baoyu-compress-image` | 图片压缩 | **format 环节**：所有配图转 WebP 并压缩到目标体积 |
| `baoyu-post-to-wechat` | 公众号发文 | **format 环节**：推送到草稿箱（人工闸门前停） |
| `rsi-wechat 获客 CTA` | 企微承接 + 双诱饵注入 | **format 环节**：正文末注入企微二维码 + 资料包/试用双诱饵（`templates/format/cta.md`） |
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
- **外部热点源**：opencli（微博/知乎/36氪/GitHub Trending/web read）
- **频率**：每天 07:20 产出 **3 篇**爆款（cron `20 7 * * *`，Asia/Shanghai）
  - 校验方式：`openclaw cron list`（真实 job 在 Gateway）；主 job id `a1687335-482e-4b24-ba14-527099ec9193`，看门狗 `c26bb402-6014-4447-aecc-e85bcabcf2cd`
  - ⚠️ **勿**以 `~/.openclaw/cron/jobs.json` 判断（旧版迁移文件，恒空）
- **发布方式**：`baoyu-post-to-wechat` API 方式
- **文章归档**：每次发布后同步到 GitHub `kenyanghui/rsi-wechat`（`articles/<日期>/`）
- **主题/颜色**：`default` / `blue`
- **作者**：`杨教练`
- **安全红线**：只进草稿箱，绝不自动群发；投资内容必含风险提示
- **获客二维码**：`config/wecom-qr.png`（企业微信**客户群活码**，多群轮换、长期有效），format 固定取此路径自动复用；换码用 `scripts/rotate_wecom_qr.sh`
  - 当前状态：过渡二维码，**有效期至 2026-09-30**，需更换为客户群活码（`--expires never`）
  - 登记于 `_rsi_ledger.md`「有效期提醒」表；换码后状态转「✅ 已换新码」
- **获客承接**：统一走企业微信；诱饵为「资料包 + 免费试用工具」双钩子；每篇文末注入 CTA 组件（`templates/format/cta.md`），二维码取 `config/wecom-qr.png`

## 详细参考

| 主题 | 文件 |
|------|------|
| 五步流水线（+归档）详细编排 | `references/pipeline.md` |
| 选题 Brief 模板 | `templates/01_topics.md` |
| 草稿 JSON 模板 | `templates/02_drafts.json` |
| 质检评分模板 | `templates/03_qa_scores.md` |
| 待发布队列模板 | `templates/04_publish_queue.md` |
| 文末获客 CTA 组件 | `templates/format/cta.md` |
| 更换企微活码脚本 | `scripts/rotate_wecom_qr.sh` |

---

_为正行明熙创造价值，RSI 自进化，越用越聪明！_ 🦐
