# Proxy Hub

统一代理聚合、订阅分发与可选显式出站能力域。M2 使用单个 Mihomo 核心，不启用 TUN，不劫持宿主流量。

## 组成

- Mihomo `v1.19.30`：Provider、健康检查、AUTO/FALLBACK、统一出口、本机节点；
- BusyBox `httpd`：只读订阅 Feed；
- 不引入第二代理核心；
- 当前不引入完整 Sub-Store，后续只有出现多格式转换、可视化订阅管理等明确需求时再评估。

## 出口模式

持久配置：

```text
/opt/server-edge/config/proxy-hub.env
```

支持：

```text
SERVER_EDGE_PROXY_EGRESS=off
SERVER_EDGE_PROXY_EGRESS=local
SERVER_EDGE_PROXY_EGRESS=provider
SERVER_EDGE_PROXY_EGRESS=hybrid
```

含义：

| 模式 | Server Edge 统一出口 | 本机节点 | 外部 Provider |
| --- | --- | --- | --- |
| `off` | 关闭 | 不提供 | 可用于订阅分发 |
| `local` | 本机直出 | 提供 | 可用于订阅分发 |
| `provider` | 外部节点 | 不提供 | 必须至少一个 |
| `hybrid` | 本机 + 外部 | 提供 | 必须至少一个 |

默认是 `local`。

`LOCAL` 只表示当前宿主自身公网出口，不代表 Oracle。部署在当前 Oracle Compute 上时 `LOCAL` 就是 Oracle 出口；换到其他 Linux 主机时仍是同一契约。

## 端口

```text
7890  Host/Container 统一显式出口，仅 egress != off
7891  LOCAL 专用 SOCKS5 节点，仅 local/hybrid
8780  订阅 Feed
9090  Mihomo Controller
```

`7891` 与 `7890` 分离。LOCAL 节点固定 `proxy: LOCAL`，不会因为统一出口选择了外部 Provider 而改变自身出口。

Host `7890` 只绑定 `127.0.0.1`。`7891`、`8780`、`9090` 优先只绑定 Tailscale IPv4；没有已连接 Tailnet 时退回 `127.0.0.1`。

跨模块容器通过：

```text
http://proxy-hub:7890
```

使用统一出口。

## Provider

Provider 是可选订阅源：

```text
/opt/server-edge/secrets/proxy-hub/providers/
├── primary.url
└── backup.url
```

每个文件只放一个 HTTPS URL，Owner 必须为 `root`，权限为 `0600` 或 `0400`。

Provider URL 不会写进对外订阅配置。Mihomo 将 Provider 缓存在 Proxy Hub 自己的状态目录，Feed 只暴露缓存后的 Provider 文件。

当 Server Edge 使用 `provider/hybrid` 出站时提供：

```text
AUTO      url-test 自动选优
FALLBACK  fallback 故障切换
PROXY     统一选择入口
```

订阅客户端同样得到 `AUTO/FALLBACK`。

## 订阅 Feed

首次安装自动生成 48 位订阅 Token：

```text
/opt/server-edge/secrets/proxy-hub/subscription-token
```

完整 URL 采用不可猜测 Token 路径：

```text
<BASE>/<TOKEN>/mihomo.yaml
```

不要在普通日志中打印 Token。需要查看完整地址时显式执行：

```bash
sudo /opt/server-edge/current/proxy-hub/scripts/show-endpoints.sh
```

默认 `BASE=auto`：

```text
http://<TAILSCALE_IP>:8780
```

因此默认订阅只在 Tailnet 可达。

### 自定义域名

编辑：

```text
/opt/server-edge/config/proxy-hub.env
```

例如：

```text
SERVER_EDGE_PROXY_EGRESS=local
SERVER_EDGE_PROXY_SUBSCRIPTION_BASE_URL=https://sub.example.com
```

只允许 HTTPS Origin，不带路径。

Proxy Hub 不抢占公网 `80/443`。配置自定义 Origin 后会写出：

```text
/opt/server-edge/runtime/contracts/proxy-subscription.json
```

内部服务固定为：

```text
network:  edge_service_proxy_public
upstream: http://proxy-feed:8080
```

后续由 `public-edge` 消费该契约并负责 DNS 对应域名的 TLS/反向代理。订阅 Token 不进入跨模块契约。

## Feed 内容

- `local/hybrid`：Feed 中包含当前宿主的 `LOCAL` SOCKS5 节点；
- 存在 Provider：Feed 通过 Server Edge 自己的缓存地址暴露 Provider；
- `off`：关闭 Server Edge 作为统一出口，但 Provider Feed 仍可工作；
- `off` 且没有 Provider：Feed 仍存在，但没有代理节点。

## Secret

除 Provider URL 外，首次安装还自动生成：

```text
/opt/server-edge/secrets/proxy-hub/controller-secret
/opt/server-edge/secrets/proxy-hub/subscription-token
```

均为 root-only，不进入 Git、普通配置或安装日志。

## 网络

```text
edge_egress_ai
edge_egress_workers
edge_service_proxy_public
proxy-hub private outbound bridge
```

- `edge_egress_*`：AI 模块访问统一代理出口；
- `edge_service_proxy_public`：Public Edge 访问订阅 Feed；
- `outbound`：Proxy Hub 自己访问互联网。

## 生命周期

健康检查：

```bash
sudo /opt/server-edge/current/proxy-hub/install/healthcheck.sh
```

查看端点：

```bash
sudo /opt/server-edge/current/proxy-hub/scripts/show-endpoints.sh
```

健康检查按当前模式分别验证 Feed、Controller、Provider 缓存、统一出口和 LOCAL 节点，不把“容器在跑”当作服务健康。
