# 参考源码快照

这些文件按明确白名单从原机复制，源码SHA256见[manifest](../evidence/source-manifest.json)。它们覆盖路由和桌面生命周期，以及本地别名预算适配函数。没有包含settings.json、provider-test.toml、auth.json、完整catalog-cache.json、日志、任务XML或二进制。

**它们是原机源码快照，不是对所有设备都适用的安装器。** 在目标机的私有部署副本里适配，不改快照后仍声称哈希与原机一致。

|文件|职责|目标机必须核对|
|---|---|---|
|local-ninfer/models.json|两个本地目录条目|引擎schema、模型名、上下文、模态和工具能力；原机声明256K与text|
|router/gateway.mjs|认证、分流、云端目录刷新|本地7777、默认gpt-6.1-sol检查、client_version、OpenCode本地认证来源|
|router/supervisor.mjs|网关子进程恢复|只监督自己的gateway，不替代模型管理|
|router/run-background.ps1|代理刷新、启动或接管supervisor|Node固定在ProgramFiles/nodejs时是否存在|
|router/refresh-proxy.ps1|读取Windows当前代理|目标机代理类型、Node proxyEnv支持|
|router/background-launcher.cs|无控制台启动PowerShell|编译为winexe；返回原脚本退出码|
|router/build-background-launcher.ps1|构建启动器|系统.NET Framework64编译器路径|
|router/codex-lifecycle.cs|应用运行时维护网关，退出后停止|WindowsApps包路径、ChatGPT.exe、当前会话、15秒宽限；CLI不计入|
|router/desktop-launcher.cs|无窗口桌面启动入口|launch-codex.ps1存在|
|router/build-lifecycle.ps1|编译生命周期和桌面启动器|Microsoft.CSharp和System.Management引用|
|router/install-background-task.ps1|注册当前最新版两个任务|同名任务先备份；真实ApplicationName、事件201；无登录/分钟触发|
|router/start-router.ps1|互斥启动与健康等待|私有settings端口、同名任务用途|
|router/launch-codex.ps1|先路由就绪再激活应用|本机真实shell:AppsFolder包标识|
|router/verify-background-window.ps1|只读窗口观察|固定18767与其他用户终端可能影响统计|
|router/verify-lifecycle.ps1|独立临时任务五项验收|不应改成控制正式网关的故障测试|
|adapter/request-compat.mjs|本地预算别名映射|嵌入已认证Responses代理；actualModelName是真实后端名|

部署所需的settings.json由目标机自行生成，完整目录由目标机自己的官方目录构建。原机从OpenCode读取本地密钥只是现有集成点；目标机没有OpenCode时改为受保护本地密钥来源即可，不需要迁移模型到OpenCode或Ollama。

参考源码中没有完整Manager runtime适配器及模型转换工具，也没有通用app-server测试驱动。执行者依照文档补齐目标机适配与验收，未完成依赖时必须标为未完成。

仓库内只提供源码，不分发可执行文件。模型、worker、Manager和第三方组件按各自上游授权取得，不因本私有交接资料而改变授权。
