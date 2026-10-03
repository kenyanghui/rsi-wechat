# 前端线内容流水线配置（前端廖晓老师 → 廖晓老师公众号）

## 概述

每天 **08:08** 自动执行前端线流水线，从 IMA 知识库**「廖晓老师」**选材，产出 **3 篇**公众号**「廖晓老师」**长文（前端开发方向，角度互不重复），全部推送该号草稿箱，由廖晓老师人工选择群发。

> **与量化线（PIPELINE.md）、教育线（PIPELINE-EDU.md）完全独立**：产物目录、选题台账、知识库、目标公众号均不同，三线互不复用产物、互不干扰。量化线的 GitHub 归档、sync-ima 回写、企微获客 CTA 均为量化线专属，**前端线一律不做**。

## 流水线总览（Step -1 → 五步）

```
Step -1 素材采集与知识库喂养（主控执行，最先跑，≤40 分钟）
  → topic（选题，从「廖晓老师」知识库挖素材）
  → writer（写作）
    → qa（质检，评分标准同量化线 qa-rubric.md）
      → format（排版 → 推「廖晓老师」草稿箱）
        → 台账回收（SOURCE-LEDGER-FE.md 更新）
```

> Step -1 失败/超时**不得阻断** topic→writer→qa→format 主链：保存已导入成果，记录日志后直接进入 topic。
> 前四步为独立 agent（topic/writer/qa/format 复用现有 agent）；Step -1 与台账回收由主控执行。

## Step -1：素材采集与知识库喂养（主控执行）⭐ v1.1 新增

**目的**：喂饱「廖晓老师」知识库（2026-10-03 建目录时仅 12 条存量），让 topic 从更厚的素材池精准选题。范式同量化线 Step 0.7（素材采集与知识库运营）。

**六步动作（强制顺序）**：

```
1. 提取兴趣点 → 读库内现有内容（get_knowledge_list，条目看 title）+ 按「受众与选题方向」
              提炼 6-10 个本轮兴趣点关键词 → 00_search/interest_profile.md
2. 微信搜寻   → 每个兴趣点 bash scripts/weixin_search.sh "<关键词>" 00_search/candidates.txt 10（Tavily 限定 mp.weixin.qq.com，自动重试；每点 2-3 个关键词变体分次调用）（每点 2-3 个查询变体），
              收集 mp.weixin.qq.com/s/ 文章链接，候选池 ≥40 条 → 00_search/candidates.txt
3. 查重       → 剔除历史已导入 URL（IMPORT_STATE 状态文件）与本轮重复
4. 归类       → 按下方「素材采集目录映射」为每条 URL 选目标文件夹（无法归类 → 1.前端技术）
5. 导入       → 按目录分组调用 import_urls_to_ima.sh（命令模板见下），
              本轮新增 ≥30 篇；不足则换关键词回第 2 步补搜
6. 验收       → 目标文件夹条目数 vs 状态文件增量核对，缺口（提交成功但解析未落库）记录
              import_log.md 并对缺口 URL 重提一次；仍失败不阻断主链
```

**导入命令模板**（按目录分组分次执行）：

```bash
IMA_KB_ID="G29-8mKAMyFzibCYGFPJcf0-7qNs_6f3QvaN4e9GEHg=" \
IMPORT_STATE=/root/agents/shared/pipeline-fe/.imported_urls.txt \
bash /root/.openclaw/workspace/skills/rsi-wechat/scripts/import_urls_to_ima.sh \
  <url文件> --folder <folder_id>
```

- `IMPORT_STATE`（`/root/agents/shared/pipeline-fe/.imported_urls.txt`）为追加式幂等清单：已在清单的 URL 自动跳过，导入成功立即记录，中断重跑不重复导入。
- 脚本内置失败自动重试 2 轮（覆盖上传失败/接口失败）；**解析失败**（提交成功但 IMA 侧未落库）由第 6 步验收核对并对缺口重提。
- 目录映射缓存见 `references/folder-map-fe.md`，**以实时 `get_knowledge_list` 为准**。

**素材采集目录映射**：

| 目标目录 | folder_id | 归类 |
|----------|-----------|------|
| 1.前端技术 | `folder_7512107134223336` | 框架/工程化/性能/新特性/CSS/浏览器（默认） |
| 2.AI编程 | `folder_7512106966456747` | AI 辅助编程/Copilot/Cursor/LLM 工具链 |
| 3.职业成长 | `folder_7512106970648387` | 职业/面试/薪资/转型/技术管理 |
| 4.行业动态 | `folder_7512106974842525` | 大厂动态/生态新闻/融资/政策 |

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

选题前必须读取 `/root/agents/shared/SOURCE-LEDGER-FE.md`（前端线独立台账，与量化线/教育线台账分开记账）：

1. **7 天内已作主素材**的源 → 不得再次作为主素材
2. **累计作为主素材 ≥2 次**的源 → 换源或标注新角度
3. 命中**重点规避区**的源 → 直接打回重选

### IMA 知识库选材

**「廖晓老师」知识库**是本流水线的主素材库，kb_id: `G29-8mKAMyFzibCYGFPJcf0-7qNs_6f3QvaN4e9GEHg=`

topic agent 选材时必须：
1. 优先从该知识库搜索、挖掘有价值内容作为选题素材
2. **素材池防呆**：该库条目尚少（2026-10-03 仅 12 条），若本轮知识库素材不足以支撑 3 个互不重复角度，允许以 web_search 前端技术热点补充选题，源清单中标注 `web_search:<来源>`，并在台账中正常记账
3. 在 `01_topics.md` 末尾附「本轮源清单」，逐条标注 `新增` / `复用+<N>`
4. 知识库操作路径：使用 `ima-skills` skill，读取 `knowledge-base/SKILL.md`；调用 `openapi/wiki/v1/search_knowledge`（参数 `knowledge_base_id` 用上面的 kb_id）与 `get_knowledge_list`
5. IMA API Base：`https://ima.qq.com/openapi/wiki/v1/`；凭证从 `~/.config/ima/client_id` 和 `~/.config/ima/api_key` 自动读取

### 受众与选题方向

- 受众：前端开发者、全栈工程师、AI 编程工具用户、技术管理者、准备入行的开发者
- 主题域：前端技术（框架/工程化/性能优化/新特性）、AI 辅助编程与前端研发实践、前端职业成长与技术选型
- 3 篇角度互不重复（建议「认知层 / 方法层 / 职业心智层」三翼），选题必须写清「爆款点」

选题输出格式与量化线一致（风格卡/核心素材/角度/爆款点/Brief ≥200字）。

## 质检（qa）规则

- 评分维度和标准：同 `/root/agents/shared/qa-rubric.md`
- **≥80 分**：入库待发布；**60-79 分**：打回重写；**<60 分**：丢弃
- 合规一票否决；原创性维度标「参考值」

## 排版（format）规则与发布账号【本线专属】

- 只处理 ≥80 分过审条目；按公众号格式排版
- **发布账号：微信公众号「廖晓老师」**（廖晓老师个人公众号）
  - AppID：`wx03311e9a5bd4d42c`
  - 多账号别名：`liao`
- **推草稿箱命令必须带 `--account liao`**（baoyu-post-to-wechat 的 `wechat-api.ts`，凭证在 `~/.baoyu-skills/baoyu-post-to-wechat/EXTEND.md` 的 accounts 配置）
- **只进草稿箱，绝不 `--submit`，绝不群发**——到人工闸门即停
- **禁止注入量化获客 CTA / 企微活码（wecom-qr）**：前端线不挂任何二维码 CTA，文末自然收尾
- 封面与插图：沿用 mxai 生成，风格贴合前端/技术受众
- ⚠️ **IP 白名单前置条件**：公众号后台「基本配置 → IP 白名单」必须包含本机出口 IP `106.53.176.184`（2026-10-03 预检返回 40164，待廖晓老师在后台添加；未加则 format 推送环节会 40164 失败，产物落盘待重推）

## 台账回收

- 流水线结束后核对 `SOURCE-LEDGER-FE.md` 已更新（3 篇素材均记账），格式同量化线台账

## 明确不做（前端线范围外）

- ❌ GitHub 归档（rsi-wechat 仓库属量化线）
- ❌ sync-ima 回写知识库
- ❌ 企微获客 CTA / 活码注入
- ❌ 自动群发
