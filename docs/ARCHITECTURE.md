# Server Edge 架构蓝图

## 1. 定位

Server Edge 是面向云主机与本地 Linux 主机的统一边缘服务平台。它采用模块化、可插拔和最小依赖设计，上层能力模块与宿主环境解耦，宿主差异统一由 `infra/host` 处理。

目标：长期、稳定、高效、安全、可恢复、可替换、可迁移。

Server Edge 不把 Oracle、AWS、Ubuntu、Debian、Home Server 或某一类硬件作为架构身份。这些都只是部署目标。

## 2. 宿主抽象

Server Edge 通过 Host Contract 约束宿主能力：

```text
Server Edge
    │
    ├── Host Contract
    │      ↓
    │   Compatible Linux Host
    │   ├── Cloud VM
    │   └── Local Host
    │
    └── Capability Domains
           ├── infra
           ├── app-hub
           ├── proxy-hub
           ├── ai-gateway
           ├── ai-workers
           └── public-edge
```

宿主只需要满足 `docs/HOST-CONTRACT.md` 定义的能力。发行版、云厂商、包管理器、服务管理器和底层网络差异不得泄漏到业务模块。

`infra/host` 是唯一宿主适配入口。

## 3. 固定一级能力域

```text
server-edge/
├── infra/
├── app-hub/
├── proxy-hub/
├── ai-gateway/
├── ai-workers/
└── public-edge/
```

| 能力域 | 长期职责 | 当前实现可替换 |
| --- | --- | --- |
| `infra` | Host Adapter、主机初始化、网络、管理面、存储、安全、备份 | 是 |
| `app-hub` | 通用应用承载 | 是 |
| `proxy-hub` | 代理聚合、健康检查、出站策略 | 是 |
| `ai-gateway` | AI API、模型、Provider、Key 与请求调度 | 是 |
| `ai-workers` | 云端或本地 AI Worker / Agent 执行与工具调用 | 是 |
| `public-edge` | 公网入口、域名、TLS、反向代理 | 是 |

`infra` 是基础设施域，其余五个均是可插拔能力模块。

## 4. `infra` 内部边界

推荐语义结构：

```text
infra/
├── host/          # Host Contract 检测与适配
├── runtime/       # 容器运行时
├── network/
│   ├── container/
│   └── overlay/
├── security/
└── storage/
```

当前统一运行时仍为 Docker Engine + Compose。是否引入其他容器运行时属于后续独立架构决策，不在当前 Host 抽象中解决。

Overlay Network 仍属于：

```text
infra/network/overlay/
```

当前可由 Tailscale 实现，但架构只依赖“私有覆盖网络/管理面”能力。

## 5. Host Contract

Host Contract 关注能力，不绑定发行版名称。至少描述：

```text
Linux
├── architecture
├── privilege
├── package manager
├── service manager
├── container runtime capability
├── filesystem capability
├── network capability
└── optional overlay capability
```

典型检测结果可以是：

```text
os=linux
arch=arm64
package_manager=apt
service_manager=systemd
container_runtime=docker
environment=cloud
```

也可以是：

```text
os=linux
arch=amd64
package_manager=apt
service_manager=systemd
container_runtime=docker
environment=local
```

对 `app-hub`、`proxy-hub`、`ai-gateway`、`ai-workers`、`public-edge` 来说，两者没有架构差异。

## 6. 支持等级

部署目标分为：

- `Verified`：完成 CI 或实机验证；
- `Supported`：存在正式 Host Adapter；
- `Compatible`：满足 Host Contract，但尚未完成完整验证；
- `Unsupported`：缺少必要宿主能力。

不得把“理论可运行”直接宣传为“正式支持”。

## 7. 环境与 Profile

Cloud 与 Local 不拆分为不同产品，也不拆成不同架构。

禁止：

```text
profiles/oracle.json
profiles/aws.json
profiles/home-server.json
```

Profile 只描述启用哪些能力模块。宿主环境由 `infra/host` 探测。

环境差异只用于能力判断，例如：

```text
public_ip=yes|no
private_ip=yes|no
nat=yes|no
ipv6=yes|no
overlay=available|unavailable
```

如果本地主机没有公网能力，可以关闭 `public-edge`，其他模块仍应正常运行。

## 8. 逻辑数据流

```text
                         Internet
                            │
                       public-edge
                            │
                ┌───────────┼───────────┐
                │           │           │
             app-hub    ai-gateway   ai-workers
                            ▲           │
                            └───────────┘
                                AI API

需要代理的出站：

app-hub / ai-gateway / ai-workers
                │
                ▼
            proxy-hub
                │
                ▼
             Internet
```

管理面与业务面分离：

```text
Operator
   │
Overlay Network
   │
infra/network/overlay
   │
SSH / Admin / Recovery
```

## 9. 网络平面

逻辑上至少区分：

- Management：SSH、私有管理、节点互联、故障恢复；
- Ingress：Public Edge 到目标能力域；
- Service：明确的跨模块 API 调用；
- Egress：需要代理的服务到 Proxy Hub；
- Data：数据库、缓存和持久化服务。

一个逻辑平面可以对应多个 Docker Network。不得把“同一平面”误解为“所有服务共用同一 bridge”。

跨 Compose 的 `edge_*` 网络由 `infra/network` 唯一声明、创建和维护；业务模块只能按 `external: true` 引用。

## 10. 初始化与运行

首次初始化、灾难恢复和全量重建存在明确前置关系：

```text
host detect
    ↓
host validate
    ↓
infra bootstrap
    ↓
目录 / 权限 / Runtime / 网络 / 存储 / Secret 路径
    ↓
可插拔业务模块部署
```

这属于 Provisioning Dependency，不属于 Runtime Dependency。

运行期各业务模块不得依赖固定启动顺序，必须通过超时、有限重试、健康检查和故障降级恢复依赖。

## 11. 宿主运行布局

仓库代码与运行状态分离：

```text
/opt/server-edge/
├── current -> releases/<release-id>
├── releases/
├── state/
├── secrets/
├── runtime/
├── backups/
└── shared/
    └── assets/
```

- `releases/`：不可变代码与配置模板；
- `state/`：模块持久状态；
- `secrets/`：本地敏感数据；
- `runtime/`：安装器和运行时元数据；
- `backups/`：一致性备份产物；
- `shared/assets/`：可选的版本化、校验、只读大型资产。

## 12. 共享大型资产

允许不同模块共享大型不可变资产，但必须满足：

- 只读挂载；
- 有版本和校验值；
- 不包含 Secret；
- 不包含模块运行状态；
- 可重新获取或重新生成；
- 不以直接共享另一模块 `data/` 的方式实现。

## 13. 实现边界

当前实现可以是：

```text
runtime      -> Docker Engine + Compose
overlay      -> Tailscale
proxy-hub    -> Mihomo
public-edge  -> Caddy
ai-workers   -> Delta / 其他 AI Worker 平台
```

这些具体实现不得升级为一级架构名。替换具体实现不应要求重构一级目录或整体网络模型。
