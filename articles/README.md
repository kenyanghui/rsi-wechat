# 已发布文章归档

本目录存放已推送到微信公众号草稿箱的文章，每天一篇，便于后续处理（数据分析、二次分发、人工复盘、构建历史文章库）。

## 结构

```
articles/<YYYY-MM-DD>/
├── article.md      # 正文终稿（Markdown）
├── meta.json       # 元数据：标题/摘要/作者/质检分/media_id/封面/标签/源
├── cover.png       # 封面图
└── images/         # 正文配图（如有）
```

## 归档方式

由流水线 format 环节产出后，主控调用：

```bash
bash scripts/archive_article.sh <YYYY-MM-DD> <产物目录>
```

脚本自动收集终稿、生成 meta.json、commit 并 push 到 GitHub。
