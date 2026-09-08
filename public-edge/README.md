# Public Edge

唯一公网入口能力域，负责域名、TLS 与反向代理。当前可由 Caddy 实现。

本目录是可插拔能力域。新增具体实现时应优先放在本模块内部，不提升为新的一级目录。

## Proxy Hub 订阅入口契约

`proxy-hub` 自己不监听公网 `80/443`。当用户为订阅 Feed 配置自定义 HTTPS Origin 时，Proxy Hub 写出运行期契约：

```text
/opt/server-edge/runtime/contracts/proxy-subscription.json
```

契约只包含：

- 服务生产者：`proxy-hub`；
- Docker Network：`edge_service_proxy_public`；
- 内部上游：`http://proxy-feed:8080`；
- 可选 `public_origin`。

订阅 Token 不进入该契约。Public Edge 后续实现必须只消费契约，不读取 `proxy-hub` 的 `state/`、`secrets/` 或内部文件布局。

当 `public_origin` 为空时，不创建公网路由；当存在 HTTPS Origin 时，Public Edge 才负责域名、TLS 和反向代理。

如需生命周期钩子，可按需增加：

`install/validate.sh`、`install/install.sh`、`install/patch.sh`、`install/backup.sh`、`install/healthcheck.sh`、`install/rollback.sh`。
