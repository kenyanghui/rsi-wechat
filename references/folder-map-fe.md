# IMA「廖晓老师」文件夹地图（v2.0，2026-10-06 重建：期货·期权·IPO前股权投资）

> kb_id = `G29-8mKAMyFzibCYGFPJcf0-7qNs_6f3QvaN4e9GEHg=`（本线主素材库）
> 本表为缓存快照，**每次运行以实时 `get_knowledge_list` 为准**（media_type=99 为文件夹，字段 title / media_id）。

## 顶层目录（v2.0 生效目录，2026-10-06 建）

| 路径 | folder_id | 归类（采集路由） |
|------|-----------|------------------|
| 1.期货投资 | `folder_7513160139409827` | 商品期货 / 金融期货 / 期货策略与风控 |
| 2.期权投资 | `folder_7513160139414798` | 期权策略 / 波动率 / 期权入门与进阶 |
| 3.股权投资IPO前 | `folder_7513160143608903` | Pre-IPO / 一级市场 / 创投 / 股权退出 |
| 4.市场与宏观动态 | `folder_7513160147796202` | 宏观 / 监管 / 行情与行业新闻（**无法归类时的默认**） |

## ⛔ v1 误采遗留（待 App 手动清理，禁止归入、检索规避）

| 路径 | folder_id | 状态 |
|------|-----------|------|
| 1.前端技术 | `folder_7512107134223336` | 历史误采 ~50 篇 |
| 2.AI编程 | `folder_7512106966456747` | 历史误采 50+ 篇 |
| 3.职业成长 | `folder_7512106970648387` | 历史误采 13 篇 |
| 4.行业动态 | `folder_7512106974842525` | 历史误采 29 篇 |
| _probe_test | `folder_7512106869981836` | API 探针遗留 |

> IMA openapi 无删除/改名 API，以上需在 IMA App 手动删除；清理前 topic 按 PIPELINE-FE.md 规则规避其来源。

## 备注

- 采集导入统一走 `scripts/import_urls_to_ima.sh`：`IMA_KB_ID=<kb_id>` + `IMPORT_STATE=/root/agents/shared/pipeline-fe/.imported_urls.txt`（幂等去重；失败自动重试 2 轮）。
- 搜索走 `scripts/weixin_search.sh`（Tavily include_domains，凭证 `/root/.config/tavily/api_key`）。
- 教育线目录地图 `references/folder-map-edu.md`；量化线 `references/folder-map.md`。
