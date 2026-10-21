# 完整模型目录与离线菜单

## 两个文件不同

`local-ninfer/models.json` 只保存两个本地条目，是合并输入。`router/catalog-cache.json` 是完整云端目录加本地条目，才可作为全局 `model_catalog_json`。

原机曾因目录只包含本地条目而丢失云端模型；启动时依赖在线目录又导致后台未运行时菜单空白。最终做法是启动直接读完整本地文件，推理期间在后台刷新，刷新失败保留已有文件。

## 获取与合并

1. 确认目标机桌面内置引擎版本和自己的可用云端默认。
2. 取得与该引擎匹配的完整官方目录。可用经目标设备自己登录认证的网关 `/models`引导；若配置已有 model_catalog_json，须处理其优先级。也可从匹配版本的官方Codex目录起步，再以目标账号的实际可用性核对。不能用app-server中经过归一化的简略model/list输出冒充完整目录。
3. 保留官方顶层对象、所有模型条目及每个条目的完整元数据，包括隐藏模型。不能只抄模型ID、显示名与context_window。
4. 追加本地条目，保持slug唯一，名称与网关别名完全一致。移除已有同名本地别名后再追加，避免重复。
5. 按当前schema检查本地元数据，特别是supported_reasoning_levels、工具方式、input_modalities、context_window等；不得宣称后端没有的能力。
6. 写入同目录临时文件后原子替换，保留旧缓存直至新文件可解析且校验通过。
7. 在配置前确认文件存在，将实际绝对路径写在TOML第一个table之前。重启客户端重新加载。

仓库提供 [merge-catalog.py](../scripts/merge-catalog.py) 执行保留字段的合并，它不联网、不获取登录令牌。`--cloud`必须指向完整目录而非简略列表，`--default-model`使用目标机已有默认。

```powershell
python .\scripts\merge-catalog.py `
  --cloud <本机完整云端目录.json> `
  --locals <本机local-ninfer\models.json> `
  --output <本机router\catalog-cache.json> `
  --default-model <本机现有云端默认ID>
```

参考gateway也会合并，但其默认云端检查和client_version仍绑定原机，需要适配。目录中的官方模型数量会随版本、账号和时间变化，不能把“9项”作为通用成功条件。

## 离线验收

菜单读取测试要区分两种离线：NInfer未运行时仍有完整菜单，网关未运行时也能由本地文件加载菜单。第二种情况下仍不能推理。生产网关正在被使用时不要为测菜单而停止它，可用不连接网关的隔离目录读取测试或空闲窗口验证。

目标机报告应同时记录菜单条目、默认项、推理强度和实际桌面画面。model/list成功只说明引擎返回的列表，不能替代目视确认桌面菜单。

本地目录是Codex特定schema。原机reference中的models.json适配0.163.0-alpha.10.2；未来版本需要验证字段。官方说明见 [模型目录分发](https://learn.chatgpt.com/docs/enterprise/roll-out-a-gateway)。
