# Server Edge

Server Edge 是面向云主机与本地 Linux 主机的模块化边缘服务平台。它不绑定 Oracle、Ubuntu 或某一类物理设备；上层能力模块统一依赖 Host Contract，宿主差异由 `infra/host` 处理。

```text
server-edge/
├── infra/
├── app-hub/
├── proxy-hub/
├── ai-gateway/
├── ai-workers/
└── public-edge/
```

`infra` 是初始化与管理底座；其余五个模块均为可插拔能力。能力名稳定，具体实现可替换。

## 部署目标

Server Edge 面向满足 Host Contract 的 Linux 主机，包括：

- Oracle Cloud、AWS、Azure、Google Cloud、Hetzner、Vultr、DigitalOcean 等云主机；
- 家用服务器、迷你主机、工作站、Bare Metal 等本地 Linux 主机。

Oracle Cloud、Ubuntu、本地服务器都只是部署目标，不是架构身份。

支持等级：

- `Verified`：完成 CI 或实机验证；
- `Supported`：存在正式 Host Adapter；
- `Compatible`：满足 Host Contract，但尚未完成完整验证。

## M1 Portable Linux Infra

M1 已完成。

已实现：

- Host Detect；
- Host Contract 校验；
- `apt + systemd` 首个 Adapter；
- Docker Engine + Compose Runtime；
- Tailscale Overlay；
- `edge_*` 受管网络；
- Infra 健康检查；
- Release Shell 可执行位恢复；
- 静态 CI 与重复安装验证。

首个 Verified Target：

```text
Oracle Cloud
Ubuntu 24.04 Noble
arm64
apt-get + systemd
Docker Engine + Compose v2
Tailscale connected
```

GitHub bootstrap 的最小前置是 Linux、root/sudo、`curl` 和 `tar`。Ubuntu/Debian + systemd 可自动补齐运行环境；其他 Linux 如果已具备兼容 Docker Engine + Compose 和基础工具，可按 Compatible 路径继续部署。

Tailscale Overlay 支持：

```text
SERVER_EDGE_OVERLAY=auto      默认
SERVER_EDGE_OVERLAY=off
SERVER_EDGE_OVERLAY=required
```

自动认证 Secret 路径：

```text
/opt/server-edge/secrets/infra/tailscale-auth-key
```

## 文档

- `docs/ARCHITECTURE.md`：系统组成、边界、网络与运行模型；
- `docs/GOVERNANCE.md`：允许和禁止的变更；
- `docs/HOST-CONTRACT.md`：Linux 宿主必须满足的能力契约；
- `manifests/`：机器可读系统契约；
- `profiles/`：选择本节点启用的能力模块；
- `install/`：安装、Patch、回滚和验证入口。

所有实现与变更必须遵循 `docs/ARCHITECTURE.md`、`docs/GOVERNANCE.md` 和 `docs/HOST-CONTRACT.md`。

## GitHub 安装

生产安装应锁定 Tag、Release 或 Commit SHA，不直接跟随 `main`。

公开仓库可直接取得引导脚本：

```bash
curl -fsSL \
  https://raw.githubusercontent.com/fongap/server-edge/<REF>/install/bootstrap.sh \
  | sudo bash -s -- --repo fongap/server-edge --ref <REF>
```

默认安装根目录：`/opt/server-edge`，可通过 `--root` 覆盖。

## Profile

Profile 只描述启用哪些能力模块，不描述云厂商或 Linux 发行版：

```bash
sudo /opt/server-edge/current/install/install.sh \
  --root /opt/server-edge \
  --profile profiles/default.json
```

禁止建立 `oracle.json`、`aws.json`、`home-server.json` 这类宿主环境 Profile。宿主差异由 `infra/host` 自动识别并处理。

## Patch

Patch 是 release-to-release 的受控变更，不等于 `git pull`：

```bash
sudo /opt/server-edge/current/install/patch.sh --ref <TARGET_REF>
```

Patch 必须在目标版本 `patches/index.json` 中声明来源版本、变更模块与回滚条件。未声明兼容路径时默认拒绝 Patch。

## 回滚

```bash
sudo /opt/server-edge/current/install/rollback.sh --to <RELEASE_ID>
```

回滚只切换已验证 Release；涉及不可逆数据迁移时必须由对应模块提供恢复钩子。
