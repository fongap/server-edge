# Server Edge 架构基线

## 1. 定位

Server Edge 是面向云主机与本地 Linux 主机的模块化服务底座。当前采用单机优先设计，重点解决宿主适配、模块边界、网络隔离、配置治理、公网入口与可恢复部署；多节点能力通过管理 Overlay 和明确契约逐步扩展。

本文件描述长期稳定的架构边界，不代表所有能力已经完成实现。模块当前完成度以根目录 `README.md` 和各模块 `README.md` 为准。

Server Edge 不把 Oracle、AWS、Ubuntu、Debian、Mini PC 或某一种物理设备作为架构身份。宿主差异统一进入 `infra/host`。

## 2. 固定能力域

一级能力域固定为：

```text
server-edge/
├── infra/
├── app-hub/
├── proxy-hub/
├── ai-gateway/
├── ai-workers/
└── public-edge/
```

| 能力域 | 长期职责 |
| --- | --- |
| `infra` | Host Adapter、容器 Runtime、网络、管理面、存储、安全与备份基础 |
| `app-hub` | 通用应用承载 |
| `proxy-hub` | 节点聚合、订阅分发、健康检查与可选显式出口 |
| `ai-gateway` | AI API、Provider、模型、Key 与请求调度 |
| `ai-workers` | AI Worker / Agent 执行与工具调用 |
| `public-edge` | 公网入口、域名、TLS 与反向代理 |

一级目录表达能力，不表达具体软件。当前可以使用 Docker、Tailscale、Mihomo、Caddy 或 Delta，但替换这些实现不应要求修改一级能力域。

## 3. 逻辑分层

逻辑上可将 Server Edge 理解为两部分，但不新增对应一级目录：

```text
Platform Foundation
├── Host / Runtime / Network / Storage / Security   -> infra
└── Public Ingress                                 -> public-edge

Capability Modules
├── app-hub
├── proxy-hub
├── ai-gateway
└── ai-workers
```

`infra` 是 Provisioning 前置，不是运行期中央编排器。业务能力完成部署后，应依靠自己的健康检查、重试和显式依赖恢复运行，而不是依赖固定启动顺序。

## 4. Host Contract

`infra/host` 是唯一宿主适配入口。

上层能力模块不得判断或适配：

- 云厂商；
- Linux 发行版；
- CPU 架构差异；
- 包管理器；
- 服务管理器；
- 云主机或本地主机身份。

可部署性由 `docs/HOST-CONTRACT.md` 与 `manifests/host-contract.json` 定义。

## 5. Profile

Profile 只描述启用哪些能力域，不描述宿主环境。

正确方向：

```text
minimal
proxy
ai
full
```

禁止按部署环境命名：

```text
oracle
aws
ubuntu
home-server
```

宿主是什么由 Host Detect 判断；要启用什么由 Profile 决定，两者保持解耦。

## 6. 配置与数据边界

Server Edge 将 Release、实例配置、Secret、持久状态和运行发现分开：

```text
Release defaults
      │
      ▼
/opt/server-edge/config/           实例非敏感配置
/opt/server-edge/secrets/          Secret
/opt/server-edge/state/            持久业务状态
/opt/server-edge/runtime/          可重建运行状态
/opt/server-edge/runtime/contracts/跨模块运行契约
```

核心规则：

- 默认配置跟随 Release；
- 实例配置跨 Release 保留；
- 模块只读取自己的配置；
- Secret 不进入普通配置；
- 跨模块动态端点通过运行契约发现；
- 模块不得读取其他模块的状态目录、数据库 Schema 或内部文件布局。

详细规则见 `docs/CONFIGURATION.md`。

## 7. 跨模块通信

跨模块依赖必须显式。

允许的形式包括：

- API；
- 明确协议的网络端点；
- Feed；
- 事件；
- 最小机器可读运行契约。

运行契约位于：

```text
/opt/server-edge/runtime/contracts/
```

契约应只包含消费者真正需要的信息，不包含 Secret。

例如 Proxy Hub 对外提供统一出口时，由 `proxy-egress` 契约公布实际端点；消费者不应硬编码 `7890`。Public Edge 发布 Proxy Hub Feed 时，只消费 `proxy-subscription` 契约与平台发布注册表，不读取 Proxy Hub 的 `.env` 或状态目录。

## 8. 公网入口

公网发布统一归 `public-edge`。

```text
Capability Service Contract
            +
/opt/server-edge/config/publications.json
            │
            ▼
        public-edge
            │
            ▼
      Domain / TLS / HTTPS
```

业务模块声明稳定服务身份和内部端点，平台发布注册表决定是否以及通过哪个 Origin 对外发布。

更换域名不应要求修改业务模块实现。

默认只有 Public Edge 管理公网 `80/443`。数据库、缓存、内部 Admin API、Proxy Controller 与 Docker API 不应直接暴露公网。

## 9. 出站能力

`proxy-hub` 是统一代理出口能力域，但统一出口本身可以关闭。

Proxy Hub 的核心职责首先是节点聚合与订阅能力；LOCAL 节点、统一显式出口、Feed 公网发布彼此独立。

默认采用显式 HTTP/SOCKS 出口，不把全局 TUN、宿主透明代理或大范围 iptables 劫持作为平台基础能力。

## 10. 网络模型

逻辑上区分以下通信平面：

- Management：SSH、私有管理、节点互联与恢复；
- Ingress：Public Edge 到业务能力；
- Service：明确的跨模块 API / Feed；
- Egress：需要代理的模块到 Proxy Hub；
- Data：数据库、缓存等内部数据服务。

跨模块 `edge_*` Docker Network 由 `infra/network` 唯一创建和维护，业务模块只能引用。

网络按真实通信关系创建，而不是按架构图预创建。只有两个或多个运行服务确实需要直接通信时，才应增加对应 Docker Network；不为尚未实现的模块提前铺设网络。

禁止所有模块共享一个无边界的大 bridge，也避免为每个抽象概念机械创建独立网络。

## 11. 管理面

Overlay Network 属于 `infra/network/overlay`，当前实现可为 Tailscale。

用途包括：

- SSH；
- 私有管理入口；
- 节点互联；
- 运维；
- 故障恢复。

Overlay 是管理面能力，不属于 Proxy Hub 的业务代理出口，也不应由某个业务模块独占。

## 12. 宿主布局

统一实例布局：

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

- `releases/`：不可变代码、模板和默认值；
- `config/`：实例非敏感配置；
- `secrets/`：敏感数据；
- `state/`：持久业务状态；
- `runtime/`：可重建运行状态；
- `runtime/contracts/`：跨模块运行发现；
- `backups/`：恢复所需备份；
- `shared/assets/`：可选的大型只读共享资产。

## 13. 当前实现与架构身份

当前实现选择包括：

```text
container runtime  -> Docker Engine + Compose v2
overlay            -> Tailscale
proxy-hub          -> Mihomo
public-edge        -> Caddy
```

这些属于实现选择，不属于一级架构名称。

当前 `app-hub`、`ai-gateway`、`ai-workers` 仍处于待开发阶段。架构为它们保留边界，但不因此提前创建不需要的常驻组件、配置文件、网络或数据服务。

## 14. 非目标

当前阶段不把 Server Edge 建成：

- Kubernetes 替代品；
- 通用 PaaS；
- 多运行时兼容层；
- 通用集群调度器；
- Service Mesh；
- 自建 Secret Manager、日志平台或监控平台。

新增平台级组件必须由真实需求驱动，而不是为了抽象完整性或未来假设。

## 15. 架构变更边界

以下变化属于架构级变更，应单独评审：

- 一级能力域增删、改名或职责改变；
- Host Contract 基础能力模型改变；
- 公网入口、管理面或统一出站模型改变；
- 引入第二容器运行时；
- 引入 Kubernetes、Service Mesh 等平台级依赖；
- 打破模块可插拔或配置/Secret/状态分离原则。

普通功能开发、Bug 修复和具体软件替换不应顺带改变上述架构基线。