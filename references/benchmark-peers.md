# 同类 Skills 调研对标（2026-09-23，v1.4.1 留存）

> 背景：用户要求上网调研与本项目各功能类似的 skills，找出可继续优化的点。
> 结论已转化为 v1.4.1 三项落地（人工修正硬/软分级、发布数据加权选题、事实锚定维）。
> 本文留存供后续版本（v1.5+）选题参考。

## 调研范围

| 项目 | 星数 | 定位 | 与我们的关系 |
|------|------|------|-------------|
| [imraywang/wewrite](https://github.com/imraywang/wewrite) | 3.3k★ | 公众号全流程 skill（主入口+9模块） | **最相似**：热点→选题→写作→审稿→配图→排版→草稿箱，含自学习飞轮 |
| [aiworkskills/wechat-article-skills](https://github.com/aiworkskills/wechat-article-skills) | 639★ | 选题/写稿/审稿/排版/配图/发布全流程，支持 OpenClaw | 同类，多 agent 框架兼容 |
| [isjiamu/gzh-design-skill](https://github.com/isjiamu/gzh-design-skill) | 3.8k★ | Markdown→公众号精致 HTML，6主题+双关卡校验 | 对标我们的 format 环节 |
| [qiye45/wechatDownload](https://github.com/qiye45/wechatDownload) | 9.5k★ | 公众号文章+评论批量下载 | 可作 Step 0.7 素材采集源（对标账号素材库） |
| [op7418/guizang-social-card-skill](https://github.com/op7418/guizang-social-card-skill) | 7.2k★ | 小红书图文+公众号封面对生成 | 对标封面/多平台分发 |
| [anthropics/skills](https://github.com/anthropics/skills)（官方） | — | skill-creator / doc-coauthoring / brand-guidelines 等 | 工程范式参考（frontmatter 纪律、触发词设计） |

## 已落地（v1.4.1）

| 借鉴来源 | 机制 | 我们的落法 |
|----------|------|-----------|
| wewrite-learn 改稿飞轮 | 人工修改→playbook：**重复≥2次或用户确认才成硬约束，单次只是软参考** | 台账第4节加「频次/级别」列 + 升级纪律；Step 0 只把「硬」级拼进硬约束 |
| wewrite-stats 数据闭环 | stats 回填后**选题模块读取并给标题/框架加权** | Step 0 预热：读台账第7节，阅读量 ≥2× 均值的标题模式进 topic task（<3 篇跳过防过拟合） |
| wewrite-review claims 核对 | 每个数字/日期/引述必须对应来源，禁止模型记忆补洞 | qa-rubric 新增第7维「事实锚定」(10分) + veto:unsourced_claim（金融内容红线） |

## 未落地（候选池，按价值/成本排序）

1. **范文库（wewrite exemplars）**：篇章级 few-shot 风格校准，区分本人/第三方文章；金句库只有句级。低成本：IMA 建文件夹即可。
2. **一稿多发（wewrite-rewrite）**：小红书图文/抖音口播稿改写+相似度检查。中成本，需各平台格式研究。
3. **排版双关卡校验（gzh-design-skill）**：format 环节排版后自动校验（字数/图片尺寸/样式内联）。中成本。
4. **对标账号采集（wechatDownload）**：Step 0.7 用其拉竞品公众号历史文章进 IMA 作对标素材。中成本。
5. **learn-theme（wewrite）**：从任意公众号文章提取排版主题。低优先级（现有 baoyu-markdown-to-html 够用）。

## 机制亮点摘录（wewrite，防丢）

- 「越用越像你」：编辑飞轮（learn-edits）+ 范文风格库（SICO few-shot）+ 阅读数据回填反哺选题，三个回路互补。
- 「one step at a time」：主入口+9独立子skill，缺前置自动补齐——与我们的九步流水线思路一致，验证了方向。
- 「只有重复出现或用户明确确认的同范围规则才会成为硬约束；单次修改始终只是软参考」——防单次偏好污染长期风格。
