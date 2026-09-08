# Server Edge Host Contract

## 1. 目的

Host Contract 定义 Server Edge 对 Linux 宿主的最小能力要求。它不绑定云厂商、发行版或硬件型号，只判断一台 Host 是否具备部署条件。

Server Edge 可部署在满足契约的云主机、VPS、本地服务器、Mini PC、Bare Metal 和其他兼容 Linux 主机。Oracle Cloud、AWS、Ubuntu、Debian、Home Server 等都只是部署目标。

## 2. 强制能力

### 操作系统

- Linux；
- 常规 POSIX 文件权限；
- 可用的持久文件系统。

### CPU

优先验证：

```text
amd64 / x86_64
arm64 / aarch64
```

其他架构只有在必需运行时已经可用时才进入 Compatible 路径。

### 权限

安装阶段必须以 root 运行，或由调用方使用 sudo 提升到 root。业务容器不得因此默认获得宿主 root 权限。

### Bootstrap 最小前置

从 GitHub bootstrap 时必须预先具备：

```text
curl
tar
```

Host Bootstrap 完成后必须具备：

```text
bash
curl
tar
ca-certificates
jq
```

缺失工具可以由正式 Host Adapter 补齐。

### 容器运行时

当前运行时契约固定为：

```text
Docker Engine
Docker Compose v2
```

必须满足 Docker daemon 可用、`docker compose` 可用，以及 Docker bridge network 可创建和复用。

当前不把 Podman 或 Kubernetes 视为等价运行时。

### 文件系统

默认运行根目录：

```text
/opt/server-edge
```

安装器允许通过 `--root` 覆盖。任何有效根目录都必须支持 POSIX 权限、符号链接、原子切换 `current`，并持久保存 `state/`、`secrets/`、`runtime/` 与 `backups/`。

### 网络

必须具备 DNS、出站 HTTPS 和 Docker bridge network 能力。公网 IP 不是必需条件。

## 3. Overlay

Overlay Network 属于推荐管理能力，不是所有节点的强制前置。当前实现为 Tailscale。

支持三种模式：

```text
auto       默认；可安装但未登录不阻断 Infra
 off       不启用 Overlay
required   必须安装并连接
```

Tailscale 属于 `infra/network/overlay`，用于 SSH、私有管理、节点互联和故障恢复，不属于 Proxy Hub 的代理出口。

## 4. Host Facts

`infra/host/detect.sh` 统一输出：

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

无法可靠识别的字段必须显式表示为 `unknown`，不得猜测。

`SERVER_EDGE_HOST_ENVIRONMENT` 只允许 `cloud | local | unknown`，且不能决定一级目录或业务模块实现。

## 5. M1 Host Adapter

当前正式自动安装路径：

```text
Ubuntu / Debian
+ apt-get
+ systemd
```

当前 Adapter 可以补齐基础工具、Docker Engine + Compose 和 Tailscale。

如果发行版不在自动安装范围，但目标 Linux 已经具备 Host Contract 所需的 Docker Engine + Compose 和基础工具，则不得仅因发行版未知而拒绝部署，应按 Compatible 路径继续。

如果系统已存在 Docker 但缺少 Compose v2，安装器默认拒绝自动替换既有 Runtime；如果检测到可能与 Docker CE 冲突的容器包，也默认停止并要求显式处理，避免破坏已有工作负载。

## 6. 支持等级

- `Verified`：完成 CI 或真实宿主安装、重复安装和基础运行验证；
- `Supported`：存在正式 Host Adapter，并处于维护范围；
- `Compatible`：满足 Host Contract，但未完成完整验证或不存在专用 Adapter；
- `Unsupported`：缺少必要能力。

当前 M1 首要实机验证目标是 Ubuntu/Debian 系的 amd64/arm64 Host；Oracle Cloud 只是其中一个部署环境。

## 7. 幂等与安全

Host Adapter 必须：

- 已满足依赖时优先复用；
- 重复执行不删除 `state/`、`secrets/` 或已有 Docker Network；
- 失败时不主动卸载或覆盖既有容器运行时；
- 不在业务模块中散布发行版判断；
- 不因扩大兼容范围而顺带引入第二容器运行时。

## 8. 非目标

Host Contract 当前不负责自动适配所有 Linux、自动修改云厂商 Security List / NSG、自动配置家庭路由 NAT、自动建立公网 IP，也不替代业务模块自身健康检查。

机器可读契约位于 `manifests/host-contract.json`；安装器与 CI 应以 Manifest 为机器执行依据，本文件负责语义说明。
