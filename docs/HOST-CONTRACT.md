# Server Edge Host Contract

## 1. 目的

Host Contract 定义 Server Edge 对 Linux 宿主的最小能力要求。它只回答“这台主机是否具备部署条件”，不定义业务模块行为，也不把云厂商、发行版或硬件型号变成架构身份。

Server Edge 可部署在满足契约的云主机、VPS、本地服务器、Mini PC 和 Bare Metal。

## 2. 最小能力

### 操作系统与文件系统

宿主必须具备：

- Linux；
- 常规 POSIX 文件权限；
- 持久文件系统；
- 符号链接；
- 可持久保存 Server Edge 实例目录。

默认根目录：

```text
/opt/server-edge
```

安装器可通过 `--root` 覆盖。目标目录必须能够持久保存 `config/`、`secrets/`、`state/`、`runtime/`、`backups/` 和 `releases/`。

### CPU

当前优先支持与验证：

```text
amd64 / x86_64
arm64 / aarch64
```

其他 CPU 架构只有在所有必需 Runtime 和组件均可用时才可能进入 `Compatible` 路径。

### 权限

安装阶段必须以 root 运行，或由调用方使用 sudo 提升到 root。

这不意味着业务容器默认获得宿主 root、privileged 或 host namespace 权限。

### Bootstrap 前置

从 GitHub 拉取并展开 Release 前，宿主至少需要：

```text
curl
tar
```

Host Bootstrap 完成后至少需要：

```text
bash
curl
tar
ca-certificates
jq
```

正式 Host Adapter 可以补齐缺失基础工具。

### 容器 Runtime

当前 Runtime Contract 固定为：

```text
Docker Engine
Docker Compose v2
```

必须满足：

- Docker daemon 可用；
- `docker compose` 可用；
- 可以创建和复用 Docker bridge network；
- 可以持久运行 Server Edge 管理的容器。

当前不把 Podman、Kubernetes 或其他 Runtime 视为等价实现。

### 网络

宿主至少需要：

- DNS；
- 出站 HTTPS；
- Docker bridge network 能力。

公网 IP 不是 Server Edge 的强制前置。只有启用公网发布时，才需要额外满足 DNS、路由和防火墙等外部条件。

## 3. Overlay

Overlay Network 是推荐的管理能力，不是所有部署的绝对前置。

当前实现为 Tailscale，归属：

```text
infra/network/overlay
```

支持模式：

```text
auto       默认；允许未连接状态继续完成基础 Infra
off        不启用 Overlay
required   必须安装并处于可用连接状态
```

Overlay 用于 SSH、私有管理、节点互联和故障恢复，不属于 Proxy Hub 的业务代理出口。

## 4. Host Facts

`infra/host/detect.sh` 负责输出统一宿主事实，包括：

```text
SERVER_EDGE_HOST_OS
SERVER_EDGE_HOST_ARCH
SERVER_EDGE_HOST_ID
SERVER_EDGE_HOST_VERSION
SERVER_EDGE_HOST_CODENAME
SERVER_EDGE_HOST_PACKAGE_MANAGER
SERVER_EDGE_HOST_SERVICE_MANAGER
SERVER_EDGE_HOST_ENVIRONMENT
SERVER_EDGE_HOST_DOCKER
SERVER_EDGE_HOST_COMPOSE
SERVER_EDGE_HOST_TAILSCALE
```

无法可靠识别的字段必须显式为 `unknown`，不得猜测。

`SERVER_EDGE_HOST_ENVIRONMENT` 只允许：

```text
cloud
local
unknown
```

该字段不能决定一级目录、Profile 或业务模块实现。

## 5. Host Adapter

Host Adapter 只负责补齐或适配宿主能力，不承载业务模块逻辑。

当前正式自动安装路径为：

```text
Ubuntu / Debian
+ apt-get
+ systemd
```

当前 Adapter 可以补齐基础工具、Docker Engine + Compose v2 和 Tailscale。

如果发行版未被自动安装器识别，但宿主已经满足 Host Contract，则不得仅因为发行版名称未知而拒绝部署；应进入 `Compatible` 路径继续能力验证。

如果宿主已经存在 Docker 但缺少 Compose v2，安装器默认不得自动替换既有 Runtime。检测到可能冲突的容器软件包时，也应停止并要求显式处理，避免破坏已有工作负载。

## 6. 支持等级

支持等级固定为：

- `Verified`：按当前验收标准完成 CI 或真实宿主验证；
- `Supported`：存在正式 Host Adapter，并处于维护范围；
- `Compatible`：满足 Host Contract，但未完成完整验证或不存在专用 Adapter；
- `Unsupported`：缺少必要能力。

不得把 `Compatible` 宣称为 `Supported` 或 `Verified`。

### 当前 Verified Target

| 环境 | 系统 | 架构 | Package | Service | Runtime | Overlay |
| --- | --- | --- | --- | --- | --- | --- |
| Oracle Cloud | Ubuntu 24.04 Noble | arm64 | apt-get | systemd | Docker Engine + Compose v2 | Tailscale |

该目标已经完成当前阶段的首次 bootstrap、重复 bootstrap、Host Contract、Infra healthcheck、受管 `edge_*` 网络、Tailscale 连接及 Shell 可执行位恢复验证。

后续新增 Verified Target 时，应采用相同或更严格的验收标准，而不是仅凭“理论兼容”升级支持等级。

## 7. 幂等与安全要求

Host Adapter 必须：

- 已满足依赖时优先复用；
- 重复执行不得删除实例 `state/`、`secrets/` 或无关工作负载；
- 失败时不得主动卸载或覆盖既有容器 Runtime；
- 不在业务模块中散布发行版判断；
- 不因扩大兼容范围顺带引入第二 Runtime。

## 8. 非目标

Host Contract 当前不负责：

- 自动适配所有 Linux 发行版；
- 自动修改云厂商 Security List / NSG；
- 自动配置家庭路由 NAT；
- 自动建立公网 IP；
- 替代业务模块自身健康检查；
- 保证尚未实现的能力模块可用。

机器可读宿主契约位于 `manifests/host-contract.json`。本文件负责语义说明，安装器与 CI 应以机器契约和实际能力检查为准。