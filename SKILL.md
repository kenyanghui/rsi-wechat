---
name: rsi-wechat
aliases:
  - 公众号流水线
  - 微信公众号内容管线
  - rsi内容管线
description: 正行明熙「RSI 自进化」微信公众号内容运营流水线。以 RSI（Recursive Self-Improvement，递归自改进）理念驱动：AI 参与改进自身内容研发，形成"能力越强→内容越好→能力更强"的反馈回路。整合九步内容流水线（热点采集→素材运营→topic→writer→qa→format→import-urls→archive→sync-ima）、9 个 baoyu 图文能力（封面图/文章插图/通用图像生成/PPT/Markdown转HTML/图片压缩/公众号发文/URL转Markdown/小红书图片），并将每次发布的文章同步归档到 GitHub；从 IMA 知识库「AI量化杨老师」挖掘素材，自动产出公众号爆款长文并推送到草稿箱（人工闸门前停）。含知识库运营（多源采集精品、查重、按主题归档、防落根目录）。Use when user mentions "发公众号", "公众号文章", "内容流水线", "rsi-wechat", "每天三篇", "每天一篇爆款", "文章归档", "RSI 自进化", "采集入库", "知识库归档", "整理知识库".
version: 1.5.0
platforms: [linux]
prerequisites:
  commands: [openclaw, opencli]
  env: [IMA_TOKEN, IMA_KB_ID, IMA_FOLDER_ID]
metadata:
  openclaw:
    homepage: https://github.com/kenyanghui/rsi-wechat
  drift_guards:
    manifest: pipeline/MANIFEST.json
    check: scripts/check_drift.sh
---

> **v1.2.0 变更**：①topic 环节新增**外部热点采集**（opencli：微博热搜/知乎热榜/36氪热榜/GitHub Trending/任意网页），与 IMA 存量素材做双轨交叉选题；②**定时校验**固化为纪律（以 `openclaw cron list` 为准，勿看旧 `~/.openclaw/cron/jobs.json`）；③新增 **Step 4.5 import-urls**：外部文章/链接经 `import_urls` 导入 IMA，形成「外部热点→入 IMA→存量素材→再选题」的 RSI 增强回路。
>
> **v1.3.0 变更**：整合原独立技能 `ima-kb-curator`，新增 **Step 0.7「素材采集与知识库运营」**（多源采集精品→查重→按主题归位→根目录整理），使知识库供给侧运营成为流水线一等公民；新增 `references/folder-map.md`、`references/ima-api-mechanics.md` 两份参考。附带实测机制：`move_knowledge` 为无效桩、同 URL 重导入=迁移、笔记用 `add_knowledge(mt=11)` 归位、文件类无法迁移。
>
> **v1.4.0 变更（借鉴 octopus-workflow：SSOT + drift guards + retrospective）**：①新增 **`pipeline/MANIFEST.json` SSOT 注册表**——版本/步骤数/环节清单唯一事实源；②新增 **`scripts/check_drift.sh` 防漂移守卫**——G1 版本一致性 / G2 步骤链口径 / G3 台账章节完整性 / G4 归档断档检测 / G5 编码健康；③**Step 7 复盘（retrospective）固化为不可跳过环节**——含人工修正 diff 采集（草稿 vs 实发，回填台账「人工修正记录」）与漂移自检；④新增 **`config/qa-rubric.json` 质检规则引擎**——六维加权 + 三条一票否决（合规/空心化/素材避重），取代散落的评分口径；⑤安全修复：IMA 凭证不再 export 落环境。
>
> **v1.5.0 变更（借鉴 Draco-Skills-Collection：路由分层 + 输出契约 + preflight + truth-first）**：①frontmatter 扩展——新增 `aliases`（中文触发别名）、`platforms`、`prerequisites`（命令/环境变量依赖清单）、`metadata.drift_guards`；②新增 **Workflow Router 路由层**——本 SKILL.md 只做「类级入口」，执行细节下沉到 `references/pipeline.md` 与各脚本；③新增 **Step 0 preflight 纪律块**（date 实测 + 凭证探测 + cron 以 `openclaw cron list` 为准）；④新增 **Step 7 简报输出契约**（固定字段 + 部分失败必须明示）；⑤新增 **truth-first 原则**——素材不足允许减产并在台账留痕，禁止凑数（写入 topic/qa 职责）。

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
4. **Truth first, no quota-filling（真相优先，不凑数）**：素材不足时宁缺毋滥——允许减产（3 篇 → 2 篇 → 1 篇）并在台账「RSI 回路快照」留痕说明原因，绝不为了凑满 3 篇发空心文。产量目标服从质量红线。

## Workflow Router（本文件是类级入口，只做路由）

借鉴 Draco `wechat-publishing-workflow` 的两层结构：**主 SKILL.md 只负责「判断该走哪条路」，执行细节全部下沉**到 references 与 scripts，控制主文件上下文占用。

| 任务意图 | 路由到 |
|---------|--------|
| 跑完整流水线 / 每日三篇 | `references/pipeline.md`（九步编排手册）→ `scripts/run_pipeline.sh` |
| 只做素材采集 / 整理知识库 | `references/pipeline.md` § Step 0.7 + `scripts/import_urls_to_ima.sh` |
| 文章归档 GitHub | `scripts/archive_article.sh` |
| 同步 IMA 知识库 | `scripts/sync_to_ima.sh` + `references/ima-api-mechanics.md` |
| 找 IMA 文件夹 ID | `references/folder-map.md` |
| 换企微获客活码 | `scripts/rotate_wecom_qr.sh` |
| 发布数据回流 | `scripts/fetch_stats.sh` |
| 版本/口径漂移排查 | `scripts/check_drift.sh`（SSOT：`pipeline/MANIFEST.json`） |

**路由纪律**：①改流程细节改 references / 脚本，不动本文件；②版本号只改 `pipeline/MANIFEST.json` 再同步本文件 frontmatter（`check_drift.sh` G1 校验）；③新增环节必须先在 MANIFEST 注册，再补文档。

## 目录结构

```
rsi-wechat/
├── SKILL.md                  # 本文件（主入口）
├── _rsi_ledger.md            # RSI 进化台账（换源避重 + 风格偏好 + 金句库 + 修正记录）
├── articles/                 # 📦 已发布文章归档（同步到 GitHub，便于后续处理）
│   └── <YYYY-MM-DD>/         # 每天一篇：article.md + meta.json + cover.png
├── references/
│   ├── pipeline.md           # 九步流水线详细编排（热点采集→素材运营→topic→writer→qa→format→import-urls→archive→sync-ima）
│   ├── folder-map.md         # IMA「AI量化杨老师」文件夹地图（含 folder_id，v1.3.0 新增）
│   └── ima-api-mechanics.md  # IMA 归档机制实测速查（可用/无效端点、迁移路径、常见坑，v1.3.0 新增）
├── pipeline/
│   ├── MANIFEST.json         # SSOT 注册表：版本/步骤数/环节清单唯一事实源（v1.4.0 新增）
│   └── PIPELINE.md           # 流水线口径卡（对外简述）
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
    ├── rotate_wecom_qr.sh    # 更换企微活码（备份→覆盖→更新 meta 与台账）
    ├── check_drift.sh        # 防漂移守卫（版本/步骤口径/台账完整性/归档断档/编码，v1.4.0 新增）
    └── fetch_stats.sh        # 发布数据回流：阅读/点赞 → meta.json + 台账（v1.4.0 新增）
```

### SSOT 与规则引擎（v1.4.0 新增）

- `pipeline/MANIFEST.json`：版本、步骤数、环节清单的**唯一事实源**；文档口径以它为准，`scripts/check_drift.sh` 据此校验。
- `config/qa-rubric.json`：qa 环节评分规则引擎（六维加权 + 三条一票否决），规则演进改此文件并在台账留痕，勿散落进 agent 提示词。

## 九步流水线（核心流程）

```
Step0.5 热点采集 → Step0.7 素材采集与知识库运营 → topic（选题） → writer（写作） → qa（质检） → format（排版发文）
   → Step4.5 import-urls（外部文章入 IMA） → archive（归档 GitHub） → sync-ima（同步 IMA 知识库）
```

- 前四个环节各是一个独立 agent（`topic`/`writer`/`qa`/`format`），由主控依次 `sessions_spawn` 编排。
- Step0.5（热点采集）、Step0.7（素材运营）、Step4.5（import-urls）、archive、sync-ima 由**主控**执行。
- **Step 7 复盘（retrospective，v1.4.0 固化，不可跳过）**：回写台账 + 人工修正 diff 采集（AI 终稿 vs 实发版，回填「人工修正记录」清零「待反馈」）+ 跑 `scripts/check_drift.sh` 漂移自检 + `scripts/fetch_stats.sh` 发布数据回流（阅读/点赞 → meta.json + 台账「发布数据」表）+ 用户简报。

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

### 素材采集与知识库运营（v1.3.0 新增，Step 0.7）

在 Step 0.5 之后、Step 1 之前运行，为当天 3 篇选题与知识资产做「供给侧」准备：**主动采集外部精品入库 + 整理既有散落条目**（原 `ima-kb-curator` 能力，已并入本技能）。

**六步动作（强制顺序）**：

```
1. 侦察目录   → 拉全量文件夹树（含 folder_id）+ 各目录既有条目（references/folder-map.md 为缓存，须以实时结果为准）
2. 多源采集   → 按 6 大领域定向采集候选（≥1.5×目标篇数）
3. 查重比对   → 候选 vs 既有条目规范化比对，剔除重复
4. 定稿与归属 → 每篇配「合适文件夹」，生成本轮清单
5. 入库与整理 → 新增入目标文件夹；既有散落/根目录条目一并归位
6. 验收       → 逐文件夹验证落位；失败重试（≥3 次）
```

**6 大采集领域（兴趣点画像）**：

| 领域 | 典型落位文件夹 | 采集源示例 |
|------|----------------|-----------|
| AI 量化技术 | `2.AI量化技术/9.AI量化交易实践` | arxiv(q-fin.TR/cs.AI)、HF、期刊 |
| AI 金融工具 | `2.AI量化技术/9.AI量化交易实践` | 产品页、GitHub、36kr |
| AI 金融 Skill/MCP | `2.AI量化技术/2.养AI-让AI不断进化/Skills`、`.../MCP` | 36kr、社区、GitHub |
| 开源量化项目 | `1.AI量化实训/量化开源研究` | github-trending、Show HN |
| 量化行业与监管资讯 | `3.AI行业动态` | 36kr、gov-policy（证监会/交易所）、东财快讯 |
| AI 前沿技术发展 | `2.AI量化技术/2.养AI-让AI不断进化`、`8.AI智能体趋势报告` | arxiv(cs.AI)、aibase、HackerNews |

**查重**：规范化标题（保留 `[0-9a-z\u4e00-\u9fff]`）后做包含匹配，命中即视为重复；既有条目来自 `get_knowledge_list` 递归全部文件夹；同一素材源 7 天内不重复用。

**入库与迁移机制（实测，务必按此执行）**：

| 类型 | 动作 |
|------|------|
| 网页/微信文章 | `import_urls`（`folder_id` **必填**）→ 用 `scripts/import_urls_to_ima.sh` |
| 笔记（media_type=11） | `add_knowledge` + `note_info.content_id=<note_id>` 归入目标文件夹 |
| 文件型（PDF/Word/PPT） | 走「preflight → check_repeated_names → create_media → COS → add_knowledge」；**已入库文件无法迁移** |

| 迁移方式 | 结论 |
|----------|------|
| `move_knowledge` | ❌ **无效桩**（36 组合静默 no-op），**不要用** |
| 同 URL 重 `import_urls` 到目标目录 | ✅ web/微信文章**真迁移**（`import_urls_to_ima.sh <url> --folder <目标>`） |
| 笔记 `add_knowledge(mt=11)` | ✅ 归入目标文件夹 |
| 文件类 | ❌ 无迁移 API，如实告知 |

**防落根目录**：入库必带 `folder_id`，绝不省略（省略=根目录）；根目录 `get_knowledge_list` 含「最近添加」全局视图，**不代表归属根目录**，验收看目标文件夹。

**与既有环节的关系**：Step 0.5 产出当日热点候选池（面向选题）；Step 0.7 主动采集精品沉淀入库并整理既有条目（面向知识资产）；Step 4.5 把本轮已引用的外部 URL 回流 IMA。三者互补，不重复。

**产物与验收**：产物为 `/root/agents/shared/pipeline/<日期>/collect/`（清单 json + 归档报告 md）；验收逐条列明采纳篇目/来源/归属文件夹/失败项/去重剔除项，逐目标文件夹 `get_knowledge_list` 验证落位，失败退避重试 ≥3 次并告警不静默。

详细编排见 `references/pipeline.md` 的 Step 0.7；机制速查见 `references/ima-api-mechanics.md`；文件夹 ID 见 `references/folder-map.md`。

### 各环节职责速览

| 环节 | Agent | 输入 | 输出 | 关键动作 |
|------|-------|------|------|----------|
| 选题 | topic | IMA 知识库 + RSI 台账 | `01_topics.md` | 挖素材、查重、定爆款选题 |
| 写作 | writer | `01_topics.md` | `02_drafts.json` | 写完整长文（付费段不占位） |
| 质检 | qa | `02_drafts.json` | `03_qa_scores.md` | 打分评级、合规一票否决 |
| 排版 | format | `03_qa_scores.md` | `04_publish_queue.md` + 草稿箱 | 排版、配图、**注入文末获客 CTA**、推草稿箱 |
| 素材运营 | 主控 | IMA 知识库 + opencli | 入库清单 + 归档报告 | **采集精品入库、查重、主题归位、根目录整理（Step 0.7）** |
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

**同步时机**：GitHub 归档（Step 5 archive）之后，由主控执行。

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
# 或直接读 references/pipeline.md 手动按九步 spawn
```

## 默认配置

- **素材库**：IMA 知识库「AI量化杨老师」，kb_id `5JU-YyL5WUdMp3ZzS_7M2B6G5XpOB4ofM2rdKkMr3jY=`
- **外部热点源**：opencli（微博/知乎/36氪/GitHub Trending/web read）
- **内容运营（v1.3.0）**：Step 0.7 素材采集与知识库运营；采集领域 6 类；迁移用 `scripts/import_urls_to_ima.sh <url> --folder <目标>`；文件夹地图见 `references/folder-map.md`
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
| 九步流水线详细编排 | `references/pipeline.md` |
| 选题 Brief 模板 | `templates/01_topics.md` |
| 草稿 JSON 模板 | `templates/02_drafts.json` |
| 质检评分模板 | `templates/03_qa_scores.md` |
| 待发布队列模板 | `templates/04_publish_queue.md` |
| 文末获客 CTA 组件 | `templates/format/cta.md` |
| 更换企微活码脚本 | `scripts/rotate_wecom_qr.sh` |
| IMA 文件夹地图（含 folder_id） | `references/folder-map.md` |
| IMA 归档机制实测速查 | `references/ima-api-mechanics.md` |

---

_为正行明熙创造价值，RSI 自进化，越用越聪明！_ 🦐
