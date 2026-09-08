# Overlay Network

语义：Server Edge 的私有管理面与节点互联能力。

当前实现使用 Tailscale，但架构只依赖 Overlay 能力，不绑定具体产品。

## 模式

通过 `SERVER_EDGE_OVERLAY` 控制：

- `auto`：默认。支持安装时自动安装；未登录不阻断 Infra 健康检查。
- `off`：关闭 Overlay。
- `required`：必须安装并连接，否则安装/健康检查失败。

## Tailscale

当前 apt + systemd Host Adapter 可在 Ubuntu/Debian 上安装 Tailscale。

认证 Secret 路径：

```text
/opt/server-edge/secrets/infra/tailscale-auth-key
```

存在该文件时安装器使用 `--auth-key=file:` 完成认证，并默认 `--accept-dns=false`，避免 Overlay 接管宿主 DNS。

可通过 `SERVER_EDGE_TAILSCALE_HOSTNAME` 指定节点名；未指定时使用宿主短主机名。

Overlay 只承担 SSH、私有管理、节点互联和故障恢复，不属于 Proxy Hub 的统一代理出口。
