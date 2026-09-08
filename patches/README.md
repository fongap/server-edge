# Patches

Patch 是 Release 到 Release 的显式兼容路径，不是 `git pull`。

目标 Release 在 `patches/index.json` 中声明可接受的来源版本。例如：

```json
{
  "from": "0.1.0",
  "to": "0.2.0",
  "modules": ["proxy-hub", "ai-gateway"],
  "backup_required": true,
  "reversible": true
}
```

发生模块状态迁移时，对应模块应提供 `install/backup.sh`、`install/patch.sh` 和必要的 `install/rollback.sh`。
