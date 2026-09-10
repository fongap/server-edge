# Server Edge

Server Edge 是面向云主机与本地 Linux 主机的模块化服务底座，采用单机优先设计，并为后续多节点互联保留清晰边界。

> 当前处于开发阶段。仓库中的一级能力域表示长期架构边界，不等于对应能力均已完成实现。

```text
server-edge/
├── infra/
├── app-hub/
├── proxy-hub/
├── ai-gateway/
├── ai-workers/
└── public-edge/
```

能力名保持稳定，Docker、Tailscale、Mihomo、Caddy 等具体实现可以替换，不提升为一级架构身份。

## 当前状态

| 能力域 | 职责 | 当前状态 |
| --- | --- | --- |
| `infra` | Host、Runtime、网络、管理面、存储、安全、备份 | 已实现基础能力并完成首个实机验证 |
| `proxy-hub` | 节点聚合、订阅分发、可选统一出口 | 已实现当前基础能力 |
| `public-edge` | 公网入口、域名、TLS、反向代理 | 已实现 `proxy-subscription` 最小发布路径 |
| `app-hub` | 通用应用承载 | 待开发 |
| `ai-gateway` | AI API、Provider、模型、Key 与请求调度 | 待开发 |
| `ai-workers` | AI Worker / Agent 执行与工具调用 | 待开发 |

当前工作重点是稳定架构、契约与文档，再逐步实现其余能力域。

## 架构原则

```text
能力边界      长期稳定
具体实现      可替换
宿主差异      只进入 infra/host
实例参数      与 Release 分离
Secret        与普通配置分离
跨模块通信    通过明确契约
公网入口      统一归 public-edge
跨模块网络    统一由 infra 管理
```

Server Edge 不以 Oracle、AWS、Ubuntu、Debian 或某一种硬件作为架构身份。它们只是部署目标；可部署性由 Host Contract 判断。

## 实例布局

```text
/opt/server-edge/
├── current -> releases/<release-id>
├── releases/
├── config/
├── secrets/
├── state/
├── runtime/
│   └── contracts/
├── backups/
└── shared/
    └── assets/
```

职责固定：

- `releases/`：Release 内的代码、模板和默认值；
- `config/`：实例级非敏感配置；
- `secrets/`：敏感数据；
- `state/`：持久业务状态；
- `runtime/`：可重建运行状态与跨模块运行契约；
- `backups/`：备份；
- `shared/assets/`：可选的大型只读共享资产。

业务模块不得通过读取其他模块的 `.env`、状态目录或内部文件布局形成隐式耦合。

## Host Contract

Server Edge 面向满足 Host Contract 的 Linux 主机，包括云主机、VPS、本地服务器和 Mini PC。

支持等级：

- `Verified`：完成规定的 CI 或真实宿主验证；
- `Supported`：存在正式 Host Adapter；
- `Compatible`：满足能力契约，但尚未完整验证；
- `Unsupported`：缺少必要能力。

当前首个 Verified Target 为 Oracle Cloud / Ubuntu 24.04 Noble / arm64 / Docker Engine + Compose v2。

## 文档

- `docs/ARCHITECTURE.md`：稳定架构边界、能力关系与长期模型；
- `docs/GOVERNANCE.md`：开发和变更必须遵守的红线；
- `docs/HOST-CONTRACT.md`：宿主最小能力与支持等级；
- `docs/CONFIGURATION.md`：配置、Secret、状态与运行契约的所有权；
- `<module>/README.md`：该能力域当前已经实现的行为；
- `manifests/`：当前机器可读契约与版本事实。

## 开发验证安装

安装应锁定 Tag、Release 或 Commit SHA，不直接依赖 `main` 或 `latest`：

```bash
curl -fsSL \
  https://raw.githubusercontent.com/fongap/server-edge/<REF>/install/bootstrap.sh \
  | sudo bash -s -- --repo fongap/server-edge --ref <REF>
```

默认根目录为 `/opt/server-edge`。

仓库已经包含 Patch 与 Rollback 框架，但当前项目仍处于开发阶段；在正式声明升级路径和恢复保证之前，不把它们视为稳定生产接口。

## 非目标

当前阶段不追求：

- Kubernetes、Service Mesh 或多运行时兼容；
- 通用集群调度器；
- 自建 Secret Manager、日志平台或监控平台；
- 为尚未出现的需求提前增加常驻组件；
- 自动适配所有 Linux 发行版和云厂商。

Server Edge 首先解决的是一台 Linux 主机上的模块化部署、边界隔离、配置治理和可恢复基础，再按真实需求扩展。