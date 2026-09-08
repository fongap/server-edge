# Server Edge Host Contract

## 1. 目的

Host Contract 定义 Server Edge 对 Linux 宿主的最小能力要求。

它不用于绑定某个云厂商、发行版或硬件型号，而用于回答一个问题：

> 这台 Linux 主机是否具备运行 Server Edge 的必要条件？

## 2. 适用范围

Server Edge 可部署在满足本契约的：

- 云主机；
- VPS；
- 本地服务器；
- Mini PC；
- Bare Metal；
- 其他兼容 Linux 主机。

Oracle Cloud、AWS、Azure、Ubuntu、Debian、Home Server 等都只是部署目标。

## 3. 必需能力

### 操作系统

- 必须是 Linux；
- 必须提供可用的 `/proc` 与 `/sys`；
- 必须支持常规 POSIX 文件权限。

### CPU 架构

安装器必须识别当前 CPU 架构。当前优先验证：

- `amd64` / `x86_64`；
- `arm64` / `aarch64`。

其他架构只有在所有必需组件均可用时才可进入 Compatible 路径。

### 权限

安装阶段必须具备 root 权限，或具备可无交互提升到 root 的 sudo 能力。

运行期业务容器不得因此默认获得宿主 root 权限。

### 基础工具

宿主必须最终具备：

```text
bash
curl
tar
ca-certificates
jq
```

安装器可以通过 Host Adapter 补齐缺失工具。

### 容器运行时

当前 Server Edge 运行时契约固定为：

```text
Docker Engine
Docker Compose v2
```

必须满足：

- Docker daemon 可用；
- 当前安装流程可执行 `docker`；
- `docker compose` 可用；
- Docker network 可创建、查询和复用。

当前不把 Podman 或 Kubernetes 视为等价运行时。

### 文件系统

宿主必须允许创建并持久保存：

```text
/opt/server-edge/
```

并支持：

- 目录权限控制；
- 符号链接；
- 原子替换当前 Release 链接；
- 持久化 state、secrets、backups 与 runtime 数据。

### 网络

宿主必须具备：

- IPv4 或 IPv6 基础联网能力；
- DNS 解析；
- 出站 HTTPS；
- Docker bridge network 能力。

公网 IP 不是必需条件。

### 管理面 Overlay

Overlay Network 是推荐管理能力，不是所有节点的强制前置。

当前实现可以使用 Tailscale。

需要 Tailscale 时，宿主应提供其要求的网络和服务能力；如目标节点明确不启用 Overlay，则不能因缺少 Tailscale 而否定整个 Host Contract。

## 4. 宿主探测字段

`infra/host` 应统一输出标准化探测结果，例如：

```text
os=linux
arch=arm64
environment=cloud
package_manager=apt
service_manager=systemd
container_runtime=docker
compose=v2
public_ip=yes
private_ip=yes
overlay=available
```

未知字段必须显式表示为 `unknown`，不得猜测。

## 5. 环境类型

环境类型只用于能力判断：

```text
environment=cloud|local|unknown
```

它不能决定一级目录、模块实现或 Profile 名称。

`cloud` 与 `local` 使用同一套 Server Edge 架构。

## 6. Host Adapter

Host Adapter 只处理宿主差异，例如：

- 包管理器；
- 服务管理器；
- 依赖安装；
- 容器运行时准备；
- 宿主级网络能力检查。

Host Adapter 不处理业务模块配置。

初期可以只实现已实际验证的平台；不得为了宣称“支持任意 Linux”预先维护大量未经测试的 Adapter。

## 7. 已满足依赖的未知发行版

如果安装器无法识别发行版，但目标 Linux 已经满足所有必需 Host Contract：

```text
Docker Engine     available
Compose v2        available
bash/curl/tar/jq  available
filesystem        compatible
network           compatible
```

则不得仅因发行版未知而拒绝部署。

此时应标记为：

```text
Compatible
```

并继续执行能力验证。

## 8. 支持等级

### Verified

完成 CI 或真实宿主安装、重复安装和基础运行验证。

### Supported

存在正式 Host Adapter，并处于维护范围。

### Compatible

满足 Host Contract，但尚未完成完整验证或不存在专用 Adapter。

### Unsupported

缺少必要 Host Contract 能力。

## 9. 非目标

Host Contract 当前不负责：

- 自动适配所有 Linux 发行版；
- 抽象 Docker 与 Podman；
- 自动修改云厂商 Security List / NSG；
- 自动配置家用路由器 NAT；
- 自动建立公网 IP；
- 替代业务模块自身健康检查。

## 10. 机器可读契约

机器可读定义位于：

```text
manifests/host-contract.json
```

安装器与 CI 应以该 Manifest 为执行依据；本文件负责语义说明。
