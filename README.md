# Codex 保留云端模型并接入本地 NInfer

这是给其他设备上的 AI 执行者使用的中文安装交接文档。它记录 2026-10-20 至 2026-10-21 的实际接入、失败与修复，并提供不含凭据的参考源码。目标是在一个 Codex 桌面模型菜单中保留原有云端 GPT，再增加本地模型。

**先读 [AI 执行入口](docs/00-AI-HANDOFF.md)，按 [Windows 安装步骤](docs/03-WINDOWS-INSTALL.md)操作，最后提交 [验收报告](examples/installation-report.md)。** 两台设备分别安装、分别验收，不共享账号文件、密钥、模型路径或运行参数。

## 最终方案

Codex 使用一个自定义 provider `cloud-local-router`。本机网关把 GPT 请求转发至官方 Codex 后端，把 `ninfer-minsi` 和 `ninfer-qiongli` 转发至本机 NInfer Responses 服务。云端继续使用目标设备自己的 ChatGPT 登录。

模型菜单使用本地完整目录，保留目标设备实际取得的官方模型条目与元数据，再追加本地条目。菜单不依赖本地模型在线，云端推理也不依赖 NInfer 在线。

本机最新版后台方式是随 Codex 桌面应用启停。无窗口生命周期控制器负责按需拉起网关，最后一个桌面应用进程退出 15 秒后停止网关。早期的登录启动、每分钟拉起属于历史方案，安装时不要同时启用。

|入口|内容|
|---|---|
|[00-AI-HANDOFF](docs/00-AI-HANDOFF.md)|可直接发给两台设备上的 AI 的执行指令|
|[01-ARCHITECTURE](docs/01-ARCHITECTURE.md)|请求、认证、目录、进程的边界|
|[02-HISTORY](docs/02-HISTORY.md)|接入全过程及每次问题为什么发生|
|[03-WINDOWS-INSTALL](docs/03-WINDOWS-INSTALL.md)|盘点、备份、隔离测试、部署、启动|
|[04-LOCAL-RESPONSES](docs/04-LOCAL-RESPONSES.md)|NInfer 前置条件、协议、预算与工具调用|
|[05-CATALOG](docs/05-CATALOG.md)|完整目录构建、离线菜单与版本匹配|
|[06-VERIFICATION](docs/06-VERIFICATION.md)|真实推理、工具循环、离线、界面及生命周期验收|
|[07-TROUBLESHOOTING](docs/07-TROUBLESHOOTING.md)|常见错误与处理顺序|
|[08-ROLLBACK](docs/08-ROLLBACK.md)|恢复云端直连与清理自有后台组件|
|[09-SOURCES-AND-LIMITS](docs/09-SOURCES-AND-LIMITS.md)|官方来源、实测范围与未验证事项|
|[reference](reference/README.md)|原机参考源码，包含机器绑定项，不是一键安装包|
|[evidence](evidence/README.md)|脱敏实测摘要及源码哈希|

## 使用范围

原机实测基线为 Windows 11、Codex 桌面版 `26.1013.4894.0`、桌面内置引擎 `0.163.0-alpha.10.2`、Node.js `26.10.0`、NInfer RC3 与自定义 Manager 适配层。源资料中的 Manager 基线为 `2.8.0`，本次整理时 Manager 未运行，未重新查询其服务版本。

原机默认云端模型为 `gpt-6.1-sol`，当时目录有 7 个可见云端条目，加上 2 个本地条目共 9 个。**这些数量、型号、262144 上下文和硬件参数都不是其他设备的安装常量。** 目标设备应保留其现有可用云端默认，并生成与其 Codex 引擎匹配的目录。

此仓库不包含模型权重、NInfer/Manager 二进制、完整 Manager runtime 打包器、账号登录状态或任何运行密钥。尚无本地服务的设备必须先完成 [本地服务前置步骤](docs/04-LOCAL-RESPONSES.md)。参考源码完整覆盖原机的路由和桌面生命周期层；其他本地后端、操作系统和新 Codex 版本需要重新验证。

## 分发给两台设备

先让设备取得此私有仓库的读取权限，再分别发送以下文字：

> 请读取本仓库 AGENTS.md 和 docs/00-AI-HANDOFF.md，在当前设备保留 Codex 现有云端模型、接入本地模型。先完成只读盘点与备份，再按文档隔离验证并部署。不要照搬原机用户名、路径、模型数量或凭据。最后填写 examples/installation-report.md 的副本，分别说明已验证与未验证项目。

本次发布只创建和上传交接资料，没有在另外两台设备上安装，也没有改变原机正在服务的网关或模型。
