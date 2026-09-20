# 内容流水线配置

## 概述

RSI（Recursive Self-Improvement，递归自改进）微信公众号内容流水线，每天 07:20 自动执行四步流水线，产出 1 篇爆款长文。核心：AI 参与改进自身内容研发，形成「能力越强→内容越好→能力更强」的反馈回路。

## 四步流水线

```
topic（选题）
  → writer（写作）
    → qa（质检）
      → format（排版推送）
```

## 产物目录

```
/root/agents/shared/pipeline/<YYYY-MM-DD>/
├── 01_topics.md      # 选题 brief（含风格卡、源清单）
├── 02_drafts.json    # 草稿
├── 03_qa_scores.md   # 质检打分
├── 04_publish_queue.md # 待发布队列
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
