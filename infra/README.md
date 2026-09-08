# Infra

负责 Server Edge 的初始化和管理底座：Host Adapter、容器运行时、网络、Overlay、存储、安全和基础恢复能力。

`infra` 是 Provisioning 前置，但不是运行期中央编排器。

## 配置

仓库默认值：

```text
infra/config/defaults.env
```

实例覆盖：

```text
/opt/server-edge/config/infra.env
```

加载顺序固定为：

```text
Release defaults
      ↓
Instance overrides
```

因此升级可以增加新默认参数，但不得覆盖已有实例值。

当前 M1 可配置项：

```text
SERVER_EDGE_INFRA_OVERLAY=auto|off|required
SERVER_EDGE_INFRA_TAILSCALE_HOSTNAME=auto|<hostname>
SERVER_EDGE_INFRA_TAILSCALE_ACCEPT_DNS=true|false
```

Tailscale Auth Key 仍是 Secret：

```text
/opt/server-edge/secrets/infra/tailscale-auth-key
```

不得放入 `infra.env`。
