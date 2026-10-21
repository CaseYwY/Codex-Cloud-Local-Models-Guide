# 来源与验证边界

整理日期为2026-10-21。资料由原机正在使用的源码、已保存的验收JSON、本次会话记录和官方文档交叉整理。没有把历史成功写成其他设备的成功。

## 官方能力与本机实现

|依据|本交接使用的事实|边界|
|---|---|---|
|[ChatGPT登录通过网关](https://learn.chatgpt.com/docs/enterprise/sign-in-with-chatgpt-through-a-gateway)|ChatGPT认证与网关认证可分头传递|官方企业文档不是本机自定义双路网关的背书；原机用户级集成另有实测|
|[网关部署与目录](https://learn.chatgpt.com/docs/enterprise/roll-out-a-gateway)|完整模型元数据、匹配客户端版本、本地目录和分发后的验收|本仓库用本机回环路由，不冒充受管企业部署|
|[配置参考](https://learn.chatgpt.com/docs/config-file/config-reference)|provider、目录、认证及配置作用域|以目标机引擎实际接受的字段为准|
|[网关协议要求](https://learn.chatgpt.com/docs/enterprise/gateway-compatibility)|Responses、流式、继续对话与工具闭环|具体本地后端仍需实测|
|[流式响应](https://developers.openai.com/api/docs/guides/streaming-responses)|使用增量与完整结束事件检查流|HTTP200或一段文字不能替代完整结束|
|[Manager仓库](https://github.com/alekk89/llama-cpp-windows-manager)|Manager来源和受支持操作入口|原机自定义NInfer runtime不是原版开箱能力|
|[NInfer RC3发行](https://github.com/kvmem/kvmem/releases/tag/v0.18.0-ninfer-rc3)|对应GPU的发行包及校验资料|模型权重、硬件兼容性和安装由目标机验证|

以上官方页面在整理时实际获取；Manager仓库和NInfer发行通过GitHub API读回。没有在此仓库中复制官方完整模型目录或任何账号数据。

## 原机实测记录

- 正式配置下云端、敏思、穷理三路文本均完成；隔离验收包含同聊天切换和本地读取随机文件。
- 本地模型服务关闭时，云端完成回复，本地请求明确失败，目录仍完整。
- 路由与本地服务都关闭时，桌面引擎仍从本地目录返回完整模型和推理强度。
- 无窗口修复后，45秒与90秒观察没有本方案的终端弹窗；网关重启后的两次真实流式回复完成。
- 应用生命周期的临时任务启动、恢复、退出停止等五项通过；实际AppModel事件筛选已核对。

脱敏摘要见[evidence](../evidence/README.md)。原始日志、配置、账号文件和任务XML没有上传。

## 没有证明的内容

- 另外两台设备已经安装或其验收已通过。
- 正式桌面完整退出、重开及所有启动入口已在原机部署当时端到端验证。当时该操作被自动审批阻止，临时任务测试仍不替代它。
- Windows重新登录或冷启动后的全链路。
- 所有GPT型号、所有MCP/apps/插件、图像、语音、多Agent、长对话压缩都没有兼容问题。
- 原机262144上下文和视觉/MTP/KV配方适合其他硬件。
- 预算32K比16K质量更高或速度更快。本次不是性能基准。

2026-10-21本次整理时，原机Manager未运行，未重新启动它，也未重跑本地大模型推理；本地通过项目是保留的历史证据。文档仓库的链接、格式和源码校验是本次执行，不能冒充目标设备安装测试。
