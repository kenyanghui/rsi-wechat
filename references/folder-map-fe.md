# IMA「廖晓老师」文件夹地图（2026-10-03 建，前端线 Step -1 参考）

> kb_id = `G29-8mKAMyFzibCYGFPJcf0-7qNs_6f3QvaN4e9GEHg=`（前端线主素材库，2026-10-03 建目录时存量 12 条）
> 本表为缓存快照，**每次运行以实时 `get_knowledge_list` 为准**（media_type=99 为文件夹，字段 title / media_id）。

## 顶层目录

| 路径 | folder_id | 归类（采集路由） |
|------|-----------|------------------|
| 1.前端技术 | `folder_7512107134223336` | 框架 / 工程化 / 性能优化 / 新特性 / CSS / 浏览器（**无法归类时的默认目录**） |
| 2.AI编程 | `folder_7512106966456747` | AI 辅助编程 / Copilot / Cursor / LLM 工具链 |
| 3.职业成长 | `folder_7512106970648387` | 职业成长 / 面试 / 薪资 / 转型 / 技术管理 |
| 4.行业动态 | `folder_7512106974842525` | 大厂动态 / 生态新闻 / 融资 / 政策 |

## 备注

- `_probe_test`（`folder_7512106869981836`）为 create_folder API 探针遗留目录，IMA 无删除 API，可在 IMA App 手动删除。
- 采集导入统一走 `scripts/import_urls_to_ima.sh`，环境变量：
  `IMA_KB_ID=<上述 kb_id>` + `IMPORT_STATE=/root/agents/shared/pipeline-fe/.imported_urls.txt`
  （IMPORT_STATE 追加式记录已导入 URL，幂等去重；失败 URL 脚本内置自动重试 2 轮）。
- 文件夹由 `openapi/wiki/v1/create_folder` 创建（2026-10-03 实测可用）；无重命名/删除 API。
