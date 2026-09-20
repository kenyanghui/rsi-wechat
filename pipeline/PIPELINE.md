# 内容流水线配置

## 概述

RSI 微信公众号内容流水线，月频自动执行，产出微信公众号文章。

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

## 排版（format）规则

- 只处理 ≥80 分过审条目
- 推送至微信公众号草稿箱
- 到人工闸门即停，绝不自动群发
