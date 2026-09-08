# Server Edge 架构蓝图

## 1. 定位

Server Edge 是面向云主机与本地 Linux 主机的统一边缘服务平台。目标是长期、稳定、安全、可恢复、可替换、可迁移。

Server Edge 不把 Oracle、AWS、Ubuntu、Debian 或本地服务器作为架构身份；它们只是部署目标。宿主差异统一由 `infra/host` 处理。

## 2. 固定能力域

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
| `infra` | Host Adapter、Runtime、网络、管理面、存储、安全、备份 |
| `app-hub` | 通用应用承载 |
| `proxy-hub` | 节点聚合、订阅分发、健康检查、可选显式出口 |
| `ai-gateway` | AI API、模型、Provider、Key 与请求调度 |
| `ai-workers` | AI Worker / Agent 执行与工具调用 |
| `public-edge` | 公网入口、域名、TLS、反向代理 |

能力名稳定，具体软件实现可替换。

## 3. Host Contract

```text
Server Edge
    │
    ├── Host Contract
    │      └── Compatible Linux Host
    │          ├── Cloud VM
    │          └── Local Host
    │
    └── Capability Domains
```

`infra/host` 是唯一宿主适配入口。上层模块不得判断云厂商、Linux 发行版、包管理器或服务管理器。

支持等级统一为 `Verified / Supported / Compatible / Unsupported`。

## 4. Profile

Profile 只描述启用哪些能力模块，不描述部署环境。

禁止：

```text
profiles/oracle.json
profiles/aws.json
profiles/ubuntu.json
profiles/home-server.json
```

## 5. 平台配置模型

Server Edge 的能力结构固定，部署参数外置。域名、端口、绑定、开关、资源、健康检查等不得散落为跨模块硬编码。

```text
Release defaults
      │ 首次初始化
      ▼
/opt/server-edge/config/
      │
      ├── <module>.env          模块实例参数
      └── publications.json     平台公网发布策略

/opt/server-edge/secrets/       Secret
/opt/server-edge/runtime/contracts/  跨模块运行契约
```

规则：

- 模块默认值位于 `<module>/config/defaults.env`；
- 实例配置位于 `/opt/server-edge/config/<module>.env`；
- 实例配置创建后跨 Release 保留，升级不得覆盖；
- 模块只能读取自己的实例配置；
- Secret 与普通配置分离；
- 跨模块参数通过运行契约传递，不读取对方 `.env`；
- 机器规则见 `manifests/configuration.json`。

详细说明见 `docs/CONFIGURATION.md`。

## 6. 域名与 Public Edge

域名属于 Server Edge 的平台发布策略，不属于某个业务模块内部实现。

统一配置：

```text
/opt/server-edge/config/publications.json
```

示例：

```json
{
  "schema_version": 1,
  "services": {
    "proxy-subscription": {"origin": "https://sub.example.com"},
    "ai-gateway": {"origin": "https://api.example.com"},
    "app-main": {"origin": "https://app.example.com"}
  }
}
```

业务模块只声明稳定 `publication_key` 和内部服务端点；`public-edge` 统一负责 80/443、域名、TLS 和反向代理。

因此：

```text
业务模块服务契约 + publications.json
                 │
                 ▼
             public-edge
                 │
                 ▼
          Domain / HTTPS
```

更换域名不得要求修改业务模块代码。

## 7. 跨模块运行契约

运行期发现信息位于：

```text
/opt/server-edge/runtime/contracts/
```

契约必须最小、机器可读、无 Secret。

例如 Proxy Hub 的统一出口端口可配置，因此 `ai-gateway`、`ai-workers`、`app-hub` 不得硬编码 `proxy-hub:7890`，而应消费 `proxy-egress` 运行契约。

同理，Public Edge 不读取 Proxy Hub 配置或状态，只消费 `proxy-subscription` 服务契约和平台发布注册表。

## 8. 网络平面

逻辑上区分：

- Management：SSH、私有管理、节点互联、恢复；
- Ingress：Public Edge 到目标能力；
- Service：明确跨模块 API/Feed；
- Egress：需要代理的服务到 Proxy Hub；
- Data：数据库、缓存、持久化服务。

所有跨模块 `edge_*` 网络由 `infra/network` 唯一声明和创建，模块只能 `external: true` 引用。

一个逻辑平面可以对应多个 Docker Network，不允许所有服务共用一个大 bridge。

## 9. Proxy Hub 数据流

节点聚合是 Proxy Hub 核心能力，Provider 至少一个。LOCAL 只是可选附加节点。

```text
Provider A ─┐
Provider B ─┼──→ AUTO / FALLBACK / PROXY
LOCAL ──────┘          │
                       ├── Subscription Feed
                       └── optional Unified Egress
```

订阅、LOCAL 节点、统一出口、域名、端口和绑定方式彼此独立配置。

Proxy Hub 对其他模块发布统一出口时，通过 `proxy-egress` 运行契约公布实际服务端点；消费者不依赖固定端口。

订阅 Feed 通过 `proxy-subscription` 服务契约声明内部端点，通过 `publications.json` 可选绑定公网域名。

## 10. 管理面

Overlay Network 归 `infra/network/overlay` 管理，当前实现可为 Tailscale。

用途：SSH、节点互联、私有后台、运维、恢复。业务模块不得成为管理面的唯一依赖。

## 11. 初始化与运行

```text
host detect
    ↓
host validate
    ↓
infra bootstrap
    ↓
目录 / 权限 / Runtime / 网络 / 配置 / Secret 路径
    ↓
可插拔业务模块部署
```

这是 Provisioning Dependency，不是 Runtime 启动顺序。运行期模块必须通过健康检查、有限重试和故障降级恢复依赖。

## 12. 宿主布局

```text
/opt/server-edge/
├── current -> releases/<release-id>
├── releases/
├── config/
│   ├── publications.json
│   └── <module>.env
├── state/
├── secrets/
├── runtime/
│   └── contracts/
├── backups/
└── shared/
    └── assets/
```

- `releases/`：不可变代码、模板；
- `config/`：持久非敏感实例配置；
- `state/`：持久业务状态与缓存；
- `secrets/`：敏感数据；
- `runtime/contracts/`：跨模块运行发现；
- `backups/`：备份；
- `shared/assets/`：可选只读共享资产。

## 13. 实现边界

当前实现可以是：

```text
runtime      -> Docker Engine + Compose
overlay      -> Tailscale
proxy-hub    -> Mihomo + minimal static Feed
public-edge  -> Caddy
ai-workers   -> Delta / 其他 AI Worker 平台
```

具体实现不得升级为一级架构名。替换具体实现不应要求重构一级目录、配置模型或整体网络模型。
