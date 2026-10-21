# Windows 安装步骤

适用于在目标设备保留自己的云端登录与模型，并建立本机路由。先完成本文件的盘点与隔离测试，再切换全局 provider。以下 `$CodexHome`、`$RouterDir`、`$CodexExe` 等均为执行者在目标机核实后设置的变量。

## 1. 只读盘点

```powershell
Get-AppxPackage -Name OpenAI.Codex | Select-Object Version, PackageFamilyName, InstallLocation
Get-Command node, git, python -ErrorAction SilentlyContinue
Get-NetTCPConnection -State Listen | Where-Object LocalPort -in 7777,18767
Get-ScheduledTask | Where-Object TaskName -like 'Codex*' | Select-Object TaskName,State
```

也可运行仓库的 `scripts/preflight.ps1`。它只做盘点，不读取密钥、不改配置、不拉起模型。目标机允许自定义 CODEX_HOME 时，先确认桌面实际使用的目录；不能仅以当前 shell 的变量推定桌面进程环境。

记录以下结果：

- 操作系统与 GPU、显存、内存，已有模型与服务。
- Codex 桌面版及其实际内置 CLI 引擎版本。不要用 PATH 上另一个 codex 的版本代替。
- 当前生效的云端默认、provider、完整目录来源及可用推理强度。
- Node 路径与版本、系统代理；参考代码的 `https.Agent({proxyEnv: ...})` 在原机 Node 26.10.0 上验证，其他版本需验证兼容性。
- 本地 Responses 地址、真实模型名、认证来源、上下文和输出上限。
- 18767/7777 是否已被其他服务使用。占用时改成其他回环端口，不结束未知进程。

本次整理时原机 Manager 的 `status` 返回控制端点未找到，说明它当时没有运行。这不影响云端路由，也不证明目标机已有可用本地模型。

## 2. 备份与最小变更清单

将目标机的用户级 config.toml、将修改的自有脚本和现存同名计划任务 XML备份到设备私有目录。备份可能含密钥，不能提交本仓库。

auth.json 不做安装修改，不复制到别的设备。仅在本地计算前后哈希以确认安装未改动登录文件，报告写 unchanged 即可。

变更清单应只包含：一个 provider 定义、顶层 provider/默认模型/目录选择、自有路由运行目录、自有任务与快捷方式、本地后端所需的最小请求适配。默认模型保留目标机已有云端默认，不强制改成原机型号。

如果已有同名 provider、相同用途网关、模型目录或任务，先检查其用途并合并，不能直接用 `-Force` 覆盖。不要清空 MCP、插件、apps、skills 或用户权限设置。

## 3. 本地服务前置条件

按 [04](04-LOCAL-RESPONSES.md) 验证真实 `/v1/responses`、SSE、工具循环和认证。只有 Chat Completions 的服务尚未满足要求。先解决本地层问题，再接 Codex。

如果目标设备暂时没有本地硬件/模型，仍可完成文档与云端路由的隔离验证，但安装报告须把本地接入标记为未完成。不要假定下载一个模型名字就能运行原机的完整 256K/视觉/MTP 配方。

## 4. 准备私有运行目录

建议布局：

```text
<实际 CODEX_HOME>/
  config.toml
  local-ninfer/
    models.json
    router/
      gateway.mjs
      supervisor.mjs
      run-background.ps1
      refresh-proxy.ps1
      start-router.ps1
      background-launcher.cs
      build-background-launcher.ps1
      codex-lifecycle.cs
      desktop-launcher.cs
      build-lifecycle.ps1
      launch-codex.ps1
      install-background-task.ps1
      settings.json              本机生成，含本机路由密钥
      catalog-cache.json         从本机云端目录生成
```

复制 `reference/local-ninfer/` 到对应位置。先按 [参考源码适配表](../reference/README.md) 修改部署副本，再运行。特别核对 gateway.mjs 的本地端口、本地认证读取函数、默认云端检查和 client_version，以及 Node路径、AppModel 包标识和进程识别。

用安全随机数在目标机生成 32 字节或更长的路由密钥，写入设备私有 settings.json 和本机 provider配置，不回显、不放命令行参数、不提交。`examples/settings.example.json` 只是字段示例。

参考实现从 OpenCode 的本地 provider 读取模型密钥。没有该文件时必须适配 `localCredential()`；本仓库不会分发原机密钥。网关只允许回环地址，云端上游和本地上游应分别受控，不能让请求体任意指定上游 URL。

## 5. 先添加未选中的 provider

将 `examples/provider.example.toml` 的 provider表合并到用户级配置，替换占位路径、端口和路由密钥。先不修改原来的顶层 model_provider，不让当前工作中的 Codex改走新网关。

参考原机用 `requires_openai_auth=true` 延用本设备自己的 ChatGPT登录，`supports_websockets=false` 使用已验证的 HTTP SSE。路由密钥通过独立头传入。它不是 ChatGPT令牌，也不是本地模型密钥。

原机将路由密钥保存在私有 provider 的 http_headers 中；这也是模板表达的基线。若改用 env_http_headers，应先证明桌面启动进程确实继承变量，不能只在一个 PowerShell窗口里设置变量就宣布桌面已配置。

解析 TOML，验证现有有效字段没有意外归到新 table。provider等敏感路由设置写在用户级配置，不能依赖项目内 `.codex/config.toml` 生效。参见 [官方配置参考](https://learn.chatgpt.com/docs/config-file/config-reference)。

## 6. 隔离启动与目录引导

编译 `build-background-launcher.ps1`，在确认新网关还未承载正式请求时，用 `Start-Process -FilePath <background-launcher.exe> -WindowStyle Hidden -PassThru` 启动待测副本。记录它实际启动的进程，只清理自己启动的副本。

健康检查应返回 service 为 codex-cloud-local-router，并从真实 PID/监听地址确认是本次进程。健康检查不证明模型成功。

按 [05](05-CATALOG.md) 引导完整目录。首次没有本地 catalog时，可在独立 app-server进程使用 provider的 model_catalog_url 获取经认证的官方目录，由网关生成完整缓存。若已有生效的 model_catalog_json，会覆盖远程目录，须在隔离测试配置里显式处理，不得删除用户目录来凑结果。

独立 app-server可读取当前用户配置与自己的登录，只通过进程级 `-c` 覆盖非密钥的 provider、model 等选择。密钥留在本机已添加的 provider表里，避免出现在进程参数。不要照搬原机 verify.py 中固定的 Codex exe路径或私有 provider-test.toml。

对于不支持该引导方式的版本，从对应引擎版本的官方完整目录生成候选目录。两条方法都必须保留全部云端元数据，禁止手写少量模型名代替。首次引导失败时停留在旧云端路由，记录错误再处理。

## 7. 真实请求与最小配置切换

在独立 app-server进程先做 [06](06-VERIFICATION.md) 中的云端、本地、切换、工具与认证隔离检查。测试进程可临时禁用 apps/MCP等无关上下文，但不保存这些禁用值。

通过后，预览并应用以下顶层变更：

```toml
# 位于第一个 table 之前。示例值必须替换为本机实际值。
model = "TARGET_EXISTING_CLOUD_DEFAULT"
model_provider = "cloud-local-router"
model_catalog_json = 'C:\Users\YOUR_USER\.codex\local-ninfer\router\catalog-cache.json'
```

写回前后都解析 TOML，对比配置对象，只允许预期差异。目录路径是实际绝对路径，Codex不会在字符串中展开 `%USERPROFILE%`。不要覆盖整个文件。

目录的云端数量以目标账号为准。保留官方隐藏条目、推理强度、上下文、工具能力等完整元数据；本地声明不能超出目标后端能力。

## 8. 安装无窗口与应用生命周期

参考最新版 `install-background-task.ps1` 会编译启动器和生命周期组件，并注册两个当前用户普通权限任务：

- Codex Cloud Local Router：按需任务，无登录或分钟触发。
- Codex Router App Lifecycle：监听本机 Codex 的 AppModel激活事件，在桌面应用运行时管理路由任务。

注册前核对同名任务、备份原定义。核对本机是否有 `Microsoft-Windows-AppModel-Runtime/Admin` 日志、事件201，以及真实 ApplicationName。未打包的安装方式或包名不同时不能直接使用原订阅。

去掉本方案早期自己的 Startup快捷方式与旧登录/分钟触发。不要删掉别的软件的启动项。首次安装时若 Codex已经运行，事件不会自动重放；可启动生命周期任务，或在空闲窗口通过新启动器重新打开桌面应用。

桌面快捷方式指向编译的 desktop-launcher.exe，它先确认网关就绪再激活 Codex。开始菜单、任务栏等入口依赖真实 AppModel事件，目标机必须另验。不要把仅启动脚本的测试当作所有入口都已验证。

`CreateNoWindow=true` 与 GUI子系统入口用于避免初始控制台。单独给 PowerShell加 `-WindowStyle Hidden` 在原机没有解决 Terminal弹窗。

## 9. 重开桌面并交付

等活动推理完成后再重开 Codex。核对菜单确实显示云端与本地模型、默认仍是云端、GPT推理强度存在。本地服务可关闭；关闭时选择本地应明确报错，不能降级成云端。

运行临时任务生命周期检查，随后在用户选定的空闲时段测试正式退出与重开，确认最后一个应用进程退出后的停止行为及无弹窗。不要用关闭一个窗口代替退出全部应用进程。

填写 [安装报告模板](../examples/installation-report.md)。报告放目标机 `reports/`，不默认上传运行配置与日志。仓库源码验证或原机记录不能代替此报告。
