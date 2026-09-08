# Public Edge

唯一公网入口能力域，负责域名、TLS 与反向代理。M2 只实现 Proxy Hub 订阅 Feed 的最小公网路由，当前使用官方 Caddy `2.11.4-alpine`；这不是完整 Public Edge 功能扩展。

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

订阅 Token 不进入契约。Public Edge 只消费这个最小契约，不读取 `proxy-hub` 的 `state/`、`secrets/` 或内部文件布局。

## 启停语义

当 `public_origin` 为空：

```text
Public Edge subscription route = inactive
Caddy = 不运行
80/443 = 不占用
```

当 `public_origin=https://sub.example.com`：

```text
Internet
   │ 80/443
   ▼
Caddy
   │ edge_service_proxy_public
   ▼
proxy-feed:8080
```

Caddy 自动处理 HTTPS/TLS，并将该域名全部请求反代到 Proxy Hub Feed。关闭自定义 Origin 后再次安装/patch，会停止受管 Caddy 容器并释放 80/443。

## 前置条件

公网域名真正可用还需要宿主外部条件：

1. 域名 A/AAAA 解析到当前 Server Edge 公网地址；
2. 云安全组/NSG、Security List 或本地防火墙允许 TCP 80/443；
3. 如使用 HTTP/3，可同时允许 UDP 443；
4. 80/443 未被其他非 Public Edge 服务占用。

安装器不会修改 DNS 或云厂商防火墙规则，也不会因为 ACME 尚未签发证书就改变模块边界。

## 安全边界

- 只有 Public Edge 发布公网 `80/443`；
- Caddy 不挂载 Docker Socket；
- 不使用 `privileged` 或 host network；
- 只加入 `edge_service_proxy_public` 与自身 outbound bridge；
- Proxy Hub 的订阅 Token 只存在 URL 路径中，不进入跨模块契约；
- Caddy 的 `/data`、`/config` 持久化到 `state/public-edge`，可由 Caddy重新获取证书与恢复运行。

## 生命周期

健康检查：

```bash
sudo /opt/server-edge/current/public-edge/install/healthcheck.sh
```

Patch：

```text
public-edge/install/patch.sh -> public-edge/install/install.sh
```

健康检查在 inactive 模式确认没有受管 Caddy 容器；active 模式验证 Caddy 运行、配置有效、80/443 已发布，并验证 `proxy-feed:8080` 在内部网络可达。它不会把公网 DNS/ACME 是否已经完成误判成代码安装失败。
