# Proxy Hub

统一代理聚合与显式出站能力域。M2 当前实现使用单个 Mihomo 核心，不引入第二代理核心、Sub-Store 或常驻 Dashboard。

## 当前实现

- Mihomo `v1.19.30`；
- 多订阅通过 `proxy-providers` 聚合；
- Provider 健康检查；
- `AUTO` 自动选优；
- `FALLBACK` 故障切换；
- `PROXY` 为默认出口策略，`DIRECT` 只允许人工选择；
- HTTP/SOCKS Mixed Port：`7890`；
- Controller：`9090`；
- 不启用 TUN，不劫持宿主流量；
- 容器不使用 `privileged`、`host network` 或 Docker Socket。

## Secret

每个订阅单独保存为 root-only 文件：

```text
/opt/server-edge/secrets/proxy-hub/providers/
├── primary.url
└── backup.url
```

文件内容只放一个 HTTPS 订阅 URL，权限必须为 `0600` 或 `0400`，Owner 必须为 `root`。

示例：

```bash
sudo mkdir -p /opt/server-edge/secrets/proxy-hub/providers
sudo sh -c 'printf "%s\n" "https://example.com/subscription" > /opt/server-edge/secrets/proxy-hub/providers/primary.url'
sudo chmod 600 /opt/server-edge/secrets/proxy-hub/providers/primary.url
```

Controller Secret 首次安装时自动生成：

```text
/opt/server-edge/secrets/proxy-hub/controller-secret
```

## 网络

容器加入：

```text
edge_egress_ai
edge_egress_workers
proxy-hub private outbound network
```

跨模块客户端通过 `proxy-hub:7890` 使用显式 HTTP/SOCKS 代理；宿主机仅在 `127.0.0.1:7890` 提供本地代理入口。

Controller 的宿主端口优先只绑定当前 Tailscale IPv4；没有已连接的 Tailscale 时退回 `127.0.0.1:9090`。Controller 始终需要 Secret。

## 生命周期

```bash
sudo /opt/server-edge/current/proxy-hub/install/healthcheck.sh
```

Patch 复用同一安装逻辑；状态备份只备份 `state/proxy-hub`，不会复制 Provider URL 或 Controller Secret。
