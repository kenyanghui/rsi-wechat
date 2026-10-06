# 廖晓老师线内容流水线配置（廖晓老师 → 廖晓老师公众号：期货·期权·IPO前股权投资）

> v2.0（2026-10-06 方向修正）：本线内容方向由「前端技术」**彻底修正**为「期货、期权投资 + IPO 前股权投资」。
> 旧方向产物与误采内容处理见文末「v2.0 修正记录」。

## 概述

每天 **08:08** 自动执行本线流水线，从 IMA 知识库**「廖晓老师」**选材，产出 **3 篇**公众号**「廖晓老师」**长文（**期货、期权投资、IPO 前股权投资**方向，角度互不重复），全部推送该号草稿箱，由廖晓老师人工选择群发。

> **与量化线（PIPELINE.md）、教育线（PIPELINE-EDU.md）完全独立**：产物目录、选题台账、知识库、目标公众号均不同，三线互不复用产物、互不干扰。企微获客 CTA、GitHub 归档为量化线专属，本线不做；**成稿回写 IMA 知识库是本线硬规则**（见下节）。

## 流水线总览（Step -1 → 五步）

```
Step -1 素材采集与知识库喂养（主控执行，最先跑，≤40 分钟）
  → topic（选题，从「廖晓老师」知识库挖素材）
  → writer（写作）
    → qa（质检，评分标准同量化线 qa-rubric.md + 投资合规一票否决）
      → format（排版 → 推「廖晓老师」草稿箱）
    → 成稿回写（sync_to_ima → IMA「廖晓老师」库「5.公众号文章」）
      → 台账回收（SOURCE-LEDGER-FE.md 更新）
```

> Step -1 失败/超时**不得阻断** topic→writer→qa→format 主链：保存已导入成果，记录日志后直接进入 topic。
> Step -1 与台账回收由主控执行；topic/writer/qa/format 复用现有独立 agent。

## Step -1：素材采集与知识库喂养（主控执行）⭐

**目的**：喂饱「廖晓老师」知识库，形成「外部精品 → 入库 → 存量素材 → 再选题」回路。范式同量化线 Step 0.7。

**六步动作（强制顺序）**：

```
1. 提取兴趣点 → 读库内近期内容（get_knowledge_list）+ 按下方「受众与选题方向」提炼 6-10 个
              兴趣点关键词（期货/期权/股权投资域）→ <今日目录>/00_search/interest_profile.md
2. 微信搜寻   → 每个兴趣点调 bash scripts/weixin_search.sh "<关键词>" 00_search/candidates.txt 10
              （Tavily 限定 mp.weixin.qq.com，自动重试；每点 2-3 个关键词变体分次调用；
              exit 1=0 结果换词重搜），候选池 ≥40 条 → 00_search/candidates.txt
3. 查重       → 剔除历史已导入 URL（IMPORT_STATE 状态文件）与本轮重复
4. 归类       → 按下方「素材采集目录映射」选目标文件夹；无法归类默认 4.市场与宏观动态
5. 导入       → 按目录分组调用 import_urls_to_ima.sh，本轮新增 ≥30 篇；不足换词补搜
6. 验收       → 目标文件夹条目数 vs 状态文件增量核对，缺口重提一次；仍失败不阻断主链
```

**导入命令模板**（按目录分组分次执行）：

```bash
IMA_KB_ID="G29-8mKAMyFzibCYGFPJcf0-7qNs_6f3QvaN4e9GEHg=" \
IMPORT_STATE=/root/agents/shared/pipeline-fe/.imported_urls.txt \
bash /root/.openclaw/workspace/skills/rsi-wechat/scripts/import_urls_to_ima.sh \
  <url文件> --folder <folder_id>
```

**素材采集目录映射**：

| 目标目录 | folder_id | 归类 |
|----------|-----------|------|
| 1.期货投资 | `folder_7513160139409827` | 商品期货/金融期货/期货策略与风控 |
| 2.期权投资 | `folder_7513160139414798` | 期权策略/波动率/期权入门与进阶 |
| 3.股权投资IPO前 | `folder_7513160143608903` | Pre-IPO/一级市场/创投/股权退出 |
| 4.市场与宏观动态 | `folder_7513160147796202` | 宏观/监管/行情与行业新闻（**默认**） |

> ⛔ **旧四目录禁止归入**：`1.前端技术`、`2.AI编程`、`3.职业成长`、`4.行业动态` 为 v1 误采遗留（API 无删除能力，待 App 手动清理），采集严禁写入。

- `IMPORT_STATE`（`/root/agents/shared/pipeline-fe/.imported_urls.txt`）为追加式幂等清单：已导入 URL 自动跳过，导入成功立即记录，中断重跑不重复导入。
- 脚本内置失败自动重试 2 轮（上传/接口失败）；解析未落库由第 6 步验收核对并重提。
- 目录映射缓存见 `references/folder-map-fe.md`，**以实时 `get_knowledge_list` 为准**。

**硬边界**：本步不产文章、不进草稿箱、不写台账（台账只记被 topic 用作主素材的源）；全程 ≤40 分钟。

## 编排可靠性硬规则（与量化线 v1.5.2 同源，优先级最高）

### 1. 禁止被动等待（防 announce 丢失）

spawn 子代理后，主控**不得以「等待完成事件」结束 turn**。必须在**同一 turn 内用 exec 轮询产物文件**：

```bash
# 等待 3 篇 writer 产物（30s 间隔，单阶段最长 30 分钟）
for i in $(seq 1 60); do
  ok=1
  for p in p1 p2 p3; do
    [ -s "/root/agents/shared/pipeline-fe/<日期>/$p/02_drafts.json" ] || ok=0
  done
  [ "$ok" = 1 ] && break
  sleep 30
done
```

- 超时（30 分钟）：记录 `_run.log`，对该篇**补 spawn 一次**；仍失败则写 `_status.json` 的 `finished:false` 并向用户告警，**不得静默退出**。

### 2. 断点续跑（幂等）

主控每次启动必须先盘点：

1. 扫描**最近 2 天**的 `/root/agents/shared/pipeline-fe/<日期>/`
2. 检查每天每篇链条：`01_topics.md → 02_drafts.json → 03_qa_scores.md → format/manifest.json`
3. 存在无 `finished:true` 标记的未完成目录 → **从断点续跑**：缺哪步补哪步，已存在的产物直接复用（**禁止覆盖重写**）
4. **只扫 pipeline-fe 目录**，绝不触碰量化线 `/root/agents/shared/pipeline/` 与教育线 `/root/agents/shared/pipeline-edu/`

### 3. 完成标记

整轮结束（成功或可控失败）必须更新 `_status.json`：

```json
{
  "date": "<日期>",
  "line": "fe",
  "finished": true,
  "stages": {"p1": "done", "p2": "done", "p3": "format"},
  "articles_pushed": 3,
  "note": "..."
}
```

## 产物目录

```
/root/agents/shared/pipeline-fe/<YYYY-MM-DD>/
├── 00_search/          # Step -1 素材采集产物
│   ├── interest_profile.md   # 本轮兴趣点画像（6-10 个关键词）
│   ├── candidates.txt        # 候选文章池（≥40，URL 一行一条带标题注释）
│   └── import_log.md         # 导入/验收日志（新增 N 篇、目录分布、失败与重试记录）
├── p1/                 # 第 1 篇（每日 3 篇）
│   ├── 01_topics.md
│   ├── 02_drafts.json
│   ├── 03_qa_scores.md
│   ├── 04_publish_queue.md
│   └── format/         # article.md + manifest.json + imgs/cover.png
├── p2/ …               # 第 2 篇（同上结构）
├── p3/ …               # 第 3 篇（同上结构）
├── _run.log            # 执行日志
└── _status.json        # 执行状态
```

失败产物移至 `/root/agents/shared/pipeline-fe-failed/<date>_<HHMMSS>/`

## 选题环节（topic）硬规则

### 强制查重

选题前必须读取 `/root/agents/shared/SOURCE-LEDGER-FE.md`（本线独立台账）：

1. **7 天内已作主素材**的源 → 不得再次作为主素材
2. **累计作为主素材 ≥2 次**的源 → 换源或标注新角度
3. 命中**重点规避区**的源 → 直接打回重选
4. **旧目录来源一律规避**：检索结果若来自 `1.前端技术/2.AI编程/3.职业成长/4.行业动态` 四个 v1 误采目录 → 弃用，并在台账「重点规避区」记账

### IMA 知识库选材

**「廖晓老师」知识库**是本流水线的主素材库，kb_id: `G29-8mKAMyFzibCYGFPJcf0-7qNs_6f3QvaN4e9GEHg=`

topic agent 选材时必须：
1. 优先从该知识库搜索、挖掘有价值内容作为选题素材（期货/期权/股权投资域）
2. **素材池防呆**：知识库素材不足以支撑 3 个互不重复角度时，允许以 web_search 期货/期权/股权投资热点补充选题，源清单中标注 `web_search:<来源>`，并在台账中正常记账
3. 在 `01_topics.md` 末尾附「本轮源清单」，逐条标注 `新增` / `复用+<N>`
4. 知识库操作路径：使用 `ima-skills` skill，调用 `openapi/wiki/v1/search_knowledge`（`knowledge_base_id` 用上面的 kb_id）与 `get_knowledge_list`
5. IMA API Base：`https://ima.qq.com/openapi/wiki/v1/`；凭证从 `~/.config/ima/client_id` 和 `~/.config/ima/api_key` 自动读取

### 受众与选题方向

- 受众：期货/期权交易者、股权投资从业者、关注一级市场与 Pre-IPO 的投资人
- 主题域：期货投资（商品/金融期货、策略与风控）、期权投资（策略/波动率）、IPO 前股权投资（Pre-IPO/一级市场/创投/退出）、宏观与市场动态（监管/行情/行业）
- 3 篇角度互不重复（建议「认知层 / 策略方法层 / 投资心智层」三翼），选题必须写清「爆款点」

选题输出格式与量化线一致（风格卡/核心素材/角度/爆款点/Brief ≥200字）。

## 质检（qa）规则

- 评分维度和标准：同 `/root/agents/shared/qa-rubric.md`
- **≥80 分**：入库待发布；**60-79 分**：打回重写；**<60 分**：丢弃
- 合规一票否决；原创性维度标「参考值」
- **投资内容合规（本线专属硬规则，一票否决）**：不承诺收益/胜率；不给出具体买卖指令（标的、合约、点位、仓位指令）；不夸大"稳赚/保本/无风险"；每篇必须含风险提示（期货/期权杠杆交易风险、股权投资流动性风险按题域对应）

## 排版（format）规则与发布账号【本线专属】

- 只处理 ≥80 分过审条目；按公众号格式排版
- **发布账号：微信公众号「廖晓老师」**（廖晓老师个人公众号）
  - AppID：`wx03311e9a5bd4d42c`
  - 多账号别名：`liao`
- **推草稿箱命令必须带 `--account liao`**（baoyu-post-to-wechat 的 `wechat-api.ts`，凭证在 `~/.baoyu-skills/baoyu-post-to-wechat/EXTEND.md` 的 accounts 配置）
- **只进草稿箱，绝不 `--submit`，绝不群发**——到人工闸门即停
- **禁止注入量化获客 CTA / 企微活码（wecom-qr）**：本线不挂任何二维码 CTA，文末自然收尾
- 封面与插图：沿用 mxai 生成，风格贴合投资/财经受众
- IP 白名单已配置（2026-10-06 生效）：出口 IP `106.53.176.184`

## 成稿回写（sync-ima）【本线专属硬规则】

3 篇推送草稿箱完成后，主控把写好的成稿回写源头条源知识库——形成「选题→成稿→沉淀回库」的闭环：

```bash
IMA_KB_ID="G29-8mKAMyFzibCYGFPJcf0-7qNs_6f3QvaN4e9GEHg=" \
IMA_FOLDER_ID="folder_7513162840543352" \
bash /root/.openclaw/workspace/skills/rsi-wechat/scripts/sync_to_ima.sh \
  <YYYY-MM-DD> /root/agents/shared/pipeline-fe/<YYYY-MM-DD>
```

- 目标：IMA「廖晓老师」库 → **「5.公众号文章」**（folder_7513162840543352，专存本线成稿）
- 脚本按 `p*/format/manifest.json` 取清单，生成规范 Markdown（标题+作者+来源+摘要+正文）逐篇上传，自动去重
- 失败不阻断主链，但必须告警并记 `_run.log`

## 台账回收

- 流水线结束后核对 `SOURCE-LEDGER-FE.md` 已更新（3 篇素材均记账），格式同量化线台账

## 明确不做（本线范围外）

- ❌ GitHub 归档（rsi-wechat 仓库属量化线）
- ❌ 企微获客 CTA / 活码注入
- ❌ 自动群发

## v2.0 修正记录（2026-10-06）

- **方向修正**：v1 误将本线定为「前端技术」（对需求"前端的廖晓老师"理解错误）；实际兴趣点为**期货、期权投资 + IPO 前股权投资**。
- **已清理**：草稿箱 12 篇前端方向草稿已全部删除（原文保留在 `pipeline-fe/2026-10-03..06/`）；新目录树已建（上表 4 个）。
- **待人工**：旧四目录（前端技术/AI编程/职业成长/行业动态）及其 140+ 篇误采内容，IMA openapi 无删除 API，需在 IMA App 手动删除；清理前 topic 按上文规则规避旧目录来源。
- 台账 `SOURCE-LEDGER-FE.md` 已重置（v1 记账基于误采素材，全部作废）。
