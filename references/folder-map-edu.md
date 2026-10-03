# IMA「AI教育杨老师」文件夹地图（教育线 Step -1 采集归位参考，2026-10-03 核对）

> kb_id = `lGFsT13HnDXykaaJhIP9xQd__gY_jmBk8fUbUrBDY9o=`（教育线主素材库）
> 本表为缓存快照，**每次运行以实时 `get_knowledge_list` 为准**（media_type=99 为文件夹，字段 title / media_id）。

## 顶层目录（2026-10-03 实测 9 个）

| 路径 | folder_id | 采集归位 |
|------|-----------|----------|
| 0.四会中学实训 | `folder_7507322792321320` | —（实训材料，不采集） |
| 1.科学副校长交流 | `folder_7396819743029799` | — |
| 2.理论案例研究 | `folder_7396864311702447` | ✅ 理论/案例研究 |
| 3.政策文件新闻 | `folder_7396864399781719` | ✅ 政策/新闻/行业动态 |
| 4.技术融合实战 | `folder_7395453947619248` | ✅ AI 工具进课堂/AI 学习力实践（**默认**） |
| 5.多元升学服务 | `folder_7396849228982178` | — |
| 6.课程标准教材 | `folder_7397184068662466` | — |
| 7.班级管理工作 | `folder_7397194025936102` | — |
| 9.RSI公众号文章 | `folder_7510314702606593` | ⛔ 本线自家产文章区，**禁止采集入此** |

## 备注

- 采集导入统一走 `scripts/import_urls_to_ima.sh`，环境变量：
  `IMA_KB_ID=<上述 kb_id>` + `IMPORT_STATE=/root/agents/shared/pipeline-edu/.imported_urls.txt`
  （幂等去重；失败 URL 脚本内置自动重试 2 轮）。
- 量化线目录地图见 `references/folder-map.md`，前端线见 `references/folder-map-fe.md`。
