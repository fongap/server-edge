# public-edge

唯一公网入口能力域，负责域名、TLS 与反向代理。当前可由 Caddy 实现。

本目录是可插拔能力域。新增具体实现时应优先放在本模块内部，不提升为新的一级目录。

如需生命周期钩子，可按需增加：

`install/validate.sh`、`install/install.sh`、`install/patch.sh`、`install/backup.sh`、`install/healthcheck.sh`、`install/rollback.sh`。
