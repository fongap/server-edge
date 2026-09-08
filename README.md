# Server Edge

Server Edge 是面向云主机与本地 Linux 主机的模块化边缘服务平台。它不绑定 Oracle、Ubuntu 或某一类物理设备；宿主差异统一由 `infra/host` 处理。

```text
server-edge/
├── infra/
├── app-hub/
├── proxy-hub/
├── ai-gateway/
├── ai-workers/
└── public-edge/
```

能力名稳定，具体实现可替换。

## 平台原则

Server Edge 不只要求模块可插拔，也要求部署参数解耦。

```text
能力结构      固定
实例参数      可配置
域名发布      平台统一配置
Secret        独立保存
跨模块端点    运行契约发现
```

统一实例布局：

```text
/opt/server-edge/
├── config/
│   ├── publications.json
│   └── <module>.env
├── secrets/
├── state/
├── runtime/
│   └── contracts/
└── releases/
```

模块默认值位于 `<module>/config/defaults.env`，首次安装初始化实例配置；升级不会覆盖已有实例值。

域名统一配置在：

```text
/opt/server-edge/config/publications.json
```

例如：

```json
{
  "schema_version": 1,
  "services": {
    "proxy-subscription": {"origin": "https://sub.example.com"},
    "ai-gateway": {"origin": "https://api.example.com"},
    "app-main": {"origin": "https://app.example.com"}
  }
}
```

业务模块不直接拥有公网域名。Public Edge 根据稳定 `publication_key` 和平台发布注册表统一处理域名、TLS 与反向代理。

跨模块端口也不得硬编码。模块通过：

```text
/opt/server-edge/runtime/contracts/
```

发布实际运行端点，消费者只读契约。

详细规则见 `docs/CONFIGURATION.md` 和 `manifests/configuration.json`。

## 部署目标

Server Edge 面向满足 Host Contract 的 Linux 主机，包括云主机与本地 Linux 主机。

支持等级：

- `Verified`：完成 CI 或实机验证；
- `Supported`：存在正式 Host Adapter；
- `Compatible`：满足 Host Contract，但尚未完整验证；
- `Unsupported`：缺少必要能力。

首个 Verified Target：

```text
Oracle Cloud
Ubuntu 24.04 Noble
arm64
Docker Engine + Compose v2
Tailscale connected
```

## M1 Portable Linux Infra

M1 已完成：Host Detect、Host Contract、apt/systemd Adapter、Docker、Tailscale、`edge_*` 网络、健康检查、Release 权限恢复、CI 与重复安装验证。

## M2 Proxy Hub

M2 使用 Mihomo `v1.19.30`。

节点聚合是必需能力：至少一个 Provider。

```text
Provider(s) ──┐
              ├── AUTO / FALLBACK / PROXY ── Subscription Feed
LOCAL 可选 ───┘
                         │
                         └── Unified Egress 可选
```

Proxy Hub 自己只管理节点、出口、端口、绑定与健康参数：

```text
/opt/server-edge/config/proxy-hub.env
```

公网订阅域名不放在 Proxy Hub 配置里，而放在平台发布注册表：

```text
/opt/server-edge/config/publications.json
```

Provider Secret：

```text
/opt/server-edge/secrets/proxy-hub/providers/*.url
```

统一出口端点写入：

```text
/opt/server-edge/runtime/contracts/proxy-egress.json
```

订阅内部服务写入：

```text
/opt/server-edge/runtime/contracts/proxy-subscription.json
```

因此 LOCAL 节点、统一出口、Feed、域名、端口和绑定方式彼此独立。

## 文档

- `docs/ARCHITECTURE.md`：架构蓝图；
- `docs/GOVERNANCE.md`：治理约束；
- `docs/HOST-CONTRACT.md`：宿主能力契约；
- `docs/CONFIGURATION.md`：平台配置模型；
- `proxy-hub/README.md`：Proxy Hub；
- `public-edge/README.md`：Public Edge；
- `manifests/`：机器可读契约。

## GitHub 安装

生产安装锁定 Tag、Release 或 Commit SHA：

```bash
curl -fsSL \
  https://raw.githubusercontent.com/fongap/server-edge/<REF>/install/bootstrap.sh \
  | sudo bash -s -- --repo fongap/server-edge --ref <REF>
```

默认根目录：`/opt/server-edge`。

## Patch

```bash
sudo /opt/server-edge/current/install/patch.sh --ref <TARGET_REF>
```

## 回滚

```bash
sudo /opt/server-edge/current/install/rollback.sh --to <RELEASE_ID>
```
