# 脱敏证据

[origin-summary.json](origin-summary.json) 由原机保存的验收JSON白名单提取，只包含模型ID、状态、测试类型和验证边界。本次整理重新读取这些记录，没有重新运行本地模型或打断网关。

[source-manifest.json](source-manifest.json) 记录本次允许分发源码的相对路径与SHA256，用来核对快照。运行时秘密文件、完整官方模型目录、日志、机器用户名、进程参数和任务XML均未上传。

这些证据属于原机。目标设备必须单独填写报告，不能复制此摘要作为自己的验收结果。
