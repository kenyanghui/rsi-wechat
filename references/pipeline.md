# 六步流水线详细编排（rsi-wechat）

> 本文件描述 `topic → writer → qa → format → archive → sync-ima` 六步内容流水线的完整编排规范，是主控 orchestrate 的动作手册。

## 每天产出 3 篇（当前模式）

一天跑 **3 轮**上述流水线，3 篇角度/素材互不重复（建议「认知层 / 商业层 / 心智层」三翼），全部推草稿箱，由杨辉老师人工选择群发。

- 产物按篇分目录：`<日期>/p1/`、`<日期>/p2/`、`<日期>/p3/`（各含 01~04 + format/）。
- 拼装 topic task 时，除查重台账外，还需把「本日已选定的其他 2 篇角度/源」贴进去，强制 3 篇不撞题。
- 归档：`archive_article.sh` 支持同日多篇，自动编号 `articles/<日期>/`、`-2/`、`-3/`；推荐让 format 产出 `format/manifest.json`（多篇清单）供归档脚本读取。
- 同步 IMA：`sync_to_ima.sh` 把归档文章同步进 IMA 知识库「4.AI生产文章」（每次发布后必做）。

## 编排总览（单篇，每日重复 3 次）

```
主控（main）
  │
  ├── Step 0：读 RSI 进化台账 + 建产物目录
  ├── Step 1：spawn topic  → 01_topics.md（选题，从 IMA 挖素材）
  ├── Step 2：spawn writer → 02_drafts.json（写作）
  ├── Step 3：spawn qa     → 03_qa_scores.md（质检）
  ├── Step 4：spawn format → 04_publish_queue.md + 草稿箱（排版发文）
  ├── Step 5：archive（主控执行）→ articles/<日期>[-n]/ + GitHub 同步
  ├── Step 6：sync-ima（主控执行）→ IMA 知识库「4.AI生产文章」
  └── Step 7：回写 RSI 台账 + 简报
```

## Step 0：预热（主控执行）

1. 确认日期，创建产物目录 `/root/agents/shared/pipeline/<YYYY-MM-DD>/`。
2. 读 RSI 进化台账 `_rsi_ledger.md`，提炼出本轮硬约束：
   - **素材避重**：7 天内复用 / 累计≥2 次的源清单。
   - **风格偏好**：上轮验证有效的标题模式/调性。
   - **金句库**：可复用的验证过金句。
3. 把这些硬约束**拼进 topic 的 task 文本**，强制选题 agent 遵守。

## Step 1：topic（选题）

**spawn 参数**：`agentId: topic`

**task 必含内容**：
- 读 `/root/agents/shared/SOURCE-LEDGER.md` 做查重（与 RSI 台账联动）。
- 从 IMA 知识库「AI量化杨老师」挖素材：
  1. 读 skill `skills/ima-skills/knowledge-base/SKILL.md`
  2. `search_knowledge` 搜索主题（量化投资/AI投资/财富传承/投资者行为）
  3. `get_knowledge_list` 浏览结构（limit 50）
  4. 找到爆款潜质素材作为主素材
- **外部参考链接**可用 `baoyu-url-to-markdown` 转成素材备用。
- 输出 `01_topics.md`（含风格卡、爆款点、200字+ Brief、本轮源清单）。

**验收**：`01_topics.md` 末尾必须有「本轮源清单」，标注新增/复用+累计次数。

## Step 2：writer（写作）

**spawn 参数**：`agentId: writer`

**task 必含内容**：
- 读 `01_topics.md`，研读标题、风格卡、核心素材、爆款点、Brief。
- 读 RSI 台账的「风格偏好」「金句库」，沿用有效模式。
- 写完整长文（2200-2600 字），**付费段/干货段绝不占位**。
- 输出 `02_drafts.json`（标题、备选标题、摘要、正文、风格卡、风险提示）。

**验收**：正文 ≥2200 字，含风险提示，无「待补充/省略」。

## Step 3：qa（质检）

**spawn 参数**：`agentId: qa`

**task 必含内容**：
- 读 `02_drafts.json` 所有草稿。
- 严格按 `qa-rubric.md` 打分（标题15/干货30/结构15/可读15/情绪10/原创15）。
- 评级：≥80 入库 / 60-79 打回 / <60 丢弃。
- **合规一票否决**：命中红线直接不采纳；投资内容必含风险提示。
- 输出 `03_qa_scores.md`。

**验收**：每篇有总分、评级、合规检查结论。

## Step 4：format（排版发文）⭐ 整合 9 个 baoyu 能力的关键环节

**spawn 参数**：`agentId: format`

**task 必含内容**（按顺序执行）：

1. 读 `03_qa_scores.md`，只取 ≥80 分条目。
2. 执行 qa 提示的轻量微调（弱化绝对化用语、合并重复话术）。
3. **生成封面图**（`baoyu-cover-image`）：读 SKILL.md，按 2.35:1 生成公众号封面。
4. **生成文章插图**（`baoyu-article-illustrator`）：读 SKILL.md，分析正文结构，在关键段落定位插图，生成配图。
5. **图片压缩**（`baoyu-compress-image`）：所有配图转 WebP 并压缩到目标体积。
6. **Markdown 转 HTML**（`baoyu-markdown-to-html`）：正文转微信兼容 HTML，套用 theme `default` / color `blue`。
7. **注入文末获客 CTA**（⭐ 获客闭环关键步）：读 `templates/format/cta.md`，在正文「风险提示」之后、文章最末尾注入「企微二维码 + 双诱饵」组件。占位符 `{{WECOM_QR_IMAGE}}` 优先取 `config/wecom-qr.png`（随配图走压缩），缺失则以文字「微信搜索：AI量化杨教练」兜底并标记待补。
8. **推公众号草稿箱**（`baoyu-post-to-wechat`）：API 方式，保存草稿，**绝不群发**。
9. 写 `04_publish_queue.md`（含 media_id、封面/二维码是否需人工补、CTA 注入校验）。

**验收**：草稿已进草稿箱，拿到 media_id；正文末含「添加后回复对应数字」+ 三个诱饵；`04_publish_queue.md` 已写。

**红线**：绝不使用 `--submit`，到人工闸门即停。

## Step 5：archive 归档到 GitHub（主控执行）⭐ 便于后续处理

**目的**：把已推送到公众号草稿箱的文章，同步归档到 GitHub `kenyanghui/rsi-wechat`，便于后续处理（数据分析、二次分发、人工复盘、构建历史文章库）。

**动作**：
1. 读 `04_publish_queue.md`，只归档**已进草稿箱**的条目（带 media_id）。
2. 调用 `scripts/archive_article.sh <日期> <产物目录>`（支持同日多篇）：
   - 优先读 `<产物目录>/format/manifest.json`（多篇清单），否则扫描 `article*.md`。
   - 逐篇收集正文、封面、配图 → 写入 `articles/<日期>/`、`-2/`、`-3/`（自动编号，绝不覆盖）。
   - 生成每篇 `meta.json`（标题/摘要/作者/质检分/media_id/封面/标签/源）。
   - 一次性 `git add` → `git commit` → `git push`。
3. 若 push 失败（网络/认证），不阻断主流程，脚本内置 3 次重试；仍失败则记录到 `_rsi_ledger.md` 并向用户告警。

**验收**：GitHub 仓库出现当日 commit，`articles/<日期>/`（及 `-2/`、`-3/`）含 article.md + meta.json。

## Step 6：sync-ima 同步到 IMA 知识库（主控执行）⭐ 沉淀知识资产

**目的**：把已进草稿箱的文章，同步归档到 IMA 知识库「AI量化杨老师」的 **「4.AI生产文章」** 文件夹（`folder_7507449254775045`），沉淀为可检索的知识资产。

**动作**：
1. 调用 `scripts/sync_to_ima.sh <日期> [产物目录] [--dry-run]`。
2. 脚本从 pipeline 产物 `manifest.json` 或 `articles/<日期>*` 归档目录收集文章清单（自动去重）。
3. 生成规范 Markdown（标题 + 作者/来源/归档日期 + 摘要 + 正文）。
4. 以 `media_type=7`（Markdown）逐篇上传（`create_media` → COS 上传 → `add_knowledge`）。

**纪律**：
- 只同步**已进草稿箱**的文章；Markdown 单个文件 ≤ 10MB。
- 上传前做重名检查；重名不支持替换（改为加时间戳后缀）。
- IMA 同步失败**不阻断**主流程（凭证缺失直接跳过），但需告警并记入台账。

**验收**：IMA「4.AI生产文章」文件夹出现当日各篇文章（`.md`）。

## Step 7：回写台账 + 简报（主控执行）

1. 更新 RSI 进化台账 `_rsi_ledger.md`：
   - 素材避重表追加本轮新源。
   - 风格偏好/金句库按质检分和人工反馈更新。
   - RSI 回路快照追加本轮（质检分变化、比上轮强在哪、下轮重点）。
2. 同步更新 `/root/agents/shared/SOURCE-LEDGER.md`。
3. 向用户简报：选题、过审/打回/丢弃、待发布清单、GitHub 与 IMA 归档状态、本轮新增源与高频复用源。

## 失败处理

- 任一步失败：整链中止，产物移至 `/root/agents/shared/pipeline-failed/<date>_<HHMMSS>/`，向用户告警。
- 全程写 `_run.log` 与 `_status.json` 到产物目录。
