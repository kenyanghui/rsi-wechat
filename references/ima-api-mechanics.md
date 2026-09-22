# IMA API 归档机制速查（实测，Step 0.7 参考）

## 可用
- `import_urls`：导入网页/微信文章；按 URL 去重；`folder_id` 必填（根目录=kb_id）。
  - 工具：`scripts/import_urls_to_ima.sh <url文件|单个URL> [--folder <folder_id>]`
- `add_knowledge`：`media_type=11` + `note_info.content_id` 归类笔记。
- `get_knowledge_list`：浏览；`folder_id` 省略=根目录；`media_type=99`=文件夹。
- `search_knowledge`：返回 `parent_folder_id`，可验证归属。
- `get_media_info`：取 `url_info.url`（微信文章/网页/文件的原始 URL）。

## 无效 / 不存在
- `move_knowledge`：**静默 no-op 桩**（36 组合全试）。字段 `src_knowledge_base_id`/`dst_knowledge_base_id` 存在，但 `media_ids` 传值后无任何效果。
- `wiki/v1/delete_knowledge`、`remove_knowledge`、`delete_media`、`update_knowledge`：端点不存在（空响应）。
- `note/v1/move_note`、`delete_note`：不存在。
- 文件类（media_type=1，PDF/Word/PPT）：无法迁移。

## 迁移可行路径
1. web/微信（media_type=2/6）：记录原 URL → 用 `import_urls_to_ima.sh <url> --folder <目标>` 重导入 = 迁移。
2. 笔记（media_type=11）：`add_knowledge(mt=11, note_info.content_id=<note_id>)` = 归入目标 folder。
3. 文件类：无解；新建时指定 folder，已入库的无法移动。

## 常见坑
- 根目录 `get_knowledge_list` 含"最近添加"全局条目，**不代表归属根目录**；验收看目标文件夹。
- `update_note` 的 updates 是 **内容块** 枚举（`BlockUpdateAction`），与移动归属无关；且需顶层 `note_id`+`user_request_id`。
- 站点适配器风控：`Navigation rejected` / `响应不是有效 JSON`，重试或换源。
