# Proxy Hub

统一节点聚合、订阅分发与可选显式出口能力域。M2 使用单个 Mihomo 核心，不启用 TUN，不劫持宿主流量。

## 核心不变量

启用 `proxy-hub` 时必须至少配置一个 Provider；节点聚合不是可选模式。

```text
Provider(s) ──┐
              ├── AUTO / FALLBACK / PROXY ── Subscription Feed
LOCAL 可选 ───┘
                         │
                         └── Unified Egress 可选
```

`LOCAL` 表示当前 Server Edge 宿主自身出口。部署在 Oracle Compute 时就是 Oracle 节点，但代码不感知 Oracle。

## 配置

默认模板：

```text
proxy-hub/config/defaults.env
```

实例覆盖：

```text
/opt/server-edge/config/proxy-hub.env
```

加载顺序：Release 默认值 → 实例覆盖。升级可以新增默认参数，但不得覆盖已有实例值。

Proxy Hub 自己只管理节点、出口、端口、绑定与健康参数：

```text
LOCAL_NODE_ENABLED
LOCAL_NODE_PUBLISH
LOCAL_NODE_ADVERTISE_HOST
EGRESS_ENABLED
EGRESS_POLICY
FEED_BIND
CONTROLLER_BIND
LOCAL_NODE_BIND
EGRESS_BIND
EGRESS_PORT
LOCAL_NODE_PORT
FEED_PORT
CONTROLLER_PORT
PROVIDER_INTERVAL
HEALTH_URL
HEALTH_INTERVAL
PROBE_INTERVAL
HEALTH_TIMEOUT
AUTO_TOLERANCE
```

公网域名不属于 Proxy Hub 模块配置。

## Provider

Provider 至少一个：

```text
/opt/server-edge/secrets/proxy-hub/providers/*.url
```

每个文件只保存一个 HTTPS URL，Owner 为 `root`，权限为 `0600` 或 `0400`。

聚合层始终生成：

```text
AUTO
FALLBACK
PROXY
```

上游真实订阅 URL 不写进客户端 Feed。

## LOCAL 节点

LOCAL 是否运行、是否写入订阅、公布什么地址分别独立配置：

```text
SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED
SERVER_EDGE_PROXY_LOCAL_NODE_PUBLISH
SERVER_EDGE_PROXY_LOCAL_NODE_ADVERTISE_HOST
```

LOCAL 固定从当前宿主直接出网，不跟随统一出口策略。

## 可选统一出口

```text
SERVER_EDGE_PROXY_EGRESS_ENABLED=true|false
SERVER_EDGE_PROXY_EGRESS_POLICY=auto|fallback|select
```

关闭统一出口不会关闭 Provider 聚合、Feed 或 LOCAL 节点。

实际跨模块出口端点写入：

```text
/opt/server-edge/runtime/contracts/proxy-egress.json
```

AI Gateway、AI Workers、App Hub 等消费者不得硬编码 `7890`。

## 订阅 Feed

首次安装生成 root-only Token：

```text
/opt/server-edge/secrets/proxy-hub/subscription-token
```

默认 Tailnet Feed 由 `FEED_BIND` 与 `FEED_PORT` 决定。

如需公网域名，不修改 `proxy-hub.env`，而是在平台发布注册表配置：

```text
/opt/server-edge/config/publications.json
```

例如：

```json
{
  "schema_version": 1,
  "services": {
    "proxy-subscription": {"origin": "https://sub.example.com"}
  }
}
```

Proxy Hub 只写出内部服务契约：

```text
/opt/server-edge/runtime/contracts/proxy-subscription.json
```

该契约只声明 `publication_key=proxy-subscription`、内部网络和 upstream，不携带域名。Public Edge 根据平台发布注册表决定是否创建公网路由。

## 默认端口

```text
7890  可选统一出口
7891  可选 LOCAL SOCKS5
8780  Subscription Feed
9090  Controller
```

四个端口都可通过实例配置调整。Controller 默认只绑定 Tailnet，不发布公网。

安装器在启动容器前检查实际宿主绑定。当前 `server-edge-proxy-hub` 自己占用的绑定允许幂等重装；若同一 IP/端口被其他 Docker 容器或宿主进程占用，则在 `docker compose up` 前明确拒绝，并提示修改对应实例端口或清理旧服务。

## 数据边界

```text
配置    /opt/server-edge/config/proxy-hub.env
Secret  /opt/server-edge/secrets/proxy-hub/
状态    /opt/server-edge/state/proxy-hub/
契约    /opt/server-edge/runtime/contracts/
```

不得混放。

## 运维

```bash
sudo /opt/server-edge/current/proxy-hub/install/healthcheck.sh
sudo /opt/server-edge/current/proxy-hub/scripts/show-endpoints.sh
```
