# RSI WeChat 内容流水线

> OpenClaw multi-agent pipeline for automated WeChat article creation.

## 功能

一句话触发 RSI 微信公众号内容流水线：选题 → 写作 → 质检 → 排版，全自动执行。

## 触发方式

```
跑流水线
```

或定时（每月 1 日 05:00）。

## 四步流水线

```
topic（选题）
  → writer（写作）
    → qa（质检）
      → format（排版）
```

## 执行规范

严格按 `{workspace}/pipeline/PIPELINE.md` 执行。

## 关键约束

- 选材前必须查 `/root/agents/shared/SOURCE-LEDGER.md`，避免 7 天内重复和累计 ≥2 次复用
- writer 付费段写完整内容，不留占位符
- qa 原创性维度标「参考值」（历史文章库暂搁置）
- 合规一票否决，60-79 分打回，<60 分丢弃，≥80 分推进
- format 到人工闸门即停，绝不自动群发

## 产物目录

```
/root/agents/shared/pipeline/<YYYY-MM-DD>/
├── 01_topics.md
├── 02_drafts.json
├── 03_qa_scores.md
├── 04_publish_queue.md
├── _run.log
└── _status.json
```

失败产物移至 `/root/agents/shared/pipeline-failed/<date>_<HHMMSS>/`。

## 主素材库

IMA 知识库「AI量化杨老师」，kb_id: `5JU-YyL5WUdMp3ZzS_7M2B6G5XpOB4ofM2rdKkMr3jY=`
