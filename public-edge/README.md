# Public Edge

唯一公网入口能力域，负责域名、TLS 与反向代理。业务模块不直接拥有公网 80/443，也不把域名写进跨模块服务契约。

## 发布模型

业务模块只声明内部服务，例如：

```text
/opt/server-edge/runtime/contracts/proxy-subscription.json
```

契约包含稳定服务信息：

- `producer`；
- `service`；
- `publication_key`；
- Docker Network；
- 内部 upstream。

域名由平台级发布注册表单独决定：

```text
/opt/server-edge/config/publications.json
```

例如：

```json
{
  "schema_version": 1,
  "services": {
    "proxy-subscription": {"origin": "https://sub.example.com"},
    "ai-gateway": {"origin": "https://api.example.com"}
  }
}
```

因此域名修改不需要修改 Proxy Hub、AI Gateway 或其他业务模块配置。

## 实例配置

Public Edge 自身只保存部署参数，不保存公网域名：

```text
public-edge/config/defaults.env
        ↓
/opt/server-edge/config/public-edge.env
```

当前实例参数：

```text
SERVER_EDGE_PUBLIC_BIND_IP=0.0.0.0
```

`80/tcp`、`443/tcp`、`443/udp` 是 Public Edge 的平台入口契约，不作为普通实例端口参数。需要限制监听接口时，只修改 `SERVER_EDGE_PUBLIC_BIND_IP`。

## 当前最小实现

当前只实现 `proxy-subscription` 的最小公网路由，使用 Caddy `2.11.4-alpine`。

未配置 `proxy-subscription` Origin：

```text
Caddy = 不运行
80/443 = 不占用
```

配置：

```json
"proxy-subscription": {"origin": "https://sub.example.com"}
```

则：

```text
Internet
   │ 80/443
   ▼
Public Edge / Caddy
   │ edge_service_proxy_public
   ▼
proxy-feed:8080
```

安装前会检查 80/443 的宿主绑定。如果旧 Caddy、Nginx、Docker 容器或其他进程仍占用目标地址，安装会在启动 Caddy 前明确失败，不会覆盖旧服务。

## 边界

- 只有 Public Edge 发布公网 `80/443`；
- Public Edge 不读取其他模块 `.env`、`state/` 或 `secrets/`；
- 只消费运行契约与平台发布注册表；
- Token、Password、Private URL 不进入跨模块契约；
- Caddy 不挂载 Docker Socket，不使用 `privileged` 或 host network；
- `edge_service_proxy_public` 继续保持 internal；Caddy 通过独立 outbound bridge 获取证书和访问外网。

## 外部前置

公网域名真正可用仍需要：DNS 指向当前公网地址，云安全组/防火墙允许 80/443，且端口未被其他服务占用。

安装器不会修改 DNS 或云厂商防火墙规则。
