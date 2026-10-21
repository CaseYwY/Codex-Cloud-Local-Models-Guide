# 后端适配矩阵

后端名称用于查文档，不用来自动判定安装成功。同一引擎的不同版本、模型、chat template、工具 parser 和推理 parser 可能表现不同。

|后端类别|开始前核对|接入决策|
|---|---|---|
|vLLM|实际版本与 served model ID；Responses 端点；模型模板、工具和推理解析方式|当前官方文档列出 Responses，仍需目标组合的完整请求、工具和流式验证；不预设推理级别|
|SGLang|实际 server/gateway 版本、端点、模型模板、工具与推理 parser|直接探测目标端点；不因 OpenAI-compatible 就假定完整 Responses。缺少契约则接经过验证的兼容层|
|llama.cpp、NInfer 等|实际构建、支持端点、模型格式、工具模板和参数名|原生通过则复用，否则最小适配；参数和预算不跨后端照搬|
|Ollama、LM Studio 等|目标版本实际 API、模型、服务配置和认证|同样按契约决定路径，不按名称推断全部能力|
|已有统一网关或其他服务|明确路由、认证、Responses 语义、数据边界与服务管理|满足契约可复用；不要为遵循案例额外重建一套|

## 每个模型的能力记录

- 服务启动是否成功，实际加载了什么模型，客户端怎样访问。
- 是否有原生 Responses；若有，哪些字段、流式事件和继续对话方式有效。
- tools、tool_choice、并行工具、调用 ID 和工具结果历史是否保留。
- 推理控制是无、模型默认、强度、开关、预算还是其他形式，哪些值被实际执行。
- 上下文、最大输出、模态和结构化输出的有效范围。
- 认证、限流、未知模型、服务离线与不支持参数的错误行为。
- 服务管理和共享范围，是否允许安装者调整或重启。

## 模型可运行与 Codex 可用的区别

引擎原生 API 能生成文本说明模型可运行。Codex 接入还要求客户端使用的协议、工具和历史语义完整。先验证前者，再验证后者；两种结果分开记录。

如果选定模型本身不支持可靠工具调用，协议转换不能凭空增加这一能力。可以明确交付有限文本模式或选择用户授权的其他模型，不把失败藏在网关默认路由里。

## 部署位置

本地客户端可以通过受控路径连接本机、WSL、容器或授权服务器上的推理服务。运行时操作由其平台的管理入口完成。不要假定 Windows 用户路径、端口映射或宿主回环地址在其他命名空间里相同。

固定版本与启动配置后，将探测结果写进 [盘点模板](../examples/device-inventory.example.json) 和 [路由模板](../examples/routes.example.json)，再按 [协议分支](04-LOCAL-RESPONSES.md) 实施。

官方参考：[vLLM 服务文档](https://docs.vllm.ai/en/stable/serving/online_serving/openai_compatible_server/)、[SGLang API](https://docs.sglang.io/docs/basic_usage/openai_api)、[SGLang 推理解析](https://docs.sglang.io/docs/advanced_features/separate_reasoning)。
