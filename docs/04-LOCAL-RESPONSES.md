# 本地 NInfer 服务与协议适配

## 安装路径选择

目标机已有认证的 NInfer `/v1/responses` 服务时，优先复用并做兼容性检查。它不必来自 Manager，也不必使用原机端口。

没有本地服务时，先从 [NInfer RC3 官方发行](https://github.com/kvmem/kvmem/releases/tag/v0.18.0-ninfer-rc3) 选择对应 GPU的运行包，核对其校验和与说明，再准备兼容模型。该发行经查询包含 RTX30/40/50三类包，不能给所有设备统一安装 RTX50包。模型格式、转换关系、显存与内存配方都由目标机核对。本仓库不提供权重或转换产物。

若采用 [llama.cpp Windows Manager](https://github.com/alekk89/llama-cpp-windows-manager)，读取本机随软件安装的 AGENTS.md并使用 llwmctl。原机通过自定义 runtime适配 NInfer；早期原版 Manager拒绝无 llama-server入口的 runtime与 `.ninfer` 模型登记，不能把原机集成能力归因于原版直接支持。

原机 Manager适配层还包含 runtime注册、启动参数映射、来源GGUF与转换结果校验、worker哈希、临时后端密钥和模型元数据脱敏。这些不在本仓库的完整分发范围内。尚无该层的设备可按官方包建立原生服务，再为别名加入最小请求适配；也可单独完成 Manager runtime集成。仅复制 request-compat.mjs不会自动得到完整 Manager安装。

## 原机的请求预算补丁

参考文件：[request-compat.mjs](../reference/adapter/request-compat.mjs)。

`normalizeResponsesBytes(bytes, actualModelName)` 对两个别名执行：

|字段|敏思|穷理|
|---|---|---|
|model|替换为真实 worker模型名|同左|
|reasoning.effort|xhigh|xhigh|
|thinking_budget|16384|32768|
|max_output_tokens|24576|40960|
|chat_template_kwargs|启用并保留思考，xhigh|同左|

该函数保留 input、instructions、tools、call_id、function_call_output等其他请求字段。除这两个别名之外，Responses原始字节不变。目标机若采用别的本地后端，需要实现等价语义，不能假定上述 NInfer扩展字段普遍通用。

原机在适配代理的 `/v1/responses` POST路径使用它，并根据改写后字节重算 Content-Length。Chat Completions另走 normalizeChatBytes，不能混用 Responses和Chat协议。

```javascript
import { normalizeResponsesBytes } from './request-compat.mjs';

// 放在已有的、经过认证的 Responses 代理内。
// actualModelName 来自目标机真实服务，不从原机照搬。
const rewritten = normalizeResponsesBytes(originalBodyBytes, actualModelName);
headers['content-length'] = rewritten.length;
delete headers['transfer-encoding'];
// 转发到目标机已验证的 NInfer /v1/responses。
```

## 必须单独验证的能力

- 真实 Responses文本响应，不是只查询 models或Chat Completions。
- SSE文本增量、终止事件和完整回复。返回HTTP 200但随后断流仍算失败。
- function_call与function_call_output能够往返；call_id、原始arguments和对话历史未被删改。
- 两档请求实际到达 NInfer，预算与输出上限生效。记录请求结构和原生日志的有效值，不能只看菜单文案。
- 错误的本地密钥被拒绝；缺失本地服务时明确失败，不改路由到云端。

工具 schema随 Codex版本变化。原机本地专用 profile曾临时使用标准function工具兼容设置 `prefer_mxc=true` 并控制多Agent上下文；这些不是要求全局关闭工具生态的安装步骤。遇到 namespace等后端不支持的工具形式，应核对当前 schema、在隔离测试中选择支持形式，或做保真适配，不能删除工具来声称 Agent接入成功。

## 硬件与模型参数

262144上下文、CPU视觉、MTP4、Host/SSD KV预算是原机特定模型和runtime配方，不能根据 Codex目录声明直接启用。新设备以实际 profile、worker帮助和可用资源为准。推理服务尚不支持图像时，本地目录保持 text模态；不因模型名中有 Vision就宣布 Codex图像路径通过。

本次接入并未重新测量不同预算的效率或质量，也没有证明32K优于16K。判断安装成功与做性能排名是不同任务。
