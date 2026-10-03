# 教育线内容流水线配置（AI教育杨老师 → 纯臻AI成长计划）

## 概述

每天 **06:06** 自动执行教育线流水线，从 IMA 知识库**「AI教育杨老师」**选材，产出 **3 篇**公众号**「纯臻AI成长计划」**长文（角度互不重复），全部推送该号草稿箱，由杨辉老师人工选择群发。

> **与量化线（PIPELINE.md）完全独立**：产物目录、选题台账、知识库、目标公众号均不同，两线互不复用产物、互不干扰。量化线的 GitHub 归档、sync-ima 回写、企微获客 CTA 均为量化线专属，**教育线一律不做**。

## 流水线总览（Step -1 → 五步）

```
Step -1 素材采集与知识库喂养（主控执行，最先跑，≤40 分钟）
  → topic（选题，从「AI教育杨老师」知识库挖素材）
  → writer（写作）
    → qa（质检，评分标准同量化线 qa-rubric.md）
      → format（排版 → 推「纯臻AI成长计划」草稿箱）
        → 台账回收（SOURCE-LEDGER-EDU.md 更新）
```

> Step -1 失败/超时**不得阻断** topic→writer→qa→format 主链：保存已导入成果，记录日志后直接进入 topic。
> Step -1 与台账回收由主控执行；topic/writer/qa/format 复用现有独立 agent。

## Step -1：素材采集与知识库喂养（主控执行）⭐ v1.1 新增（2026-10-03）

**目的**：喂饱「AI教育杨老师」知识库，形成「外部精品 → 入库 → 存量素材 → 再选题」回路，让 topic 从更厚素材池精准选题。范式同量化线 Step 0.7（素材采集与知识库运营）。

**六步动作（强制顺序）**：

```
1. 提取兴趣点 → 读库内近期内容（get_knowledge_list）+ 按「受众与选题方向」提炼 6-10 个
              本轮兴趣点关键词 → <今日目录>/00_search/interest_profile.md
2. 微信搜寻   → 每个兴趣点 bash scripts/weixin_search.sh "<关键词>" 00_search/candidates.txt 10（Tavily 限定 mp.weixin.qq.com，自动重试；每点 2-3 个关键词变体分次调用）（每点 2-3 个查询变体），
              收集 mp.weixin.qq.com/s/ 链接，候选池 ≥40 条 → 00_search/candidates.txt
3. 查重       → 剔除历史已导入 URL（IMPORT_STATE 状态文件）与本轮重复
4. 归类       → 按下方「素材采集目录映射」选目标文件夹
5. 导入       → 按目录分组调用 import_urls_to_ima.sh，本轮新增 ≥30 篇；不足换词补搜
6. 验收       → 目标文件夹条目数 vs 状态文件增量核对，缺口（提交成功但解析未落库）记录
              import_log.md 并对缺口 URL 重提一次；仍失败不阻断主链
```

**导入命令模板**（按目录分组分次执行）：

```bash
IMA_KB_ID="lGFsT13HnDXykaaJhIP9xQd__gY_jmBk8fUbUrBDY9o=" \
IMPORT_STATE=/root/agents/shared/pipeline-edu/.imported_urls.txt \
bash /root/.openclaw/workspace/skills/rsi-wechat/scripts/import_urls_to_ima.sh \
  <url文件> --folder <folder_id>
```

- `IMPORT_STATE` 为追加式幂等清单：已导入 URL 自动跳过，成功即记录，中断重跑不重复。
- 脚本内置失败自动重试 2 轮（上传/接口失败）；解析未落库由第 6 步验收核对并重提。
- 目录映射缓存见 `references/folder-map-edu.md`，以实时 `get_knowledge_list` 为准。

**素材采集目录映射**：

| 目标目录 | folder_id | 归类 |
|----------|-----------|------|
| 4.技术融合实战 | `folder_7395453947619248` | AI 工具进课堂/AI 学习力实践（**默认**） |
| 2.理论案例研究 | `folder_7396864311702447` | 理论/案例研究 |
| 3.政策文件新闻 | `folder_7396864399781719` | 政策/新闻/行业动态 |

> ⛔ 禁止采集入「9.RSI公众号文章」（那是本线自家产文章区）。

**硬边界**：本步不产文章、不进草稿箱、不写台账（台账只记被 topic 用作主素材的源）；全程 ≤40 分钟。

## 编排可靠性硬规则（与量化线 v1.5.2 同源，优先级最高）

### 1. 禁止被动等待（防 announce 丢失）

spawn 子代理后，主控**不得以「等待完成事件」结束 turn**。必须在**同一 turn 内用 exec 轮询产物文件**：

```bash
# 等待 3 篇 writer 产物（30s 间隔，单阶段最长 30 分钟）
for i in $(seq 1 60); do
  ok=1
  for p in p1 p2 p3; do
    [ -s "/root/agents/shared/pipeline-edu/<日期>/$p/02_drafts.json" ] || ok=0
  done
  [ "$ok" = 1 ] && break
  sleep 30
done
```

- 超时（30 分钟）：记录 `_run.log`，对该篇**补 spawn 一次**；仍失败则写 `_status.json` 的 `finished:false` 并向用户告警，**不得静默退出**。

### 2. 断点续跑（幂等）

主控每次启动必须先盘点：

1. 扫描**最近 2 天**的 `/root/agents/shared/pipeline-edu/<日期>/`
2. 检查每天每篇链条：`01_topics.md → 02_drafts.json → 03_qa_scores.md → format/manifest.json`
3. 存在无 `finished:true` 标记的未完成目录 → **从断点续跑**：缺哪步补哪步，已存在的产物直接复用（**禁止覆盖重写**）
4. **只扫 pipeline-edu 目录**，绝不触碰量化线的 `/root/agents/shared/pipeline/`

### 3. 完成标记

整轮结束（成功或可控失败）必须更新 `_status.json`：

```json
{
  "date": "<日期>",
  "line": "edu",
  "finished": true,
  "stages": {"p1": "done", "p2": "done", "p3": "format"},
  "articles_pushed": 3,
  "note": "..."
}
```

## 产物目录

```
/root/agents/shared/pipeline-edu/<YYYY-MM-DD>/
├── 00_search/          # Step -1 素材采集产物（interest_profile/candidates/import_log）
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

失败产物移至 `/root/agents/shared/pipeline-edu-failed/<date>_<HHMMSS>/`

## 选题环节（topic）硬规则

### 强制查重

选题前必须读取 `/root/agents/shared/SOURCE-LEDGER-EDU.md`（教育线独立台账，与量化线台账分开记账）：

1. **7 天内已作主素材**的源 → 不得再次作为主素材
2. **累计作为主素材 ≥2 次**的源 → 换源或标注新角度
3. 命中**重点规避区**的源 → 直接打回重选

### IMA 知识库选材

**「AI教育杨老师」知识库**是本流水线的主素材库，1462 条内容，kb_id: `lGFsT13HnDXykaaJhIP9xQd__gY_jmBk8fUbUrBDY9o=`

topic agent 选材时必须：
1. 优先从该知识库搜索、挖掘有价值内容作为选题素材
2. 在 `01_topics.md` 末尾附「本轮源清单」，逐条标注 `新增` / `复用+<N>`
3. 知识库操作路径：使用 `ima-skills` skill，读取 `knowledge-base/SKILL.md`；调用 `openapi/wiki/v1/search_knowledge`（参数 `knowledge_base_id` 用上面的 kb_id）与 `get_knowledge_list`
4. IMA API Base：`https://ima.qq.com/openapi/wiki/v1/`；凭证从 `~/.config/ima/client_id` 和 `~/.config/ima/api_key` 自动读取

### 受众与选题方向

- 受众：家长、教师、教育从业者、关心 AI 时代学习的成人学习者
- 主题域：AI 学习力、AI 工具进课堂/进家庭、AI 提问力、AI 方法/习惯/思维培养、AI 时代的教育选择
- 3 篇角度互不重复（建议「认知层 / 方法层 / 家长心智层」三翼），选题必须写清「爆款点」

选题输出格式与量化线一致（风格卡/核心素材/角度/爆款点/Brief ≥200字）。

## 质检（qa）规则

- 评分维度和标准：同 `/root/agents/shared/qa-rubric.md`
- **≥80 分**：入库待发布；**60-79 分**：打回重写；**<60 分**：丢弃
- 合规一票否决；原创性维度标「参考值」

## 排版（format）规则与发布账号【本线专属】

- 只处理 ≥80 分过审条目；按公众号格式排版
- **发布账号：微信公众号「纯臻AI成长计划」**
  - 公众号 ID：`agdwh2019`；原始 ID：`gh_4ccbce5e83c4`
  - AppID：`wx6e559dcf307b755f`
  - 多账号别名：`chunzhen`
- **推草稿箱命令必须带 `--account chunzhen`**（baoyu-post-to-wechat 的 `wechat-api.ts`，凭证在 `~/.baoyu-skills/baoyu-post-to-wechat/EXTEND.md` 的 accounts 配置）
- **只进草稿箱，绝不 `--submit`，绝不群发**——到人工闸门即停
- **禁止注入量化获客 CTA / 企微活码（wecom-qr）**：教育线不挂任何二维码 CTA，文末自然收尾
- 封面与插图：沿用 mxai 生成，风格贴合教育受众

## 台账回收

- 流水线结束后核对 `SOURCE-LEDGER-EDU.md` 已更新（3 篇素材均记账），格式同量化线台账

## 明确不做（教育线范围外）

- ❌ GitHub 归档（rsi-wechat 仓库属量化线）
- ❌ sync-ima 回写知识库
- ❌ 企微获客 CTA / 活码注入
- ❌ 自动群发
