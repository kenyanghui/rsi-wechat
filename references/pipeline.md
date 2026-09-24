# 九步流水线详细编排（rsi-wechat v1.5.0）

> 本文件描述 `[热点采集] → [素材运营] → topic → writer → qa → format → [import-urls] → archive → sync-ima` 九步内容流水线的完整编排规范，是主控 orchestrate 的动作手册。
> 带方括号的三步为 v1.2.0/v1.3.0 新增（v1.3.0 新增「素材运营」Step 0.7，整合原 ima-kb-curator）。
> v1.5.0 新增：Step 0 preflight 纪律块、Step 7 简报输出契约、truth-first 减产规则（借鉴 Draco-Skills-Collection）。

## Truth First（产量服从质量红线）

**Truth first, no quota-filling**：每日 3 篇是目标而非硬性配额。当高质量素材不足（IMA 可用新素材 + 当日热点均不足以支撑 3 个互不重复的扎实角度）时：

- 允许减产：3 篇 → 2 篇 → 1 篇，甚至当日 0 篇；**绝不凑数发空心文**。
- 减产必须在 `_rsi_ledger.md`「RSI 回路快照」留痕：写明减产原因（素材不足/热点荒/查重剔除过多）。
- 简报中必须明示「今日计划 3 篇，实际产出 N 篇，减产原因：…」。
- qa 对「为凑数而空心化」的文章直接一票否决（`config/qa-rubric.json` 已有该红线，此处强调执行）。

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
  ├── Step 0：读 RSI 进化台账 + 建产物目录 + 校验 cron
  ├── Step 0.5：热点采集（opencli）→ 热点候选池 ⭐新增
  ├── Step 0.7：素材采集与知识库运营 → 精品入库 + 查重 + 主题归位 + 根目录整理 ⭐v1.3.0新增
  ├── Step 1：spawn topic  → 01_topics.md（选题：IMA 存量 × 外部热点 交叉）
  ├── Step 2：spawn writer → 02_drafts.json（写作）
  ├── Step 3：spawn qa     → 03_qa_scores.md（质检）
  ├── Step 4：spawn format → 04_publish_queue.md + 草稿箱（排版发文）
  ├── Step 4.5：import-urls（主控执行）→ 外部文章/链接导入 IMA ⭐新增
  ├── Step 5：archive（主控执行）→ articles/<日期>[-n]/ + GitHub 同步
  ├── Step 6：sync-ima（主控执行）→ IMA 知识库「4.AI生产文章」
  └── Step 7：回写 RSI 台账 + 简报
```

## Step 0：预热（主控执行）

> **Preflight 纪律（v1.5.0 新增，借鉴 Draco）**：以下检查必须**实测**，禁止凭记忆/推断跳过。任一项失败 → 按「失败处理」降级或中止，不静默带病起跑。

1. **日期实测**：跑 `date '+%Y-%m-%d %H:%M %Z'` 确认当天日期与时区（Asia/Shanghai），不要凭上下文推断「今天」。
2. **凭证探测**：IMA 凭证（token/知识库 ID）可读且有效（探测失败 → Step 0.5/4.5/6 相关动作降级跳过并告警，不阻断 topic→writer→qa→format 主链）。
3. **cron 校验（v1.2.0 纪律）**：以 `openclaw cron list` 实时输出为准，勿看旧 `~/.openclaw/cron/jobs.json`。
4. 创建产物目录 `/root/agents/shared/pipeline/<YYYY-MM-DD>/`。
5. 读 RSI 进化台账 `_rsi_ledger.md`，提炼出本轮硬约束：
   - **素材避重**：7 天内复用 / 累计≥2 次的源清单。
   - **风格偏好**：上轮验证有效的标题模式/调性。
   - **金句库**：可复用的验证过金句。
   - **人工修正分级（v1.5.1）**：第 4 节级别=「硬」（出现≥2次或明确确认）必须遵守；级别=「软」仅作 writer 倾向提示。
   - **发布数据加权（v1.5.1，借鉴 wewrite-stats）**：读第 7 节「发布数据」，阅读量 ≥2× 均值的标题 → 提炼其模式进 topic task 作优先参考；样本 <3 篇时跳过（防过拟合）。
6. 把这些硬约束**拼进 topic 的 task 文本**，强制选题 agent 遵守。

## Step 0.5：热点采集（主控执行）⭐ 新增

1. 跑 2-3 条 opencli 热点命令，取当日 top N，形成「热点候选池」：
   - `opencli weibo hot --limit 20 -f json`
   - `opencli 36kr hot -f json`
   - `opencli github-trending repos --since daily -f json`（技术向可选）
2. 容错：任一命令失败（风控/Bridge 未连接）→ 降级 `web_search`/`web_fetch`，记录降级原因，不阻断。
3. 把「热点候选池」贴进 topic 的 task 文本。

**自检**：`opencli doctor`（Extension 需 connected）。

## Step 0.7：素材采集与知识库运营（主控执行）⭐ v1.3.0 新增

**目的**：在选题之前，为当天 3 篇与知识资产做「供给侧」准备——**主动采集外部精品入库 + 整理既有散落条目**（原独立技能 `ima-kb-curator` 的能力，已并入本技能）。与 Step 0.5（面向当日选题的热点池）、Step 4.5（面向本轮引用的回流）互补。

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

**采集命令**：一律 `opencli … -f json`（`github-trending` / `arxiv` / `36kr` / `gov-policy` / `aibase` / `hackernews` / `eastmoney`）；风控/导航拒绝 → 降级 `web_search`/`web_fetch`，不阻断。

**查重**：规范化标题（保留 `[0-9a-z\u4e00-\u9fff]`）后做包含匹配，命中即视为重复；既有条目来自 `get_knowledge_list` 递归全部文件夹；同一素材源 7 天内不重复用。

**入库与迁移机制（实测，务必按此执行）**：
- 网页/微信文章 → `import_urls`（`folder_id` **必填**），用 `scripts/import_urls_to_ima.sh`。
- 笔记（media_type=11）→ `add_knowledge` + `note_info.content_id=<note_id>` 归入目标文件夹。
- 文件型（PDF/Word/PPT）→ 「preflight → check_repeated_names → create_media → COS → add_knowledge」；**已入库文件无法迁移**。

| 迁移方式 | 结论 |
|----------|------|
| `move_knowledge` | ❌ **无效桩**（36 组合静默 no-op），**不要用** |
| 同 URL 重 `import_urls` 到目标目录 | ✅ web/微信文章**真迁移**（`import_urls_to_ima.sh <url> --folder <目标>`） |
| 笔记 `add_knowledge(mt=11)` | ✅ 归入目标文件夹 |
| 文件类 | ❌ 无迁移 API，如实告知 |

**防落根目录**：入库必带 `folder_id`，绝不省略（省略=根目录）；根目录 `get_knowledge_list` 含「最近添加」全局视图，**不代表归属根目录**，验收看目标文件夹。

**产物与验收**：产物为 `/root/agents/shared/pipeline/<日期>/collect/`（清单 json + 归档报告 md）；验收逐条列明采纳篇目/来源/归属文件夹/失败项/去重剔除项，逐目标文件夹 `get_knowledge_list` 验证落位，失败退避重试 ≥3 次并告警不静默。

> 机制速查见 `references/ima-api-mechanics.md`；文件夹 ID 见 `references/folder-map.md`。

## Step 1：topic（选题）

**spawn 参数**：`agentId: topic`

**task 必含内容**：
- 读 `/root/agents/shared/SOURCE-LEDGER.md` 做查重（与 RSI 台账联动）。
- **交叉选题（v1.2.0 新增）**：从「热点候选池」中优先选**能用量化/财富认知角度切入的热点**作切入钩子；主体观点仍须来自自有知识库（禁止空心化）。热点来源也登记进 SOURCE-LEDGER.md 避重。
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
- 严格按 **`config/qa-rubric.json`**（质检规则引擎，v1.4.0 新增；v1.5.1 扩为七维）打分：七维加权（标题钩子18/干货密度22/结构节奏13/合规可信17/事实锚定10/移动端可读10/获客组件10）。
- 评级：≥85 入库 / 触发 veto 或 <85 按修改建议打回 / 同篇最多重写 2 次后换选题。
- **一票否决（veto）**：合规红线（收益承诺）、内容空心化（主体观点非自有知识库）、素材避重命中——命中即退回（veto:source_dup 退回 topic）。
- 输出 `03_qa_scores.md`（含各维得分、总分、veto 命中、修改建议、金句提炼候选）。

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
7. **注入文末获客 CTA**（⭐ 获客闭环关键步）：读 `templates/format/cta.md`，在正文「风险提示」之后、文章最末尾注入「企微二维码 + 双诱饵」组件。占位符 `{{WECOM_QR_IMAGE}}` **固定取 `config/wecom-qr.png`（客户群活码，多群轮换、长期有效）**，随配图走压缩；缺失则以文字「微信搜索：AI量化杨教练」兜底并标记待补。
   - **活码自动复用**：format 只认固定路径 `config/wecom-qr.png`，换码无需改文章/模板；启动时读 `config/wecom-qr.meta.json`，若 `never_expires=true` 直接复用，若已过期/3天内到期则在 `04_publish_queue.md` 标记「二维码待更换」。
   - 换码动作：`bash scripts/rotate_wecom_qr.sh <新码> --expires never`（备份旧码 → 覆盖 → 更新 meta 与台账）。
8. **推公众号草稿箱**（`baoyu-post-to-wechat`）：API 方式，保存草稿，**绝不群发**。
9. 写 `04_publish_queue.md`（含 media_id、封面/二维码是否需人工补、CTA 注入校验）。

**验收**：草稿已进草稿箱，拿到 media_id；正文末含「添加后回复对应数字」+ 三个诱饵；`04_publish_queue.md` 已写。

**红线**：绝不使用 `--submit`，到人工闸门即停。

## Step 4.5：import-urls 外部文章入 IMA（主控执行）⭐ 新增

**目的**：把本轮引用的外部热点文章/参考链接回流进 IMA 知识库，沉淀为可检索素材，形成「外部热点→入 IMA→存量素材→再选题」的增强回路。

**动作**：
1. 收集本轮 topic/writer 使用的外部 URL（写入临时文件，每行一个）。
2. 执行 `bash scripts/import_urls_to_ima.sh <url文件> [--folder <folder_id>] [--dry-run]`。
3. 网页/微信文章直接走 `import_urls`；文件型 URL 走文件上传流程。

**触发条件**：仅当本轮使用了外部 URL 素材时执行；无则跳过。
**纪律**：凭证缺失直接跳过并告警；失败不阻断主流程；导入结果记入 `_rsi_ledger.md`「素材避重」表（标注「外部导入」）。

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
4. 以 `media_type=7`（Markdown）逐篇上传（`check_repeated_names` → `create_media` → COS 上传 → `add_knowledge`）。

**纪律**：
- 只同步**已进草稿箱**的文章；Markdown 单个文件 ≤ 10MB。
- 上传前调用 `check_repeated_names` 查重；重名不支持替换（自动加时间戳后缀）。
- **幂等去重**：已同步过的文章（本地状态文件 `.synced_manifest.txt` 记录内容指纹 + 远端查重）自动跳过，可安全重复执行。
- IMA 同步失败**不阻断**主流程（凭证缺失直接跳过），但需告警并记入台账。
- 输出按「成功 / 重名改名 / 跳过(幂等) / 失败」分类汇总。

**验收**：IMA「4.AI生产文章」文件夹出现当日各篇文章（`.md`）。

## Step 7：retrospective 复盘 + 回写台账 + 简报（主控执行，v1.4.0 固化）⭐ RSI 回路闭环

0. **定时校验（v1.2.0）**：确认 `openclaw cron list` 中主 job（`a1687335-482e-4b24-ba14-527099ec9193`，`20 7 * * *` @ Asia/Shanghai）启用且频率正确；**勿**以 `~/.openclaw/cron/jobs.json` 判断。
1. 更新 RSI 进化台账 `_rsi_ledger.md`：
   - 素材避重表追加本轮新源。
   - 风格偏好/金句库按质检分和人工反馈更新。
   - RSI 回路快照追加本轮（质检分变化、比上轮强在哪、下轮重点）。
2. **人工修正采集（v1.4.0 新增，治「待反馈」积压）**：拿 `articles/<日期>*/article.md`（AI 终稿）与公众号后台**实际群发版**做 diff：
   - 有差异 → 逐条写入台账「4. 人工修正记录」（改了什么/为什么/固化为规则？），杨辉老师的每次改动都是进化信号。
   - 无差异 → 把风格偏好表中对应行的「人工反馈」从「待反馈」更新为「照发」，并给标题模式写结论。
4. **漂移自检（v1.4.0 新增）**：跑 `bash scripts/check_drift.sh`，FAIL 则当场修复（版本口径/台账章节）后再收尾。
5. **发布数据回流（v1.4.0 新增）**：杨辉老师群发后，用 `bash scripts/fetch_stats.sh --all` 拉阅读/点赞回写 `meta.json` 的 `stats` 字段与台账「7. 发布数据」表（需 `~/.config/wechat/{appid,secret}` 或 `WECHAT_STATS_JSON` 离线注入；未配则跳过不阻断）。刚群发的文章数据有 1 天延迟，建议次日用 `--all` 补采。
6. 同步更新 `/root/agents/shared/SOURCE-LEDGER.md`。
7. 向用户简报。

**简报输出契约（v1.5.0 新增，借鉴 Draco Output Contract）**——最终简报必须包含以下固定字段，部分失败必须明示（不允许只报喜）：

```text
【RSI 流水线日报 <YYYY-MM-DD>】
1. 产出：计划 3 篇 / 实际 N 篇（若 N<3 必须给减产原因，truth-first）
2. 选题与质检：各篇标题、质检分、过审/打回/丢弃
3. 待发布清单：media_id 列表（已进草稿箱，等人工群发）
4. 归档状态：GitHub commit（成功/失败+原因）、IMA「4.AI生产文章」同步数
5. 素材动态：本轮新增源、高频复用源、外部导入 URL 数
6. 人工修正 diff 摘要（无差异则写「照发」）
7. 漂移自检：check_drift.sh 结果（PASS/FAIL+修复动作）
8. 发布数据增量（如有；无则写「暂无，次日补采」）
```

> 纪律：Step 7 不可跳过。RSI 的本质是「每轮复盘的教训成为下轮硬约束」——跳过复盘等于白跑一轮。

## 失败处理

- 任一步失败：整链中止，产物移至 `/root/agents/shared/pipeline-failed/<date>_<HHMMSS>/`，向用户告警。
- 全程写 `_run.log` 与 `_status.json` 到产物目录。
