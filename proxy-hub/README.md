# Proxy Hub

统一代理聚合与显式出站能力域。M2 当前实现使用单个 Mihomo 核心，不引入第二代理核心、Sub-Store 或常驻 Dashboard。

## 当前实现

- Mihomo `v1.19.30`；
- `LOCAL` 是始终存在的本机出口节点，`type: direct`；
- 部署在 Oracle Cloud 时，`LOCAL` 即 Oracle 公网出口；
- 外部订阅可选，通过 `proxy-providers` 聚合；
- 有 Provider 时提供 `AUTO` 自动选优与 `FALLBACK` 故障切换；
- `PROXY` 为默认出口策略，默认首先使用 `LOCAL`；
- HTTP/SOCKS Mixed Port：`7890`；
- Controller：`9090`；
- 不启用 TUN，不劫持宿主流量；
- 容器不使用 `privileged`、`host network` 或 Docker Socket。

`proxy-hub` 不判断 Oracle、AWS、本地主机等宿主身份。`LOCAL` 表示“当前 Server Edge 宿主自身的公网出口”，因此同一实现可部署到任意满足 Host Contract 的 Linux 主机。

## LOCAL 节点

M2 不要求先配置外部订阅。首次安装即可只运行：

```text
PROXY
└── LOCAL
```

在当前 Oracle 部署上，流量经 `LOCAL` 时直接从 Oracle Compute 的公网出口发出。

如果 Tailscale 已连接，宿主 Mixed Port 和 Controller 都只绑定当前 Tailscale IPv4，因此 Tailnet 内其他设备可通过：

```text
http://<TAILSCALE_IP>:7890
socks5://<TAILSCALE_IP>:7890
```

把这台 Server Edge 宿主作为代理节点使用。没有已连接的 Tailscale 时，两者都只退回 `127.0.0.1`，不会暴露公网。

跨模块容器继续通过：

```text
proxy-hub:7890
```

访问统一出口，不依赖宿主端口。

## 外部 Provider

外部订阅是可选扩展。每个订阅单独保存为 root-only 文件：

```text
/opt/server-edge/secrets/proxy-hub/providers/
├── primary.url
└── backup.url
```

文件内容只放一个 HTTPS 订阅 URL，权限必须为 `0600` 或 `0400`，Owner 必须为 `root`。

加入 Provider 后，配置自动扩展为：

```text
PROXY
├── LOCAL
├── AUTO
└── FALLBACK
    └── proxy-providers
```

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

`edge_egress_*` 仅提供跨模块访问；Proxy Hub 自己通过独立 outbound bridge 访问互联网。

## 生命周期

```bash
sudo /opt/server-edge/current/proxy-hub/install/healthcheck.sh
```

健康检查同时验证 Controller API 与真实代理出口。Patch 复用同一安装逻辑；状态备份只备份 `state/proxy-hub`，不会复制 Provider URL 或 Controller Secret。
