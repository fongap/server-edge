# Proxy Hub

统一节点聚合、订阅分发与可选显式出口能力域。M2 使用单个 Mihomo 核心，不启用 TUN，不劫持宿主流量。

## 核心不变量

节点聚合是 Proxy Hub 的必需能力，不是可选模式。启用 `proxy-hub` 时必须至少配置一个 Provider；没有 Provider 时安装拒绝继续。

```text
Provider(s) ──┐
              ├── AUTO / FALLBACK / PROXY ── Subscription Feed
LOCAL 可选 ───┘
                         │
                         └── Unified Egress 可选
```

`LOCAL` 表示当前 Server Edge 宿主自身的公网出口。部署在 Oracle Compute 时它就是 Oracle 节点，但代码不感知 Oracle。

## 配置模型

仓库唯一默认值源：

```text
proxy-hub/config/defaults.env
```

首次安装只复制一次到：

```text
/opt/server-edge/config/proxy-hub.env
```

后续升级不会覆盖宿主配置。

节点、出口、发布、端口和健康参数互相独立：

```text
# 节点
SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED=true|false
SERVER_EDGE_PROXY_LOCAL_NODE_PUBLISH=true|false
SERVER_EDGE_PROXY_LOCAL_NODE_ADVERTISE_HOST=auto|<host>

# 出口
SERVER_EDGE_PROXY_EGRESS_ENABLED=true|false
SERVER_EDGE_PROXY_EGRESS_POLICY=auto|fallback|select

# 订阅
SERVER_EDGE_PROXY_SUBSCRIPTION_ORIGIN=auto|https://sub.example.com
SERVER_EDGE_PROXY_FEED_BIND=tailnet|loopback

# 暴露
SERVER_EDGE_PROXY_CONTROLLER_BIND=tailnet|loopback
SERVER_EDGE_PROXY_LOCAL_NODE_BIND=tailnet|loopback
SERVER_EDGE_PROXY_EGRESS_BIND=tailnet|loopback

# 端口
SERVER_EDGE_PROXY_EGRESS_PORT=7890
SERVER_EDGE_PROXY_LOCAL_NODE_PORT=7891
SERVER_EDGE_PROXY_FEED_PORT=8780
SERVER_EDGE_PROXY_CONTROLLER_PORT=9090

# Provider / 健康检查
SERVER_EDGE_PROXY_PROVIDER_INTERVAL=21600
SERVER_EDGE_PROXY_HEALTH_URL=https://cp.cloudflare.com
SERVER_EDGE_PROXY_HEALTH_INTERVAL=600
SERVER_EDGE_PROXY_PROBE_INTERVAL=300
SERVER_EDGE_PROXY_HEALTH_TIMEOUT=5000
SERVER_EDGE_PROXY_AUTO_TOLERANCE=100
```

`SUBSCRIPTION_ORIGIN` 只决定客户端订阅 URL；`LOCAL_NODE_ADVERTISE_HOST` 只决定订阅中 LOCAL 节点公布的地址。两者没有隐式关联。

## Provider

Provider 必须至少一个：

```text
/opt/server-edge/secrets/proxy-hub/providers/
├── primary.url
└── backup.url
```

每个文件只保存一个 HTTPS URL，Owner 必须为 `root`，权限为 `0600` 或 `0400`。

上游真实 URL 不写进客户端 Feed。Mihomo 将 Provider 缓存到本地状态目录，订阅 Feed 只引用 Server Edge 自己的缓存地址。

聚合层始终生成：

```text
AUTO      url-test 自动选优
FALLBACK  fallback 故障切换
PROXY     人工/策略选择入口
```

## LOCAL 节点

`SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED=true` 时启动独立 SOCKS5 节点。默认绑定 Tailnet，并固定从当前宿主直接出网，不跟随统一出口策略。

是否把 LOCAL 写进客户端订阅由 `SERVER_EDGE_PROXY_LOCAL_NODE_PUBLISH` 单独决定。

默认公布地址取实际绑定地址；如需另一个节点域名或地址，只改：

```text
SERVER_EDGE_PROXY_LOCAL_NODE_ADVERTISE_HOST=node.example.com
```

这不会改变订阅域名。

## 可选出口

统一出口与节点聚合完全独立。

```text
SERVER_EDGE_PROXY_EGRESS_ENABLED=false
```

只关闭 Server Edge 的统一显式代理入口，不关闭 Provider 聚合、健康检查、Feed 或 LOCAL 节点。

启用时：

```text
SERVER_EDGE_PROXY_EGRESS_POLICY=auto      # 默认走 AUTO
SERVER_EDGE_PROXY_EGRESS_POLICY=fallback  # 默认走 FALLBACK
SERVER_EDGE_PROXY_EGRESS_POLICY=select    # 走 PROXY，可人工选择
```

跨模块容器使用：

```text
http://proxy-hub:<EGRESS_PORT>
```

## 订阅 Feed

首次安装自动生成 root-only Token：

```text
/opt/server-edge/secrets/proxy-hub/subscription-token
```

订阅格式：

```text
<ORIGIN>/<TOKEN>/mihomo.yaml
```

默认 `ORIGIN=auto`，根据 `FEED_BIND` 和 `FEED_PORT` 生成。例如默认 Tailnet：

```text
http://<TAILSCALE_IP>:8780/<TOKEN>/mihomo.yaml
```

查看完整地址：

```bash
sudo /opt/server-edge/current/proxy-hub/scripts/show-endpoints.sh
```

Token 不进入普通安装日志或跨模块契约。

## 自定义域名

只需配置独立 Origin：

```text
SERVER_EDGE_PROXY_SUBSCRIPTION_ORIGIN=https://sub.example.com
```

Proxy Hub 不占用公网 `80/443`。它通过 `edge_service_proxy_public` 向 `public-edge` 提供内部 Feed，并写出：

```text
/opt/server-edge/runtime/contracts/proxy-subscription.json
```

`public-edge` 只消费这个契约，负责域名、TLS 和反向代理；不会读取 Proxy Hub 的 Secret 或 State。

## 端口职责

默认值：

```text
7890  统一显式出口，可关闭、可改端口
7891  LOCAL 专用 SOCKS5，可关闭、可改端口
8780  Subscription Feed，可改端口
9090  Mihomo Controller，可改端口
80/443  仅 Public Edge 在配置公网 Origin 时使用
```

## Secret 与状态

Secret：

```text
/opt/server-edge/secrets/proxy-hub/providers/*.url
/opt/server-edge/secrets/proxy-hub/controller-secret
/opt/server-edge/secrets/proxy-hub/subscription-token
```

配置：

```text
/opt/server-edge/config/proxy-hub.env
```

状态：

```text
/opt/server-edge/state/proxy-hub/
```

三者不得互相混放。

## 运维

健康检查：

```bash
sudo /opt/server-edge/current/proxy-hub/install/healthcheck.sh
```

端点查看：

```bash
sudo /opt/server-edge/current/proxy-hub/scripts/show-endpoints.sh
```

健康检查验证 Provider 缓存与 Feed；LOCAL 和统一出口只在各自启用时额外验证。
