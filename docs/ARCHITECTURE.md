# Server Edge 架构蓝图

## 1. 定位

Server Edge 是单节点或多节点可复用的边缘服务底座。它采用模块化、可插拔和最小依赖设计，但不把单台边缘服务器强行演化为重型微服务平台。

目标：长期、稳定、高效、安全、可恢复、可替换。

## 2. 固定一级能力域

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
| `infra` | 主机初始化、网络、管理面、存储、安全、备份 | 是 |
| `app-hub` | 通用应用承载 | 是 |
| `proxy-hub` | 代理聚合、健康检查、出站策略 | 是 |
| `ai-gateway` | AI API、模型、Provider、Key 与请求调度 | 是 |
| `ai-workers` | 云端 AI Worker / Agent 执行与工具调用 | 是 |
| `public-edge` | 公网入口、域名、TLS、反向代理 | 是 |

`infra` 是基础设施域，其余五个均是可插拔能力模块。

## 3. 逻辑数据流

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

当前 Overlay 可以由 Tailscale 实现，但架构只依赖“覆盖网络/管理面”能力。

## 4. 网络平面

逻辑上至少区分：

- Management：SSH、私有管理、节点互联、故障恢复。
- Ingress：Public Edge 到目标能力域。
- Service：明确的跨模块 API 调用。
- Egress：需要代理的服务到 Proxy Hub。
- Data：数据库、缓存和持久化服务。

一个逻辑平面可以对应多个 Docker Network。不得把“同一平面”误解为“所有服务共用同一 bridge”。

跨 Compose 的 `edge_*` 网络由 `infra/network` 唯一声明、创建和维护；业务模块只能按 `external: true` 引用。

## 5. 初始化与运行

首次初始化、灾难恢复和全量重建存在明确前置关系：

```text
infra bootstrap
    ↓
目录 / 权限 / 网络 / 存储 / Secret 路径
    ↓
可插拔业务模块部署
```

这属于 Provisioning Dependency，不属于 Runtime Dependency。

运行期各业务模块不得依赖固定启动顺序，必须通过超时、有限重试、健康检查和故障降级恢复依赖。

## 6. 宿主运行布局

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

- `releases/`：不可变代码与配置模板。
- `state/`：模块持久状态。
- `secrets/`：本地敏感数据。
- `runtime/`：安装器和运行时元数据。
- `backups/`：一致性备份产物。
- `shared/assets/`：可选的版本化、校验、只读大型资产。

## 7. 共享大型资产

允许不同模块共享大型不可变资产，但必须满足：

- 只读挂载；
- 有版本和校验值；
- 不包含 Secret；
- 不包含模块运行状态；
- 可重新获取或重新生成；
- 不以直接共享另一模块 `data/` 的方式实现。

## 8. 管理面

Overlay Network 归属：

```text
infra/network/overlay/
```

当前可使用 Tailscale，职责包括 SSH、节点互联、私有管理和故障救援。

任何业务组件都不得成为服务器管理面的唯一依赖。

## 9. 实现边界

当前实现可以是：

```text
proxy-hub   -> Mihomo
public-edge -> Caddy
ai-workers  -> Delta / 其他 AI Worker 平台
```

这些名字不得升级为一级架构名。替换具体实现不应要求重构一级目录或整体网络模型。
