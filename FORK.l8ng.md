# FORK.l8ng.md — fork 专属改动与运维笔记

本仓库 fork 自上游（MiaAI-Lab/Qwen3.8-27B-SGLang-DGX-Spark）。为避免跟随上游
README.md / CHANGELOG.md 产生长期合并冲突，**fork 的所有专属改动只记录在本文件**；
这两个上游文档保持原样不改动。

## 与 upstream 的差异

### 1. Chat template：默认启用 froggeric v22（`CHAT_TEMPLATE` 开关，2026-09-16）

动机：服务器原本跑的是 checkpoint 自带模板（各 QUANT 档 checkpoint 的
`chat_template.jinja` 与官方 `Qwen/Qwen3.8-27B` 逐字节一致，md5 `519239a4`）。
该 stock 模板有三条**可达的请求级 500**（`raise_exception`，非服务崩溃），且
SGLang 会把 `reasoning_effort` 原样传入模板（在 pin 的镜像 commit `708f51e44`
的 `serving_chat.py` 核实过）：

1. `reasoning_effort` 不在 `xhigh|medium|low`（如 OpenAI 标准值 `high`/`minimal`）；
2. 对话中段出现 system/developer 消息；
3. 历史里没有任何 user 消息（agent 交接尾部）。

行为（`start.sh`）：

| 设置 | 行为 |
|---|---|
| 不设（默认） | **v22 启用**：挂载 `templates/qwen3.8-froggeric-v22.jinja` 并传 `--chat-template` |
| `CHAT_TEMPLATE=stock` | 退出 override，用 checkpoint 自带模板（回滚方式） |
| 其他 `.jinja` 名 / 绝对路径 | 使用那份模板 |
| 文件不存在 | 启动早期报错并打印解析路径 |

- 文件：`templates/qwen3.8-froggeric-v22.jinja`（md5 `23640fe0`，与
  `.tmp/2026-08-16-…` 归档中经 vLLM 生产验证的模板逐字节一致）；
  出处/校验/兼容性详见 `templates/README.md`。
- `start-dspark.sh` / `start-dflash.sh` 经 `exec start.sh` 自动继承，无需改动。
- Caveat：`--tool-call-parser qwen3_coder` 下**不要**传
  `chat_template_kwargs={"tool_call_format": "json"}`（hermes 形状无法解析）。
- 已验证（off-box）：渲染矩阵（普通对话/关思考/reasoning_content 历史
  与 stock 逐字节相同；三条 500 路径 v22 均正常渲染；工具轮往返形状与
  qwen3_coder 兼容；生成前缀 `<think>` 形状不变，`--reasoning-parser qwen3`
  不受影响）+ stub-docker 接线测试（默认开 / stock / 绝对路径 / 缺失报错 /
  包装脚本继承）。
- 待 GB10 验收：默认模板启动后 ① `reasoning_effort:"high"` 请求 500→200；
  ② 一次 tools 往返返回结构化 `tool_calls`；③ 一次关思考请求；
  ④ `bench/bench.sh` 吞吐持平（纯聊天渲染逐字节相同，理论零回退）。

### 2. .gitignore 白名单追加

`templates/`、`templates/*.jinja`、`templates/README.md`、`FORK.l8ng.md`
（本文件）。其余白名单规则与 upstream 一致。

### 3. `.env.sample` 增加 `CHAT_TEMPLATE` 说明块

（功能开关的示例与默认值；upstream 侧未动其他行。）

## 思考强度推荐（依据 .tmp/2026-08-16 归档报告）：`reasoning_effort=medium`

数据来自归档三层测试（Qwen3.8-27B-FP8 + vLLM 0.26.0 + v22 模板，
4×5060 Ti，2026-08-16；全部不设输出上限）：

| 模式 | 质量（L1 基础 + L3 竞赛数学 40 题） | 耗时 | 思考量 |
|---|---|---|---|
| xhigh（默认） | 40/40 (100%) | 基准（创作 76.1s） | 5154 字/竞赛题，占生成预算 43% |
| **medium** | **40/40 (100%)** | **-30%（竞赛）~-47%（创作）** | **-37%~-86%，占比 11%** |
| 关思考 | 34/40 (85%)，6 道真错全在多步数学/逻辑/几何 | -40%~-63% | 0 |

- xhigh 与 medium 连 MATH-500（AMC/AIME 级）都双双满分，质量测不出差异；
  medium 用 1/3~1/7 的思考量达到同样效果。
- `low` 实测不稳定（思考量波动大），已淘汰。
- 思考量即上下文占用：长对话/agent 场景 medium 省出的预算最值钱。
- 注意：质量结论是模板层行为、可平移到本 SGLang fork；但具体耗时/吞吐数字
  是那台 4×5060 Ti 机器的，GB10 未复测。

启用方式：

- 服务端全局默认（不改脚本，走现成 EXTRA_ARGS）：
  `EXTRA_ARGS='--default-chat-template-kwargs {"reasoning_effort": "medium"}' ./start.sh`
- 按请求覆盖：`chat_template_kwargs: {"reasoning_effort": "xhigh|medium|low"}`；
  简单/批量任务关思考：`{"enable_thinking": false}`（非思考场景推荐按模型卡
  temperature=0.7 / top_p=0.8 / presence_penalty=1.5）。

## 维护约定

- upstream 的 `README.md` / `CHANGELOG.md` 不修改；fork 改动一律更新本文件。
- 保留 `.tmp/` 归档（本地，不入库）：模板出处与测试报告的唯一来源。
