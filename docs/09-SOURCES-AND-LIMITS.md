# 来源与验证边界

更新于 2026-10-21。当前主流程是后端无关的安装与验收方法，原机结果单列为 [历史案例](../cases/ninfer-windows/README.md)。没有将一个后端的成功外推到另一个后端。

## 资料来源

|来源|使用范围|
|---|---|
|[Codex 网关兼容要求](https://learn.chatgpt.com/docs/enterprise/gateway-compatibility)|客户端面向的 Responses、流式、工具、历史与错误契约|
|[Codex 网关部署与目录](https://learn.chatgpt.com/docs/enterprise/roll-out-a-gateway)|完整目录、版本匹配与实际客户端验收|
|[ChatGPT 登录通过网关](https://learn.chatgpt.com/docs/enterprise/sign-in-with-chatgpt-through-a-gateway)|保留 ChatGPT 登录时的认证分离；不是所有云端都必须用此机制|
|[Codex 配置参考](https://learn.chatgpt.com/docs/config-file/config-reference)|provider、目录、作用域与生效配置|
|[vLLM OpenAI-compatible 服务](https://docs.vllm.ai/en/stable/serving/online_serving/openai_compatible_server/)|官方文档列出 Responses；目标版本和模型仍须测试|
|[SGLang 文档](https://docs.sglang.io/)|按安装版本查看 API、模型、工具和启动参数|
|[SGLang OpenAI API](https://docs.sglang.io/docs/basic_usage/openai_api)|明确接口类别；不根据品牌推断目标服务具备完整 Responses|
|[SGLang reasoning parser](https://docs.sglang.io/docs/advanced_features/separate_reasoning)|解析思考输出与模型行为；不把 parser 等同于通用强度控制|

这些页面在本次修订时实际获取。stable/main 文档可能晚于目标安装版本；执行者应固定实际版本，再做运行验证。页面写了兼容并不等于目标设备已经通过。

## 当前与历史证据

主目录的 [发布验证](../evidence/README.md) 记录文档、模板和通用工具检查。案例的模型、工具与生命周期记录只属于该原机组合。

没有在本次修订中安装或测试 vLLM/SGLang 真实模型，没有改变原机正在运行的服务，也没有验证另外两台设备已安装成功。

## 不作统一保证

模型种类、数量、served ID、推理强度、思考预算、上下文、输出、采样、图像与工具支持均不作统一预设。后端支持某项 API，也不意味着每个模型和 parser 组合都支持该 API 的所有功能。

Windows 案例的启动任务不直接适用于 Linux、macOS、容器或跨主机服务。长对话压缩、WebSocket、MCP、apps、语音、并行工具等按用户实际使用范围逐项验收。

遇到未知值保留未知；无法证明参数生效时，不仅凭 HTTP 200 或模型自述标为通过。
