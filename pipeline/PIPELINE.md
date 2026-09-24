# 内容流水线配置

## 概述

RSI（Recursive Self-Improvement，递归自改进）微信公众号内容流水线，每天 07:20 自动执行九步流水线，产出 **3 篇**爆款长文（角度互不重复），全部推送草稿箱供人工选择群发，并同步归档到 GitHub。核心：AI 参与改进自身内容研发，形成「能力越强→内容越好→能力更强」的反馈回路。

## 九步流水线

每天跑 3 轮，3 篇角度/素材互不重复（建议「认知层/商业层/心智层」三翼）。产物按篇分目录：`<日期>/p1/`、`p2/`、`p3/`。

```
Step0.5 热点采集 → Step0.7 素材运营
  → topic（选题） → writer（写作） → qa（质检） → format（排版推送）
    → Step4.5 import-urls → archive（同步 GitHub） → sync-ima（同步 IMA）
```

### 文章归档（archive，每次发布后必做）

已推送公众号草稿箱的文章，必须同步归档到 GitHub `kenyanghui/rsi-wechat`，便于后续处理：

```
articles/<YYYY-MM-DD>/       # 第 1 篇
articles/<YYYY-MM-DD>-2/     # 第 2 篇（同日多篇自动编号）
articles/<YYYY-MM-DD>-3/     # 第 3 篇
├── article.md      # 正文
├── meta.json       # 元数据（含 media_id）
├── cover.png       # 封面
└── images/         # 配图
```

调用 `scripts/archive_article.sh <日期> <产物目录>` 完成收集 → commit → push（支持同日多篇，优先读 `format/manifest.json`，内置推送重试）。


## 编排可靠性硬规则（v1.5.2，优先级最高）

> 背景：2026-09-21/23/24 三次断链，根因是网关子代理「完成事件(announce)偶发丢失」× 主控被动等待无兜底。以下三条为强制契约，全文与 `/root/agents/shared/PIPELINE.md` 保持同步。

### 1. 禁止被动等待（防 announce 丢失）

spawn 子代理后，主控**不得以「等待完成事件」结束 turn**。必须在**同一 turn 内用 exec 轮询产物文件**（产物落盘是唯一可信依据，announce 只作提前推进参考）：

```bash
for i in $(seq 1 60); do
  ok=1
  for p in p1 p2 p3; do
    [ -s "/root/agents/shared/pipeline/<日期>/$p/02_drafts.json" ] || ok=0
  done
  [ "$ok" = 1 ] && break
  sleep 30
done
```

超时（30 分钟）：记录 `_run.log`，对该篇**补 spawn 一次**；仍失败则写 `_status.json` 的 `finished:false` 并向用户告警，**不得静默退出**。

### 2. 断点续跑（幂等）

主控每次启动必须先盘点：① 扫描**最近 2 天**产物目录；② 检查每天每篇链条 `01→02→03→format/manifest.json`；③ 存在无 `finished:true` 的未完成目录 → 从断点续跑，缺哪步补哪步，**禁止覆盖重写**已验证产物；④ **续跑优先、不双跑**——本轮续跑后当天全新目录不再新开全量任务，留给下一个定时触发。

### 3. 完成标记（看门狗依据）

整轮结束（成功或可控失败）必须更新 `_status.json`：`finished:true/false` + `stages` 各篇进度 + `articles_pushed`。看门狗 `scripts/watchdog_pipeline.sh`（v1.5.2）**只认磁盘标记**，不信任 cron 表面状态（主控可能「正常结束」但实际断链）。

## 产物目录

```
/root/agents/shared/pipeline/<YYYY-MM-DD>/
├── p1/               # 第1篇
│   ├── 01_topics.md      # 选题 brief（含风格卡、源清单）
│   ├── 02_drafts.json    # 草稿
│   ├── 03_qa_scores.md   # 质检打分
│   ├── 04_publish_queue.md # 待发布队列
│   └── format/           # 终稿 + 封面 + manifest.json
├── p2/               # 第2篇（结构同上）
├── p3/               # 第3篇（结构同上）
├── _run.log          # 执行日志
└── _status.json      # 执行状态
```

失败产物移至 `/root/agents/shared/pipeline-failed/<date>_<HHMMSS>/`。

## 选题环节（topic）硬规则

### 强制查重

选题前必须读取 `/root/agents/shared/SOURCE-LEDGER.md`：

1. **7 天内已作主素材**的源 → 不得再次作为主素材
2. **累计作为主素材 ≥2 次**的源 → 换源或标注新角度
3. 命中**重点规避区**的源 → 直接打回重选

### IMA 知识库选材

**「AI量化杨老师」知识库**为主素材库，kb_id: `5JU-YyL5WUdMp3ZzS_7M2B6G5XpOB4ofM2rdKkMr3jY=`

topic agent 必须：
1. 优先从该知识库搜索、挖掘选题素材
2. 在 `01_topics.md` 末尾附「本轮源清单」，标注 `新增` 或 `复用+<N>`

## 质检（qa）规则

- **≥80 分**：入库待发布
- **60-79 分**：打回 writer 重写
- **<60 分**：丢弃
- 合规一票否决
- 原创性维度标「参考值」

## 排版（format）规则 — 整合 9 个 baoyu skill

- 只处理 ≥80 分过审条目
- 推送至微信公众号草稿箱
- 到人工闸门即停，绝不自动群发

### baoyu 能力嵌入点（必须用好）

| baoyu skill | 用途 |
|-------------|------|
| `baoyu-cover-image` | 生成公众号封面图（2.35:1） |
| `baoyu-article-illustrator` | 分析正文结构，在关键段落生成插图 |
| `baoyu-image-gen` | 兜底补充图像生成 |
| `baoyu-markdown-to-html` | 正文转微信兼容 HTML（含主题样式） |
| `baoyu-compress-image` | 所有配图转 WebP 并压缩 |
| `baoyu-post-to-wechat` | 推送草稿箱（API 方式） |
| `baoyu-url-to-markdown` | 外部参考链接转素材（topic 环节） |
| `baoyu-xhs-images` | 同一素材复用小红书（可选） |
| `baoyu-slide-deck` | 长文转信息图/幻灯（可选二次传播） |

## RSI 进化台账（_rsi_ledger.md，每轮必回收）

每轮流水线结束后，主控必须更新 `_rsi_ledger.md`：
1. 素材避重表追加新源
2. 风格偏好/金句库按质检分和人工反馈更新
3. RSI 回路快照记录「质检分变化、比上轮强在哪、下轮重点」

> 上一轮的人工修正和质检反馈，是下一轮最重要的养分（越用越聪明）。
